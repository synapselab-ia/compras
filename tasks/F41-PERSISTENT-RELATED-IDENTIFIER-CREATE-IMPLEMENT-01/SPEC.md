# F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01 - Implementar vínculo persistente mínimo de identificador relacionado

**Classe:** T2 - banco/segurança  
**Estado:** READY após integração da F40  
**Dependências:** ADR-016, migrations `0001..0009`, identidade confiável, read model persistente, F29/F32/F35/F38  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A F40 define a primeira boundary persistente para vincular um identificador administrativo a uma contratação existente, mas ainda não existe implementação operacional.

O schema e a leitura de `related_identifiers` já existem. Falta materializar a capability de criação com autorização pilot-only, atomicidade de auditoria, idempotência por UUID preparado e resultados sanitizados.

## Objetivo

Implementar a decisão ADR-016 sem UI e sem Server Action.

A F41 deve criar somente a boundary persistente server/database necessária para:

- criar um `related_identifier` em contratação ativa autorizada;
- registrar exatamente um evento atômico `related_identifier_linked`;
- reconhecer replay exato da mesma solicitação pelo UUID preparado;
- falhar fechado em colisões, cross-team e negações;
- preservar `NULL`, vazio e espaços sem normalização;
- manter runtime normal sem DML direto.

## Execução obrigatória

1. recuperar `main` real após F40;
2. revalidar `CONTEXT_MANIFEST`;
3. ler ADR-016 integralmente;
4. confirmar migrations `0001..0009` byte-for-byte antes da alteração;
5. criar migration aditiva `0010` ou nome equivalente ordenável;
6. criar capability dedicada `compras_related_identifier_create_owner` ou nome materialmente equivalente;
7. criar apenas policies/grants necessários à nova capability;
8. criar primitive `SECURITY DEFINER` com `search_path = pg_catalog`;
9. manter runtime sem DML direto;
10. criar provisioning separado que conceda somente `EXECUTE` da primitive à role runtime alvo;
11. criar adapter server-only estreito;
12. implementar replay seguro conforme ADR-016;
13. criar testes SQL adversariais;
14. criar prova PostgreSQL concorrente real;
15. criar testes unitários do adapter;
16. adicionar workflow dedicado F41 e regressões aplicáveis;
17. executar red-team integral;
18. revisar diff completo;
19. confirmar `0001..0009` imutáveis;
20. promover somente após todos os gates aplicáveis verdes.

## Contrato server-only

A interface de persistência aceita somente:

```text
contractingId: string
relatedIdentifierId: string
identifierKind: string | null
identifierValue: string
sourceSystem: string | null
note: string | null
```

O adapter gera `eventId` server-side em cada tentativa.

Não aceitar no contrato público do adapter:

- `teamId`;
- actor;
- membership;
- issuer;
- subject;
- `linkedAt`;
- `unlinkedAt`;
- `eventId`;
- timestamp de auditoria.

`contractingId` e `relatedIdentifierId` são candidatos opacos, não authority.

## Semântica textual obrigatória

Não aplicar:

- trim;
- uppercase/lowercase;
- máscara;
- regex de formato;
- empty-to-NULL implícito;
- limite de tamanho de negócio;
- taxonomia fechada;
- deduplicação por texto.

`identifierValue` é string NOT NULL e deve preservar inclusive vazio e espaços.

`identifierKind`, `sourceSystem` e `note` devem preservar:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

## Migration 0010

A migration deve ser exclusivamente aditiva.

Ela não pode reescrever `0001..0009`.

Deve materializar, no mínimo:

- role técnica dedicada e selada;
- grants coluna-a-coluna mínimos;
- policies RLS específicas para insert de related identifier e evento;
- primitive de criação;
- ownership seguro da primitive;
- revoke de `PUBLIC EXECUTE`;
- postflight que prove least privilege e ausência de authority herdada.

Não criar tabela de deduplicação de negócio.

Não criar índice/constraint de unicidade sobre `identifier_value`, tipo, origem ou combinações.

## Autorização

Usar guard target-team da ADR-016.

A operação só é autorizada quando:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está visível pela identidade;
3. contratação está ativa;
4. usuário possui membership não revogada na equipe alvo;
5. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive se seu app_user estiver desabilitado.

Membership adicional do mesmo usuário em outra equipe não bloqueia por si só.

Não usar guard global F29.

Cross-team, inexistente, inativo e falha de membership devem ser indistinguíveis externamente.

## Primitive

A função material deve ser equivalente a:

```text
create_related_identifier(
  p_contracting_id uuid,
  p_related_identifier_id uuid,
  p_identifier_kind text,
  p_identifier_value text,
  p_source_system text,
  p_note text,
  p_event_id uuid
) returns text
```

Resultados internos permitidos:

- `created`;
- `already-linked`;
- `denied`.

A primitive define `operation_at` internamente.

### Fluxo mínimo

1. resolver identidade corrente;
2. autorizar contratação alvo pelo guard pilot-only;
3. antes de inserir, verificar se o `relatedIdentifierId` já é replay exato autorizado;
4. se replay exato, retornar `already-linked`;
5. tentar inserir `related_identifiers`;
6. inserir evento `related_identifier_linked` com o mesmo `operation_at`;
7. retornar `created`;
8. em `unique_violation` da row, reexecutar somente a prova autorizada de replay dentro do tratamento transacional adequado;
9. se a prova falhar, retornar `denied`;
10. qualquer falha de evento ou erro técnico deve reverter a row.

A implementação não pode transformar `unique_violation` de event UUID em `already-linked`.

## Prova de replay

`already-linked` exige, simultaneamente:

- contratação candidata ainda autorizada e ativa;
- mesma row `related_identifiers.id`;
- mesmo team e contracting;
- `unlinked_at IS NULL`;
- textos exatamente iguais com comparação null-safe;
- exatamente um evento canônico `related_identifier_linked` para esse `related_identifier_id`;
- actor igual à membership derivada;
- `occurred_at = linked_at`;
- `created_at = linked_at`;
- shape do evento sem field/old/new/note/item.

Se qualquer elemento não puder ser provado, retornar `denied`.

Não reconhecer row desvinculada.

Não reconhecer row sem evento.

## Auditoria

Criação bem-sucedida deve inserir exatamente um evento:

```text
event_type = related_identifier_linked
team_id = team derivado
contracting_id = contratação derivada
actor_membership_id = membership derivada
related_identifier_id = row criada
occurred_at = operation_at
created_at = operation_at
field_key = NULL
old_value = NULL
new_value = NULL
note = NULL
item_id = NULL
```

Falha do evento reverte a row.

Não atualizar `contractings.updated_at`.

## Least privilege

A capability pode somente:

- resolver identidade;
- ler memberships necessárias;
- ler contratação alvo;
- ler colunas necessárias de related identifier/event para replay;
- inserir colunas aprovadas em `related_identifiers`;
- inserir colunas aprovadas em `contracting_events`;
- executar helpers indispensáveis.

Ela não pode:

- UPDATE/DELETE em `related_identifiers`;
- UPDATE em `contractings`;
- UPDATE/DELETE em `contracting_events`;
- DML em itens ou allocator;
- executar primitives F26/F29/F32/F35/F38;
- possuir LOGIN, SUPERUSER, BYPASSRLS, ownership de tabela-base ou membership utilizável.

Runtime normal recebe somente EXECUTE explícito da primitive.

## Adapter server-only

Criar módulo server-only estreito, preferencialmente no domínio de contracting detail, que:

- valide candidatos UUID sem usar isso como autorização;
- preserve textos exatamente;
- aceite `string | null` para campos nullable;
- gere `eventId` com UUID server-side;
- use o trusted database context existente;
- aceite apenas os resultados internos previstos;
- converta `denied` para `not-available`;
- converta falhas técnicas e resultados impossíveis para `unavailable`;
- não faça fallback para demo;
- não exponha SQL, team, actor, membership ou timestamps.

Resultados externos:

```text
created
already-linked
not-available
unavailable
```

## Concorrência obrigatória

Adicionar prova PostgreSQL real para:

1. várias chamadas concorrentes com mesmo UUID e mesmo payload;
2. exatamente uma `created`;
3. restantes `already-linked`;
4. uma única row;
5. um único evento;
6. mesmo UUID com payload divergente não faz overwrite;
7. UUIDs diferentes com payload idêntico podem criar rows distintas.

Não usar retry cego que converta qualquer unique violation em sucesso.

## Testes adversariais obrigatórios

Cobrir integralmente a matriz da ADR-016, incluindo:

- auth/context ausente e malformado;
- app_user desabilitado;
- membership ausente/revogada;
- segundo membro;
- cross-team;
- contratação arquivada/cancelada;
- colisão cross-team do UUID;
- replay exato;
- colisão com payload diferente;
- row sem exatamente um evento canônico de vínculo;
- row desvinculada;
- campos vazios e spaces-only;
- `NULL` versus `''`;
- falha de evento com rollback;
- colisão de event UUID;
- authority e grants;
- ausência de DML runtime;
- ausência de authority cruzada entre capabilities.

## Artefatos esperados

Preferencialmente:

- `database/migrations/0010_related_identifier_create.sql`;
- `database/provisioning/grant_related_identifier_create_runtime.sql`;
- `database/tests/related_identifier_create.sql`;
- `src/features/contracting-detail/persistent-related-identifier-create.ts`;
- testes unitários do adapter;
- teste PostgreSQL concorrente;
- `.github/workflows/f41-related-identifier-create.yml`.

Nomes podem variar sem alterar o contrato.

## Gates

Executar pelo menos:

- lint;
- typecheck;
- testes unitários;
- build;
- suíte SQL de foundation/read policies;
- suíte F22;
- suíte F29;
- suíte F32;
- suíte F35;
- suíte F38;
- nova suíte F41;
- prova concorrente F41;
- revisão integral do diff;
- red-team de grants/policies/authority;
- confirmação byte-for-byte de migrations `0001..0009`.

Se algum gate não existir ou não puder ser executado, registrar `SKIPPED` e o motivo. Não declarar PASS imaginado.

## Fora do escopo

- UI;
- Server Action;
- edição de identificador;
- desvínculo/re-link;
- exclusão;
- taxonomia de tipo/origem;
- máscara ou validação específica de processo;
- importação externa;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- provider hosted;
- secret;
- dado real.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados fictícios/sanitizados;
- repositório público tratado como superfície permanente;
- autenticação não é autorização;
- RLS/capabilities autoritativas;
- runtime normal sem DML direto;
- migrations aplicadas `0001..0009` imutáveis;
- Q-003, Q-004 e Q-009 permanecem abertas;
- falha protegida nunca vira demo fallback.

## Critério de encerramento

F41 fecha quando a criação persistente mínima de `related_identifiers` estiver implementada e provada contra a matriz adversarial, com row + evento atômicos, idempotência segura por UUID preparado, least privilege, resultados sanitizados e todas as regressões aplicáveis verdes, sem UI nesta slice.
