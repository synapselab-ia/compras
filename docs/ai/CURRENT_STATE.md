# Current State - Compras

**PROJECT_STATUS:** F34_DESIGN_COMPLETE_F35_READY  
**CURRENT_PHASE:** F34 concluída e verificada; F35 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_UI_OBJECT_MUTATION_AND_OBJECT_DETAIL_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_VALIDATED_F34_ITEM_CREATE_DESIGN_ACCEPTED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F34_HOSTED_WRITES  
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
**F34_PR:** `#51`  
**F34_CORRECTED_DESIGN_HEAD:** `86d1ca411ee2a74af322aae43693255651d1d0c3`  
**F34_CORRECTED_CI_RUN:** `34971780173` - PASS  
**F34_CORRECTED_F22_PREFLIGHT_RUN:** `34971780249` - PASS  
**F34_CORRECTED_F29_CREATE_RUN:** `34971780144` - PASS  
**F34_CORRECTED_F32_MUTATION_RUN:** `34971780237` - PASS  
**LAST_GOOD_COMMIT:** `86d1ca411ee2a74af322aae43693255651d1d0c3`  
**LAST_GOOD_CI_RUN:** `34971780173`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A sessão recuperou `main` em `bfa9a65fae06ef8c3cc29586287160be3ab29d31`, confirmou ausência de PR aberta e ausência de branch F34 preexistente e localizou F34 como a única `NEXT_ACTION` canônica.

O `CONTEXT_MANIFEST` foi revalidado contra todos os blobs estáveis declarados. PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, ARCHITECTURE, SECURITY, DATABASE, DEFINITION_OF_DONE, SOURCE_OF_TRUTH e WORK_PROTOCOL permaneceram exatamente nos hashes esperados. `CONTEXT_STATUS = VALID`.

F34 foi classificada como T2 design-only. Foram lidos schema físico, SECURITY, DATABASE, fontes de produto, OPEN_QUESTIONS, SPEC F34, ADR-011/012/013 e migrations F26/F29/F32.

## F34 - criação persistente mínima de item desenhada

A decisão aceita está em `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md`.

A implementação futura está especificada em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

### Payload

A futura boundary server-only aceita apenas:

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` será `string | null` até PostgreSQL `numeric`. Item UUID e event UUID são gerados server-side. Team, actor, membership, issuer, subject e ordinal ficam fora da authority do browser.

Não foi criada regra de trim, empty-to-NULL, descrição non-empty, quantidade positiva, unidade obrigatória, catálogo obrigatório, limite de tamanho ou precisão/escala de negócio. Q-004 permanece aberta.

### Autorização

O guard segue F26/F32 por equipe alvo:

- identidade interna ativa;
- contratação visível e ativa;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia, inclusive com `app_user` desabilitado. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. Q-009 permanece aberta.

### Capability

ADR-014 escolhe capability própria equivalente a `compras_contracting_item_create_owner`, com role `NOLOGIN`, `NOINHERIT`, não privilegiada, `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático, `PUBLIC EXECUTE` revogado e runtime normal recebendo somente `EXECUTE`.

F26/F29/F32 permanecem inalteradas.

### Red-team e correção do lock

O primeiro rascunho usava `SELECT ... FOR UPDATE` em `contractings` para serializar `MAX(ordinal) + 1`.

O red-team manual bloqueou essa abordagem porque locking clauses PostgreSQL exigem privilégio `UPDATE`. Conceder UPDATE à capability de item create ampliaria authority sobre a contratação pai sem necessidade funcional.

O desenho final usa tabela técnica de allocator por contratação:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
```

Fluxo final:

1. autorizar a contratação por leitura protegida;
2. criar a row do allocator somente após autorização;
3. bloquear a row do allocator;
4. revalidar autorização após o lock;
5. reconciliar `last_ordinal` com `MAX(ordinal)` real, incluindo retired;
6. alocar `1` se não houver valor ou `maior + 1` caso contrário;
7. atualizar allocator e inserir item + evento na mesma transação.

A capability recebe UPDATE somente de `last_ordinal` e zero UPDATE em `contractings`.

Writers da mesma contratação serializam na mesma row técnica. Contratações diferentes usam rows distintas, sem lock global. Gaps não são reutilizados. Falha de item/evento reverte também o allocator.

### Atomicidade e resultado

Cada sucesso gera exatamente um item e um evento `item_created` atômicos. `contractings.updated_at` não é alterado.

A futura boundary expõe somente `created`, `not-available` e `unavailable`.

## Red-team F34

O desenho final rejeita:

- authority de browser sobre scope/actor/membership/ordinal/UUIDs internos;
- UPDATE em `contractings` só para locking;
- allocator antes de autorização ou sem revalidação após lock;
- `MAX + 1` sem serialização;
- retry cego de unique violation;
- lock global;
- reutilização automática de gaps;
- DML direto para runtime;
- ampliação de F26/F29/F32;
- capability privilegiada ou utilizável como login;
- regras de quantidade/unidade/catálogo não suportadas;
- conversão de `numeric` por `Number`/`parseFloat`;
- item/evento/allocator sem atomicidade;
- update de `contractings.updated_at`;
- deduplicação sem chave canônica;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real;
- reescrita de migrations aplicadas.

## Verificação F34

O primeiro head `cfb83dbe9510495016584acda837cbcae30db5e4` passou os gates automatizados, mas não foi promovido após o red-team detectar a questão de privilégio do row lock.

Head corrigido `86d1ca411ee2a74af322aae43693255651d1d0c3`:

- CI `34971780173`: PASS;
- F22 Private Preview Preflight `34971780249`: PASS;
- F29 Contracting Create `34971780144`: PASS;
- F32 Contracting Object Mutation `34971780237`: PASS.

O diff da F34 permanece exclusivamente documental. Migrations `0001..0006`, código operacional, grants, policies, provider hosted, secrets e dados reais permanecem intocados.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01 - Implementar criação persistente mínima de item`.

A SPEC está em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

F35 deve implementar somente ADR-014: migration `0007`, allocator técnico, capability dedicada, primitive, provisioning, adapter server-only, provas PostgreSQL 17 e workflow dedicado. UI/Server Action permanecem fora da slice.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.