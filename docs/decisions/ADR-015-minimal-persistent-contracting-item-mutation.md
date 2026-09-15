# ADR-015: Edição persistente mínima de item de contratação

**Status:** Accepted  
**Data:** 2026-09-15  
**Escopo:** desenho da primeira mutação persistente de `contracting_items`; implementação pertence à F38  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

Após F36, o detalhe persistente permite criar e reler itens por uma boundary estreita baseada na ADR-014. Ainda não existe authority para editar um item já criado.

O schema físico já contém, em `contracting_items`:

- `id`;
- `team_id`;
- `contracting_id`;
- `ordinal`;
- `description`;
- `quantity numeric NULL`;
- `unit`;
- `catalog_code`;
- `created_at`;
- `updated_at`;
- `retired_at`.

A primeira edição não deve transformar isso em CRUD amplo. Em particular, F37 não decide reorder, retire/restore, delete nem pesquisa de preços. Q-004 e Q-009 permanecem abertas.

Os precedentes F31/F32/F33 e ADR-013 já provaram o padrão para uma mutação persistente existente: capability dedicada, optimistic concurrency por expected value, conflito antes de no-op, evento atômico, runtime sem DML direto e resultados externos sanitizados. F34/F35/F36 e ADR-014 fixaram a semântica dos campos de item, inclusive transporte de `numeric` sem conversão JavaScript e preservação de `NULL`, string vazia e espaços.

A F29 também recebeu a migration aditiva `0008_contracting_create_concurrency_repair.sql` para corrigir a corrida entre as duas constraints únicas de `contractings`. Essa migration é parte do histórico aplicado e permanece imutável. A futura implementação F38 começa, portanto, em `0009`.

## Decisão

A primeira edição persistente de item será uma operação atômica de snapshot completo dos quatro campos editáveis:

- `description`;
- `quantity`;
- `unit`;
- `catalog_code`.

A operação recebe o estado esperado dos quatro campos e o novo estado solicitado dos quatro campos. Qualquer divergência no snapshot esperado produz `conflict` antes de qualquer avaliação de no-op.

Essa escolha evita lost update entre campos diferentes. Exemplo: se um writer altera `unit` enquanto outro formulário antigo tenta alterar apenas `description`, o segundo formulário não pode sobrescrever silenciosamente a `unit` nova que carregava de forma stale.

`ordinal`, `retired_at`, `created_at`, `team_id`, `contracting_id` e `id` não são editáveis por essa boundary.

## 1. Contrato server-only

A interface server-only da F38 deve ser conceitualmente equivalente a:

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

Tipos esperados:

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

`contractingId` e `itemId` são apenas seletores candidatos. O par evita confused deputy entre duas contratações da mesma equipe, mas nenhum dos IDs define team, actor ou autorização.

O browser nunca fornece como authority:

- `team_id`;
- actor;
- membership;
- issuer;
- subject;
- `ordinal`;
- `retired_at`;
- timestamps;
- UUIDs de evento.

A futura UI poderá ecoar os valores lidos do read model protegido como snapshot esperado, exatamente como F33 faz com `expectedObject`. Enforcement continua no banco.

## 2. Semântica exata dos valores

### Textos

`description`, `unit` e `catalog_code` não sofrem trim nem normalização.

Devem permanecer distintos quando o schema permitir:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

`description` continua `NOT NULL`. A boundary não inventa regra non-empty, tamanho máximo ou normalização. `expectedDescription` e `newDescription` são strings, inclusive `''` e spaces-only.

### Numeric

`quantity` continua `numeric NULL` no PostgreSQL e `string | null` na interface TypeScript.

A aplicação não usa `Number`, `parseFloat` nem outra conversão floating-point. O adapter passa o texto parametrizado para cast PostgreSQL `numeric`.

A decisão não inventa:

- positividade;
- obrigatoriedade;
- escala máxima de negócio;
- precisão máxima de negócio;
- vínculo obrigatório com `unit`.

`NULL`, zero, negativo, fração e alta precisão válida continuam permitidos pelo que o schema atual suporta.

A concorrência compara valores `numeric` no banco. Portanto a precondição preserva o valor numérico exato representável pelo tipo, não a grafia lexical original do input. Auditoria de quantidade usa a representação textual produzida pelo PostgreSQL a partir do valor persistido, sem round-trip por número JavaScript.

Texto não convertível para `numeric` falha antes da mutação e é sanitizado como `unavailable`. Não há tentativa de corrigir ou adivinhar o número.

## 3. Optimistic concurrency

A primitive deve bloquear a row do item autorizado com `SELECT ... FOR UPDATE`.

Diferentemente do lock rejeitado em F34 sobre a contratação pai, aqui a própria operação já necessita `UPDATE` limitado em `contracting_items`. O lock não justifica authority nova sobre `contractings`.

Após autorização e lock, comparar os quatro valores atuais com o snapshot esperado usando semântica null-safe:

```text
current.description IS NOT DISTINCT FROM expectedDescription
current.quantity IS NOT DISTINCT FROM expectedQuantity
current.unit IS NOT DISTINCT FROM expectedUnit
current.catalog_code IS NOT DISTINCT FROM expectedCatalogCode
```

A ordem de decisão é obrigatória:

1. autorização;
2. `conflict` se qualquer expected divergir;
3. `unchanged` se o snapshot atual inteiro já for igual ao snapshot novo;
4. `updated` somente quando houver ao menos um campo realmente alterado.

Consequências:

- stale expected nunca vira `unchanged` só porque os valores novos coincidem com o estado corrente;
- duas chamadas concorrentes com o mesmo expected antigo produzem no máximo um `updated`;
- retries posteriores da mesma chamada bem-sucedida retornam `conflict`, não replay-success;
- no-op não altera `updated_at` e não cria evento.

Não é criada coluna de versão nesta slice.

## 4. Autorização pilot-only

A autorização segue o guard target-team de F26/F32/F35, não o guard global de criação F29.

A mutação só é permitida quando:

1. `current_app_user_id()` resolve para usuário interno ativo;
2. o item candidato pertence ao `contractingId` candidato e está visível no escopo RLS;
3. o item possui `retired_at IS NULL`;
4. a contratação pai existe no mesmo `team_id`, com `archived_at IS NULL` e `cancelled_at IS NULL`;
5. o usuário possui membership não revogada na equipe alvo;
6. essa equipe possui exatamente uma membership com `revoked_at IS NULL`.

A contagem inclui membership de app_user desabilitado, seguindo a postura conservadora já adotada. Um segundo membro não revogado bloqueia.

Uma membership adicional do mesmo usuário em outra equipe não bloqueia por si só. O team já existe na row alvo, portanto copiar o guard global F29 criaria política nova sem necessidade.

Cross-team, item inexistente, item retirado, contratação inexistente/inativa, identidade inválida e problema de membership colapsam no mesmo resultado de negação.

Q-009 continua aberta.

### Revalidação durante a operação

O lock é adquirido no item, não na contratação pai. A implementation deve revalidar pai ativo e guard pilot-only após obter o lock do item.

RLS permanece autoritativa também no `UPDATE` e no `INSERT` dos eventos. Se parent/membership deixar de ser elegível entre a checagem procedural e qualquer write, a policy deve impedir a conclusão. Falha posterior reverte toda a transação.

## 5. Capability dedicada e least privilege

F38 cria uma capability própria equivalente a:

`compras_contracting_item_mutation_owner`

Ela permanece:

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

O lifecycle segue ADR-005 e as migrations existentes. A primitive é `SECURITY DEFINER`, usa `search_path = pg_catalog`, SQL estático/parametrizado e tem `PUBLIC EXECUTE` revogado.

O runtime normal recebe somente `EXECUTE` por provisioning separado. Nenhuma role runtime recebe DML direto.

### Grants máximos

A capability pode receber somente o necessário para:

- resolver identidade confiável;
- ler memberships para o guard target-team;
- ler o estado ativo da contratação pai;
- ler e bloquear o item alvo;
- atualizar em `contracting_items` apenas `description`, `quantity`, `unit`, `catalog_code` e `updated_at`;
- inserir os fatos de auditoria aprovados em `contracting_events`;
- executar helpers de identidade necessários.

A capability não recebe:

- INSERT ou DELETE em `contracting_items`;
- UPDATE de `ordinal`, `retired_at`, `created_at`, `team_id`, `contracting_id` ou `id`;
- qualquer UPDATE em `contractings`;
- qualquer authority no allocator `contracting_item_ordinal_counters`;
- UPDATE/DELETE em `contracting_events`;
- authority de F26, F29, F32 ou F35.

F26/F29/F32/F35 também não recebem authority adicional.

## 6. Primitive conceitual

A implementação deve materializar função equivalente a:

```text
mutate_contracting_item_fields(
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

Os quatro UUIDs de evento são gerados pelo adapter server-only e nunca fazem parte do contrato recebido do browser. Eles correspondem de forma fixa aos quatro campos e permitem registrar de 1 a 4 fatos escalares sem extensão PostgreSQL adicional e sem serialização JSON inventada.

Todos os quatro UUIDs podem ser gerados por tentativa, mesmo quando parte deles não for usada porque o campo correspondente não mudou.

## 7. Auditoria atômica por campo

O schema de `contracting_events` representa mudança escalar com `field_key`, `old_value` e `new_value`. Uma edição que muda mais de um campo deve gerar um evento para cada campo realmente alterado, todos na mesma transação da row update.

Não será inventado blob JSON de before/after dentro de uma única coluna text.

Cada evento usa:

- `event_type = 'item_changed'`;
- `item_id = item alvo`;
- `team_id` e `contracting_id` derivados do item/banco;
- `actor_membership_id` derivado da identidade confiável;
- `field_key` em `description`, `quantity`, `unit` ou `catalog_code`;
- `old_value` e `new_value` correspondentes ao campo;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `note = NULL`;
- `related_identifier_id = NULL`.

Para texto nullable, `NULL` permanece `NULL` e `''` permanece string vazia. Para `quantity`, old/new são produzidos por `numeric::text` no banco, preservando `NULL` e sem conversão JavaScript.

A insertion order lógica é `description`, `quantity`, `unit`, `catalog_code`, mas os eventos da mesma operação compartilham o mesmo instante e não representam causalidade entre si.

Uma mudança de N campos cria exatamente N eventos, com `1 <= N <= 4`. `unchanged` cria zero eventos.

Falha de qualquer evento, inclusive UUID duplicado ou violação de policy, reverte:

- a atualização do item;
- `updated_at`;
- qualquer evento anterior da mesma tentativa.

`contractings.updated_at` não muda.

## 8. RLS da capability

F38 deve adicionar policies específicas da nova capability, sem ampliar policies existentes.

### SELECT/UPDATE do item

A row só pode ser visível/editável quando:

- `retired_at IS NULL`;
- parent `team_id + contracting_id` está ativo;
- usuário corrente possui membership não revogada naquele team;
- existe exatamente uma membership não revogada naquele team.

A policy de UPDATE deve manter as mesmas condições no `USING` e `WITH CHECK`. Como a capability não pode alterar scope, ordinal ou retired state, ela não consegue transformar a row em outro recurso.

### INSERT de eventos

A policy de auditoria exige:

- `event_type = 'item_changed'`;
- `item_id IS NOT NULL`;
- `field_key` em exatamente um dos quatro campos aprovados;
- `note IS NULL`;
- `related_identifier_id IS NULL`;
- actor membership corrente no mesmo team;
- exatamente uma membership não revogada no team;
- parent ativo;
- item ativo no mesmo `team_id + contracting_id`;
- `new_value` coerente com o valor já persistido do campo indicado.

A policy não tenta reconstruir o valor antigo a partir da row já atualizada. O old value é capturado dentro da primitive antes do update e inserido pela função confiável.

## 9. Semântica de resultado

Resultado interno da primitive:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

Interface server-only:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para `denied`;
- `unavailable` para falha técnica, configuração, conexão, cast numeric inválido, erro de driver ou resultado impossível.

`conflict` e `unchanged` só podem ser observados depois da autorização. Nenhum resultado revela se um item arbitrário existe em outro team, está retired ou pertence a outra contratação.

Falha protegida nunca cai para fixtures/demo.

## 10. Red-team da decisão

O desenho é rejeitado se permitir qualquer um dos caminhos abaixo:

1. browser controlar team, actor, membership, issuer, subject, ordinal, retired state, timestamp ou event UUID;
2. `itemId` de outra contratação do mesmo team ignorar o binding com `contractingId`;
3. cross-team/inexistente/retired/inactive parent virar oracle;
4. segundo membro não revogado virar permissão multiusuário;
5. copiar o guard global F29 sem necessidade;
6. runtime receber DML direto;
7. ampliar F26/F29/F32/F35;
8. nova capability criar, deletar, reorder ou retire/restore item;
9. capability tocar allocator;
10. trim, empty-to-NULL ou regra non-empty inventada;
11. `quantity` passar por `Number`/`parseFloat`;
12. positividade, escala ou precisão de negócio serem inventadas;
13. stale snapshot parcial sobrescrever alteração concorrente em outro campo;
14. stale expected virar `unchanged` porque new coincide com estado corrente;
15. no-op alterar timestamp ou criar evento;
16. update sobreviver à falha de qualquer evento;
17. audit blob JSON substituir a semântica escalar já disponível no schema;
18. evento registrar quantidade por float JavaScript;
19. retry pós-sucesso criar segundo conjunto de eventos;
20. `contractings.updated_at` ser alterado;
21. migration aplicada `0001..0008` ser reescrita;
22. provider hosted, secret ou dado real ser necessário.

Nenhum desses caminhos é aceito.

## 11. Matriz adversarial obrigatória para F38

F38 deve provar no mínimo:

1. mutation autorizada de cada um dos quatro campos isoladamente;
2. mutation atômica de todos os quatro campos em uma única chamada;
3. exatamente um evento por campo realmente alterado;
4. todos os eventos da tentativa usam o mesmo `operation_at` do `updated_at`;
5. description `''`, spaces-only e leading/trailing spaces preservados;
6. unit/catalog `NULL`, `''`, spaces-only e leading/trailing spaces preservados;
7. quantity `NULL`, zero, negativo, fração e alta precisão válida sem float JS;
8. numeric inválido retorna `unavailable` sem update/evento;
9. snapshot stale em qualquer campo retorna `conflict` sem update/evento;
10. stale expected continua `conflict` mesmo se new snapshot coincide com estado atual;
11. expected atual + new snapshot idêntico retorna `unchanged` sem timestamp/evento;
12. 8 writers concorrentes com o mesmo expected produzem exatamente um `updated`, demais `conflict` e somente o conjunto de eventos do vencedor;
13. retry pós-sucesso retorna `conflict` e não duplica evento;
14. event failure no primeiro, intermediário e último campo alterado reverte tudo;
15. claims ausentes/malformados, identidade desconhecida ou usuário desabilitado negam;
16. membership ausente/revogada nega;
17. segundo membro não revogado bloqueia, inclusive app_user desabilitado;
18. membership adicional do mesmo usuário em outro team não bloqueia a equipe alvo;
19. cross-team, item inexistente, parent mismatch e retired são externamente indistinguíveis;
20. parent archived/cancelled bloqueia;
21. mudança de parent/membership durante a janela de operação não consegue concluir write fora da policy;
22. forged ordinal/retired/timestamps/team/actor/event IDs não fazem parte da API pública;
23. capability não possui INSERT/DELETE de item nem UPDATE fora dos quatro campos + `updated_at`;
24. capability não toca allocator ou `contractings`;
25. runtime normal não possui DML direto;
26. Auth/read-only runtime não recebe EXECUTE;
27. F26/F29/F32/F35 permanecem com authority original;
28. migrations `0001..0008` permanecem byte-for-byte imutáveis;
29. somente dados/identidades fictícios e nenhum provider hosted write.

## Consequências

A decisão adiciona uma boundary estreita, mas ainda não disponibiliza edição na UI. A F38 implementa banco, provisioning, adapter e testes. Uma slice posterior poderá integrar a jornada no detalhe reutilizando apenas essa boundary.

A operação multi-campo exige mais parâmetros internos e até quatro eventos por tentativa. Esse custo é aceito para obter snapshot concurrency correta e auditoria escalar sem ampliar schema ou inventar encoding opaco.

## Fora do escopo

- UI/Server Action de edição de item;
- `ordinal` e reorder;
- `retired_at` e retire/restore;
- delete;
- pesquisa de preços e Q-004;
- política multiusuário e Q-009;
- nova regra de quantidade/unidade/catálogo;
- alteração de schema de produto para version column;
- provider hosted;
- retomada F21;
- dado real.

## Implementação subsequente

A implementação pertence exclusivamente a:

`F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01`.
