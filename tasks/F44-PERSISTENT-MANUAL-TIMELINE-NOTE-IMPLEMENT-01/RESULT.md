# F44 - Resultado da criação persistente mínima de nota manual na timeline

**Estado:** COMPLETED / PASS  
**PR de implementação:** `#71`  
**Head promovido:** `c057b381454ad1d0499338fda1915ff337056fbe`  
**Merge em main:** `55f887252cfd5e5e81596e7434e6d5cec906aced`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Resultado

A ADR-017 foi implementada como uma boundary persistente específica para criação de nota manual na timeline, sem Server Action e sem UI.

Foram integrados:

- `database/migrations/0011_manual_timeline_note_create.sql`;
- capability selada `compras_manual_timeline_note_create_owner`;
- primitive `public.create_manual_timeline_note(uuid, uuid, text)`;
- provisioning `database/provisioning/grant_manual_timeline_note_create_runtime.sql`;
- adapter server-only `src/features/contracting-detail/persistent-manual-timeline-note-create.ts`;
- helper server-only `preparePersistentManualTimelineNoteEventId()`;
- testes unitários do adapter;
- prova SQL adversarial;
- prova PostgreSQL concorrente real;
- workflow dedicado `F44 Manual Timeline Note Create`.

Migrations `0001..0010` permaneceram byte-for-byte imutáveis. A migration `0011` é estritamente aditiva.

## Contrato da boundary

O adapter server-only aceita somente:

```text
contractingId: string
eventId: string
note: string | null
```

`contractingId` e `eventId` são seletores técnicos opacos. Nenhum deles concede scope, identidade ou autorização.

O helper `preparePersistentManualTimelineNoteEventId()` gera o UUID do evento no servidor para uma intenção de criação.

Team, actor, membership, issuer, subject, `event_type`, timestamps, field/old/new, item e related identifier não são authority do caller.

Resultados externos:

- `created`;
- `already-added`;
- `not-available`;
- `unavailable`.

## Shape persistido

A primitive cria somente o evento canônico:

```text
id = eventId preparado
team_id = team derivado
contracting_id = target autorizado
actor_membership_id = membership derivada
event_type = 'manual_note_added'
occurred_at = operation_at
field_key = NULL
old_value = NULL
new_value = NULL
note = valor exato recebido
related_identifier_id = NULL
item_id = NULL
created_at = operation_at
```

`operation_at` é gerado no banco.

A operação não altera `contractings.updated_at` nem qualquer outro estado estruturado da contratação.

## Autorização

A primitive reutiliza o guard target-team pilot-only:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está ativa;
3. o usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia a operação mesmo quando o app_user correspondente está desabilitado.

Membership adicional do mesmo usuário em outra equipe não amplia nem bloqueia a authority da equipe alvo por si só.

Q-009 permanece aberta.

## Idempotência, replay e concorrência

O `eventId` é a chave técnica estável de uma única intenção.

`already-added` exige nova autorização do target e prova exata de:

- mesmo team;
- mesmo contracting;
- mesmo actor membership derivado;
- `event_type = 'manual_note_added'`;
- `note IS NOT DISTINCT FROM p_note`;
- field/old/new/related/item nulos;
- `created_at = occurred_at`.

Colisão não equivalente retorna `denied` internamente e permanece opaca externamente.

Não existe deduplicação por conteúdo da nota.

A prova PostgreSQL concorrente validou:

- oito chamadas concorrentes com o mesmo UUID e payload;
- exatamente uma resposta `created`;
- sete respostas `already-added`;
- exatamente um evento persistido;
- mesmo UUID com notas divergentes sem overwrite;
- UUIDs distintos com nota idêntica criando eventos distintos.

## Semântica textual

A implementação preserva exatamente:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

Não há trim, case-folding, empty-to-NULL, máscara, regra de tamanho de negócio, categoria, prioridade ou sanitização de persistência inventada.

## Least privilege

A capability F44:

- é `NOLOGIN`, `NOINHERIT`, não privilegiada e sem `BYPASSRLS`;
- não possui ownership de tabela-base;
- possui somente leituras necessárias para identidade, guard e replay;
- possui INSERT coluna-a-coluna apenas nas colunas aprovadas de `contracting_events`;
- não pode inserir field/old/new/related identifier/item;
- não possui UPDATE/DELETE em eventos;
- não possui DML em `contractings`, itens, identifiers ou allocator;
- não recebe EXECUTE das primitives F26/F29/F32/F35/F38/F41.

As capabilities anteriores não receberam EXECUTE da primitive F44.

O runtime normal recebe somente EXECUTE explícito da nova primitive por provisioning separado e continua sem DML direto.

## Red-team

A matriz adversarial cobriu:

- capability insegura por LOGIN, SUPERUSER, CREATEROLE, BYPASSRLS ou membership utilizável;
- runtime com INHERIT ou DML direto;
- claims ausentes, malformados e identidade desconhecida;
- app_user desabilitado;
- app_user ativo sem membership;
- membership revogada;
- segundo membro não revogado, inclusive app_user desabilitado;
- contratação cross-team, inexistente, arquivada e cancelada;
- colisão cross-team do UUID sem oracle;
- replay exato;
- mesmo UUID com nota diferente;
- colisão com outro event type;
- colisão com actor diferente;
- colisão com shape não canônico;
- `NULL`, vazio, spaces-only e leading/trailing spaces;
- UUIDs distintos com nota idêntica;
- shape fechado do evento;
- ausência de DML direto na runtime;
- ausência de authority cruzada entre capabilities;
- `contractings.updated_at` invariável;
- concorrência PostgreSQL real.

Também foi feita inspeção do diff final. A PR adicionou somente sete arquivos da F44 e não alterou nenhum arquivo anterior.

Nenhum dado real, secret ou identificador operacional foi introduzido. Os cenários de teste usam apenas dados e identidades `DEMO`.

## Verificação

O primeiro run do workflow F44 encontrou uma falha restrita ao teste concorrente: a consulta de verificação usava `max(uuid)`, operação inexistente no PostgreSQL. A agregação foi corrigida para operar sobre representação textual dos UUIDs, sem alteração da primitive, RLS, grants, capability ou comportamento de produção.

Head final promovido `c057b381454ad1d0499338fda1915ff337056fbe`:

- CI `36459883858`: PASS;
- F22 Private Preview Preflight `36459883436`: PASS;
- F29 Contracting Create `36459883423`: PASS;
- F32 Contracting Object Mutation `36459883601`: PASS;
- F35 Contracting Item Create `36459883350`: PASS;
- F38 Contracting Item Mutation `36459883374`: PASS;
- F41 Related Identifier Create `36459883354`: PASS;
- F44 Manual Timeline Note Create `36459883410`: PASS.

Não havia review thread pendente na PR `#71` antes da promoção.

## Imutabilidade

As migrations anteriores foram verificadas novamente no head final e permaneceram com os mesmos blobs:

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

A partir desta integração, `0011_manual_timeline_note_create.sql` também passa a ser migration aplicada e imutável.

## Invariantes preservados

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público tratado como superfície permanente;
- F21 permanece `ON HOLD`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS e capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- falha protegida nunca vira demo fallback;
- F44 não adicionou Server Action nem UI.
