# Current State - Compras

**PROJECT_STATUS:** F33_INTEGRATED_F34_READY  
**CURRENT_PHASE:** F33 integrada em `main`; F34 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_UI_OBJECT_MUTATION_AND_OBJECT_DETAIL_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_NARROW_NEXT_ACTION_MUTATION_MINIMAL_CREATE_AND_OBJECT_MUTATION_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F33_HOSTED_WRITES  
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
**F29_MERGE_COMMIT:** `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`  
**F30_MERGE_COMMIT:** `c0f6e822253e9e324f00bc674f4805f52cbca16c`  
**F31_MERGE_COMMIT:** `b541592aa4a392dfab439389daaddcd4c811c5e5`  
**F32_MERGE_COMMIT:** `e7f893e8d186853b859dfb281f134d057b0b6e97`  
**F33_PR:** `#49` - MERGED  
**F33_FINAL_PR_HEAD:** `81f926b91657fe6de458d4ad01aee15f62672592`  
**F33_PR_CI_RUN:** `34850892351` - PASS  
**F33_PR_F22_PREFLIGHT_RUN:** `34850892414` - PASS  
**F33_PR_F29_CREATE_RUN:** `34850892361` - PASS  
**F33_PR_F32_MUTATION_RUN:** `34850892323` - PASS  
**F33_MERGE_COMMIT:** `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`  
**F33_MAIN_CI_RUN:** `34851216964` - PASS  
**F33_MAIN_F22_PREFLIGHT_RUN:** `34851216895` - PASS  
**F33_MAIN_F29_CREATE_RUN:** `34851216887` - PASS  
**F33_MAIN_F32_MUTATION_RUN:** `34851217022` - PASS  
**LAST_GOOD_COMMIT:** `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`  
**LAST_GOOD_CI_RUN:** `34851216964`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e execução desta sessão

A sessão recuperou `main` em `d4afcca06b968bfac8467a1f492d99cdcc8d5c57`, confirmou ausência de PR/branch F33 preexistente e localizou F33 como a única `NEXT_ACTION` canônica.

O `CONTEXT_MANIFEST` foi revalidado contra a árvore real de `main`; os blobs estáveis permaneceram coerentes e `CONTEXT_STATUS = VALID`.

F33 foi classificada como feature T1 com impacto T2 em autorização/escrita server-side. Foram inspecionados ADR-013, SECURITY, DATABASE, SPEC F33, precedentes F27/F30, read model do detalhe e a boundary F32 antes da implementação.

A implementação ocorreu na branch `f33-persistent-contracting-object-detail-ui`, PR `#49`. O diff final continha somente sete arquivos de aplicação/testes. Não houve migration, grant, policy, RLS, capability, primitive PostgreSQL, provider hosted write, secret ou dado real.

O head `81f926b91657fe6de458d4ad01aee15f62672592` passou CI, F22, F29 e F32. A PR foi integrada por merge commit `c4c3d5416ecfd7f49c74ffd0a32425db8621958c` e os quatro workflows passaram novamente em `main`.

## F33 - edição persistente de Objeto integrada no detalhe

### Server Action estreita

`updatePersistentObjectAction` aceita do FormData somente:

```text
contractingId
expectedObject
newObject
```

Cada scalar confiável é lido exatamente uma vez. Duplicata ou ausência falha fechado. `expectedObject` e `newObject` são strings obrigatórias porque `object` é `NOT NULL`, mas string vazia e espaços continuam valores válidos e são preservados sem trim/normalização.

Team, actor, membership, issuer, subject, event UUID, callback e campos extras não são encaminhados. A action delega autorização, lock, optimistic concurrency, atomicidade e auditoria integralmente a `mutatePersistentContractingObject`.

Erro inesperado vira somente `unavailable`, sem detalhe interno. Redirects e revalidação usam rota local fixa do detalhe. `updated` e `conflict` revalidam o read model; conflito nunca vira overwrite silencioso.

### UI e feedback

No modo persistente, o detalhe passou a mostrar editor de `Objeto` usando o valor protegido atual como `expectedObject`. O editor de `Próxima ação` da F27 permanece separado.

A UI de objeto expõe somente os cinco estados sanitizados:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

Cross-team, inexistente e outras negações continuam sem oracle externo. Query string carrega somente o estado sanitizado, nunca conteúdo do objeto ou authority.

No modo demo, nenhum form de mutação de objeto é renderizado e feedback forjado é ignorado. A Server Action também bloqueia execução fora do modo persistente.

### Authority preservada

F33 não adicionou SQL nem DML próprio. A authority continua:

```text
sessão Better Auth validada
-> iss/sub em contexto LOCAL
-> boundary F32
-> capability PostgreSQL estreita
-> RLS/autorização pilot-only
```

F26 continua exclusiva de `next_action`; F29 continua exclusiva de criação mínima de contratação; F32 continua exclusiva de mutação de `object`.

Migrations `0001..0006` permanecem imutáveis.

## Red-team F33

O diff e os testes cobrem e rejeitam:

- authority de browser para team/actor/membership/issuer/subject/event UUID;
- callback/redirect arbitrário;
- scalar duplicado ou ausente alcançando F32;
- demo/configuração inválida alcançando write;
- trim, normalização ou empty-to-NULL;
- conflito convertido em sucesso;
- falha de banco vazando connection string ou detalhe interno;
- feedback distinguível entre negações protegidas;
- controles novos de stage/status/responsável/waiting;
- SQL/DML na Server Action;
- expansão de grants/capabilities;
- alteração de migrations aplicadas;
- provider hosted, secret ou dado real.

Não havia review threads pendentes na PR `#49`.

## Verificação F33

Head final da PR `81f926b91657fe6de458d4ad01aee15f62672592`:

- CI `34850892351`: PASS, incluindo lint, typecheck, testes, build, database e auth-database;
- F22 Private Preview Preflight `34850892414`: PASS;
- F29 Contracting Create `34850892361`: PASS;
- F32 Contracting Object Mutation `34850892323`: PASS.

Pós-merge `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`:

- CI `34851216964`: PASS;
- F22 Private Preview Preflight `34851216895`: PASS;
- F29 Contracting Create `34851216887`: PASS;
- F32 Contracting Object Mutation `34851217022`: PASS.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item`.

A SPEC está em `tasks/F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01/SPEC.md`.

F34 é design-only. Deve decidir payload mínimo, UUIDs server-side, autorização por contratação/equipe alvo, atribuição concorrente de `ordinal`, capability least-privilege, evento atômico e matriz adversarial da futura implementação, sem resolver Q-004/Q-009 e sem alterar migrations `0001..0006`.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.