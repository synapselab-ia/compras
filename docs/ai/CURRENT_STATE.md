# Current State — Compras

**PROJECT_STATUS:** F28_INTEGRATED_F29_READY  
**CURRENT_PHASE:** F28 integrada em `main`; ADR-012 aprovada; F29 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_AND_FIRST_PERSISTENT_NEXT_ACTION_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_NARROW_NEXT_ACTION_MUTATION_VALIDATED_CREATE_DESIGN_READY_FOR_IMPLEMENTATION  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F28_HOSTED_WRITES  
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
**F28_PR:** `#44` — MERGED  
**F28_FINAL_PR_HEAD:** `d58f811eda8b99dd8c4dc28d1adc7f2b7d0e91ca`  
**F28_PR_CI_RUN:** `34616939065` — PASS  
**F28_PR_PREFLIGHT_RUN:** `34616938983` — PASS  
**F28_MERGE_COMMIT:** `04b3e063314180e683e76adbe7c9c5affd53e14f`  
**F28_MAIN_CI_RUN:** `34617114461` — PASS  
**F28_MAIN_PREFLIGHT_RUN:** `34617114500` — PASS  
**LAST_GOOD_COMMIT:** `04b3e063314180e683e76adbe7c9c5affd53e14f`  
**LAST_GOOD_CI_RUN:** `34617114461`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e promoção desta sessão

A sessão retomou a frente F27 no estado real do GitHub, confirmou os gates finais do head documental, mergeou a PR `#43` e confirmou novamente os gates pós-merge.

A única `NEXT_ACTION` seguinte, F28, foi executada na branch `f28-persistent-contracting-create-design`. Não havia branch nem PR F28 anterior.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 blobs estáveis e permaneceu `VALID`. A inspeção obrigatória incluiu produto, questões abertas, SECURITY, DATABASE, ADR-003/005/009/011, migrations `0001..0004`, boundary/testes F26/F27 e Definition of Done.

F28 foi promovida pela PR `#44` após red-team e gates verdes no head final. O merge `04b3e063314180e683e76adbe7c9c5affd53e14f` recebeu CI pós-merge `34617114461` PASS e F22 Private Preview Preflight `34617114500` PASS.

Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## F28 — criação persistente mínima desenhada

A ADR-012 define uma boundary pilot-only, auditável e idempotente para o cadastro inicial de `contractings`.

### Payload

A futura criação recebe semanticamente somente:

```text
contractingId
object
```

`contractingId` é UUID preparado pelo servidor antes da submissão e também funciona como idempotency key da solicitação preparada. Não é segredo nem autorização.

`object` é preservado exatamente. Não foi inventado trim, tamanho máximo ou regra non-empty além do `NOT NULL` já existente no schema.

`next_action`, stage, status, responsável, waiting, itens e identificadores ficam fora da criação inicial. Campos nullable começam `NULL`; `next_action` continua sendo alterado pela boundary F26/F27 após a linha existir.

### Escopo e ator pilot-only

Team, actor e `created_by_membership_id` nunca vêm do browser.

A criação só é elegível quando:

1. `current_app_user_id()` resolve para usuário ativo;
2. o usuário possui exatamente uma membership não revogada em todo o banco;
3. o team derivado não está arquivado;
4. o team possui exatamente uma membership não revogada.

Múltiplas memberships do usuário bloqueiam por ambiguidade. Segundo membro não revogado no team também bloqueia, inclusive se o `app_user` correspondente estiver desabilitado. Q-009 continua aberta.

### Capability e atomicidade

Criação recebe capability própria equivalente a `compras_contracting_create_owner`; a capability F26 não é ampliada.

A nova role deve seguir ADR-005 e permanecer `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. A primitive será `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

Runtime normal continua sem DML direto e receberá apenas `EXECUTE` explícito por provisionamento separado.

A nova contratação persiste somente ID, team derivado, `object`, creator derivado e timestamps. Responsible/stage/status/waiting/next_action/archived/cancelled ficam `NULL`.

Na mesma transação nasce exatamente um evento `contracting_created`, com team/actor/contracting derivados e o mesmo instante de banco. Falha do evento reverte o cadastro.

### Idempotência

Replay com mesmo candidate UUID só retorna `already-created` depois de autorização corrente e prova exata de mesmo team derivado, mesmo creator derivado e mesmo `object`.

Colisão diferente ou cross-team retorna negação genérica. Double-submit concorrente deve produzir uma única row, um único evento, um `created` e os demais `already-created`.

Não há deduplicação semântica por texto de objeto nem infraestrutura externa de idempotência.

## Red-team e verificação F28

O desenho rejeitou browser escolhendo escopo/ator, ambiguidade de memberships, autorização multiusuário implícita, DML direto no runtime, ampliação F26, criador automaticamente responsável, taxonomias abertas obrigatórias, criação sem evento, idempotência por segredo client-side, deduplicação por conteúdo e side channel cross-team.

Q-001, Q-002, Q-006 e Q-009 permanecem abertas. Migrations `0001..0004` permanecem imutáveis.

Head final da PR `d58f811eda8b99dd8c4dc28d1adc7f2b7d0e91ca`:

- CI `34616939065`: PASS — verify, database e auth-database;
- F22 Private Preview Preflight `34616938983`: PASS.

Pós-merge `04b3e063314180e683e76adbe7c9c5affd53e14f`:

- CI `34617114461`: PASS — verify, database e auth-database;
- F22 Private Preview Preflight `34617114500`: PASS.

O diff F28 contém somente documentação/SPEC. A revisão final não encontrou connection strings, hostnames de provider, secrets, dados reais, migrations reescritas, runtime alterado ou provider hosted write.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01 — Implementar boundary de criação persistente mínima`.

F29 deve materializar ADR-012 por migration `0005`, capability/grants/policies mínimos, primitive específica, provisionamento separado, interface server-only e testes PostgreSQL de autorização, atomicidade, rollback e idempotência concorrente. Server Action/UI de cadastro ficam fora dessa slice.

F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.
