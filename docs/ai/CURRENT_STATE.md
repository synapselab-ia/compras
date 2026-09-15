# Current State - Compras

**PROJECT_STATUS:** F35_INTEGRATED_F36_READY  
**CURRENT_PHASE:** F35 concluída, integrada e verificada; F36 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_UI_OBJECT_MUTATION_OBJECT_DETAIL_UI_AND_ITEM_CREATE_SERVER_BOUNDARY_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F35_HOSTED_WRITES  
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
**F35_PR:** `#52`  
**F35_FINAL_HEAD:** `aecbd46fcc9824abecd3f43656be37f0269841cf`  
**F35_MERGE_COMMIT:** `879902c9e55c60ae514e0ce961f9246202c5c9f8`  
**LAST_GOOD_COMMIT:** `879902c9e55c60ae514e0ce961f9246202c5c9f8`  
**LAST_GOOD_CI_RUN:** `34986357314`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e validação

A sessão recuperou `main` inicialmente em `51b02799e5994567ca144b38c4117271695ff7e2`, localizou a frente ativa F35 na branch `f35-contracting-item-create-implement`, PR `#52`, e confirmou que ela estava baseada no mesmo `main` canônico.

O `CONTEXT_MANIFEST` foi revalidado contra a árvore canônica. PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, ARCHITECTURE, SECURITY, DATABASE, DEFINITION_OF_DONE, SOURCE_OF_TRUTH e WORK_PROTOCOL permaneceram exatamente nos hashes declarados. `CONTEXT_STATUS = VALID`.

F35 foi tratada como T2 por envolver nova migration, capability, RLS, primitive e escrita persistente. `REAL_DATA_ALLOWED = NO` permaneceu obrigatório.

## F35 - criação persistente mínima de item integrada

F35 materializou ADR-014 sem UI/Server Action.

### Schema e capability

A migration aditiva `database/migrations/0007_contracting_item_create.sql` criou:

- `public.contracting_item_ordinal_counters` como estado técnico de allocator por contratação;
- RLS habilitada e forçada no allocator;
- capability dedicada `compras_contracting_item_create_owner`;
- primitive `public.create_contracting_item(uuid,text,numeric,text,text,uuid,uuid)`.

A capability permanece `NOLOGIN`, `NOINHERIT`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE`, `NOREPLICATION`, sem ownership de tabelas-base, sem membership utilizável e com `PUBLIC EXECUTE` revogado.

Runtime normal não recebeu DML direto. O provisioning separado concede somente `EXECUTE` da primitive F35 ao runtime de domínio validado.

F26, F29 e F32 não receberam item-create authority. A capability F35 não recebeu authority das primitives anteriores.

### Autorização pilot-only

A operação segue o guard por equipe alvo de F26/F32:

- identidade interna ativa derivada de contexto confiável;
- contratação candidata visível e ativa;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia, inclusive se seu `app_user` estiver desabilitado. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. Q-009 permanece aberta.

Cross-team, inexistente, usuário desabilitado, membership ausente/revogada, segundo membro, contratação arquivada e contratação cancelada colapsam para negação protegida.

### Allocator e concorrência

F35 mantém zero UPDATE em `contractings`.

Após autorização inicial, a primitive:

1. cria a row técnica do allocator se necessário;
2. bloqueia somente essa row com `SELECT ... FOR UPDATE`;
3. revalida identidade, contratação ativa e guard pilot-only após o lock;
4. lê `MAX(contracting_items.ordinal)` incluindo itens retirados;
5. reconcilia o máximo real com `last_ordinal`;
6. aloca `1` quando ambos inexistem ou `maior + 1` nos demais casos;
7. atualiza o allocator;
8. insere item e evento na mesma transação.

Gaps não são reutilizados. Contratações distintas usam rows de allocator distintas, sem lock global. Overflow de `integer` falha fechado sem wraparound.

O teste PostgreSQL real provou 8 writers concorrentes na mesma contratação, todos `created`, com ordinais sequenciais e únicos, 8 eventos correspondentes e allocator reconciliado. Também provou que uma contratação diferente não bloqueia atrás de allocator alheio e que uma contratação arquivada enquanto o writer espera o lock é revalidada e negada antes do insert.

### Payload e semântica

O adapter server-only `createPersistentContractingItem` aceita somente:

```text
contractingId
description
quantity
unit
catalogCode
```

Item UUID e event UUID são gerados server-side. Team, actor, membership, issuer, subject e ordinal não vêm do browser.

`description`, `unit` e `catalogCode` não sofrem trim/normalização. Vazio e espaços permanecem exatos conforme a nullability física. `quantity` permanece `string | null` até o cast PostgreSQL `numeric`, sem `Number` ou `parseFloat`.

Quantidade `NULL`, zero, negativa, fracionária e de alta precisão tecnicamente válida foi provada. Texto não convertível para `numeric` falha como `unavailable` sanitizado, sem item/evento/resíduo.

Q-004 continua aberta. Nenhuma regra de positividade, unidade obrigatória, catálogo obrigatório, escala/precisão de negócio, tamanho ou pesquisa de preços foi inventada.

### Atomicidade e auditoria

Cada sucesso cria exatamente um item e um evento `item_created`, usando o mesmo `operation_at` para timestamps previstos. `contractings.updated_at` permanece inalterado.

Falha do evento reverte item e avanço do allocator. Targets negados não recebem allocator novo, item ou evento.

A boundary externa expõe somente:

- `created`;
- `not-available`;
- `unavailable`.

Nenhum detalhe de SQL, sessão, claims, team, actor, membership, ordinal ou UUID interno é retornado.

## Red-team F35

O red-team e as suites cobriram e rejeitaram:

- capability com LOGIN, SUPERUSER, CREATEROLE ou BYPASSRLS;
- membership SET-capable ou privilege escalation da capability;
- DML direto no runtime;
- UPDATE em `contractings`;
- UPDATE/DELETE de item/evento pela capability;
- ampliação de F26/F29/F32;
- authority de browser sobre team/actor/membership/ordinal/item UUID/event UUID;
- claims ausentes, malformados ou desconhecidos;
- app_user desabilitado, membership revogada/ausente e segundo membro;
- oracle cross-team/inexistente;
- allocator criado para target negado;
- gap reuse ou exclusão de retired do máximo;
- falha de evento sem rollback integral;
- conversão JS de `numeric`;
- cast numérico inválido com resíduo;
- overflow de ordinal com wraparound;
- update de `contractings.updated_at`;
- provider hosted, secret ou dado real;
- alteração das migrations `0001..0006`.

O primeiro workflow F35 encontrou um defeito real no uso qualificado de `GREATEST`; a implementação foi corrigida para comparação explícita com semântica de `NULL`. O head corrigido e posteriormente ampliado pelo red-team ficou totalmente verde.

## Verificação F35

Head final da PR `aecbd46fcc9824abecd3f43656be37f0269841cf`:

- CI `34981481674`: PASS;
- F22 Private Preview Preflight `34981481259`: PASS;
- F29 Contracting Create `34981481276`: PASS;
- F32 Contracting Object Mutation `34981481384`: PASS;
- F35 Contracting Item Create `34981481346`: PASS.

PR `#52` integrada por merge commit `879902c9e55c60ae514e0ce961f9246202c5c9f8`.

Pós-merge em `main`:

- CI `34986357314`: PASS;
- F22 Private Preview Preflight `34986357311`: PASS;
- F29 Contracting Create `34986357632`: PASS;
- F32 Contracting Object Mutation `34986357326`: PASS;
- F35 Contracting Item Create `34986357430`: PASS.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01 - Integrar criação persistente de item no detalhe`.

A SPEC está em `tasks/F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01/SPEC.md`.

F36 deve integrar apenas Server Action/UI sobre F35, sem alterar PostgreSQL authority, migrations `0001..0007`, grants, policies ou capabilities. Demo permanece read-only. Q-004 e Q-009 permanecem abertas.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.