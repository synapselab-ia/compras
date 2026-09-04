# Current State — Compras

**PROJECT_STATUS:** F20_INTEGRATED_F21_READY  
**CURRENT_PHASE:** F20 integrada em `main`; F21 READY; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_HOSTED_PERSISTENT_PREVIEW_PENDING  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_VERSIONED_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_CI_PROVEN_HOSTED_PREVIEW_PENDING  
**DEPLOYMENT_STATUS:** VERCEL_PREVIEW_READY_DEMO_ONLY_PROTECTED_NO_SECRETS_GIT_AUTODEPLOY_DISABLED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_IMPLEMENTATION_COMMIT:** `49bd1f346373d2c97eb5f32b009b2b2ea6551408`  
**F20_PR:** `#36` — MERGED  
**F20_MERGE_COMMIT:** `a5313463b3ccf7f7d3b229ca0ab8798f586cafcc`  
**F20_PR_CI_RUN:** `33871652187` — PASS  
**F20_MAIN_CI_RUN:** `33871786734` — PASS  
**LAST_GOOD_COMMIT:** `a5313463b3ccf7f7d3b229ca0ab8798f586cafcc`  
**LAST_GOOD_CI_RUN:** `33871786734`  
**F19_DECISION:** `ADOPT` — ADR-009  
**ON_HOLD:** `F17-B2` — Managed Better Auth observado não permitia WRITE + READBACK de `disable_sign_up=true`; permanece somente como evidência histórica

## Estado real

A F20 foi concluída, validada e integrada em `main` pela PR `#36`.

O merge commit canônico é `a5313463b3ccf7f7d3b229ca0ab8798f586cafcc`. A CI de `main` `33871786734` passou integralmente:

- `verify`: PASS — install, lint, typecheck, testes e Next.js build;
- `database`: PASS — suíte PostgreSQL/RLS existente;
- `auth-database`: PASS — red-team de role Auth, migrations Auth e integração Better Auth/PostgreSQL.

A CI final da PR antes do merge também passou integralmente em `33871652187`.

O `CONTEXT_MANIFEST` permaneceu válido durante a work unit. Nenhum dado real, usuário real ou secret operacional foi usado.

## F20 — resultado integrado

A ADR-009 agora está materializada no runtime:

- `better-auth@1.6.23` é dependência direta e pinada;
- `pg` é dependência runtime;
- `@neondatabase/auth` saiu do runtime;
- Better Auth roda em módulo `server-only`;
- email/senha habilitado com `disableSignUp=true`;
- `socialProviders={}` e nenhum plugin de método lateral;
- trusted origin HTTPS exata, sem wildcard/localhost hospedável;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- `subject` nasce somente da sessão validada server-side;
- `/api/auth/[...path]` continua deny-all;
- sign-in/sign-out continuam Server Actions estreitas;
- `AUTH_DATABASE_URL` e `DATABASE_URL` são separados e fail-closed;
- `BETTER_AUTH_SECRET` e `COMPRAS_AUTH_BASE_URL` permanecem server-only.

## Cookies e sessão

O transporte usa forwarding explícito de `Set-Cookie`.

Sign-in somente retorna sucesso após cookie ativo, readback server-side da sessão e correspondência do `user.id`. Sign-out somente retorna sucesso após cookie de invalidação e confirmação de que a sessão anterior não resolve mais.

## Schema Auth e roles

Migrations integradas:

- `database/auth/migrations/0001_better_auth_1_6_23.sql`;
- `database/auth/migrations/0002_auth_runtime_boundary.sql`.

A role `compras_auth_runtime` deve permanecer `LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION`, sem ownership das relações Auth e sem grants de domínio.

A CI provou isolamento nos dois sentidos:

- Auth runtime não lê o domínio;
- domínio runtime não lê o schema Auth.

## Bootstrap fictício

Existe bootstrap one-shot administrativo, não roteável e restrito a `example.invalid`.

Ele cria somente identidade Better Auth, não cria `app_users`/membership e retorna apenas o `subject`. A execução hospedada desse bootstrap ainda não ocorreu.

## Red-team F20

PASS para os principais gates:

- signup fechado;
- catch-all Auth permanece deny-all;
- métodos laterais ausentes;
- trusted origin estrita;
- subject não aceito do browser;
- sign-in sem cookie/session real não é aceito;
- sign-out sem revogação real não é aceito;
- autenticação não cria autorização automaticamente;
- role Auth com `BYPASSRLS` é rejeitada;
- Auth → domínio: DENY;
- domínio → Auth: DENY;
- runtime Auth não é owner;
- migrations Auth são versionadas da versão pinada;
- nenhum fallback silencioso para demo foi introduzido;
- nenhum recurso hosted persistente ou dado real foi criado na F20.

## Providers / hosted

F20 não provisionou nem alterou recursos persistentes Vercel/Neon.

A faixa F18 continua como demonstração hospedada separada:

- Preview `READY`;
- Vercel Authentication ativa;
- somente fixtures fictícias;
- nenhum banco/Auth interno/secret;
- `COMPRAS_PERSISTENT_READ_ENABLED` não habilitado;
- Git auto-deploy permanece desabilitado conforme checkpoint anterior.

F17 continua `ON HOLD` apenas como histórico do blocker do Managed Neon Auth e não é caminho crítico.

## Last good

O last-good canônico passa a ser o merge F20 `a5313463b3ccf7f7d3b229ca0ab8798f586cafcc`, validado pela CI de `main` `33871786734`.

Isso ainda não representa um preview persistente operacional. `REAL_DATA_ALLOWED` continua `NO`.

## Próxima ação

Executar somente `F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01/SPEC.md`.
