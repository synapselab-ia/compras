# F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01 - Implementar criação persistente de nota manual na timeline

**Classe:** T2 - banco/segurança  
**Estado:** READY após integração da F43  
**Dependências:** ADR-017, migrations `0001..0010`, identidade confiável, read model persistente, precedentes F26/F29/F32/F35/F38/F41  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A F43 define a primeira boundary persistente de nota manual na timeline, mas ainda não existe primitive, capability ou adapter operacional para criar esse evento.

## Objetivo

Implementar ADR-017 sem UI e sem Server Action. A F44 deve criar somente a boundary server/database necessária para inserir `manual_note_added` em contratação ativa autorizada, com idempotência por UUID preparado, replay exato, least privilege e resultados sanitizados.

## Execução obrigatória

1. recuperar `main` real após F43 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-017 integralmente;
3. confirmar migrations `0001..0010` byte-for-byte antes de editar;
4. criar migration aditiva `0011_manual_timeline_note_create.sql` ou nome ordenável equivalente;
5. criar capability dedicada `compras_manual_timeline_note_create_owner` ou equivalente;
6. adicionar somente grants e policies RLS necessários;
7. criar primitive `SECURITY DEFINER` com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
8. manter runtime normal sem DML direto;
9. criar provisioning separado que conceda somente `EXECUTE` da primitive;
10. criar adapter server-only estreito e helper server-only de preparo do `eventId`;
11. implementar replay exato após autorização atual;
12. criar testes SQL adversariais e prova PostgreSQL concorrente real;
13. criar testes unitários do adapter;
14. adicionar workflow F44 e regressões aplicáveis;
15. executar red-team integral de authority, RLS, grants, opacidade, idempotência e concorrência;
16. confirmar `0001..0010` imutáveis e promover somente após gates verdes.

## Contrato server-only

A interface de persistência aceita somente:

```text
contractingId: string
eventId: string
note: string | null
```

`contractingId` e `eventId` são candidatos opacos, não authority. O helper `preparePersistentManualTimelineNoteEventId()` ou equivalente deve gerar UUID server-side para a intenção.

Não aceitar team, actor, membership, issuer, subject, `event_type`, timestamps, field/old/new, item ou related identifier.

## Semântica textual

Preservar exatamente `NULL`, `''`, spaces-only e leading/trailing spaces. Não aplicar trim, empty-to-NULL, case-folding, limite de negócio, sanitização de persistência, Markdown/HTML, categoria ou prioridade.

## Primitive

A função deve ser materialmente equivalente a:

```text
create_manual_timeline_note(
  p_contracting_id uuid,
  p_event_id uuid,
  p_note text
) returns text
```

Resultados internos permitidos: `created`, `already-added`, `denied`.

Fluxo mínimo:

1. validar argumentos técnicos obrigatórios;
2. resolver identidade corrente;
3. autorizar contratação candidata pelo guard target-team pilot-only;
4. derivar actor membership;
5. se `eventId` já existir, reconhecer `already-added` somente após prova exata do evento canônico;
6. se não existir, definir `operation_at` no banco;
7. inserir exatamente um evento `manual_note_added` com shape ADR-017;
8. em conflito concorrente, executar somente releitura autorizada e prova exata;
9. colisão não equivalente retorna `denied`;
10. erro técnico não é convertido em replay-success.

## Shape obrigatório

```text
id = p_event_id
team_id = team derivado
contracting_id = target autorizado
actor_membership_id = membership derivada
event_type = 'manual_note_added'
occurred_at = operation_at
field_key = NULL
old_value = NULL
new_value = NULL
note = p_note
related_identifier_id = NULL
item_id = NULL
created_at = operation_at
```

Não atualizar `contractings.updated_at`.

## Prova de replay

`already-added` exige contratação ainda autorizada e ativa, mesmo team/contracting, mesmo actor derivado, `event_type = 'manual_note_added'`, `note IS NOT DISTINCT FROM p_note`, field/old/new/related/item nulos e `created_at = occurred_at`.

Colisão com outro team, contratação, actor, note, event type ou shape não vira sucesso.

## Autorização

Usar o guard target-team de ADR-017:

- current app user ativo;
- contratação candidata visível e ativa;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia mesmo com app_user desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia por si só.

Inexistente, cross-team, desabilitado, membership ausente/revogada, segundo membro, arquivada/cancelada e colisão não equivalente devem permanecer opacos externamente.

## Migration 0011

A migration é exclusivamente aditiva e não reescreve `0001..0010`.

Deve materializar:

- role técnica dedicada e selada;
- grants coluna-a-coluna mínimos;
- policy de memberships necessária ao guard;
- leitura restrita da contratação alvo;
- leitura restrita de eventos manuais para replay;
- policy de INSERT do shape fechado;
- primitive;
- ownership seguro e revoke de PUBLIC EXECUTE;
- postflight de least privilege, ownership, membership e `search_path`.

INSERT em `contracting_events` deve ser limitado às colunas `id`, `team_id`, `contracting_id`, `actor_membership_id`, `event_type`, `occurred_at`, `note` e `created_at`.

A capability não pode possuir UPDATE/DELETE de eventos nem DML de contratação, itens, identifiers ou allocator.

## Provisioning

Criar `database/provisioning/grant_manual_timeline_note_create_runtime.sql` ou equivalente, seguindo o lifecycle seguro das capabilities existentes.

O runtime recebe somente `EXECUTE` da nova primitive. Preflight e postflight devem rejeitar DML direto e membership utilizável na capability.

## Adapter server-only

O adapter deve:

- validar UUIDs somente como formato técnico;
- preservar `note` exatamente;
- usar trusted database mutation context existente;
- aceitar somente resultados internos previstos;
- mapear `denied` para `not-available`;
- mapear falha técnica e resultado impossível para `unavailable`;
- não fazer fallback para demo;
- não expor SQL, team, actor, membership ou timestamps.

Resultados externos:

```text
created
already-added
not-available
unavailable
```

## Concorrência obrigatória

Adicionar prova PostgreSQL real para chamadas concorrentes com mesmo `eventId` e mesmo payload. Deve haver exatamente um evento, um `created` e os demais `already-added`.

Também provar que mesmo UUID com nota divergente não faz overwrite e que UUIDs diferentes com nota idêntica podem criar eventos distintos.

## Testes adversariais obrigatórios

Cobrir auth/context ausente e malformado, app_user desabilitado, membership ausente/revogada, segundo membro, cross-team, contratação arquivada/cancelada, colisão cross-team do UUID, replay exato, colisão com nota diferente, colisão com outro event type, NULL/vazio/espaços, shape fechado, ausência de DML runtime, capability selada, ausência de authority cruzada e não alteração de `contractings.updated_at`.

## Artefatos esperados

Preferencialmente:

- `database/migrations/0011_manual_timeline_note_create.sql`;
- `database/provisioning/grant_manual_timeline_note_create_runtime.sql`;
- `database/tests/manual_timeline_note_create.sql`;
- adapter e testes em `src/features/contracting-detail/`;
- teste PostgreSQL concorrente;
- `.github/workflows/f44-manual-timeline-note-create.yml`;
- `tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/RESULT.md` ao concluir.

## Gates

Executar lint, typecheck, testes unitários, build, suites de foundation/read policies, F22, F29, F32, F35, F38, F41, nova suíte F44, prova concorrente, revisão integral do diff e confirmação byte-for-byte de `0001..0010`.

Se algum gate não existir ou não puder ser executado, registrar `SKIPPED` e motivo. Nunca declarar PASS imaginado.

## Fora do escopo

UI, Server Action, edição/exclusão de evento, evento genérico, mutations de campos operacionais, Pendência, edição/desvínculo de identifier, pesquisa de preços, Q-009, Q-010, provider hosted, secret e dado real.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados fictícios/sanitizados;
- repositório público tratado como superfície permanente;
- F21 permanece ON HOLD;
- questões abertas permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal sem DML direto;
- migrations `0001..0010` imutáveis;
- falha protegida nunca vira demo fallback.

## Critério de encerramento

F44 fecha quando a criação persistente mínima de nota manual estiver implementada e provada com um evento atômico, idempotência segura por UUID preparado, replay exato, least privilege, resultados sanitizados, concorrência real e regressões aplicáveis verdes, sem UI nesta slice.
