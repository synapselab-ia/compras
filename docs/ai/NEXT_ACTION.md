# Next Action — Compras

## F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01 — Implementar limiter distribuído do sign-in privado

**Classe:** `T1 — feature de suporte` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** implementar em código/migration o limiter application-side distribuído definido pela ADR-010, provando atomicidade, fail-closed, trusted source e privacidade em PostgreSQL efêmero/CI, sem realizar writes hosted.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F22 foi integrada em `main` e os runs pós-merge passaram integralmente:

- CI canônica `33880974626`: PASS;
- F22 Private Preview Preflight `33880974672`: PASS.

A F23 revalidou a fronteira atual e fechou a decisão arquitetural em ADR-010:

- Better Auth `auth.api` server-side não herda o rate limiter embutido;
- limiter somente em memória não é enforcement distribuído aceitável;
- Vercel Firewall/WAF será defesa edge obrigatória para exposição hosted mais ampla, mas não é suficiente sozinho;
- o limiter autoritativo application-side usará PostgreSQL compartilhado;
- `x-forwarded-for` só pode ser aceito sob a fronteira Vercel validada e em formato único/estrito;
- email/IP serão convertidos imediatamente em buckets HMAC pseudônimos, sem persistência/log em claro;
- falha do limiter/store deve retornar `unavailable` e nunca chamar Better Auth;
- limite excedido deve mapear para o mesmo resultado externo genérico `rejected` de credenciais inválidas.

F21 continua `ON HOLD`: a superfície Vercel disponível nesta sessão ainda não fornece o readback/CRUD de Deployment Protection/bypasses e sensitive Preview env vars escopadas à branch exigido por seu `resume_when`.

## Execução obrigatória

1. recuperar estado/contexto e confirmar ADR-010/F23 integrada antes de editar;
2. inspecionar `private-admission.ts`, configuração Auth, migrations Auth e testes F20/F22;
3. criar nova migration versionada para namespace/tabela/function do limiter, sem reescrever migrations aplicadas;
4. manter `PUBLIC` sem grants e `compras_auth_runtime` sem ownership/superuser/BYPASSRLS/CREATEROLE;
5. implementar policy versionada:
   - `source`: 120/15 min;
   - `identifier`: 20/15 min;
   - `pair`: 8/5 min;
6. consumir os três buckets atomicamente antes de `auth.api.signInEmail`;
7. usar relógio do PostgreSQL e provar ausência de lost update sob concorrência;
8. derivar buckets HMAC por HKDF/domain separation a partir de `BETTER_AUTH_SECRET`, sem nova secret;
9. implementar resolver hosted que aceite somente `x-forwarded-for` Vercel único e IP válido; chains/ausência/configuração inválida devem falhar fechadas;
10. integrar no Server Action sem alterar o fluxo já validado de cookie/session readback;
11. limite excedido -> `rejected` sem chamar Better Auth;
12. limiter/config/store indisponível -> `unavailable` sem chamar Better Auth;
13. implementar purge oportunístico limitado e indexado para buckets expirados;
14. manter logs sem email, IP, HMAC individual, password, cookie, token, connection string ou payload de sessão;
15. executar red-team unitário/PostgreSQL/Auth, lint, typecheck, testes e build;
16. revisar diff integral e atualizar checkpoint deixando exatamente uma próxima ação.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente identidade/dados fictícios;
- nenhum recurso Vercel/Neon/Redis/KV hosted novo;
- nenhuma environment variable hosted;
- Vercel Authentication não é reduzida;
- signup normal continua fechado;
- `/api/auth/[...path]` continua deny-all;
- sign-in continua Server Action estreita;
- Better Auth não é chamado se limiter bloquear/falhar;
- autenticação continua separada de autorização;
- RLS/domínio não são alterados;
- browser não define origem confiável;
- limiter não armazena email/IP em claro;
- runtime Auth continua sem grants no domínio;
- migration aplicada nunca é reescrita;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo.

## Fonte da tarefa

Executar `tasks/F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01/SPEC.md`, seguindo ADR-010, ADR-009, ADR-007, `docs/architecture/SECURITY.md`, `docs/architecture/DATABASE.md` e as provas F20/F22.

## Critério de encerramento

F24 fecha quando o limiter application-side estiver implementado e provado em PostgreSQL 17 efêmero com concorrência real, fail-closed e privacidade, mantendo o fluxo Auth existente e toda a CI em PASS, sem qualquer provider hosted alterado. Ao final deve existir exatamente uma nova `NEXT_ACTION` executável.
