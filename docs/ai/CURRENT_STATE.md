# Current State - Compras

**PROJECT_STATUS:** F37_DESIGN_VERIFIED_F38_READY_AFTER_PROMOTION  
**CURRENT_PHASE:** F37 concluída e verificada na PR #57; promoção pendente; F38 é a próxima implementação; F21 ON HOLD  
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
**LAST_GOOD_MAIN_COMMIT:** `738666901fae43ce25dd11398904735e15c85da1`  
**LAST_GOOD_MAIN_CI_RUN:** `35010854766`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A sessão recuperou o estado real do GitHub antes de iniciar F37. `main` apontava para o checkpoint F36/F37 em `a65ceca1eb6662c96882f0569a0ae8b17bb884f5`, mas existia uma frente operacional ainda não promovida na branch `repair-f29-concurrency-conflict`.

Essa branch correspondia à regressão concorrencial real encontrada após o checkpoint anterior na boundary F29. O protocolo canônico determinou concluir e verificar essa frente antes de executar a NEXT_ACTION de design.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos. Todos os blobs declarados continuaram idênticos. `CONTEXT_STATUS = VALID`.

## Reparo F29 promovido antes da F37

A criação mínima de contratação da F29 usava `ON CONFLICT (id) DO NOTHING`. `contractings` possui, além da PK em `id`, a unique composta `(team_id, id)` usada por FKs escopadas. Sob retries concorrentes da mesma solicitação, PostgreSQL podia detectar primeiro a unique composta e lançar `23505`, impedindo o resultado idempotente `already-created`.

A PR `#56` materializou a correção como migration aditiva:

`database/migrations/0008_contracting_create_concurrency_repair.sql`

Migrations `0001..0007` permaneceram byte-for-byte imutáveis.

A correção substitui apenas o corpo da primitive F29 para usar `ON CONFLICT DO NOTHING` e, após qualquer conflito de unicidade, executar a mesma verificação exata e autorizada de replay antes de retornar `already-created`. Colisão não equivalente continua `denied` e não vira oracle.

O teste concorrente foi ampliado para rodadas repetidas com oito writers.

### Red-team do reparo

O primeiro head da PR #56 falhou corretamente: `CREATE OR REPLACE FUNCTION` executado como o owner selado não possuía `CREATE` no schema `public`.

O reparo foi corrigido para:

1. conceder `CREATE ON SCHEMA public` ao owner somente dentro da transaction de migration;
2. obter a aresta temporária necessária para `SET ROLE`;
3. substituir a função;
4. resetar role e revogar a aresta temporária;
5. revogar `CREATE` do schema antes do postflight;
6. provar no postflight que o owner não reteve esse privilege e que owner, `SECURITY DEFINER` e `search_path` continuaram corretos.

Head verificado `4866569e96c8c1dc1547528727183f1443153b1d`:

- F29 Contracting Create run `35010742639`: PASS;
- F35 Contracting Item Create run `35010742711`: PASS;
- F32 Contracting Object Mutation run `35010742570`: PASS;
- F22 Private Preview Preflight run `35010742884`: PASS;
- CI run `35010742710`: PASS.

A PR #56 foi integrada por merge `738666901fae43ce25dd11398904735e15c85da1`. Os workflows pós-merge de `main` ficaram verdes, incluindo CI run `35010854766` e F35 run `35010854614`; nenhuma execução desse head terminou em failure.

A partir desse merge, migrations aplicadas `0001..0008` são histórico imutável.

## F37 - desenho da edição persistente mínima de item

Com `main` reparado e verde, a única NEXT_ACTION canônica F37 foi executada na branch `f37-persistent-contracting-item-mutation-design`, PR `#57`.

F37 permaneceu design-only. Nenhuma migration, primitive, grant, policy, provisioning, adapter, Server Action ou UI da edição de item foi implementada.

Artefatos:

- `docs/decisions/ADR-015-minimal-persistent-contracting-item-mutation.md`;
- `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`;
- SPEC F37 atualizada para `COMPLETED / DESIGN PASS`.

### Decisão de concorrência

A mutação futura usa snapshot completo dos quatro campos editáveis:

```text
description
quantity
unit
catalog_code
```

O contrato server-only recebe `contractingId + itemId`, os quatro valores esperados e os quatro valores novos.

`SELECT ... FOR UPDATE` é feito somente na row do item. Depois da autorização e lock:

1. qualquer divergência entre estado atual e snapshot esperado retorna `conflict`;
2. somente com expected atual, snapshot novo idêntico retorna `unchanged`;
3. caso contrário, a operação retorna `updated`.

`conflict` é avaliado antes de `unchanged`. Isso impede lost update entre campos diferentes e impede replay pós-sucesso de criar novo histórico.

### Semântica de dados

- `description`, `unit` e `catalog_code` não sofrem trim ou normalização;
- `description` continua `NOT NULL`, mas `''` e spaces-only não são proibidos;
- `unit` e `catalog_code` preservam `NULL`, `''` e espaços como valores distintos;
- `quantity` permanece `numeric NULL` no PostgreSQL e `string | null` na interface TypeScript;
- nenhum `Number` ou `parseFloat` é permitido;
- numeric inválido deve falhar fechado como `unavailable`, sem update/evento e sem detalhe interno;
- não foi criada regra de positividade, escala, precisão de negócio, unidade obrigatória ou catálogo obrigatório.

### Autorização

O guard segue F26/F32/F35 por team alvo:

- identidade interna ativa;
- item candidato vinculado ao `contractingId` candidato e visível sob RLS;
- item com `retired_at IS NULL`;
- parent no mesmo team, não arquivado e não cancelado;
- membership do usuário não revogada no team;
- exatamente uma membership não revogada no team.

Segundo membro não revogado bloqueia, inclusive se o app_user estiver desabilitado. Outra membership do mesmo usuário em outro team não bloqueia por si só.

Team, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs nunca são authority do browser.

### Capability e auditoria

F38 terá capability própria equivalente a `compras_contracting_item_mutation_owner`, sem ampliar F26/F29/F32/F35.

Authority máxima de UPDATE em item:

```text
description
quantity
unit
catalog_code
updated_at
```

Sem INSERT/DELETE de item, sem alteração de ordinal/retired/scope, sem UPDATE em `contractings`, sem authority no allocator F35 e sem UPDATE/DELETE de eventos.

Uma mudança de N campos gera exatamente N eventos escalares `item_changed`, um por campo realmente alterado, usando `field_key`, `old_value`, `new_value`, `item_id` e o mesmo `operation_at`. Quantity é auditada a partir de `numeric::text` no banco. No-op gera zero eventos. Falha de qualquer evento reverte toda a operação.

O adapter F38 gerará quatro event UUIDs server-side por tentativa, mapeados fixamente aos quatro campos. Nenhum deles vem do browser.

### Resultados sanitizados

Primitive futura:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

Adapter futuro:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

`conflict` e `unchanged` só são observáveis depois da autorização. Cross-team, inexistente, retired, parent mismatch e demais negações continuam indistinguíveis externamente.

## Red-team F37

O desenho final rejeita explicitamente:

- scope/actor/event UUID controlados pelo browser;
- `itemId` desvinculado do `contractingId` candidato;
- mutação de retired ou parent inativo;
- side channel cross-team/inexistente;
- autorização multiusuário implícita;
- guard global F29 copiado sem necessidade;
- DML direto no runtime;
- expansão de capabilities existentes;
- authority sobre allocator, ordinal, retire/restore ou `contractings`;
- trim, empty-to-NULL ou validação de negócio inventada;
- float JavaScript para quantity;
- stale snapshot parcial com last-write-wins;
- stale expected convertido em `unchanged`;
- no-op com timestamp/evento;
- update sobrevivendo a falha de evento;
- audit blob JSON inventado;
- reescrita de migrations `0001..0008`;
- provider hosted, secret ou dado real.

## Verificação F37 antes do checkpoint

Head de design `811786a774342a23b09576e6bb7f6040443a5775`:

- F29 Contracting Create run `35011273671`: PASS;
- F35 Contracting Item Create run `35011273867`: PASS;
- F32 Contracting Object Mutation run `35011273734`: PASS;
- F22 Private Preview Preflight run `35011273773`: PASS;
- CI run `35011273737`: PASS.

O diff verificado antes deste checkpoint continha somente ADR-015, SPEC F37 e SPEC F38. Nenhum arquivo operacional ou de banco foi alterado pela F37.

## Próxima ação

Existe exatamente uma NEXT_ACTION canônica após a promoção da F37:

`F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item`.

A SPEC está em `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`.

F38 implementará migration `0009_contracting_item_mutation.sql`, capability e RLS dedicadas, primitive, provisioning, adapter server-only e matriz adversarial PostgreSQL/concorrência. Server Action e UI permanecem fora da F38.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-004 e Q-009 permanecem abertas.
