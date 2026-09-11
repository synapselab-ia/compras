# Current State — Compras

**PROJECT_STATUS:** F27_INTEGRATED_F28_DESIGN_COMPLETED_PR_F29_READY  
**CURRENT_PHASE:** F28 concluída por ADR-012 e verificada na PR #44; checkpoint final da PR em validação; F29 READY; F21 ON HOLD; F17 ON HOLD histórico  
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
**F27_PR:** `#43` — MERGED  
**F27_FINAL_PR_HEAD:** `cf5d939f91d758c47cb713eeb8143a6dee3c9cce`  
**F27_MERGE_COMMIT:** `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`  
**F27_MAIN_CI_RUN:** `34615115211` — PASS  
**F27_MAIN_PREFLIGHT_RUN:** `34615115289` — PASS  
**F28_PR:** `#44` — OPEN / CHECKPOINT FINAL EM VALIDAÇÃO  
**F28_DESIGN_VERIFIED_HEAD:** `53145f2887b7ad14d7a3d404238b15a749ef1c02`  
**F28_DESIGN_CI_RUN:** `34616454186` — PASS  
**F28_DESIGN_PREFLIGHT_RUN:** `34616454064` — PASS  
**LAST_GOOD_COMMIT:** `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`  
**LAST_GOOD_CI_RUN:** `34615115211`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A sessão retomou a PR #43 no ponto exato deixado pelo checkpoint anterior. Os gates finais do head documental estavam verdes e a F27 foi promovida:

- PR `#43`: MERGED;
- merge em `main`: `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`;
- CI pós-merge `34615115211`: PASS;
- F22 Private Preview Preflight pós-merge `34615115289`: PASS.

Depois disso, a única `NEXT_ACTION` canônica F28 foi iniciada em `f28-persistent-contracting-create-design`, PR `#44`.

Não havia branch/PR F28 pré-existente. O `CONTEXT_MANIFEST` foi revalidado contra os 10 blobs estáveis e permaneceu `VALID`.

A inspeção obrigatória incluiu produto, questões abertas, SECURITY, DATABASE, ADR-003/005/009/011, migrations `0001..0004`, F26/F27 e Definition of Done.

Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## F28 — criação persistente mínima desenhada

A ADR-012 define uma boundary pilot-only para o cadastro inicial de `contractings`.

### Payload

A futura criação recebe somente:

```text
contractingId
object
```

`contractingId` é UUID preparado pelo servidor antes da submissão e funciona também como idempotency key da solicitação preparada. Não é segredo nem autorização.

`object` é preservado exatamente. Não foi inventado trim, tamanho máximo ou regra non-empty além do `NOT NULL` já existente no schema.

`next_action`, stage, status, responsável, waiting, itens e identificadores ficam fora da criação inicial. Campos nullable começam `NULL`; `next_action` continua sendo alterado posteriormente pela boundary F26/F27.

### Escopo e ator

Team, actor e `created_by_membership_id` nunca vêm do browser.

A criação só é elegível quando:

1. `current_app_user_id()` resolve para usuário ativo;
2. o usuário possui exatamente uma membership não revogada em todo o banco;
3. o team derivado não está arquivado;
4. o team possui exatamente uma membership não revogada.

Múltiplas memberships do usuário bloqueiam por ambiguidade. Segundo membro não revogado no team também bloqueia, inclusive quando o `app_user` correspondente está desabilitado. Q-009 continua aberta.

### Capability

Criação recebe capability própria equivalente a `compras_contracting_create_owner`; a capability F26 não é ampliada.

A nova role deve ser `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável, seguindo ADR-005.

A primitive é `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado. Runtime normal continua sem DML direto e recebe somente `EXECUTE` explícito em provisionamento separado.

### Estado e evento

A nova contratação persiste apenas `id`, team derivado, `object`, creator derivado e timestamps. Responsible/stage/status/waiting/next_action/archived/cancelled ficam `NULL`.

Na mesma transação nasce exatamente um evento `contracting_created`, com team/actor/contracting derivados. Os quatro timestamps de row/event usam o mesmo instante de banco. Falha do evento reverte o cadastro.

### Idempotência

Replay com mesmo candidate UUID só retorna `already-created` depois de autorização corrente e prova exata de mesmo team derivado, mesmo creator derivado e mesmo `object`.

Colisão diferente ou cross-team retorna negação genérica. Double-submit concorrente deve produzir uma única row, um único evento, um `created` e os demais `already-created`.

Não há deduplicação semântica por texto de objeto e não foi introduzida infraestrutura externa de idempotência.

## Red-team F28

A decisão rejeita:

- team/actor/membership/issuer/subject/created_by confiáveis do browser;
- escolha silenciosa entre múltiplas memberships;
- autorização multiusuário implícita;
- `INSERT` direto no runtime;
- ampliação da capability F26;
- criador automaticamente responsável;
- stage/status/waiting/next_action obrigatórios na criação;
- cadastro sem evento atômico;
- idempotência por segredo client-side;
- deduplicação por `object` sem regra de negócio;
- side channel de colisão cross-team;
- reescrita de migrations `0001..0004`.

Q-001, Q-002, Q-006 e Q-009 permanecem abertas.

## Verificação F28

Head de design `53145f2887b7ad14d7a3d404238b15a749ef1c02`:

- CI `34616454186`: PASS — verify, database e auth-database;
- F22 Private Preview Preflight `34616454064`: PASS;
- lint/typecheck/test/build: PASS;
- foundation/RLS/F26: PASS;
- Better Auth/F24: PASS.

A PR recebeu commits documentais posteriores para fechar SPEC/checkpoint e avançar a única próxima ação. Esses commits devem receber os mesmos gates verdes antes do merge.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01 — Implementar boundary de criação persistente mínima`.

F29 deve materializar ADR-012 por migration `0005`, capability/grants mínimos, primitive de criação, provisionamento separado, interface server-only e testes PostgreSQL de autorização/atomicidade/idempotência concorrente. Server Action/UI de cadastro ficam fora dessa slice.

F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.
