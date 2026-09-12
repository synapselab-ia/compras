# Current State — Compras

**PROJECT_STATUS:** F29_INTEGRATED_F30_READY  
**CURRENT_PHASE:** F29 integrada em `main`; F30 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_UI_AND_CONTRACTING_CREATE_BOUNDARY_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_NARROW_NEXT_ACTION_MUTATION_AND_MINIMAL_CONTRACTING_CREATE_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F29_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_MERGE_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**F25_MERGE_COMMIT:** `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`  
**F26_MERGE_COMMIT:** `1e9e03eddeac9584ee6044a2393fe6b1e9a31726`  
**F27_MERGE_COMMIT:** `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`  
**F28_MERGE_COMMIT:** `04b3e063314180e683e76adbe7c9c5affd53e14f`  
**F29_PR:** `#45` — MERGED  
**F29_FUNCTIONAL_HEAD:** `d35edbd54e516de9c2eac943d3c854a30ed729a9`  
**F29_FINAL_PR_HEAD:** `a54fc909229458017140cfaa70fd3311144a3ab4`  
**F29_PR_CI_RUN:** `34696792923` — PASS  
**F29_PR_F22_PREFLIGHT_RUN:** `34696792988` — PASS  
**F29_PR_CREATE_RUN:** `34696792903` — PASS  
**F29_MERGE_COMMIT:** `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`  
**F29_MAIN_CI_RUN:** `34696856515` — PASS  
**F29_MAIN_F22_PREFLIGHT_RUN:** `34696856531` — PASS  
**F29_MAIN_CREATE_RUN:** `34696856481` — PASS  
**LAST_GOOD_COMMIT:** `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`  
**LAST_GOOD_CI_RUN:** `34696856515`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e promoção desta sessão

A sessão recuperou `main` em `a61353ef0e7b3a59982f78e8f1e27943e27b4ef0`, confirmou F28 integrada/verde, revalidou os 10 blobs do `CONTEXT_MANIFEST` e localizou F29 como a única frente canônica ativa. Não existia branch/PR F29 anterior.

A implementação foi feita na branch `f29-persistent-contracting-create-implement`, PR `#45`, sem provider hosted write, sem dado real e sem alteração de migrations aplicadas `0001..0004`.

O head documental final `a54fc909229458017140cfaa70fd3311144a3ab4` repetiu todos os gates em verde antes da promoção. A PR `#45` foi então mergeada por merge commit `3781ec4eebc0b7618f865a83fcf1214ea13c4a71` e os três workflows pós-merge também passaram em `main`.

## F29 — criação persistente mínima integrada

F29 materializa ADR-012 por uma boundary PostgreSQL/server-only específica para criação inicial de `contractings`.

### Migration e capability

Foi adicionada `database/migrations/0005_contracting_create.sql` com owner técnico dedicado `compras_contracting_create_owner`:

- `NOLOGIN`, `NOINHERIT`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE`, `NOREPLICATION`;
- sem ownership de tabelas-base e sem membership utilizável;
- lifecycle compatível com ADR-005/PostgreSQL 17;
- primitive `public.create_contracting_minimal(uuid,text,uuid)` `SECURITY DEFINER` com `search_path = pg_catalog` e `PUBLIC EXECUTE` revogado.

Provisionamento separado em `database/provisioning/grant_contracting_create_runtime.sql` concede somente `EXECUTE` ao runtime explícito e seguro. O runtime continua sem DML direto.

### Escopo e payload

A interface server-only recebe somente `contractingId + object`. Event UUID é gerado no servidor. Team, actor, membership, issuer, subject e `created_by` não são argumentos confiáveis.

A criação só passa quando:

1. `current_app_user_id()` resolve;
2. o usuário possui exatamente uma membership não revogada em todo o banco;
3. o team derivado existe e não está arquivado;
4. o team possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia mesmo com `app_user` desabilitado. Múltiplas memberships do próprio usuário também bloqueiam. Q-009 continua aberta.

### Estado, auditoria e idempotência

A row inicial grava apenas ID, team derivado, `object`, creator derivado e timestamps. Responsible/stage/status/waiting/next_action/archived/cancelled permanecem `NULL`.

Na mesma transação é criado exatamente um evento `contracting_created`; row/event compartilham um único instante de banco. Falha do evento reverte a contratação.

O candidate UUID é idempotency key não secreta. Replay exato autorizado retorna `already-created`; mismatch ou colisão cross-team retorna negação genérica. Teste concorrente com oito writers prova exatamente uma row, um evento, um `created` e sete `already-created`.

### Adapter server-only

`src/features/contracting-create/persistent-create.ts`:

- gera candidate UUID por `randomUUID()`;
- valida candidate UUID;
- preserva `object` exatamente, inclusive string vazia;
- gera event UUID server-side;
- chama somente a primitive parametrizada via `withTrustedDatabaseMutationContext`;
- mapeia `denied` para `not-available` e falha inesperada para `unavailable`;
- não possui demo fallback nem logging de detalhe sensível.

`src/server/database/operational-safety.ts` também proíbe a nova capability como role operacional.

## Red-team e verificação F29

A primeira execução do workflow F29 encontrou um erro sintático no postflight da migration. A correção removeu apenas a expressão inválida e preservou o enforcement; nenhum controle foi reduzido para obter PASS.

A matriz adversarial prova, entre outros pontos:

- capability insegura `LOGIN`, `BYPASSRLS` ou com membership `SET ROLE` é rejeitada;
- runtime/Auth/read-only não recebem authority indevida;
- runtime não possui DML direto;
- F26 não recebe INSERT de criação e F29 não recebe UPDATE/EXECUTE F26;
- claims ausentes/malformados, identidade desconhecida/desabilitada, membership ausente/revogada/ambígua, team arquivado e segundo membro fecham acesso;
- browser não escolhe team/actor/creator/event UUID;
- cross-team collision não revela existência;
- evento e criação são atômicos;
- replay não duplica evento;
- oito writers concorrentes colapsam em uma criação.

Gates finais da PR no head `a54fc909229458017140cfaa70fd3311144a3ab4`:

- CI `34696792923`: PASS;
- F22 Private Preview Preflight `34696792988`: PASS;
- F29 Contracting Create `34696792903`: PASS.

Pós-merge `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`:

- CI `34696856515`: PASS — verify, database e auth-database;
- F22 Private Preview Preflight `34696856531`: PASS;
- F29 Contracting Create `34696856481`: PASS.

A revisão integral não encontrou provider hosted write, dado real ou secret real. Credenciais presentes no workflow são exclusivamente valores `DEMO-*` de PostgreSQL descartável/localhost.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F30-PERSISTENT-CONTRACTING-CREATE-UI-01 — Tornar cadastro persistente mínimo utilizável`.

F30 deve conectar uma jornada UI/Server Action estreita à boundary F29, preparando candidate UUID no servidor e encaminhando somente `contractingId + object`, mantendo demo read-only, redirects/feedback sanitizados e migrations `0001..0005` imutáveis.

F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.
