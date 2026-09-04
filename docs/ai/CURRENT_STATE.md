# Current State — Compras

**PROJECT_STATUS:** F20_SELF_HOSTED_AUTH_IMPLEMENTED_F21_READY  
**CURRENT_PHASE:** F20 concluída / PASS; F21 READY; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_HOSTED_PERSISTENT_PREVIEW_PENDING  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_VERSIONED_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_CI_PROVEN_HOSTED_PREVIEW_PENDING  
**DEPLOYMENT_STATUS:** VERCEL_PREVIEW_READY_DEMO_ONLY_PROTECTED_NO_SECRETS_GIT_AUTODEPLOY_DISABLED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_IMPLEMENTATION_COMMIT:** `49bd1f346373d2c97eb5f32b009b2b2ea6551408`  
**F20_CI_RUN:** `33869932738`  
**F20_PR:** `#36`  
**LAST_GOOD_COMMIT:** `49bd1f346373d2c97eb5f32b009b2b2ea6551408`  
**LAST_GOOD_CI_RUN:** `33869932738`  
**F19_DECISION:** `ADOPT` — ADR-009  
**ON_HOLD:** `F17-B2` — Managed Better Auth observado não permitia WRITE + READBACK de `disable_sign_up=true`; permanece somente como evidência histórica

## Estado real

A frente ativa F20 está na branch `f20-self-hosted-auth-implement` / PR `#36` contra `main`. O commit funcional validado é `49bd1f346373d2c97eb5f32b009b2b2ea6551408`.

A CI `33869932738` terminou integralmente em PASS:

- `verify`: PASS — install, lint, typecheck, testes e Next.js build;
- `database`: PASS — toda a suíte PostgreSQL/RLS existente, incluindo default-deny, trusted reads, capability de diretório e detalhe protegido;
- `auth-database`: PASS — red-team de role Auth insegura, provisionamento de roles separadas e integração Better Auth/PostgreSQL.

O `CONTEXT_MANIFEST` permaneceu válido durante a execução F20. Nenhum dado real, usuário real ou secret operacional foi usado.

## F20 — Better Auth self-hosted implementado

A decisão ADR-009 deixou de ser apenas design/prova e virou implementação no repositório.

Resultado material:

- `better-auth@1.6.23` é dependência direta e pinada;
- `pg` é dependência runtime para PostgreSQL Auth;
- a dependência runtime de `@neondatabase/auth` foi removida;
- instância Better Auth vive em módulo `server-only`;
- `emailAndPassword.enabled=true` e `disableSignUp=true`;
- `socialProviders={}` e nenhum plugin de método lateral;
- `trustedOrigins` aceita somente origem HTTPS exata, sem wildcard/localhost hospedável;
- issuer confiável fixo: `urn:compras:better-auth:self-hosted:v1`;
- `subject` nasce somente de sessão Better Auth validada server-side;
- `/api/auth/[...path]` continua deny-all;
- sign-in/sign-out continuam Server Actions estreitas;
- `AUTH_DATABASE_URL` e `DATABASE_URL` são configurações separadas e fail-closed;
- `BETTER_AUTH_SECRET` e `COMPRAS_AUTH_BASE_URL` permanecem server-only.

## Cookies e sessão

A F20 escolheu forwarding explícito de `Set-Cookie` em vez de ampliar plugins.

O sign-in somente retorna sucesso depois de:

1. Better Auth autenticar credenciais existentes;
2. emitir cookie de sessão ativo;
3. a sessão ser lida de volta server-side com o cookie emitido;
4. o `user.id` da sessão corresponder ao usuário autenticado;
5. o cookie ser persistido pela Server Action.

O sign-out somente retorna sucesso depois de:

1. Better Auth emitir invalidação do cookie de sessão;
2. a sessão anterior deixar de resolver;
3. a invalidação ser persistida pela Server Action.

Assim, a aplicação não presume sucesso de cookie/session.

## Schema Auth e roles

Foi adicionada trilha de migration própria:

- `database/auth/migrations/0001_better_auth_1_6_23.sql` — schema gerado da versão pinada contra PostgreSQL 17;
- `database/auth/migrations/0002_auth_runtime_boundary.sql` — boundary de runtime.

A boundary exige `compras_auth_runtime` com `LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION`, sem ownership de relações Auth e sem grants de domínio.

A CI provou também o isolamento inverso: role de domínio sem acesso ao schema Auth.

## Bootstrap fictício

Existe mecanismo one-shot não roteável para laboratório/preflight:

- exige modo explícito `FICTITIOUS_ONE_SHOT`;
- aceita somente identidade em `example.invalid`;
- cria somente identidade Better Auth;
- não cria `app_users`, membership ou autorização de domínio;
- retorna somente o `subject` necessário à etapa administrativa futura;
- permanece fora de qualquer rota pública.

A execução hospedada desse bootstrap não ocorreu na F20.

## Red-team F20

Os principais ataques/erros procurados foram cobertos:

- signup apesar de `disableSignUp=true`: REJEITADO;
- catch-all Auth delegando para Better Auth: NÃO;
- OAuth/OTP/magic link/passkey/admin/reset laterais: AUSENTES;
- origem wildcard/localhost hospedável: REJEITADA;
- subject vindo do browser: REJEITADO pela fronteira server-side;
- sign-in sem cookie/session comprovados: NÃO ACEITO;
- sign-out sem revogação comprovada: NÃO ACEITO;
- criação automática de `app_user`/membership: NÃO OCORRE;
- role Auth com `BYPASSRLS`: migration REJEITOU em CI;
- Auth runtime lendo `public.teams`: DENY `42501`;
- domínio runtime lendo `auth.user`: DENY `42501`;
- Auth runtime como owner: NÃO;
- migration via painel/manual/latest: NÃO; SQL versionado da versão pinada;
- fallback silencioso para demo em falha Auth: NÃO introduzido;
- recurso hosted persistente/dado real: NÃO criado.

## Verificação

CI final funcional F20: `33869932738`.

Resultado:

- install from lockfile: PASS;
- lint: PASS;
- typecheck: PASS;
- testes unitários: PASS;
- testes de Auth/cookies/session/sign-out: PASS;
- Next.js build: PASS;
- PostgreSQL/RLS legado: PASS;
- red-team role Auth privilegiada: PASS;
- migrations Auth: PASS;
- integração Better Auth PostgreSQL: PASS;
- isolamento Auth/domínio: PASS;
- signup fechado: PASS;
- bootstrap fictício sem autorização automática: PASS.

Uma primeira execução da PR detectou incompatibilidade de tipagem na abstração `ReturnType<typeof betterAuth>`; a correção preservou o tipo inferido da instância configurada. A CI subsequente acima passou integralmente.

## Providers / hosted

F20 não provisionou nem alterou ambiente persistente Vercel/Neon.

A faixa F18 continua como demonstração hospedada separada:

- Preview `READY`;
- Vercel Authentication ativa;
- somente fixtures fictícias;
- nenhum banco/Auth interno/secret;
- `COMPRAS_PERSISTENT_READ_ENABLED` não habilitado;
- Git auto-deploy permanece desabilitado conforme checkpoint anterior.

F17 continua `ON HOLD` somente como histórico do blocker do Managed Neon Auth e não voltou ao caminho crítico.

## Last good

O last-good de implementação do repositório passa a ser F20 / `49bd1f346373d2c97eb5f32b009b2b2ea6551408`, validado pela CI `33869932738`.

Isso não significa que exista preview persistente operacional: a prova hosted com Better Auth self-hosted ainda é a próxima work unit. `REAL_DATA_ALLOWED` continua `NO`.

## Próxima ação

Executar somente `F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01/SPEC.md`.
