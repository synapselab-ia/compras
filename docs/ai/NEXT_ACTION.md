# Next Action — Compras

## F20-SELF-HOSTED-AUTH-IMPLEMENT-01 — Implementar Better Auth self-hosted mantendo a fronteira F14/F08

**Classe:** `T1 — feature` com impacto de `T2 — segurança` e `T3 — integração externa`  
**Estado:** READY  
**Objetivo:** substituir o adaptador Managed Neon Auth no código por Better Auth self-hosted, com signup negado por configuração versionada, schema/roles/migrations reproduzíveis e a mesma fronteira server-side + RLS, sem provisionar ambiente hosted persistente.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F19 terminou em **ADOPT** e a ADR-009 registrou a decisão arquitetural:

- o Managed Neon Auth observado permanece incapaz de impor/read-back signup restrito e fica `ON HOLD` como rota;
- Better Auth self-hosted provou localmente `disableSignUp=true` com signup rejeitado;
- a prova também validou bootstrap one-shot não roteável, sign-in de usuário existente, sessão server-side e sign-out;
- PostgreSQL, schema separado, role Auth runtime mínima e migrations controladas permitem preservar a fronteira F14/F08/RLS;
- nenhum provider social/plugin lateral é necessário.

A aplicação ainda usa `@neondatabase/auth`; portanto a decisão precisa virar implementação testada antes de qualquer novo provisionamento privado.

## Execução obrigatória

1. recuperar estado/contexto e validar manifest;
2. revalidar documentação oficial Better Auth v1.6/versão escolhida e PostgreSQL/Next.js quando necessário;
3. promover `better-auth` a dependência direta com versão exata e adicionar dependências PostgreSQL necessárias;
4. implementar a instância Better Auth em módulo `server-only`;
5. preservar a API estreita de `private-admission`/`readPrivateAuthSessionState` e remover dependência Managed Neon somente após equivalência;
6. manter `/api/auth/[...path]` deny-all;
7. configurar `emailAndPassword.enabled=true`, `disableSignUp=true`, `socialProviders={}`, trusted origins estritos e sem plugin de método lateral;
8. implementar/testar cookies de Server Actions com `nextCookies()` oficial ou forwarding explícito;
9. fixar issuer server-side `urn:compras:better-auth:self-hosted:v1`;
10. separar `AUTH_DATABASE_URL` de `DATABASE_URL`;
11. gerar/versionar schema Auth da versão pinada e criar boundary de schema/roles/grants em PostgreSQL efêmero;
12. implementar/testar bootstrap one-shot somente fictício e não roteável;
13. provar signup negado, sign-in, sessão, sign-out, ausência de auto-`app_user`/membership e isolamento Auth/domínio;
14. executar red-team integral da SPEC;
15. rodar lint, typecheck, testes, PostgreSQL/RLS e build;
16. revisar diff e atualizar checkpoint deixando exatamente uma próxima ação.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- nenhum recurso Neon/Vercel persistente novo nesta work unit;
- nenhum secret real em Git/chat/log/artifact;
- nenhum usuário real;
- nenhuma rota pública de signup/OAuth/OTP/reset/admin;
- autenticação não cria autorização;
- role Auth runtime não é owner/superuser/BYPASSRLS e não lê domínio;
- role do domínio não ganha acesso Auth por conveniência;
- identidade só nasce de sessão server-side;
- falha Auth não cai silenciosamente para demo no caminho persistente;
- Vercel Authentication continua obrigatória para o preview hospedado existente;
- F17 continua ON HOLD, não volta a ser frente ativa por rotina.

## Fonte da tarefa

Executar `tasks/F20-SELF-HOSTED-AUTH-IMPLEMENT-01/SPEC.md`, ADR-009, ADR-007, ADR-006, `docs/architecture/SECURITY.md` e `docs/architecture/DATABASE.md`.

## Critério de encerramento

F20 fecha somente quando Better Auth self-hosted estiver implementado no repositório e provado em CI/local efêmero como substituto seguro do adaptador Managed Neon, sem provisionamento hosted e sem dados reais. Ao final deve existir exatamente uma nova `NEXT_ACTION` executável para o preflight/provisionamento privado fictício.
