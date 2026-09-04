# Current State — Compras

**PROJECT_STATUS:** F22_IMPLEMENTED_PR_GREEN_F23_READY  
**CURRENT_PHASE:** F22 implementada e verificada na PR `#38`; F23 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_PERSISTENT_PREVIEW_BLOCKED_PRE_SECRETS  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_AND_FICTITIOUS_PREFLIGHT_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_FICTITIOUS_BOOTSTRAP_AND_AUTHZ_SEPARATION_PROVEN  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_VERCEL_AUTH_OBSERVED_NO_F22_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_FINAL_CHECKPOINT_COMMIT:** `a1037b38269c2e67e0ec249ed597eb5171eb31d2`  
**F21_CHECKPOINT_MERGE_COMMIT:** `b38ad708a6f668b4886930a96eaff95a1251590a`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F21_FINAL_CHECKPOINT_CI_RUN:** `33873458508` — PASS  
**F22_BRANCH:** `f22-private-preview-seed-smoke-assets`  
**F22_PR:** `#38` — OPEN / GREEN PRE-CHECKPOINT  
**F22_IMPLEMENTATION_PROOF_HEAD:** `5ef25de708b74ede8e938b5527ad6019b24bd688`  
**F22_CANONICAL_CI_RUN:** `33880106437` — PASS  
**F22_PREFLIGHT_CI_RUN:** `33880106555` — PASS  
**LAST_GOOD_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**LAST_GOOD_CI_RUN:** `33873458508`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Estado real recuperado para F22

A work unit partiu da `main` `73cd3ec1ef524c526c91124d40efae1eff2061ce`, cuja CI `33873458508` estava integralmente em PASS.

Não existia branch/PR F22 ativa. Foi criada `f22-private-preview-seed-smoke-assets` e aberta a PR `#38` para executar a única `NEXT_ACTION` então canônica: `F22-PRIVATE-PREVIEW-SEED-SMOKE-ASSETS-01`.

O `CONTEXT_MANIFEST` foi revalidado diretamente contra a árvore de `main`: todos os 10 inputs estáveis continuaram nos blobs esperados. `CONTEXT_STATUS = VALID`.

F21 continuou `ON HOLD` durante toda a unidade. Nenhuma condição de `resume_when` foi presumida satisfeita e nenhum write Vercel/Neon hosted foi realizado.

## F22 — assets reproduzíveis implementados

A F22 adicionou uma trilha operacional exclusivamente fictícia em `src/server/preflight/`, separada das migrations canônicas.

### Seed de autorização fictícia

`fictitious-private-preview.ts`:

- é `server-only`;
- exige modo exato `FICTITIOUS_EPHEMERAL`;
- usa UUIDs determinísticos e conteúdo explicitamente artificial;
- contém duas equipes fictícias e duas contratações fictícias;
- recebe somente o `subject` criado pelo bootstrap Better Auth fechado;
- verifica esse subject na tabela Auth e exige email persistido em `example.invalid`;
- não cria nem altera identidade Better Auth;
- cria `app_user` e membership em operação administrativa separada;
- concede membership somente à equipe Alpha;
- executa postflight de todas as relações esperadas e da ausência de membership cross-team;
- retorna somente `{ kind: "seeded" }` e usa erro genérico fail-closed.

As tabelas de domínio usam `FORCE RLS` e não possuem policy de INSERT. Por isso o seed exige conexão administrativa one-shot explicitamente privilegiada; essa credencial nunca é runtime e nunca é usada como prova de autorização operacional.

### Harness PostgreSQL

`fictitious-private-preview.postgres.test.ts` prova em PostgreSQL 17 descartável:

- email fora de `example.invalid` é rejeitado pelo bootstrap;
- bootstrap Better Auth cria somente identidade Auth;
- antes do seed, `app_users=0` e `memberships=0`;
- identidade Auth sem autorização interna vê zero contratações;
- seed administrativo separado cria somente a autorização fictícia esperada;
- configuração normal continua `disableSignUp=true`;
- sign-in, sessão e sign-out funcionam para a identidade fictícia existente;
- usuário autorizado vê somente a própria equipe;
- UUID conhecido da outra equipe continua invisível;
- claims ausentes, issuer errado, subject errado e claims malformados falham fechados;
- roles runtime Auth/domínio permanecem `NOINHERIT`, sem superuser, `BYPASSRLS`, `CREATEDB` ou `CREATEROLE`;
- roles runtime não possuem relações;
- Auth runtime não lê o domínio;
- domínio runtime não lê o schema Auth.

## Composição de migrations — achado de red-team

O primeiro ensaio do workflow F22 detectou um conflito real de ownership ao tentar aplicar `database/auth/migrations/0002_auth_runtime_boundary.sql` depois de `database/migrations/0003_team_member_directory.sql`.

A migration Auth `0002` revoga privilégios em todas as relações `public` que já existem. A view `team_member_directory`, porém, pertence deliberadamente à capability role `compras_team_directory_view_owner`; o migrator normal não é owner dessa view e o `REVOKE ALL ... ON ALL TABLES IN SCHEMA public` falhou fechado.

A correção não reescreveu nenhuma migration. O preflight composto aplica:

```text
domínio 0001
-> domínio 0002
-> Auth 0001
-> Auth 0002
-> domínio 0003
```

Depois da criação da capability view há postflight explícito exigindo que `compras_auth_runtime` continue sem `SELECT` sobre `public.team_member_directory`.

Esse achado tornou o harness mais fiel à fronteira de ownership já aprovada em ADR-005.

## CI e verificação F22

O head funcional `5ef25de708b74ede8e938b5527ad6019b24bd688` passou as duas suítes relevantes antes do checkpoint documental:

- CI canônica `33880106437`: PASS em `verify`, `database` e `auth-database`;
- `verify`: install, lint, typecheck, testes completos e build Next.js — PASS;
- `database`: migrations/RLS/capability/detalhe persistente — PASS;
- `auth-database`: role Auth adversarial, migrations Auth e integração Better Auth/PostgreSQL — PASS;
- workflow `F22 Private Preview Preflight` `33880106555`: PASS;
- integração F22 real em PostgreSQL: PASS.

As credenciais operacionais do workflow F22 são geradas aleatoriamente durante o job e mascaradas antes de serem colocadas no ambiente. Os URLs de conexão também são mascarados. O serviço PostgreSQL usa autenticação `trust` somente dentro do runner descartável para evitar que uma senha de serviço apareça no log de inicialização do container; isso não altera grants, ownership ou RLS usados na prova.

## Red-team F22

Resultado:

- email fora de `example.invalid` aceito: NÃO;
- seed sem gate fictício: NÃO;
- issuer/equipe oriundos do browser: NÃO;
- bootstrap criando `app_user`/membership automaticamente: NÃO;
- mesma role Auth/domínio: NÃO;
- runtime owner/superuser/BYPASSRLS/CREATEROLE: NÃO;
- identidade Auth sem autorização retornando dado: NÃO;
- cross-team por UUID conhecido retornando linha: NÃO;
- claims inválidos abrindo acesso: NÃO;
- Auth runtime lendo domínio/capability view: NÃO;
- domínio runtime lendo Auth: NÃO;
- migration canônica reescrita: NÃO;
- catch-all Auth reaberto: NÃO;
- signup normal reaberto: NÃO;
- output de teste contendo credencial operacional/connection string/cookie/token: NÃO nos runs verdes finais;
- recurso Vercel/Neon hosted criado: NÃO;
- identidade/dado real usado: NÃO.

O primeiro run F22 falho havia usado uma senha estática fictícia de serviço visível no metadata/log do container. Apesar de não ser secret operacional, isso foi tratado como falha de higiene do próprio red-team; o workflow final eliminou esse valor e os runs verdes posteriores usam somente valores gerados e mascarados.

## F21 permanece ON HOLD

Nada na F22 altera o blocker externo da F21.

Retomar F21 somente quando a sessão Vercel autenticada puder:

1. ler/read-back Deployment Protection/Vercel Authentication e bypasses relevantes;
2. criar, atualizar, listar metadados e remover sensitive Preview env vars escopadas à branch;
3. inspecionar/disparar o Preview sem criar Production pública por conveniência.

Secrets nunca devem ser enviados por chat para contornar esse blocker.

## Last good

Enquanto a PR `#38` não estiver integrada, o last-good canônico de `main` permanece `73cd3ec1ef524c526c91124d40efae1eff2061ce`, validado pela CI `33873458508`.

O fechamento final F22 deve atualizar este checkpoint depois do merge e dos runs de `main`.

## Próxima ação

Executar somente `F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01/SPEC.md`.

F23 é uma frente de design independente para fechar o controle distribuído de abuso do sign-in privado. F21 permanece `ON HOLD` até seu `resume_when` ser objetivamente satisfeito.
