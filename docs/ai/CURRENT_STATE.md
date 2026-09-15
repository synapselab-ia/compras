# Current State - Compras

**PROJECT_STATUS:** F37_INTEGRATED_F38_READY  
**CURRENT_PHASE:** F37 integrada e verificada; F38 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_UI_OBJECT_MUTATION_OBJECT_DETAIL_UI_ITEM_CREATE_BOUNDARY_AND_ITEM_CREATE_DETAIL_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_VALIDATED_F29_CONCURRENCY_REPAIR_0008_INTEGRATED_F37_DESIGN_ONLY  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F37_HOSTED_WRITES  
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
**F33_MERGE_COMMIT:** `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`  
**F33_CHECKPOINT_MERGE_COMMIT:** `bfa9a65fae06ef8c3cc29586287160be3ab29d31`  
**F34_MERGE_COMMIT:** `51b02799e5994567ca144b38c4117271695ff7e2`  
**F35_MERGE_COMMIT:** `879902c9e55c60ae514e0ce961f9246202c5c9f8`  
**F36_PR:** `#54`  
**F36_MERGE_COMMIT:** `c177e7e8c1b3a46a5d5c3276b4945b81019c706a`  
**F29_CONCURRENCY_REPAIR_PR:** `#56`  
**F29_CONCURRENCY_REPAIR_VERIFIED_HEAD:** `4866569e96c8c1dc1547528727183f1443153b1d`  
**F29_CONCURRENCY_REPAIR_MERGE_COMMIT:** `738666901fae43ce25dd11398904735e15c85da1`  
**F37_PR:** `#57`  
**F37_DESIGN_VERIFIED_HEAD:** `811786a774342a23b09576e6bb7f6040443a5775`  
**F37_FINAL_PR_HEAD:** `40a7fb0de96ae571b4a07afc43c41bf1787da0a8`  
**F37_MERGE_COMMIT:** `88d7d43f06afe8a9eef4d446331c173a8d238856`  
**LAST_GOOD_MAIN_COMMIT:** `88d7d43f06afe8a9eef4d446331c173a8d238856`  
**LAST_GOOD_MAIN_CI_RUN:** `35011822038`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou o estado real do GitHub, incluindo a branch operacional `repair-f29-concurrency-conflict` que ainda não havia sido promovida. Essa frente foi concluída antes da NEXT_ACTION canônica F37.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos. Todos os blobs declarados permaneceram idênticos. `CONTEXT_STATUS = VALID`.

GitHub continua sendo a fonte de verdade. Chat é descartável.

## Reparo F29 concluído

A verificação pós-checkpoint anterior havia encontrado uma corrida real na criação mínima F29. `contractings` possui PK em `id` e unique composta `(team_id, id)`. Com múltiplos retries simultâneos, `ON CONFLICT (id) DO NOTHING` podia perder a corrida na unique composta e lançar `23505` antes do reconhecimento idempotente.

A PR `#56` adicionou exclusivamente:

`database/migrations/0008_contracting_create_concurrency_repair.sql`

A correção usa `ON CONFLICT DO NOTHING` e só retorna `already-created` depois da mesma prova exata e autorizada de replay. Colisões não equivalentes continuam `denied`.

Migrations `0001..0007` não foram reescritas.

### Red-team do reparo

O primeiro head do reparo falhou corretamente porque o owner selado da primitive não possuía `CREATE` no schema durante `CREATE OR REPLACE FUNCTION`.

A correção final concede esse privilege apenas dentro da transaction de migration, faz o replace sob o owner, revoga a aresta temporária e o schema `CREATE` antes do postflight e prova que nenhum privilege extra permaneceu.

Head final `4866569e96c8c1dc1547528727183f1443153b1d` passou CI, F22, F29, F32 e F35. A PR #56 foi integrada por `738666901fae43ce25dd11398904735e15c85da1`, também com gates pós-merge verdes.

Migrations `0001..0008` são agora histórico aplicado imutável.

## F37 integrada

A única NEXT_ACTION canônica F37 foi executada como design-only na PR `#57`.

Artefatos integrados:

- `docs/decisions/ADR-015-minimal-persistent-contracting-item-mutation.md`;
- `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`;
- SPEC F37 marcada `COMPLETED / DESIGN PASS`;
- checkpoint canônico atualizado para F38.

Nenhuma migration, policy, grant, primitive, provisioning, adapter, Server Action ou UI F38 foi implementada pela F37.

### Decisão ADR-015

A primeira edição persistente de item será uma mutação atômica dos quatro campos existentes:

```text
description
quantity
unit
catalog_code
```

O contrato server-only recebe:

```text
contractingId
itemId
expectedDescription
expectedQuantity
expectedUnit
expectedCatalogCode
newDescription
newQuantity
newUnit
newCatalogCode
```

`contractingId + itemId` são seletores candidatos e vinculam o item ao parent esperado, mas não definem scope ou autorização.

Team, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs nunca são authority do browser.

### Semântica exata

- `description`, `unit` e `catalog_code` não sofrem trim ou normalização;
- `description` permanece `NOT NULL`, sem regra non-empty inventada;
- `unit` e `catalog_code` preservam `NULL`, `''` e espaços como estados distintos;
- `quantity` permanece `numeric NULL` no PostgreSQL e `string | null` no TypeScript;
- nenhum `Number`, `parseFloat` ou round-trip floating-point é permitido;
- numeric inválido falha fechado e vira `unavailable` sem write;
- nenhuma regra de positividade, escala, precisão de negócio ou unidade obrigatória foi criada.

### Optimistic concurrency

A primitive F38 bloqueará apenas a row do item por `SELECT ... FOR UPDATE`.

Depois de autorização e lock:

1. qualquer diferença entre o estado atual e qualquer dos quatro expected retorna `conflict`;
2. somente com o snapshot esperado atual, um novo snapshot idêntico retorna `unchanged`;
3. caso contrário, a operação retorna `updated`.

`conflict` é avaliado antes de `unchanged`. Isso impede lost update entre campos diferentes e impede replay pós-sucesso de gerar novo histórico.

No-op não altera `updated_at` e não cria evento.

### Autorização target-team

A futura mutation exige:

- identidade interna ativa;
- item vinculado ao `contractingId` candidato;
- item com `retired_at IS NULL`;
- parent no mesmo team, não arquivado e não cancelado;
- membership não revogada do usuário no team alvo;
- exatamente uma membership não revogada no team.

Segundo membro não revogado bloqueia, inclusive se seu app_user estiver desabilitado. Outra membership do mesmo usuário em outro team não bloqueia por si só.

Cross-team, inexistente, parent mismatch, retired e parent inativo continuam externamente indistinguíveis.

Q-009 continua aberta.

### Capability e auditoria

F38 criará uma capability dedicada equivalente a `compras_contracting_item_mutation_owner`.

Ela poderá atualizar somente:

```text
description
quantity
unit
catalog_code
updated_at
```

Ela não poderá:

- inserir/deletar item;
- alterar ordinal, retired state, scope ou created_at;
- atualizar `contractings`;
- tocar o allocator F35;
- atualizar/deletar eventos;
- reutilizar authority de F26/F29/F32/F35.

Runtime normal continuará sem DML direto e receberá somente `EXECUTE` por provisioning explícito.

Cada campo realmente alterado gera exatamente um evento escalar `item_changed`, com `item_id`, `field_key`, `old_value`, `new_value` e o mesmo `operation_at`. Quantity é serializada para auditoria por `numeric::text` no banco. Falha de qualquer evento reverte toda a tentativa.

## Red-team F37

O desenho final rejeita:

- payload forjado de scope/actor/event IDs;
- `itemId` desvinculado do `contractingId` candidato;
- item retired ou parent inativo mutável;
- oracle cross-team/inexistente;
- policy multiusuário implícita;
- DML direto no runtime;
- expansão de F26/F29/F32/F35;
- authority sobre allocator, reorder, retire/restore ou `contractings`;
- trim, empty-to-NULL ou regra de negócio inventada;
- float JavaScript para quantity;
- expected parcial com last-write-wins;
- stale expected convertido em `unchanged`;
- no-op com timestamp/evento;
- update parcial quando evento falha;
- audit blob JSON inventado;
- alteração de migrations `0001..0008`;
- provider hosted, secret ou dado real.

## Verificação F37

Head de design `811786a774342a23b09576e6bb7f6040443a5775`:

- F29 run `35011273671`: PASS;
- F35 run `35011273867`: PASS;
- F32 run `35011273734`: PASS;
- F22 run `35011273773`: PASS;
- CI run `35011273737`: PASS.

Depois do checkpoint, head final da PR `40a7fb0de96ae571b4a07afc43c41bf1787da0a8`:

- F29 run `35011718484`: PASS;
- F35 run `35011718305`: PASS;
- F32 run `35011718284`: PASS;
- F22 run `35011718452`: PASS;
- CI run `35011718318`: PASS.

A PR #57 foi integrada por merge `88d7d43f06afe8a9eef4d446331c173a8d238856`.

Pós-merge em `main`:

- F29 run `35011821924`: PASS;
- F35 run `35011821930`: PASS;
- F32 run `35011822011`: PASS;
- F22 run `35011822040`: PASS;
- CI run `35011822038`: PASS.

O diff F37 alterou somente documentação, ADR e SPECs. Nenhum arquivo operacional, migration, policy, grant, workflow de authority ou provider foi alterado na F37.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item`.

A SPEC está em `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`.

F38 começa em migration `0009_contracting_item_mutation.sql` e deve implementar capability/RLS/primitive dedicadas, provisioning de EXECUTE, adapter server-only e a matriz adversarial PostgreSQL/concorrência da ADR-015. Server Action e UI permanecem fora da F38.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-004 e Q-009 permanecem abertas.
