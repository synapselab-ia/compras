# Current State - Compras

**PROJECT_STATUS:** F31_INTEGRATED_F32_READY  
**CURRENT_PHASE:** F31 integrada em `main`; F32 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_BOUNDARY_AND_F30_CREATE_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_NARROW_NEXT_ACTION_MUTATION_MINIMAL_CREATE_VALIDATED_OBJECT_MUTATION_DESIGNED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F31_HOSTED_WRITES  
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
**F31_PR:** `#47` - MERGED  
**F31_FINAL_PR_HEAD:** `c908e931c30f352b5614e13e76bc277190868bc0`  
**F31_PR_CI_RUN:** `34702329753` - PASS  
**F31_PR_F22_PREFLIGHT_RUN:** `34702329739` - PASS  
**F31_PR_F29_CREATE_RUN:** `34702329761` - PASS  
**F31_MERGE_COMMIT:** `b541592aa4a392dfab439389daaddcd4c811c5e5`  
**F31_MAIN_CI_RUN:** `34702460575` - PASS  
**F31_MAIN_F22_PREFLIGHT_RUN:** `34702460564` - PASS  
**F31_MAIN_F29_CREATE_RUN:** `34702460571` - PASS  
**LAST_GOOD_COMMIT:** `b541592aa4a392dfab439389daaddcd4c811c5e5`  
**LAST_GOOD_CI_RUN:** `34702460575`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e promoção desta sessão

A sessão recuperou `main` em `ac0162677f39d1f176ad5a9e0c431770c3d3d204`, confirmou que não havia PR nem branch F31 ativa e localizou F31 como a única `NEXT_ACTION` canônica.

Os 10 blobs do `CONTEXT_MANIFEST` foram revalidados e todos coincidiram com os hashes esperados. `CONTEXT_STATUS = VALID`.

F31 foi classificada como T2 de desenho arquitetural. Foram inspecionados ADR-011/ADR-012, SECURITY, DATABASE, Q-009, F25/F26/F27/F29/F30, migrations 0004/0005, matrizes PostgreSQL F26/F29 e adapters/Server Actions associados.

A implementação documental foi realizada na branch `f31-contracting-object-mutation-design`, PR `#47`. O diff final continha somente seis arquivos de documentação/SPEC, sem migration, SQL, adapter, Server Action ou UI. Não houve provider hosted write, secret, dado real ou alteração das migrations aplicadas `0001..0005`.

O head final `c908e931c30f352b5614e13e76bc277190868bc0` passou CI, F22 Private Preview Preflight e F29 Contracting Create antes da promoção. A PR `#47` foi integrada por merge commit `b541592aa4a392dfab439389daaddcd4c811c5e5`, e os três workflows pós-merge também passaram em `main`.

## F31 - edição persistente de object desenhada

A decisão canônica está em `docs/decisions/ADR-013-persistent-contracting-object-mutation.md`.

### Alternativa adotada

A edição de `contractings.object` terá capability PostgreSQL própria. Foram rejeitados:

- ampliar F26;
- ampliar F29;
- conceder DML direto à role runtime.

A futura role técnica equivalente a `compras_contracting_object_mutation_owner` deve permanecer `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. A primitive será `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

### Payload e confiança

A interface server-only futura recebe somente:

```text
contractingId
expectedObject
newObject
```

Event UUID nasce server-side. Team, actor, membership, creator, issuer e subject são derivados exclusivamente da sessão Better Auth validada + contexto LOCAL + banco.

`object` permanece `text NOT NULL` e é preservado exatamente, inclusive string vazia e espaços. Não existe trim, limite, regra non-empty ou empty-to-NULL inventado.

### Autorização pilot-only

A regra segue F26 porque a linha existente já possui `team_id` canônico:

- identidade interna ativa;
- contratação visível e não arquivada/cancelada;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia mesmo com `app_user` desabilitado.

Uma membership adicional do mesmo usuário em outra equipe não bloqueia por si só. O guard global de exatamente uma membership da F29 é específico da criação antes de existir team derivável da row e não será copiado para edição.

Q-009 continua aberta.

### Concorrência e histórico

A primitive futura deve usar `SELECT ... FOR UPDATE` + precondição exata/null-safe de `expectedObject`.

Ordem após autorização:

1. stale expected resulta em `conflict`;
2. expected atual + novo valor igual resulta em `unchanged`;
3. mudança real atualiza `object`/`updated_at` e cria exatamente um evento `object_changed`.

`conflict` vem antes de `unchanged`, inclusive quando o estado atual já coincide com `newObject`, evitando converter stale write em sucesso causalmente ambíguo.

Mudança real cria `field_key = 'object'`, old/new exatos, actor/team derivados e mesmo instante para estado/evento. Falha do evento reverte o update. Eventos permanecem append-only.

Retry idêntico após sucesso retorna conflito por expected stale e não cria segundo evento. F31 não introduz replay-success para mutações de campo.

### Resultados sanitizados

A boundary futura expõe somente:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para negação;
- `unavailable` para falha técnica.

Cross-team, inexistente, identidade inválida, membership ausente/revogada, segundo membro e contratação arquivada/cancelada permanecem indistinguíveis externamente.

## Red-team F31

O desenho e o diff integral foram revisados contra:

- authority controlada pelo browser;
- reutilização indevida de F26/F29;
- DML direto de runtime;
- capability com grants além de `object`/`updated_at`;
- update sem evento atômico;
- trim/normalização/empty-to-NULL;
- lost update;
- stale expected convertido em no-op/sucesso;
- side channel cross-team;
- inferência de política multiusuário;
- cópia indevida do guard global F29;
- reescrita de migrations aplicadas;
- provider hosted, secret ou dado real.

Nenhum desses caminhos foi aceito. Não havia review threads pendentes na PR.

## Verificação F31

F31 é design-only. Nenhum código operacional, migration, SQL, adapter, Server Action ou UI foi alterado.

A matriz adversarial de F32 foi registrada em `tasks/F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01/SPEC.md`, incluindo concorrência real PostgreSQL, rollback, isolamento F26/F29 e preservação de string vazia/espaços.

Gates no head final da PR `c908e931c30f352b5614e13e76bc277190868bc0`:

- CI `34702329753`: PASS, com verify, database e auth-database;
- F22 Private Preview Preflight `34702329739`: PASS;
- F29 Contracting Create `34702329761`: PASS.

Pós-merge `b541592aa4a392dfab439389daaddcd4c811c5e5`:

- CI `34702460575`: PASS;
- F22 Private Preview Preflight `34702460564`: PASS;
- F29 Contracting Create `34702460571`: PASS.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01 - Implementar boundary persistente de edição do objeto`.

F32 implementará somente PostgreSQL/server-only. UI/Server Action de edição ficará para work unit posterior.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.
