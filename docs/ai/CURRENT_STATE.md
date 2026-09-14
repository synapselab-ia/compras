# Current State - Compras

**PROJECT_STATUS:** F32_INTEGRATED_F33_READY  
**CURRENT_PHASE:** F32 integrada em `main`; F33 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_UI_AND_OBJECT_MUTATION_BOUNDARY_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_NARROW_NEXT_ACTION_MUTATION_MINIMAL_CREATE_AND_OBJECT_MUTATION_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F32_HOSTED_WRITES  
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
**F32_PR:** `#48` - MERGED  
**F32_FINAL_PR_HEAD:** `69e304c1fc47e0f548df70f4900b12b9a82d8483`  
**F32_PR_CI_RUN:** `34840241372` - PASS  
**F32_PR_F22_PREFLIGHT_RUN:** `34840241356` - PASS  
**F32_PR_F29_CREATE_RUN:** `34840241361` - PASS  
**F32_PR_F32_MUTATION_RUN:** `34840241521` - PASS  
**F32_MERGE_COMMIT:** `e7f893e8d186853b859dfb281f134d057b0b6e97`  
**F32_MAIN_CI_RUN:** `34840505900` - PASS  
**F32_MAIN_F22_PREFLIGHT_RUN:** `34840505998` - PASS  
**F32_MAIN_F29_CREATE_RUN:** `34840505896` - PASS  
**F32_MAIN_F32_MUTATION_RUN:** `34840505989` - PASS  
**LAST_GOOD_COMMIT:** `e7f893e8d186853b859dfb281f134d057b0b6e97`  
**LAST_GOOD_CI_RUN:** `34840505900`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e promoção desta sessão

A sessão recuperou o estado real do GitHub em `main`, localizou F32 como a única `NEXT_ACTION` canônica e confirmou que não havia frente F32 preexistente em PR/branch. Os blobs do `CONTEXT_MANIFEST` foram revalidados contra os hashes canônicos antes da execução. `CONTEXT_STATUS = VALID`.

F32 foi classificada como feature T1 com impacto T2 em banco/autorização. Foram lidos ADR-013, SECURITY, DATABASE, SPEC F32, migrations/provisionamentos/testes F26/F29 e `withTrustedDatabaseMutationContext` antes de materializar a boundary.

A implementação foi realizada na branch `f32-contracting-object-mutation-implement`, PR `#48`. O diff final adicionou somente a migration F32, provisionamento, provas PostgreSQL, adapter server-only, testes e workflow dedicado. Migrations aplicadas `0001..0005` permaneceram imutáveis. Não houve UI/Server Action nesta slice, provider hosted write, secret ou dado real.

O head `69e304c1fc47e0f548df70f4900b12b9a82d8483` passou todos os gates da PR. A PR `#48` foi integrada por merge commit `e7f893e8d186853b859dfb281f134d057b0b6e97`. CI, F22, F29 e o workflow F32 passaram novamente em `main` após o merge.

## F32 - boundary persistente de edição de object integrada

### Capability e least privilege

`database/migrations/0006_contracting_object_mutation.sql` cria `compras_contracting_object_mutation_owner` como capability separada de F26/F29.

A role é `NOLOGIN`, `NOINHERIT`, `NOSUPERUSER`, `NOBYPASSRLS`, sem ownership de tabelas-base, sem membership utilizável e sem schema `CREATE` residual. O runtime normal não recebe DML direto.

A primitive `public.mutate_contracting_object(uuid,text,text,uuid)` é `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado. `database/provisioning/grant_contracting_object_mutation_runtime.sql` concede somente `EXECUTE` ao runtime explicitamente escolhido.

F26 não ganhou authority sobre `object`. F29 não ganhou update authority. F32 não herdou EXECUTE das primitives F26/F29.

### Payload e confiança

O adapter server-only `src/features/contracting-detail/persistent-object-mutation.ts` aceita somente:

```text
contractingId
expectedObject
newObject
```

O event UUID é gerado server-side. Team, actor, membership, issuer e subject não são aceitos do browser. O adapter usa `withTrustedDatabaseMutationContext` para estabelecer o contexto LOCAL confiável e devolve somente:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

Detalhes internos de banco/driver não são propagados.

### Autorização pilot-only

A autorização segue o guard da F26 por equipe alvo:

- identidade interna ativa;
- contratação alvo visível, não arquivada e não cancelada;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia mesmo quando o `app_user` correspondente está desabilitado.

Uma membership adicional do mesmo usuário em outra equipe não bloqueia por si só, pois a row existente define a equipe canônica. O guard global da F29 não foi copiado.

Q-009 continua aberta.

### Concorrência, string exata e histórico

A primitive usa `SELECT ... FOR UPDATE` e compara `expectedObject` exatamente.

Ordem após autorização:

1. stale expected retorna `conflict`;
2. expected atual + novo valor igual retorna `unchanged`;
3. mudança real atualiza `object`/`updated_at` e cria exatamente um `object_changed`.

`conflict` é avaliado antes de `unchanged`, inclusive quando outro writer já chegou ao mesmo `newObject`.

`object` continua `text NOT NULL` sem regra inventada de trim, tamanho, non-empty ou empty-to-NULL. String vazia, spaces-only e leading/trailing spaces são preservados exatamente.

Mudança real cria `field_key = 'object'`, old/new exatos, actor/team derivados e o mesmo instante de banco para `contractings.updated_at`, `contracting_events.occurred_at` e `created_at`.

Falha de inserção do evento reverte também a atualização e o timestamp. No-op não altera timestamp nem cria evento.

### Indistinguibilidade de negação

Cross-team, UUID inexistente, identidade inválida, membership ausente/revogada, segundo membro, contratação arquivada e contratação cancelada resultam externamente em negação genérica, sem oracle de existência.

## Red-team F32

A matriz adversarial rejeita:

- capability com `LOGIN`, `BYPASSRLS` ou membership `SET` utilizável;
- runtime com DML direto;
- capability atualizando colunas fora de `object`/`updated_at`;
- reutilização ou vazamento de authority entre F26/F29/F32;
- claims ausentes/malformados/desconhecidos;
- usuário desabilitado;
- membership ausente ou revogada;
- segundo membro não revogado na equipe alvo, inclusive `app_user` desabilitado;
- lost update e stale retry convertido em sucesso;
- trim/normalização de vazio/espaços;
- evento em no-op/conflito/negação;
- diferença externa entre cross-team e inexistente;
- escrita em arquivado/cancelado;
- update sobrevivendo à falha do evento;
- provider hosted, secret ou dado real.

A prova de concorrência PostgreSQL dispara 8 writers com o mesmo expected value. O resultado provado é exatamente 1 `updated`, 7 `conflict` e 1 evento correspondente ao estado vencedor.

## Verificação F32

Head final da PR `69e304c1fc47e0f548df70f4900b12b9a82d8483`:

- CI `34840241372`: PASS;
- F22 Private Preview Preflight `34840241356`: PASS;
- F29 Contracting Create `34840241361`: PASS;
- F32 Contracting Object Mutation `34840241521`: PASS.

Pós-merge `e7f893e8d186853b859dfb281f134d057b0b6e97`:

- CI `34840505900`: PASS;
- F22 Private Preview Preflight `34840505998`: PASS;
- F29 Contracting Create `34840505896`: PASS;
- F32 Contracting Object Mutation `34840505989`: PASS.

O workflow F32 executa PostgreSQL 17, preflight adversarial de role/capability, matriz SQL completa e teste real de concorrência. CI preserva lint, typecheck, testes, build, database e auth-database.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01 - Integrar edição persistente do objeto no detalhe`.

A SPEC está em `tasks/F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01/SPEC.md`.

F33 deve apenas conectar a boundary F32 ao detalhe persistente por Server Action/UI estreita, mantendo migrations `0001..0006` e capabilities imutáveis, demo read-only, exact-string, expected-value, conflito sem overwrite e authority fora do browser.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.
