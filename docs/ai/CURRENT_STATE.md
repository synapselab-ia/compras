# Current State - Compras

**PROJECT_STATUS:** F43_INTEGRATED_F44_READY  
**CURRENT_PHASE:** F43 integrada e verificada; F44 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_CONTRACTING_CREATE_NEXT_ACTION_OBJECT_ITEM_CREATE_ITEM_EDIT_AND_RELATED_IDENTIFIER_CREATE_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_F38_F41_VALIDATED_MIGRATIONS_0001_0010_IMMUTABLE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F43_HOSTED_WRITE_VALIDATION_REQUIRED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F42_PR:** `#67`  
**F42_MERGE_COMMIT:** `53db535df7981f957674ca708bea7b30308992b3`  
**F43_PR:** `#69`  
**F43_FINAL_HEAD:** `c253311e989d0d4f93031ab7cbbea3ac875005e5`  
**F43_MERGE_COMMIT:** `adab76f1a02ca4602c917d812ceb1d5721ddbfd4`  
**F43_CI_RUN:** `35997435206`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto desta frente

A sessão recuperou `main` no checkpoint F42/F43, commit `47b9ec768a408e12d81e49219ebff5c9eacd0609`.

Não havia PR aberta. As branches F42 e checkpoint anteriores eram históricas; não existia branch operacional F43 ativa. A única frente canônica era:

`F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01 - Desenhar criação persistente de nota manual na timeline`.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos e todos os blob SHAs coincidiram. `CONTEXT_STATUS = VALID`.

Como F43 é T2, foram lidos diretamente SECURITY, DATABASE, Definition of Done, PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, o schema físico de `contracting_events`, as migrations/capabilities de escrita recentes e o resultado F42.

O repositório continua público e `REAL_DATA_ALLOWED = NO` permanece obrigatório.

## F43 integrada

A work unit foi executada na branch:

`f43-persistent-manual-timeline-note-design`

e promovida pela PR `#69`.

Head final promovido:

`c253311e989d0d4f93031ab7cbbea3ac875005e5`.

Merge em `main`:

`adab76f1a02ca4602c917d812ceb1d5721ddbfd4`.

F43 foi exclusivamente documental e adicionou somente:

- `docs/decisions/ADR-017-minimal-persistent-manual-timeline-note.md`;
- `tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/SPEC.md`.

Nenhum runtime, migration, policy, grant, capability, primitive, provisioning, adapter, Server Action ou UI foi alterado.

## Decisão ADR-017

A primeira nota manual persistente será uma capability específica sobre `contracting_events`, sem primitive genérica de eventos.

Contrato server-only definido para a implementação:

```text
contractingId: string
eventId: string
note: string | null
```

`contractingId` é somente seletor candidato. `eventId` é UUID técnico preparado server-side e estável nos retries da mesma intenção. Nenhum deles concede scope ou autorização.

O browser não define team, actor, membership, issuer, subject, `event_type`, timestamps, field/old/new, item ou related identifier.

## Shape do evento manual

O evento canônico F44 será:

```text
id = eventId preparado
team_id = team derivado
contracting_id = contratação autorizada
actor_membership_id = membership derivada
event_type = 'manual_note_added'
occurred_at = operation_at
field_key = NULL
old_value = NULL
new_value = NULL
note = valor exato
related_identifier_id = NULL
item_id = NULL
created_at = operation_at
```

`operation_at` vem do banco. A operação não altera `contractings.updated_at` e não muda qualquer estado estruturado da contratação.

## Semântica textual

`note` segue o contrato físico `text NULL` sem regra de negócio inventada.

Continuam distintos:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

Não existe trim, empty-to-NULL, case-folding, limite arbitrário, sanitização de persistência, Markdown/HTML, categoria ou prioridade nesta boundary.

## Idempotência e concorrência

O próprio evento é a entidade criada. Por isso o `eventId` precisa permanecer estável nos retries da mesma intenção. Deduplicação por conteúdo da nota foi rejeitada.

`already-added` só pode ser reconhecido depois de nova autorização do target e prova exata do evento existente: mesmo team, contracting e actor, event type fixo, nota null-safe idêntica, campos auxiliares nulos e `created_at = occurred_at`.

Mesmo UUID com payload divergente não faz overwrite. UUIDs diferentes com a mesma nota podem criar eventos distintos. Colisão cross-team, em outra contratação ou com outro event type permanece opaca.

## Autorização e least privilege

ADR-017 reutiliza o guard target-team pilot-only de F26/F32/F35/F38/F41:

1. current app user ativo;
2. contratação candidata visível e ativa;
3. membership não revogada do usuário na equipe alvo;
4. exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia, inclusive se o app_user correspondente estiver desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia por si só.

A capability futura é dedicada, conceitualmente `compras_manual_timeline_note_create_owner`, selada e sem LOGIN/SUPERUSER/BYPASSRLS/ownership de tabela-base.

Runtime normal receberá somente `EXECUTE` da primitive futura por provisioning separado.

O INSERT de evento será coluna-a-coluna apenas para `id`, `team_id`, `contracting_id`, `actor_membership_id`, `event_type`, `occurred_at`, `note` e `created_at`.

A capability não recebe UPDATE/DELETE de eventos nem DML de contratação, item, identifier ou allocator. F26/F29/F32/F35/F38/F41 não ganham authority adicional.

## Red-team F43

A decisão foi revisada contra os principais atalhos perigosos. Foram rejeitados:

- evento genérico controlável pelo caller;
- team, actor, membership, issuer, subject ou timestamp como authority do browser;
- `event_type` ou campos auxiliares arbitrários;
- novo UUID automático em cada retry da mesma intenção;
- deduplicação por texto da nota;
- replay por simples colisão de UUID;
- DML direto de eventos na runtime;
- UPDATE/DELETE de evento na capability;
- DML de contratação/item/identifier na nova capability;
- ampliação de capabilities existentes;
- vínculo de evento em target cross-team ou inativo;
- oracle de existência por colisão;
- normalização textual sem fonte canônica;
- categoria, prioridade ou entidade Pendência inventadas;
- alteração artificial de `contractings.updated_at`;
- reescrita de migration aplicada;
- resolução implícita de Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 ou Q-010;
- fallback para demo;
- provider hosted, secret ou dado real.

## Verificação F43

A comparação `main...head` mostrou exatamente dois arquivos documentais novos.

Migrations `0001..0010` foram comparadas entre `main` e a branch F43 e permaneceram byte-for-byte idênticas.

Não havia review thread pendente na PR `#69` antes do merge.

Gates no head final `c253311e989d0d4f93031ab7cbbea3ac875005e5`:

- CI `35997435206`: PASS;
- F22 Private Preview Preflight `35997435203`: PASS;
- F29 Contracting Create `35997435119`: PASS;
- F32 Contracting Object Mutation `35997435090`: PASS;
- F35 Contracting Item Create `35997435047`: PASS;
- F38 Contracting Item Mutation `35997435210`: PASS;
- F41 Related Identifier Create `35997435125`: PASS.

A slice não exigiu provider hosted write nem dado real.

## Imutabilidade

SHAs das migrations após F43:

- `0001_core_foundation.sql`: `a10e9733b71abae272fb58b763cae4c1439dd70c`;
- `0002_trusted_identity_read_policies.sql`: `ba6dd439f86e893faf1e4cb5ef59a3730876a757`;
- `0003_team_member_directory.sql`: `33b98ad1b6134a02b0662e9f2f03dfbd07df92a8`;
- `0004_next_action_mutation.sql`: `7773f1c0c19efb055a42d953d08bca1dab082b85`;
- `0005_contracting_create.sql`: `fdf8bfd1176c9c1e047b1d5fcb3512c9fab71d74`;
- `0006_contracting_object_mutation.sql`: `f3318318720b9df270430088001ad1f6002a4728`;
- `0007_contracting_item_create.sql`: `ddb098fe03c123b7b6cb8665890b1a2c8c12093b`;
- `0008_contracting_create_concurrency_repair.sql`: `c91f379aef0d0922c7de3be78d798e537fef9099`;
- `0009_contracting_item_mutation.sql`: `11f0639ae623eefb5794e69a1c7419cfd6a66fc2`;
- `0010_related_identifier_create.sql`: `9a1dd6fec62181c506a5efad8d5518f53cf2e154`.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01 - Implementar criação persistente de nota manual na timeline`.

A SPEC está em:

`tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/SPEC.md`.

F44 deve implementar ADR-017 com migration aditiva `0011`, capability dedicada, policies/grants mínimos, primitive, provisioning, adapter server-only, helper de candidate UUID, testes SQL adversariais, prova PostgreSQL concorrente e workflow/regressões.

F44 não inclui UI nem Server Action.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.

Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas.
