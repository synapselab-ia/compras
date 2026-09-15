# Current State - Compras

**PROJECT_STATUS:** F34_DESIGN_COMPLETE_F35_READY  
**CURRENT_PHASE:** F34 concluída; F35 READY; F21 ON HOLD  
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
**F34_VALIDATED_DESIGN_HEAD:** `cfb83dbe9510495016584acda837cbcae30db5e4`  
**F34_PR_CI_RUN:** `34970699468` - PASS  
**F34_PR_F22_PREFLIGHT_RUN:** `34970699518` - PASS  
**F34_PR_F29_CREATE_RUN:** `34970699591` - PASS  
**F34_PR_F32_MUTATION_RUN:** `34970699549` - PASS  
**LAST_GOOD_COMMIT:** `cfb83dbe9510495016584acda837cbcae30db5e4`  
**LAST_GOOD_CI_RUN:** `34970699468`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A sessão recuperou `main` em `bfa9a65fae06ef8c3cc29586287160be3ab29d31`, confirmou ausência de PR aberta e ausência de branch F34 preexistente e localizou F34 como a única `NEXT_ACTION` canônica.

O `CONTEXT_MANIFEST` foi revalidado contra todos os blobs estáveis declarados. PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, ARCHITECTURE, SECURITY, DATABASE, DEFINITION_OF_DONE, SOURCE_OF_TRUTH e WORK_PROTOCOL permaneceram exatamente nos hashes esperados. `CONTEXT_STATUS = VALID`.

F34 foi classificada como T2 design-only. Foram lidos o schema físico de `contracting_items`/`contracting_events`, SECURITY, DATABASE, fontes de produto, OPEN_QUESTIONS, SPEC F34, ADR-011/012/013 e migrations F26/F29/F32 antes de fechar a decisão.

## F34 - criação persistente mínima de item desenhada

A decisão foi registrada em `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md`.

A implementação futura está especificada em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

### Payload mínimo

O adapter server-only da F35 deverá aceitar somente:

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` será `string | null` no TypeScript até o parâmetro PostgreSQL `numeric`, evitando perda de precisão por `Number` JavaScript.

Item UUID e event UUID serão gerados server-side. Team, actor, membership, issuer, subject e ordinal não são authority do browser.

Não foi criada regra de trim, empty-to-NULL, descrição non-empty, quantidade positiva, unidade obrigatória, catálogo obrigatório, limite de tamanho ou precisão/escala de negócio. Q-004 permanece aberta.

### Autorização pilot-only

A criação de item segue o guard target-team de F26/F32:

- identidade interna ativa;
- contratação alvo visível e ativa;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia, inclusive com `app_user` desabilitado. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. O guard global da F29 não é copiado porque a contratação já fornece o team canônico.

Q-009 permanece aberta.

### Capability e authority

ADR-014 escolhe capability própria equivalente a `compras_contracting_item_create_owner`.

A implementação deverá preservar:

- role `NOLOGIN`, `NOINHERIT` e não privilegiada;
- sem `BYPASSRLS`, ownership de tabela ou membership utilizável;
- primitive `SECURITY DEFINER` com `search_path = pg_catalog`;
- SQL estático e `PUBLIC EXECUTE` revogado;
- runtime normal sem DML direto;
- provisioning separado concedendo apenas `EXECUTE`;
- F26/F29/F32 sem ampliação de authority.

### Ordinal e concorrência

O browser não fornece `ordinal`.

A primitive deverá bloquear a contratação autorizada com `SELECT ... FOR UPDATE` e somente depois calcular o próximo ordinal como `1` quando não houver item ou `MAX(ordinal) + 1` caso contrário.

O cálculo considera itens retirados e não reutiliza gaps. Writes concorrentes na mesma contratação são serializados pela row pai. Contratações diferentes não usam lock global. A constraint única permanece como backstop, sem retry cego como mecanismo primário.

### Atomicidade e auditoria

Cada criação bem-sucedida deverá inserir exatamente um item e exatamente um `contracting_events` com `event_type = 'item_created'` e `item_id` correspondente, na mesma transação e com um único instante de banco para os timestamps definidos.

Falha do evento reverte o item. Negação não cria item nem evento. `contractings.updated_at` não será alterado por item create nesta boundary.

### Resultado externo

A primitive poderá distinguir apenas `created` e `denied`. A boundary server-only exporá somente:

- `created`;
- `not-available`;
- `unavailable`.

Cross-team, inexistente e demais negações protegidas permanecem sem oracle. Falha técnica não cai para demo e não expõe SQL, driver, claims, connection string, UUID interno ou ordinal.

## Red-team F34

A revisão adversarial rejeitou e o desenho final não contém:

- scope/actor/membership/ordinal/UUIDs internos controlados pelo browser;
- `MAX + 1` sem lock da contratação pai;
- retry cego de unique violation;
- lock global entre contratações;
- reutilização automática de gaps;
- DML direto para runtime;
- ampliação de F26/F29/F32;
- capability utilizável como login ou com privilege escalation;
- regra de quantidade/unidade/catálogo não suportada;
- conversão de `numeric` via `Number`/`parseFloat`;
- item ou evento sem atomicidade;
- update desnecessário de `contractings.updated_at`;
- deduplicação sem chave de negócio aprovada;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real;
- reescrita das migrations `0001..0006`.

## Verificação F34

Head de desenho validado `cfb83dbe9510495016584acda837cbcae30db5e4`:

- CI `34970699468`: PASS;
- F22 Private Preview Preflight `34970699518`: PASS;
- F29 Contracting Create `34970699591`: PASS;
- F32 Contracting Object Mutation `34970699549`: PASS.

O diff validado antes do checkpoint continha somente ADR-014 e SPEC F35.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01 - Implementar criação persistente mínima de item`.

A SPEC está em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

F35 deve implementar somente a boundary definida em ADR-014: migration `0007`, capability dedicada, primitive, provisioning, adapter server-only, provas PostgreSQL 17 e workflow dedicado. UI/Server Action permanecem fora da slice.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.