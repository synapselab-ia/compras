# F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01 - Integrar edição persistente de item no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY / NEXT após integração da F38  
**Dependências:** F38, ADR-015, F36, F33, ADR-003 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F38 integrou a boundary PostgreSQL/server-only para editar os quatro campos mutáveis de um `contracting_item`, mas ainda não existe jornada de edição no detalhe persistente.

O read model atual apresenta item por `label + note` e não deve ser parseado para reconstruir o snapshot optimistic concurrency. A UI precisa receber o snapshot bruto protegido diretamente do read model autorizado, preservando `NULL`, string vazia, espaços e `numeric::text`.

A próxima slice deve tornar exclusivamente a operação F38 utilizável no detalhe, sem ampliar authority PostgreSQL, sem criar reorder/retire/delete e sem resolver Q-004 ou Q-009.

## Objetivo

No modo persistente autorizado, permitir editar somente:

```text
description
quantity
unit
catalog_code
```

por item ativo já retornado pelo read model protegido, usando exclusivamente:

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

A integração deve preservar o snapshot esperado completo, sem authority de browser para team/actor/membership/issuer/subject/ordinal/retired/timestamps/event UUIDs, com feedback sanitizado e demo estritamente read-only.

## 1. Recuperação e limites

Antes de implementar:

1. recuperar `main` real após F38;
2. revalidar `CONTEXT_MANIFEST`;
3. confirmar PR #59 integrada e gates pós-merge verdes;
4. ler ADR-015, resultado F38 e esta SPEC;
5. inspecionar F33 e F36 como precedentes de Server Action/UI;
6. inspecionar `persistent-read.ts`, `types.ts`, detalhe, actions e feedbacks atuais;
7. manter migrations `0001..0009` byte-for-byte imutáveis;
8. não alterar grants, policies, capabilities, primitive ou provisioning F38.

F39 não implementa nova authority de banco.

## 2. Read model protegido para edição

O snapshot de edição deve vir da mesma consulta protegida de `contracting_items`, nunca de parsing de `label`, `note`, DOM ou texto formatado.

Estender a apresentação de item com um valor bruto somente para a jornada de edição, conceitualmente:

```text
mutationSnapshot: {
  description: string
  quantity: string | null
  unit: string | null
  catalogCode: string | null
} | null
```

Requisitos:

- persistent read autorizado preenche o snapshot a partir das colunas reais já lidas;
- `quantity` vem de `numeric::text` como hoje;
- `description`, `unit` e `catalog_code` permanecem exatos;
- `NULL` não vira string vazia na camada de dados;
- fixtures/demo não ganham snapshot de escrita operacional e podem usar `null`;
- a UI de edição só existe com `source = persistent` e snapshot presente;
- falha protegida não cai para fixture/demo.

O snapshot é precondição de concorrência, não scope/autorização. A autoridade continua derivada e imposta por F38/RLS.

## 3. Server Action dedicada

Criar uma Server Action específica para F38.

Ela deve:

- verificar novamente que persistence está habilitada antes de chamar F38;
- ler cada scalar esperado no máximo uma vez;
- falhar fechado em valores duplicados ou ambíguos;
- aceitar apenas os campos de transporte definidos nesta SPEC, além de `$ACTION_*` internos do framework;
- rejeitar campos extras controláveis pelo browser;
- validar `contractingId` e `itemId` como UUIDs candidatos;
- não executar SQL/DML próprio;
- chamar exclusivamente `mutatePersistentContractingItem`;
- não gerar nem aceitar event UUID no FormData;
- não aceitar team, actor, membership, issuer, subject, ordinal, retired state ou timestamps como authority;
- não aceitar callback, redirect ou URL arbitrária;
- nunca cair para demo write;
- nunca refletir SQL, claims, connection string, UUID de evento ou detalhe de autorização.

### Campos de transporte

A action pode aceitar somente:

```text
contractingId
itemId
expectedDescription
expectedQuantity
expectedUnitKind
expectedUnit
expectedCatalogCodeKind
expectedCatalogCode
newDescription
newQuantity
newUnitKind
newUnit
newCatalogCodeKind
newCatalogCode
```

`expectedUnitKind`, `expectedCatalogCodeKind`, `newUnitKind` e `newCatalogCodeKind` aceitam somente:

```text
null
text
```

A codificação explícita existe porque `unit` e `catalog_code` distinguem `NULL` de `''`.

Para `kind = null`, a action constrói `null`. Para `kind = text`, usa exatamente a string correspondente, inclusive `''` e espaços. Não trimar nem converter automaticamente vazio para `NULL`.

`expectedQuantity` ausente representa `null`; quando presente deve ser string exata. `newQuantity` literalmente vazia representa `null`; qualquer texto não vazio segue exatamente para F38/PostgreSQL. Não usar `Number`, `parseFloat` ou regex de negócio.

`description` continua string obrigatória apenas por shape técnico do schema, mas `''` e spaces-only são valores válidos.

## 4. Snapshot optimistic concurrency

Cada formulário deve carregar como expected exatamente o snapshot bruto que originou a edição:

```text
expectedDescription
expectedQuantity
expectedUnit
expectedCatalogCode
```

A UI/browser pode transportar esses expected values, mas não decide autorização. F38 compara os quatro de forma null-safe sob item row lock.

Proibir:

- expected parcial;
- reconstrução a partir de label/note;
- timestamp como versão;
- ordinal como versão;
- retry automático após `conflict`;
- substituir expected pelo new antes de chamar F38.

Ao ocorrer `conflict`, apresentar estado sanitizado e permitir que novo render/readback protegido forneça o snapshot atual. Não reaplicar automaticamente a edição perdida.

## 5. UI de item

No detalhe persistente, cada item ativo com snapshot protegido pode exibir um editor mínimo para os quatro campos.

Campos:

- descrição;
- quantidade opcional;
- unidade com distinção explícita entre texto e `NULL`;
- código de catálogo com distinção explícita entre texto e `NULL`;
- submit.

### Description

Usar controle textual que preserve exatamente:

- `''`;
- spaces-only;
- leading/trailing spaces.

Não usar `required`, trim ou max length de negócio.

### Quantity

Usar input textual, não `type=number`, com `inputMode="decimal"` apenas como dica de teclado.

- valor atual `null` aparece como campo vazio;
- submissão literalmente vazia representa `null`;
- texto não vazio segue exato;
- não validar positividade, escala ou precisão no browser.

### Unit e catalogCode

Como `NULL` e `''` são distintos, a UI deve oferecer escolha acessível e explícita entre:

```text
Texto
Ausente (NULL)
```

Pode ser `select`, radio group ou controle equivalente sem depender de inferência por campo vazio.

Quando `Texto` estiver selecionado, o input textual é preservado exatamente, inclusive vazio e espaços. Quando `Ausente (NULL)` estiver selecionado, a action envia `null` para F38 de forma explícita.

A implementação pode manter o input visível quando `NULL` estiver selecionado, mas seu texto não pode substituir a escolha explícita `null`.

## 6. Resultado e feedback

Estados F38:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

A camada browser-facing deve mapear somente para mensagens fixas e sanitizadas.

Semântica mínima:

- `updated`: revalidar somente a rota local fixa do detalhe e informar sucesso;
- `unchanged`: informar que não houve alteração, sem inventar evento ou sucesso de write;
- `conflict`: informar genericamente que o item mudou desde o snapshot exibido e que os valores atuais devem ser relidos; não expor old/current protegido na query string;
- `not-available`: mensagem genérica que não distingue inexistente, cross-team, retired, parent inativo ou membership;
- `unavailable`: falha técnica temporária sanitizada;
- valor desconhecido/array na query não é refletido.

Nenhum resultado pode virar oracle de team, actor, membership, existência protegida ou retired state.

A navegação/redirect deve ser derivada somente do `contractingId` validado e rota local fixa. Callback/redirect do cliente é proibido.

## 7. Pending e double-submit

Reutilizar ou generalizar o submit button baseado em `useFormStatus` para desabilitar a tentativa enquanto pending.

Isso reduz double-submit acidental na UI, mas não muda a semântica de F38: retry pós-sucesso com expected antigo retorna `conflict`.

Não inventar idempotência/replay-success na F39.

## 8. Demo e falhas protegidas

Demo permanece estritamente read-only:

- nenhum editor F38;
- nenhum hidden expected snapshot operacional;
- nenhuma chamada da Server Action F39;
- query string forjada não mostra feedback que sugira write real.

Persistence inválida ou falha de leitura protegida não habilita editor e não cai para demo.

## 9. Fora do escopo

F39 não inclui:

- migration nova;
- alteração de RLS/grants/capabilities/primitive/provisioning;
- reorder/edição de `ordinal`;
- retire/restore;
- delete de item;
- criação de item, além da F36 já existente;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- provider hosted ou secrets;
- dado real.

## 10. Matriz adversarial obrigatória

Provar no mínimo:

1. persistent mode autorizado renderiza editor F38 para item ativo com snapshot protegido;
2. demo não renderiza editor nem expected snapshot operacional;
3. persistence inválida/falha protegida não chama F38 e não cai para demo;
4. read model entrega description/quantity/unit/catalogCode brutos sem parsing de label/note;
5. quantity continua `numeric::text | null` no read model;
6. action encaminha `contractingId + itemId` e os quatro expected/new exatos;
7. scalars duplicados falham fechado antes de F38;
8. campos extras falham fechado;
9. team/actor/membership/issuer/subject/ordinal/retired/timestamps/event UUIDs forjados não atravessam a action;
10. callback/redirect forjado não controla navegação;
11. contractingId/itemId malformados não chegam a F38;
12. itemId não é obtido de label/note;
13. expected snapshot não é parcial nem derivado de timestamp/ordinal;
14. description `''`, spaces-only e leading/trailing spaces não são normalizados;
15. unit `NULL`, `''` e spaces-only possuem codificação distinta;
16. catalogCode `NULL`, `''` e spaces-only possuem codificação distinta;
17. expected unit/catalog `NULL` versus empty permanecem distintos;
18. quantity null chega como `null`;
19. quantity `0`, negativa, fracionária e high precision chega como string exata;
20. quantity não usa `type=number`, `Number` ou `parseFloat`;
21. numeric inválido resulta somente em `unavailable` sanitizado;
22. `updated` revalida somente rota local fixa e o readback vem do modelo protegido;
23. `unchanged` não cria aparência de novo evento;
24. `conflict` não faz retry automático nem expõe current protegido em URL;
25. `not-available` não distingue cross-team/inexistente/retired/inativo;
26. erro contendo conexão/SQL/claim não aparece no HTML/navegação;
27. pending desabilita repetição acidental;
28. nenhum controle de reorder/retire/restore/delete/preço é criado;
29. migrations `0001..0009` permanecem byte-for-byte;
30. F26/F29/F32/F35/F38 não recebem authority nova;
31. CI, F22, F29, F32, F35 e F38 continuam verdes.

## 11. Red-team obrigatório

Rejeitar PASS se:

- UI reconstruir expected a partir de texto formatado;
- `NULL` de unit/catalog virar vazio implicitamente;
- browser puder fornecer authority de scope/actor/event IDs;
- action executar SQL/DML próprio ou contornar F38;
- expected parcial permitir lost update;
- conflito virar retry automático;
- quantity passar por float JavaScript;
- trim/empty-to-NULL ocorrer sem escolha explícita;
- demo ou configuração inválida puder gravar;
- protected failure cair para fixture/demo;
- callback/redirect externo for controlável pelo cliente;
- feedback revelar existência ou estado protegido;
- migrations/grants/policies/capabilities F38 forem alterados;
- escopo expandir para reorder/retire/delete/preço;
- Q-004/Q-009 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## 12. Verificação

Executar:

- lint;
- typecheck;
- unit/component tests;
- build;
- CI database/Auth;
- F22 Private Preview Preflight;
- F29 Contracting Create;
- F32 Contracting Object Mutation;
- F35 Contracting Item Create;
- F38 Contracting Item Mutation;
- diff/red-team integral.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F35 continua exclusiva da criação de item;
- F38 continua exclusiva da edição dos quatro campos de item;
- migrations aplicadas `0001..0009` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Critério de encerramento

F39 fecha quando uma pessoa autorizada em modo persistente puder editar os quatro campos de um item ativo usando exclusivamente F38, com snapshot bruto protegido, optimistic concurrency completo, distinção de `NULL`/texto, quantity sem coerção JavaScript, feedback sanitizado, readback protegido, demo read-only e todos os gates/adversariais verdes.
