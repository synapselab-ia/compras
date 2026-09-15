# F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item

**Classe:** T2 - banco, autorização e escrita server-side  
**Estado:** PLANNED / NEXT após integração da F37  
**Dependências:** ADR-015, ADR-014, ADR-013, ADR-003, ADR-005, ADR-009, F32, F35 e migration 0008  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

ADR-015 definiu a menor authority segura para editar os quatro campos existentes de um `contracting_item`, mas ainda não existe migration, capability, primitive, provisioning ou adapter server-only correspondente.

A implementação precisa provar optimistic concurrency por snapshot completo, auditoria escalar atômica, semântica exata de texto/numeric, guard pilot-only e least privilege sem ampliar F26/F29/F32/F35.

## Objetivo

Implementar uma boundary persistente que altere, de forma atômica, somente:

- `description`;
- `quantity`;
- `unit`;
- `catalog_code`.

A boundary recebe `contractingId + itemId`, snapshot esperado dos quatro campos e snapshot novo dos quatro campos. Team, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs não fazem parte da authority do browser.

Não existe UI ou Server Action nesta slice.

## 1. Recuperação e contexto

Antes de implementar:

1. recuperar `main` real e confirmar F37/ADR-015 integradas;
2. revalidar `CONTEXT_MANIFEST`;
3. confirmar migration `0008_contracting_create_concurrency_repair.sql` integrada e imutável;
4. ler ADR-013, ADR-014 e ADR-015;
5. inspecionar migrations/provisioning/tests F32 e F35;
6. inspecionar `withTrustedDatabaseMutationContext` e o read model protegido de item;
7. não modificar migrations `0001..0008`.

## 2. Migration nova

Criar somente nova migration ordenada:

`database/migrations/0009_contracting_item_mutation.sql`

A migration deve criar:

- capability dedicada;
- RLS policies específicas de SELECT/UPDATE do item;
- policy específica de INSERT de evento;
- primitive de mutação;
- revogações e grants mínimos.

Não alterar schema funcional de `contracting_items`, não criar version column e não tocar o allocator F35.

## 3. Capability dedicada

Criar role equivalente a:

`compras_contracting_item_mutation_owner`

Requisitos:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem `rolconfig` persistente;
- sem ownership de tabelas-base;
- sem membership utilizável.

PostgreSQL 17 pode conservar somente a aresta administrativa segura já aceita pelo padrão ADR-005, sem `SET` ou herança utilizável.

## 4. Grants máximos

A capability pode receber somente:

- `USAGE` no schema necessário;
- SELECT mínimo em `app_users` para identity helpers;
- SELECT mínimo em `memberships` para actor e guard target-team;
- SELECT mínimo em `contractings` para parent ativo;
- SELECT das colunas necessárias em `contracting_items`;
- UPDATE somente de `description`, `quantity`, `unit`, `catalog_code`, `updated_at` em `contracting_items`;
- INSERT coluna-a-coluna em `contracting_events` apenas para `id`, `team_id`, `contracting_id`, `actor_membership_id`, `event_type`, `occurred_at`, `field_key`, `old_value`, `new_value`, `item_id`, `created_at`;
- EXECUTE somente dos helpers de identidade necessários.

Proibir por teste:

- INSERT/DELETE em item;
- UPDATE de `id`, `team_id`, `contracting_id`, `ordinal`, `created_at`, `retired_at`;
- qualquer UPDATE em `contractings`;
- qualquer privilege no allocator `contracting_item_ordinal_counters`;
- UPDATE/DELETE em eventos;
- authority de F26/F29/F32/F35.

Runtime normal continua sem DML direto.

## 5. Primitive

Criar função conceitualmente equivalente a:

```text
public.mutate_contracting_item_fields(
  p_contracting_id uuid,
  p_item_id uuid,
  p_expected_description text,
  p_expected_quantity numeric,
  p_expected_unit text,
  p_expected_catalog_code text,
  p_new_description text,
  p_new_quantity numeric,
  p_new_unit text,
  p_new_catalog_code text,
  p_description_event_id uuid,
  p_quantity_event_id uuid,
  p_unit_event_id uuid,
  p_catalog_code_event_id uuid
) returns text
```

Requisitos:

- `SECURITY DEFINER`;
- `SET search_path = pg_catalog`;
- SQL estático/parametrizado;
- `PUBLIC EXECUTE` revogado;
- owner = capability F38;
- runtime recebe somente EXECUTE por provisioning separado;
- nenhum argumento de team/actor/membership/issuer/subject/ordinal/retired/timestamp.

Os quatro UUIDs de evento são parâmetros internos entre adapter e primitive e nunca entram no contrato público do adapter.

## 6. Contrato server-only

Criar adapter previsto como:

`src/features/contracting-detail/persistent-item-mutation.ts`

API conceitual:

```text
mutatePersistentContractingItem({
  contractingId,
  itemId,
  expectedDescription,
  expectedQuantity,
  expectedUnit,
  expectedCatalogCode,
  newDescription,
  newQuantity,
  newUnit,
  newCatalogCode
})
```

Tipos:

```text
contractingId: string
itemId: string
expectedDescription: string
expectedQuantity: string | null
expectedUnit: string | null
expectedCatalogCode: string | null
newDescription: string
newQuantity: string | null
newUnit: string | null
newCatalogCode: string | null
```

O adapter deve:

- ser `server-only`;
- reutilizar `withTrustedDatabaseMutationContext`;
- validar somente shape técnico necessário, sem regra de negócio nova;
- gerar quatro event UUIDs server-side por tentativa;
- não possuir overload/opção para o caller fornecer event UUIDs;
- não aceitar team, actor, membership, issuer, subject, ordinal, retired state ou timestamps;
- não usar `Number`, `parseFloat` ou equivalente em quantity;
- passar expected/new quantity como parâmetros destinados a PostgreSQL `numeric`;
- não trimar/normalizar texto;
- mapear somente os estados sanitizados definidos abaixo;
- nunca expor SQL, claims, connection string, event UUIDs ou detalhe interno;
- nunca cair para fixture/demo.

## 7. Autorização e row lock

A primitive segue o guard target-team de F26/F32/F35.

Fluxo mínimo:

1. rejeitar argumentos estruturais impossíveis, incluindo IDs/description/event IDs nulos;
2. resolver `current_app_user_id()`;
3. selecionar o item candidato por `p_item_id + p_contracting_id`, sob RLS, exigindo `retired_at IS NULL`;
4. adquirir `FOR UPDATE` somente na row do item;
5. derivar `team_id` e parent a partir da row/banco;
6. confirmar parent ativo no mesmo scope;
7. derivar membership não revogada do usuário na equipe alvo;
8. exigir exatamente uma membership não revogada na equipe alvo;
9. somente depois avaliar conflito/no-op;
10. revalidar parent/membership após o lock antes do write.

A policy de UPDATE e a policy de evento continuam sendo enforcement final se parent/membership mudar durante a operação.

Segundo membro não revogado bloqueia, inclusive app_user desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia por si só.

`contractingId` e `itemId` são seletores, não authority. Mismatch de parent, cross-team, inexistente, retired, archived/cancelled e negação de membership retornam o mesmo `denied` interno.

## 8. Optimistic concurrency por snapshot completo

Após autorização e lock, comparar current contra todos os expected com `IS NOT DISTINCT FROM`.

Se qualquer campo divergir:

`conflict`

A comparação cobre os quatro campos mesmo quando o caller pretende alterar somente um deles. Isso é obrigatório para impedir overwrite silencioso de atualização concorrente em outro campo.

Somente se expected inteiro estiver atual:

- se current inteiro = new inteiro, retornar `unchanged`;
- caso contrário, executar `updated`.

`conflict` deve ser avaliado antes de `unchanged`.

No-op não altera `updated_at` e não gera evento.

Não criar retry automático de conflito no adapter.

## 9. Update permitido

Uma alteração real usa um único `operation_at = clock_timestamp()` e atualiza somente:

- `description = p_new_description`;
- `quantity = p_new_quantity`;
- `unit = p_new_unit`;
- `catalog_code = p_new_catalog_code`;
- `updated_at = operation_at`.

Não alterar `contractings.updated_at`.

O UPDATE deve comprovar que exatamente a row autorizada foi atualizada. Policy/RLS continua ativa sob `FORCE ROW LEVEL SECURITY`.

## 10. Auditoria atômica

Para cada campo realmente alterado, inserir exatamente um evento:

```text
event_type = item_changed
item_id = item alvo
field_key = description | quantity | unit | catalog_code
old_value = valor anterior em texto/null
new_value = valor novo em texto/null
occurred_at = operation_at
created_at = operation_at
note = NULL
related_identifier_id = NULL
```

Team, contracting e actor são derivados do banco.

Mapeamento de event UUID interno:

- description -> `p_description_event_id`;
- quantity -> `p_quantity_event_id`;
- unit -> `p_unit_event_id`;
- catalog_code -> `p_catalog_code_event_id`.

Inserir eventos somente dos campos alterados, em ordem lógica fixa `description`, `quantity`, `unit`, `catalog_code`.

Quantity old/new deve ser gerada no PostgreSQL por cast `numeric::text`, preservando `NULL` e sem round-trip JavaScript.

Falha de qualquer evento deve reverter update, timestamp e todos os eventos da tentativa.

Eventos continuam append-only.

## 11. RLS específica

### Memberships

A capability precisa de policy SELECT que permita contar memberships não revogadas para o guard target-team, incluindo app_user desabilitado.

### Item SELECT/UPDATE

Criar policies específicas da capability que exijam:

- `retired_at IS NULL`;
- contratação pai correspondente ativa;
- membership corrente não revogada no team;
- exatamente uma membership não revogada no team.

UPDATE deve ter `USING` e `WITH CHECK` equivalentes. A capability não pode alterar as colunas usadas para scope/retired state.

### Event INSERT

Criar policy específica que exija:

- `event_type = 'item_changed'`;
- `item_id IS NOT NULL`;
- `field_key IN ('description','quantity','unit','catalog_code')`;
- `note IS NULL`;
- `related_identifier_id IS NULL`;
- actor membership corrente e mesmo team;
- exatamente uma membership não revogada no team;
- parent ativo;
- item ativo no mesmo scope;
- `new_value` coerente com o valor persistido do campo indicado.

Não conceder UPDATE/DELETE de evento.

## 12. Semântica de texto e numeric

### Description

Preservar exatamente `''`, spaces-only e leading/trailing spaces. Não inventar non-empty ou max length.

### Unit e catalogCode

Preservar `NULL`, `''`, spaces-only e leading/trailing spaces de forma distinta. Não converter empty-to-NULL.

### Quantity

Interface TypeScript usa `string | null` até o PostgreSQL.

Provar:

- `NULL`;
- `0`;
- negativo;
- fração;
- alta precisão válida.

Nenhuma passagem por float JavaScript.

Texto inválido para `numeric` deve falhar sem update/evento e virar `unavailable` externo. Não criar regex de negócio para substituir a gramática do PostgreSQL.

## 13. Provisioning

Criar script separado previsto como:

`database/provisioning/grant_contracting_item_mutation_runtime.sql`

Ele deve:

- receber explicitamente a runtime role;
- recusar role inexistente/insegura/capability owner;
- recusar role com direct DML de domínio;
- confirmar owner selado e primitive correta;
- conceder somente EXECUTE da primitive F38;
- não deixar membership SET/INHERIT na capability;
- provar que Auth/read-only runtime não receberam EXECUTE.

## 14. Resultados

Primitive:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

Adapter:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para `denied`;
- `unavailable` para configuração, conexão, numeric inválido, driver, erro técnico ou resultado impossível.

`conflict` e `unchanged` somente depois da autorização.

Cross-team/inexistente/retired/parent mismatch/inativo continuam indistinguíveis externamente.

## 15. Matriz adversarial obrigatória

Provar no mínimo:

1. cada campo isolado pode ser alterado por caller autorizado;
2. quatro campos podem mudar atomicamente na mesma operação;
3. N campos alterados geram exatamente N eventos;
4. `updated_at` e todos os eventos usam o mesmo operation_at;
5. no-op retorna `unchanged` sem timestamp/evento;
6. expected stale em qualquer campo retorna `conflict` sem write;
7. stale expected continua conflict quando new já coincide com current;
8. 8 writers concorrentes com mesmo expected resultam em 1 updated, 7 conflict e somente eventos do vencedor;
9. retry idêntico pós-sucesso retorna conflict sem segundo evento;
10. event UUID duplicado no primeiro campo alterado causa rollback total;
11. falha no evento intermediário causa rollback dos eventos anteriores e update;
12. falha no último evento causa rollback integral;
13. description vazio/espaços permanece exato;
14. unit/catalog NULL/vazio/espaços permanecem distintos;
15. quantity NULL/zero/negativo/fração/alta precisão persiste sem float JS;
16. numeric inválido é unavailable e não grava;
17. claims ausentes/malformados/unknown/disabled negam;
18. membership ausente/revogada nega;
19. segundo membro não revogado bloqueia, inclusive disabled user;
20. outra membership do mesmo usuário em outro team não bloqueia a equipe alvo;
21. cross-team, inexistente, parent mismatch e retired produzem somente not-available;
22. archived/cancelled parent bloqueia;
23. mudança de parent/membership na janela de operação não conclui write fora de RLS;
24. browser não fornece team/actor/membership/issuer/subject/event IDs/ordinal/retired/timestamps;
25. capability só atualiza quatro campos + updated_at;
26. capability não possui INSERT/DELETE de item;
27. capability não toca allocator;
28. capability não atualiza contractings;
29. eventos não podem ser updated/deleted;
30. runtime normal não recebe DML direto;
31. Auth/read-only runtimes não recebem EXECUTE;
32. F26/F29/F32/F35 não ganham authority F38;
33. F38 não ganha authority F26/F29/F32/F35;
34. migrations 0001..0008 permanecem byte-for-byte imutáveis;
35. F22, CI, F29, F32, F35 e Auth permanecem verdes;
36. somente dados/identidades fictícios e nenhum provider hosted write.

## 16. Red-team de implementação

Rejeitar PASS se:

- qualquer input do browser definir scope/actor ou event UUID;
- mutation não vincular item ao contractingId candidato;
- item retired puder ser alterado;
- parent archived/cancelled puder ser contornado;
- stale snapshot parcial virar last-write-wins;
- conflict for avaliado depois de no-op;
- text sofrer trim/normalização;
- quantity passar por Number/parseFloat;
- policy de evento aceitar field_key fora dos quatro campos;
- audit old/new puder vazar via resultado externo;
- falha de evento deixar update parcial;
- capability tocar ordinal/retired/allocator/contractings;
- runtime ganhar DML direto;
- migration aplicada for reescrita;
- provider hosted, secret ou dado real for necessário.

## 17. Verificação

Executar:

- lint;
- typecheck;
- testes unitários;
- build;
- PostgreSQL 17 migration/provisioning/matriz adversarial;
- concorrência real com múltiplas conexões;
- CI database/Auth;
- F22 Private Preview Preflight;
- F29 Contracting Create;
- F32 Contracting Object Mutation;
- F35 Contracting Item Create;
- revisão integral de diff e grants.

## 18. Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0008` permanecem imutáveis;
- F35 continua exclusiva de item create;
- F38 não implementa UI.

## Fora do escopo

- Server Action/UI de edição;
- reorder/ordinal;
- retire/restore;
- delete;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- regra nova de quantidade/unidade/catálogo;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F38 fecha quando a boundary ADR-015 estiver implementada e provada em PostgreSQL 17 contra least privilege, target-team authorization, snapshot concurrency, audit atômico, rollback, exact text/numeric semantics e resultados sanitizados, com adapter server-only e regressões verdes, sem UI nesta slice.
