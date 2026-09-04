# Next Action — Compras

## F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01 — Provisionar e provar preview privado fictício com Better Auth self-hosted

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** materializar em ambiente hospedado descartável a arquitetura já provada na F20, com Vercel Authentication antes de secrets, Better Auth self-hosted, roles PostgreSQL separadas, RLS e somente identidade/dados fictícios.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F20 terminou em PASS na CI `33869932738`:

- `verify`: lint, typecheck, testes e build em PASS;
- `database`: suíte PostgreSQL/RLS existente em PASS;
- `auth-database`: schema Better Auth, boundary de role, red-team de `BYPASSRLS` e integração PostgreSQL Auth/domínio em PASS.

O repositório agora possui Better Auth self-hosted implementado, `better-auth@1.6.23` pinado diretamente, migrations Auth versionadas, signup fechado, cookie/session/sign-out verificados, bootstrap fictício one-shot e isolamento entre Auth e autorização de domínio.

O próximo risco relevante não é mais de implementação local: é provar que a mesma fronteira permanece válida no Preview hospedado real sem ampliar exposição ou usar dados reais.

## Execução obrigatória

1. recuperar o estado real de GitHub, Vercel e Neon antes de qualquer write;
2. revalidar documentação oficial atual aplicável a Deployment Protection, escopo de environment variables, lifecycle de Preview/rollback e PostgreSQL/roles;
3. confirmar Vercel Authentication/Deployment Protection antes de anexar qualquer secret;
4. criar/selecionar ambiente PostgreSQL descartável somente para prova fictícia;
5. criar roles distintas de migration, Auth runtime e domínio runtime, sem privilégios administrativos/BYPASSRLS;
6. aplicar migrations canônicas do domínio `0001..0003` e Auth `0001..0002`;
7. provar isolamento Auth → domínio e domínio → Auth;
8. executar bootstrap one-shot somente com identidade `example.invalid` fictícia e desligá-lo imediatamente;
9. criar autorização/seed fictícios de forma separada, sem hook automático de Auth;
10. anexar ao Preview/branch somente `AUTH_DATABASE_URL`, `DATABASE_URL`, `BETTER_AUTH_SECRET` e `COMPRAS_AUTH_BASE_URL` necessários;
11. habilitar `COMPRAS_PERSISTENT_READ_ENABLED=true` somente após proteção, roles, migrations e seed estarem validados;
12. provar sign-in, sessão, sign-out, signup negado, deny-all do catch-all Auth, unknown identity deny e cross-team deny/RLS;
13. provar fail-closed sem fallback silencioso para demo;
14. revisar logs/bundle/artifacts para ausência de secrets e conteúdo interno;
15. executar rollback/deprovisionamento se qualquer gate falhar ou manter somente residual privado/fictício explicitamente justificado;
16. atualizar checkpoint e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- nenhum usuário, email, processo ou conteúdo real;
- repositório público recebe somente informação sanitizada;
- Vercel Authentication continua obrigatória;
- signup público continua negado;
- `/api/auth/[...path]` continua deny-all;
- nenhum OAuth/OTP/magic link/passkey/reset/admin público;
- autenticação não cria autorização;
- identidade nasce somente de sessão validada server-side;
- Auth runtime e domínio runtime usam credenciais/roles distintas;
- nenhuma role runtime é owner/superuser/BYPASSRLS;
- Auth runtime não lê domínio e domínio runtime não lê Auth;
- credencial bootstrap/migration não vira variável runtime;
- erro Auth/DB não cai silenciosamente para demo;
- Managed Neon Auth permanece fora do caminho crítico;
- F17 permanece `ON HOLD` somente como evidência histórica do blocker anterior.

## Fonte da tarefa

Executar `tasks/F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01/SPEC.md`, ADR-009, ADR-007, ADR-006, ADR-005, ADR-003, `docs/architecture/SECURITY.md` e `docs/architecture/DATABASE.md`.

## Critério de encerramento

F21 fecha somente quando o Preview privado fictício com Better Auth self-hosted estiver comprovadamente protegido e funcional ponta a ponta, ou quando um blocker externo objetivo impedir a prova sem relaxamento de segurança. Em ambos os casos, registrar o estado real e deixar exatamente uma próxima ação executável.
