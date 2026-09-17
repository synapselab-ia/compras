# Current State - Compras

**PROJECT_STATUS:** F38_INTEGRATED_F39_READY  
**CURRENT_PHASE:** F38 integrada e verificada; F39 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_CREATE_OBJECT_ITEM_CREATE_UI_AND_ITEM_MUTATION_BOUNDARY_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_F38_VALIDATED_MIGRATIONS_0001_0009_IMMUTABLE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F38_HOSTED_WRITE_UI  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F26_MERGE_COMMIT:** `1e9e03eddeac9584ee6044a2393fe6b1e9a31726`  
**F27_MERGE_COMMIT:** `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`  
**F29_MERGE_COMMIT:** `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`  
**F30_MERGE_COMMIT:** `c0f6e822253e9e324f00bc674f4805f52cbca16c`  
**F32_MERGE_COMMIT:** `e7f893e8d186853b859dfb281f134d057b0b6e97`  
**F33_MERGE_COMMIT:** `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`  
**F35_MERGE_COMMIT:** `879902c9e55c60ae514e0ce961f9246202c5c9f8`  
**F36_MERGE_COMMIT:** `c177e7e8c1b3a46a5d5c3276b4945b81019c706a`  
**F29_CONCURRENCY_REPAIR_PR:** `#56`  
**F29_CONCURRENCY_REPAIR_MERGE_COMMIT:** `738666901fae43ce25dd11398904735e15c85da1`  
**F37_PR:** `#57`  
**F37_MERGE_COMMIT:** `88d7d43f06afe8a9eef4d446331c173a8d238856`  
**F38_PR:** `#59`  
**F38_FINAL_HEAD:** `3643ce63bdd9e7d0564dba7662987197610fccb5`  
**F38_MERGE_COMMIT:** `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`  
**LAST_GOOD_MAIN_COMMIT:** `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`  
**LAST_GOOD_MAIN_CI_RUN:** `35225868866`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou `main` em `a49a53d73ca99d046051fee0395db21c84f68b27`, confirmou ausência de PR aberta e de branch F38 operacional, e identificou F38 como a única `NEXT_ACTION` canônica.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos. Todos os blobs declarados permaneceram idênticos. `CONTEXT_STATUS = VALID`.

F38 foi classificada T2 por criar nova capability, policies, primitive, provisioning e adapter server-only. `REAL_DATA_ALLOWED = NO` permaneceu obrigatório.

## F38 integrada

A PR `#59` materializou ADR-015 sem Server Action ou UI.

Artefatos operacionais integrados:

- `database/migrations/0009_contracting_item_mutation.sql`;
- `database/provisioning/grant_contracting_item_mutation_runtime.sql`;
- `src/features/contracting-detail/persistent-item-mutation.ts`;
- unit tests do adapter;
- prova SQL adversarial;
- prova PostgreSQL concorrente real;
- workflow `F38 Contracting Item Mutation`.

O resultado detalhado está em `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/RESULT.md`.

Migrations `0001..0008` permaneceram byte-for-byte. Com a promoção da F38, `0001..0009` passam a ser histórico aplicado imutável.

## Boundary F38

A boundary permite modificar somente:

```text
description
quantity
unit
catalog_code
```

mais `updated_at` operacional do item.

Contrato server-only:

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

Team, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs não fazem parte da authority do caller público. Os quatro event UUIDs são gerados server-side em cada tentativa.

`quantity` permanece `string | null` até os parâmetros PostgreSQL `numeric`. Description/unit/catalog não sofrem trim ou normalização.

Resultados externos possíveis:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

`denied` interno é sempre `not-available` externo.

## Autorização e concorrência

A primitive F38:

1. resolve identidade interna ativa pelo contexto confiável;
2. seleciona `itemId + contractingId` sob RLS;
3. exige item não retired;
4. bloqueia somente a row do item com `FOR UPDATE`;
5. deriva `team_id` do banco;
6. revalida parent ativo no mesmo team;
7. deriva membership não revogada do usuário no team alvo;
8. exige exatamente uma membership não revogada no team;
9. compara o snapshot esperado completo dos quatro campos;
10. somente depois decide `conflict`, `unchanged` ou `updated`.

`conflict` é avaliado antes de `unchanged`. Portanto stale expected continua conflito mesmo quando o novo snapshot já coincide com current e retry pós-sucesso não vira replay-success.

Segundo membro não revogado bloqueia, inclusive se seu app_user estiver desabilitado. Membership adicional do mesmo usuário em outro team não bloqueia a equipe alvo por si só.

Cross-team, inexistente, parent mismatch, retired, archived/cancelled e negação de membership continuam indistinguíveis externamente.

Q-009 permanece aberta.

## Least privilege F38

A capability dedicada é:

`compras_contracting_item_mutation_owner`

Ela permanece:

- `NOLOGIN`;
- `NOINHERIT`;
- sem SUPERUSER/CREATEDB/CREATEROLE/BYPASSRLS/REPLICATION;
- sem ownership de tabelas-base;
- sem membership utilizável;
- sem schema CREATE persistente.

UPDATE permitido em `contracting_items` somente para:

```text
description
quantity
unit
catalog_code
updated_at
```

A capability não pode:

- INSERT/DELETE item;
- alterar id/team/contracting/ordinal/created_at/retired_at;
- atualizar `contractings`;
- tocar `contracting_item_ordinal_counters`;
- UPDATE/DELETE evento;
- executar boundaries F26/F29/F32/F35.

Runtime normal recebe somente `EXECUTE` F38 por provisioning separado e continua sem DML direto. Auth/read-only runtime não recebe EXECUTE F38.

## Auditoria F38

Cada campo realmente alterado gera exatamente um evento `item_changed`, em ordem:

```text
description
quantity
unit
catalog_code
```

Cada evento recebe `item_id`, `field_key`, old/new escalares e actor/team/contracting derivados do banco. Quantity é serializada por `numeric::text` no PostgreSQL.

Um único `operation_at` alimenta `contracting_items.updated_at`, `occurred_at` e `created_at` dos eventos da tentativa. No-op não atualiza timestamp e não cria evento.

Falha do primeiro, de evento intermediário ou do último evento reverte item, timestamp e todos os eventos da tentativa.

`contractings.updated_at` não é alterado.

## Red-team F38

O gate dedicado e as suites provaram:

- rejeição de capability preexistente com LOGIN, SUPERUSER, CREATEROLE ou BYPASSRLS;
- rejeição de membership SET-capable na capability;
- rejeição de runtime INHERIT e runtime com DML direto;
- isolamento de EXECUTE para domain runtime explicitamente provisionado;
- ausência de authority cruzada F26/F29/F32/F35;
- claims ausentes/malformados/desconhecidos e app_user disabled;
- membership revogada;
- segundo membro não revogado, inclusive app_user desabilitado;
- membership do mesmo usuário em outra equipe sem bloqueio indevido;
- cross-team, inexistente, parent mismatch, retired, archived e cancelled;
- forged team/actor/membership/issuer/subject/event UUID/ordinal/retired/timestamp sem authority;
- texto vazio/espaços e `NULL` preservados;
- numeric zero/negativo/fração/high precision sem float JavaScript;
- numeric inválido sem residue;
- oito writers concorrentes com mesmo expected: exatamente um `updated` e sete `conflict`;
- retry pós-sucesso sem segundo histórico;
- parent arquivado ou membership revogada enquanto writer aguarda item lock;
- rollback integral em falha do primeiro, intermediário e último evento.

O primeiro head geral de CI encontrou somente uma falha de teste flakey criada na própria F38: a asserção rejeitava qualquer UUID aleatório contendo o substring `9999`. Um UUID legítimo coincidiu casualmente. A correção passou a comparar os quatro UUIDs gerados contra os quatro UUIDs forjados exatos. Nenhuma regra de produção ou segurança foi relaxada.

## Verificação F38

Head final da PR `3643ce63bdd9e7d0564dba7662987197610fccb5`:

- CI `35225725483`: PASS;
- F22 Private Preview Preflight `35225725558`: PASS;
- F29 Contracting Create `35225725477`: PASS;
- F32 Contracting Object Mutation `35225725555`: PASS;
- F35 Contracting Item Create `35225725650`: PASS;
- F38 Contracting Item Mutation `35225725479`: PASS.

PR #59 integrada por merge commit `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`.

Pós-merge em `main`:

- CI `35225868866`: PASS;
- F22 Private Preview Preflight `35225868874`: PASS;
- F29 Contracting Create `35225868945`: PASS;
- F32 Contracting Object Mutation `35225868819`: PASS;
- F35 Contracting Item Create `35225868818`: PASS;
- F38 Contracting Item Mutation `35225868927`: PASS.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01 - Integrar edição persistente de item no detalhe`.

A SPEC está em `tasks/F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01/SPEC.md`.

F39 é integration-only e não pode alterar authority PostgreSQL. Ela deve expor F38 no detalhe persistente com:

- snapshot bruto protegido dos quatro campos, sem parse de label/note;
- expected snapshot completo;
- distinção explícita `NULL` versus texto para unit/catalogCode;
- quantity `string | null` sem coerção JS;
- Server Action que chama somente F38;
- feedback sanitizado;
- pending contra double-submit;
- demo read-only;
- sem reorder/retire/delete/preço.

Migrations `0001..0009` permanecem imutáveis durante F39.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-004 e Q-009 permanecem abertas.
