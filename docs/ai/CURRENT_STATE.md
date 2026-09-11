# Current State — Compras

**PROJECT_STATUS:** F26_IMPLEMENTED_PR_READY_F27_NEXT  
**CURRENT_PHASE:** F26 implementada e verificada na PR #42; checkpoint final da PR em validação; F27 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_SIGNIN_LIMITER_INTEGRATED_FIRST_DOMAIN_WRITE_IMPLEMENTED_NO_UI_YET  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_NARROW_NEXT_ACTION_MUTATION_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F26_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_MERGE_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**F25_MERGE_COMMIT:** `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`  
**F26_PR:** `#42` — OPEN / MERGEABLE  
**F26_FUNCTIONAL_VERIFIED_HEAD:** `ca670b05cdc2f0c80b520f0573c05032c4a73cc6`  
**F26_FUNCTIONAL_CI_RUN:** `34605291444` — PASS  
**F26_FUNCTIONAL_PREFLIGHT_RUN:** `34605291428` — PASS  
**F26_CHECKPOINT_HEAD_BEFORE_FINAL_DOCS:** `571d841c0167a9ac8635b6cb02792167477ea11b`  
**LAST_GOOD_COMMIT:** `ca670b05cdc2f0c80b520f0573c05032c4a73cc6`  
**LAST_GOOD_CI_RUN:** `34605291444`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A execução F26 partiu de `main` em `65cfece6d558d9810e853914dbbb1c32837df23c` e localizou a frente ativa `f26-first-persistent-next-action-mutation-implement`, PR `#42`.

O `CONTEXT_MANIFEST` foi validado contra os 10 blobs estáveis e permaneceu `VALID`. A inspeção T1/T2 incluiu SECURITY, DATABASE, ADR-003/005/009/011, migrations do domínio, adapters de contexto confiável e suites RLS/PostgreSQL.

Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## F26 — primeira mutação persistente implementada

A ADR-011 foi materializada sem ampliar CRUD normal.

### Banco e capability

Criados:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- `database/tests/next_action_mutation.sql`.

A role técnica `compras_next_action_mutation_owner` permanece `NOLOGIN`, `NOINHERIT`, sem superuser, `BYPASSRLS`, `CREATEDB`, `CREATEROLE`, replication, ownership de tabelas-base ou membership utilizável.

A primitive `public.mutate_contracting_next_action(uuid,text,text,uuid)` é `SECURITY DEFINER`, usa `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado. O runtime normal não recebe `UPDATE`/`INSERT` direto; recebe somente `EXECUTE` explícito por provisionamento transacional estreito.

### Autorização pilot-only

Identidade é derivada exclusivamente da sessão Better Auth validada e do contexto LOCAL `iss/sub`. Browser não fornece actor, team, membership, issuer ou subject confiáveis.

Q-009 continua aberta. A mutação só autoriza quando o usuário corrente possui a única membership `revoked_at IS NULL` da equipe alvo. Segundo membro ativo bloqueia a escrita, inclusive se o app_user correspondente estiver desabilitado.

Cross-team, inexistente, identidade desconhecida/desabilitada, membership ausente/revogada, equipe multi-member e contratação arquivada/cancelada falham fechados sem side channel de existência.

### Atomicidade, histórico e concorrência

Mudança real atualiza `next_action`/`updated_at` e insere exatamente um `contracting_events` `next_action_changed` na mesma transação, com actor/team/contracting derivados do banco e um único instante de banco para estado/evento.

Falha do evento reverte o update. No-op retorna `unchanged` sem timestamp/evento. Expected stale retorna `conflict` sem write.

O teste concorrente PostgreSQL 17 executou oito writers com o mesmo expected antigo e provou exatamente 1 `updated`, 7 `conflict` e 1 evento.

### Adapter server-side

Criados `withTrustedDatabaseMutationContext` e `mutatePersistentContractingNextAction`.

A boundary:

- valida identidade antes do banco;
- valida conexão e role operacional não privilegiada;
- usa `BEGIN` normal + contexto LOCAL `iss/sub`;
- faz rollback em falha;
- destrói conexão de estado incerto;
- sanitiza erros;
- gera `event_id` no servidor;
- não possui fallback para demo.

## Red-team e verificação F26

Foram exercitados, entre outros:

- capability `LOGIN`/`BYPASSRLS`/membership utilizável → rejeitada;
- runtime com DML direto → rejeitado;
- alteração de stage/status/responsável/waiting → sem grant;
- eventos `UPDATE`/`DELETE` → sem grant;
- claims ausentes/malformados → deny;
- identidade/membership inválidas → deny;
- cross-team/inexistente → mesmo resultado externo;
- segundo membro ativo → deny;
- archived/cancelled → deny;
- no-op/stale/rollback de evento → corretos;
- race de oito writers → exatamente um winner/evento;
- Auth e runtime read-only sem mutation `EXECUTE`.

Head funcional `ca670b05cdc2f0c80b520f0573c05032c4a73cc6`:

- CI `34605291444`: PASS (`verify`, `database`, `auth-database`);
- F22 Private Preview Preflight `34605291428`: PASS;
- lint/typecheck/test/build: PASS;
- PostgreSQL/RLS/Auth/F24: PASS.

Os commits de checkpoint documental posteriores não alteram a implementação; ainda assim a PR deve receber gates finais verdes no head atual antes do merge.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica na frente ativa:

`F27-PERSISTENT-NEXT-ACTION-DETAIL-UI-01 — Integrar edição persistente de próxima ação no detalhe`.

F27 deve tornar utilizável somente a capability F26 por Server Action estreita no detalhe persistente, mantendo demo read-only, Q-009 aberta, runtime sem DML direto e nenhuma nova autoridade.

F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.
