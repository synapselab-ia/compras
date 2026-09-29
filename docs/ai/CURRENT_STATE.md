# Current State - Compras

**PROJECT_STATUS:** F46_INTEGRATED_F47_READY  
**CURRENT_PHASE:** F46 integrada e verificada; F47 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_CONTRACTING_CREATE_NEXT_ACTION_OBJECT_ITEM_CREATE_ITEM_EDIT_RELATED_IDENTIFIER_CREATE_AND_MANUAL_TIMELINE_NOTE_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_F38_F41_F44_VALIDATED_MIGRATIONS_0001_0011_IMMUTABLE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F44_HOSTED_WRITE_VALIDATION_REQUIRED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F42_PR:** `#67`  
**F42_MERGE_COMMIT:** `53db535df7981f957674ca708bea7b30308992b3`  
**F43_PR:** `#69`  
**F43_MERGE_COMMIT:** `adab76f1a02ca4602c917d812ceb1d5721ddbfd4`  
**F44_PR:** `#71`  
**F44_FINAL_HEAD:** `c057b381454ad1d0499338fda1915ff337056fbe`  
**F44_MERGE_COMMIT:** `55f887252cfd5e5e81596e7434e6d5cec906aced`  
**F44_CI_RUN:** `36459883858`  
**F44_WORKFLOW_RUN:** `36459883410`
**F45_PR:** `#73`
**F45_FINAL_HEAD:** `e5236dbbeef4fcb8bf2d568f37c2495e41a09f1a`
**F45_MERGE_COMMIT:** `0800553d95bddc8d4f2febe29f418dd543c1c659`  
**F45_HARDENING_PR:** `#75`  
**F45_HARDENING_HEAD:** `36157c0e78783789e0d7f69700e2cb55686e4030`  
**F45_HARDENING_MERGE_COMMIT:** `60bcd9b7c86788f87d6dc76d8eec07a27611e59a`  
**F46_PR:** `#77`  
**F46_FINAL_HEAD:** `aeb8e75a097680a2c1aad5f4f1274d42fb5398dd`  
**F46_MERGE_COMMIT:** `12ff777e94ffcd14879eea6b09fb4905e3347642`  
**F46_CI_RUN:** `36575375791`  

**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto desta frente

A sessão recuperou o estado real do GitHub antes de qualquer edição.

No início da frente:

- `main` estava em `8ff39822207842f5df2b39b62a296628f75e8698`;
- não havia PR aberta;
- F43 já estava integrada;
- a única `NEXT_ACTION` canônica era F44;
- `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos e todos os blob SHAs coincidiram;
- migrations `0001..0010` foram verificadas byte-for-byte antes da implementação.

`CONTEXT_STATUS = VALID`.

O repositório permanece público e `REAL_DATA_ALLOWED = NO` continua obrigatório.

## F44 integrada

A work unit foi executada na branch:

`f44-persistent-manual-timeline-note-implement`

e promovida pela PR `#71`.

Head final promovido:

`c057b381454ad1d0499338fda1915ff337056fbe`.

Merge em `main`:

`55f887252cfd5e5e81596e7434e6d5cec906aced`.

A F44 implementou a ADR-017 sem UI e sem Server Action.

Foram adicionados:

- migration aditiva `0011_manual_timeline_note_create.sql`;
- capability dedicada `compras_manual_timeline_note_create_owner`;
- primitive `public.create_manual_timeline_note(uuid, uuid, text)`;
- provisioning separado com EXECUTE-only para runtime;
- adapter server-only;
- helper server-only de preparo do `eventId`;
- teste unitário do adapter;
- suíte SQL adversarial;
- prova PostgreSQL concorrente real;
- workflow dedicado F44.

O resultado detalhado está em:

`tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/RESULT.md`.

## Boundary F44

Contrato server-only:

```text
contractingId: string
eventId: string
note: string | null
```

`contractingId` e `eventId` são candidatos opacos. Scope, identidade, actor e autorização são derivados em boundaries confiáveis e aplicados no PostgreSQL.

A primitive grava somente `manual_note_added` com shape fechado e timestamp definido no banco.

Ela não altera `contractings.updated_at`.

A nota preserva exatamente `NULL`, vazio, spaces-only e leading/trailing spaces.

Resultados externos:

- `created`;
- `already-added`;
- `not-available`;
- `unavailable`.

## Autorização e least privilege

O guard target-team pilot-only permanece:

1. current app user ativo;
2. target ativo;
3. membership não revogada na equipe alvo;
4. exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia mesmo quando o app_user correspondente está desabilitado.

Q-009 continua aberta.

A capability F44 é dedicada e selada. Não possui ownership de tabela-base, UPDATE/DELETE de eventos nem DML em contratação, itens, identifiers ou allocator.

Runtime normal recebe somente EXECUTE da primitive F44 por provisioning separado e continua sem DML direto.

F26/F29/F32/F35/F38/F41 não receberam authority adicional.

## Idempotência e concorrência

`eventId` é estável por intenção.

`already-added` exige autorização atual e prova exata do evento canônico existente.

Mesmo UUID com payload divergente não faz overwrite.

UUIDs diferentes com nota idêntica podem criar eventos distintos.

A prova PostgreSQL real validou oito chamadas concorrentes com o mesmo UUID/payload:

- 1 `created`;
- 7 `already-added`;
- 1 evento persistido.

## Red-team e verificação

A F44 foi testada contra:

- roles/capabilities inseguras;
- runtime com INHERIT ou DML direto;
- auth/context ausente ou malformado;
- identidade desconhecida ou desabilitada;
- membership ausente/revogada;
- segundo membro não revogado;
- targets inexistentes, cross-team, arquivados e cancelados;
- colisões de UUID não equivalentes;
- replay divergente;
- event type/actor/shape incorretos;
- normalização indevida de texto;
- deduplicação por conteúdo;
- alteração de `contractings.updated_at`;
- authority cruzada entre capabilities;
- concorrência real.

O primeiro run F44 encontrou somente um defeito no teste concorrente: uso de `max(uuid)` na consulta de asserção. A agregação foi corrigida para texto, sem alteração de comportamento de produção.

Gates no head final `c057b381454ad1d0499338fda1915ff337056fbe`:

- CI `36459883858`: PASS;
- F22 Private Preview Preflight `36459883436`: PASS;
- F29 Contracting Create `36459883423`: PASS;
- F32 Contracting Object Mutation `36459883601`: PASS;
- F35 Contracting Item Create `36459883350`: PASS;
- F38 Contracting Item Mutation `36459883374`: PASS;
- F41 Related Identifier Create `36459883354`: PASS;
- F44 Manual Timeline Note Create `36459883410`: PASS.

Não havia review thread pendente na PR `#71`.

## Imutabilidade

Migrations `0001..0010` permaneceram byte-for-byte idênticas aos blobs canônicos verificados antes da execução.

A nova migration aplicada é:

- `0011_manual_timeline_note_create.sql`: `cc5d9016a5af409af8c71dd6d0f780fe5065c575`.

A partir de F44, migrations `0001..0011` são baseline imutável.

## F45 integrada

F45 foi promovida pela PR `#73`, head final `e5236dbbeef4fcb8bf2d568f37c2495e41a09f1a`, merge `0800553d95bddc8d4f2febe29f418dd543c1c659`.

A slice integrou F44 ao detalhe persistente com Server Action estreita, candidate `eventId` preparado server-side e estável apenas em retry técnico `unavailable`, transporte explícito de `NULL`/texto, feedback sanitizado, revalidação/readback protegido e demo read-only.

O diff final não tocou migrations, grants, policies, capability, primitive ou provisioning F44. Migrations `0001..0011` permaneceram imutáveis.

Todos os oito gates aplicáveis ficaram verdes no head final: CI, F22, F29, F32, F35, F38, F41 e F44. Não havia review thread pendente.

Resultado detalhado:

`tasks/F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01/RESULT.md`.

### Revisão pós-integração F45

A F45 recebeu hardening pela PR `#75`, head final `36157c0e78783789e0d7f69700e2cb55686e4030`, merge `60bcd9b7c86788f87d6dc76d8eec07a27611e59a`.

A revisão fechou as duas lacunas encontradas na auditoria pós-integração:

- o campo textual agora só existe quando `noteKind = text`; `Ausente (NULL)` envia `null` sem scalar de texto;
- a matriz adversarial de candidate/retry, malformed input, protected failure, demo e sanitização passou a ter cobertura explícita adicional.

A primeira execução do CI da revisão expôs somente um defeito em fixture de teste por uso de argumento `undefined` com valor default. A fixture foi corrigida sem mudança de produção.

No head final da revisão, CI, F22, F29, F32, F35, F38, F41 e F44 ficaram verdes. Não havia review thread pendente.

Migrations `0001..0011`, grants, policies, capability, primitive e provisioning F44 permaneceram imutáveis.

## F46 integrada

F46 foi executada como slice exclusivamente documental na branch:

`f46-persistent-responsible-mutation-design`

e promovida pela PR `#77`.

Head final validado:

`aeb8e75a097680a2c1aad5f4f1274d42fb5398dd`.

Merge em `main`:

`12ff777e94ffcd14879eea6b09fb4905e3347642`.

A frente produziu:

- `docs/decisions/ADR-018-persistent-responsible-mutation.md`;
- `tasks/F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01/SPEC.md`.

Nenhuma migration, primitive, policy, grant, provisioning, adapter, Server Action ou UI foi adicionada em F46.

### Decisão F46

ADR-018 define uma boundary dedicada para `contractings.responsible_membership_id` com:

- payload server-only restrito a `contractingId`, expected membership e new membership;
- team, actor, issuer, subject e actor membership derivados de contexto confiável;
- candidate responsável tratado somente como valor solicitado, nunca authority;
- clear para `NULL` preservado porque o schema canônico já admite responsável ausente;
- candidate não nulo limitado a membership do mesmo team, não revogada e com app_user não desabilitado;
- guard target-team pilot-only idêntico ao padrão F26/F32/F35/F38/F41/F44;
- `SELECT ... FOR UPDATE` + expected value null-safe;
- precedência `denied -> conflict -> unchanged -> candidate validation -> updated`;
- evento atômico `responsible_changed`, `field_key = 'responsible_membership_id'`, com old/new UUID textual ou `NULL`;
- capability dedicada futura, runtime sem DML direto e provisioning EXECUTE-only;
- resultados externos `updated`, `unchanged`, `conflict`, `not-available` e `unavailable`.

Q-009 permanece aberta. Enquanto o guard pilot-only exigir exatamente uma membership não revogada no target team, a boundary não permite transferência entre dois membros ativos da mesma equipe.

### Estado degradado e red-team

O red-team documental encontrou e corrigiu uma distinção importante antes da promoção:

- responsável atual apontando para membership revogada pode ser limpo/substituído quando o actor continua sendo o único membro não revogado;
- responsável atual apontando para app_user desabilitado cuja membership continua não revogada conta como segundo membro e bloqueia a capability pilot-only, em vez de ser "corrigido" contornando Q-009;
- no-op de referência revogada continua sem evento e sem novo timestamp depois de target/guard autorizados.

Também foram rejeitados:

- browser-controlled team/actor/identity;
- candidate membership como prova de autorização;
- assignment cross-team;
- nova atribuição para membership revogada;
- nova atribuição para app_user desabilitado;
- UPDATE genérico de `contractings`;
- DML direto do runtime;
- last-write-wins;
- evento sem update atômico;
- oracle cross-team por feedback;
- autoatribuição obrigatória ou responsável non-null inventado;
- alteração de migrations aplicadas;
- resolução implícita de Q-009;
- provider hosted, secret ou dado real.

### Verificação F46

O diff final da PR `#77` continha exatamente dois arquivos novos, ambos documentais.

A comparação contra o baseline pós-F45 confirmou migrations `0001..0011` byte-for-byte imutáveis.

Não havia review thread pendente antes do merge.

Gates no head final `aeb8e75a097680a2c1aad5f4f1274d42fb5398dd`:

- CI `36575375791`: PASS;
- F22 Private Preview Preflight `36575375726`: PASS;
- F29 Contracting Create `36575375568`: PASS;
- F32 Contracting Object Mutation `36575375621`: PASS;
- F35 Contracting Item Create `36575375676`: PASS;
- F38 Contracting Item Mutation `36575375679`: PASS;
- F41 Related Identifier Create `36575375596`: PASS;
- F44 Manual Timeline Note Create `36575375785`: PASS.

`REAL_DATA_ALLOWED = NO` permaneceu preservado.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01 - Implementar edição persistente do responsável interno`.

A SPEC está em:

`tasks/F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01/SPEC.md`.

F47 é T2 e deve materializar ADR-018 em migration aditiva `0012`, capability dedicada, RLS/grants mínimos, primitive, provisioning, adapter server-only, testes PostgreSQL/adversariais/concorrentes e workflow/regressões aplicáveis, sem UI ou Server Action.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.

Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas.
