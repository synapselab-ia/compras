# Current State - Compras

**PROJECT_STATUS:** F44_INTEGRATED_F45_READY  
**CURRENT_PHASE:** F44 integrada e verificada; F45 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_CONTRACTING_CREATE_NEXT_ACTION_OBJECT_ITEM_CREATE_ITEM_EDIT_RELATED_IDENTIFIER_CREATE_UI_AND_MANUAL_TIMELINE_NOTE_BOUNDARY_INTEGRATED  
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

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01 - Integrar criação persistente de nota manual no detalhe`.

A SPEC está em:

`tasks/F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01/SPEC.md`.

F45 deve integrar a boundary F44 ao detalhe persistente com Server Action estreita, `eventId` preparado server-side e estável em retry técnico, transporte explícito de `NULL`/texto, feedback sanitizado, readback pela timeline protegida e demo read-only.

F45 não altera migration, grant, policy, capability, primitive ou provisioning F44.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.

Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas.
