# ADR-014 - Criação persistente mínima de item da contratação

**Status:** Accepted  
**Data:** 2026-09-15  
**Escopo:** desenho da boundary persistente exclusiva para adicionar um item a uma contratação existente; implementação pertence à F35  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

O núcleo funcional inicial prevê itens dentro de uma `Contratação`. A fundação física já possui `contracting_items` com `id`, `team_id`, `contracting_id`, `ordinal`, `description`, `quantity`, `unit`, `catalog_code`, timestamps e `retired_at`, além de `contracting_events.item_id` para vincular fatos históricos ao item.

As decisões anteriores estabeleceram propriedades que esta escrita não pode diluir:

- ADR-011/F26 mantém uma capability específica para `next_action`;
- ADR-012/F29 mantém uma capability específica para criação mínima de contratação;
- ADR-013/F32 mantém uma capability específica para edição de `object`;
- runtime normal permanece sem DML direto nas tabelas operacionais protegidas;
- identity/scope/actor vêm de sessão validada e banco, nunca da UI;
- Q-009 permanece aberta, portanto a escrita continua pilot-only;
- migrations aplicadas `0001..0006` são imutáveis.

O schema canônico não define positividade, precisão de negócio, obrigatoriedade de quantidade, obrigatoriedade de unidade, catálogo obrigatório, trim, tamanho máximo de descrição ou regra de pesquisa de preços. Q-004 permanece aberta.

F34 é design-only. Nenhum SQL operacional, migration, grant, adapter, Server Action ou UI é implementado nesta decisão.

## Alternativas avaliadas

### A. DML direto pela role runtime

A aplicação poderia inserir `contracting_items` e `contracting_events` diretamente em uma transação server-side.

**Rejeitada.** Isso exigiria DML direto para a credencial operacional normal e ampliaria authority além da operação aprovada.

### B. Ampliar F26, F29 ou F32

Uma capability existente poderia receber novos grants de item create.

**Rejeitada.** As capabilities existentes foram provadas para responsabilidades distintas. Misturar item create com next action, contracting create ou object mutation enfraqueceria least privilege e regressão independente.

### C. Capability própria com primitive estreita

Criar capability `NOLOGIN` específica, com primitive `SECURITY DEFINER`, grants coluna-a-coluna, RLS específica e evento atômico.

**Adotada.** Mantém as authorities existentes seladas e permite provar item create isoladamente.

## Decisão

A criação persistente de item será uma operação específica, pilot-only, auditável e serializada por contratação, executada por capability PostgreSQL própria.

A implementação F35 deverá materializar uma primitive conceitualmente equivalente a:

```text
create_contracting_item(
  p_contracting_id uuid,
  p_description text,
  p_quantity numeric,
  p_unit text,
  p_catalog_code text,
  p_item_id uuid,
  p_event_id uuid
)
```

O nome exato pode variar sem alterar a decisão.

A primitive não aceita `team_id`, `app_user_id`, membership, actor, issuer, subject ou `ordinal` como argumentos.

## 1. Payload e fronteira de confiança

A interface server-only da F35 deve aceitar somente:

```text
contractingId
description
quantity
unit
catalogCode
```

Semântica na camada TypeScript:

- `contractingId`: seletor candidato, nunca authority;
- `description`: `string`, porque `description` é `text NOT NULL`;
- `quantity`: `string | null`, para evitar perda de precisão por `Number` JavaScript e delegar a conversão ao PostgreSQL `numeric`;
- `unit`: `string | null`;
- `catalogCode`: `string | null`.

A camada server-only gera `itemId` e `eventId` em cada tentativa e os passa à primitive. Esses UUIDs não fazem parte do contrato aceito do browser e não são tokens de autorização.

A implementação não deve:

- aplicar `trim` em `description`, `unit` ou `catalogCode`;
- converter string vazia de campo textual nullable em `NULL` por conveniência;
- impor tamanho máximo não existente no schema;
- exigir descrição non-empty;
- exigir quantidade positiva, não zero ou inteira;
- exigir unidade ou catálogo;
- impor escala/precisão de negócio;
- usar `parseFloat` ou `Number` para quantidade;
- inferir qualquer regra de Q-004.

`description = ''` e descrição composta apenas por espaços continuam permitidas pelo contrato físico atual. Para `unit` e `catalogCode`, `NULL`, string vazia e strings com espaços permanecem estados distintos.

`quantity` é valor numérico. `NULL`, zero, negativos e frações continuam tecnicamente permitidos enquanto nenhuma regra de negócio os proibir. Entrada que não seja convertível para `numeric` falha fechada como erro técnico sanitizado, sem criar item ou evento.

## 2. UUIDs e repetição

`itemId` e `eventId` são gerados no servidor confiável dentro da tentativa de criação e nunca aceitos da UI.

A operação não cria deduplicação semântica baseada em descrição, quantidade, unidade ou catálogo, pois nenhuma chave de negócio canônica define quando duas linhas são duplicadas. Cada invocação autorizada e concluída representa uma criação distinta.

Uma futura UI deve evitar submissão repetida acidental por estado pending, mas F34 não inventa idempotência persistente. Caso uso real exija replay idempotente, isso requer decisão própria.

## 3. Autorização pilot-only por equipe alvo

Como a contratação alvo já existe e possui `team_id` canônico, a autorização segue o padrão target-team de F26/F32, não o guard global de criação F29.

A capability só autoriza quando:

1. `current_app_user_id()` resolve para usuário interno ativo;
2. a contratação candidata existe e é visível pelo escopo derivado da identidade;
3. a contratação está ativa, com `archived_at IS NULL` e `cancelled_at IS NULL`;
4. existe membership `revoked_at IS NULL` do usuário corrente na equipe da contratação;
5. essa membership é a única membership `revoked_at IS NULL` da equipe alvo.

Uma segunda membership não revogada na equipe alvo bloqueia a capability, inclusive quando o `app_user` correspondente estiver desabilitado. Outra membership não revogada do mesmo usuário em equipe diferente não bloqueia por si só.

Inexistente, cross-team, usuário desabilitado, membership ausente/revogada, segundo membro, contratação arquivada e contratação cancelada devem colapsar para a mesma negação externa. Q-009 permanece aberta.

## 4. Capability e least privilege

A F35 deve criar role técnica equivalente a:

`compras_contracting_item_create_owner`

A role deve permanecer:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem `rolconfig` persistente;
- sem ownership de tabelas-base;
- sem membership utilizável em outra role.

O lifecycle segue ADR-005 e os precedentes F26/F29/F32. Nenhuma aresta persistente pode permitir `SET ROLE` ou herança da capability.

A primitive deve ser `SECURITY DEFINER`, usar `search_path = pg_catalog`, SQL estático/parametrizado e ter `PUBLIC EXECUTE` revogado.

### Grants máximos esperados

A capability pode receber apenas o necessário para:

- resolver a identidade corrente;
- ler memberships exigidas pelo guard pilot-only;
- localizar a contratação alvo sem adquirir write authority sobre `contractings`;
- ler ordinais dos itens da contratação;
- inserir as colunas aprovadas de `contracting_items`;
- inserir as colunas aprovadas de `contracting_events`;
- inserir/ler/atualizar somente o estado técnico do alocador de ordinal descrito abaixo;
- executar helpers de identidade necessários.

O `INSERT` em `contracting_items` deve ser coluna-a-coluna, limitado a:

- `id`;
- `team_id`;
- `contracting_id`;
- `ordinal`;
- `description`;
- `quantity`;
- `unit`;
- `catalog_code`;
- `created_at`;
- `updated_at`.

`retired_at` nasce `NULL` e não entra no grant de insert.

O `INSERT` em `contracting_events` deve ser coluna-a-coluna, limitado a:

- `id`;
- `team_id`;
- `contracting_id`;
- `actor_membership_id`;
- `event_type`;
- `occurred_at`;
- `item_id`;
- `created_at`.

A capability não recebe `UPDATE` ou `DELETE` sobre `contracting_items`, `contractings` ou `contracting_events`.

A role runtime normal recebe somente `EXECUTE` da primitive por provisionamento explícito e separado da migration. F26, F29 e F32 não recebem item-create authority, e a nova capability não recebe authority das primitives anteriores.

RLS permanece autoritativa sob `FORCE ROW LEVEL SECURITY`.

## 5. Alocador técnico de ordinal

### Por que não usar `SELECT ... FOR UPDATE` em `contractings`

A primeira versão do desenho considerou bloquear a row pai de `contractings`. O red-team rejeitou essa alternativa porque PostgreSQL exige privilégio `UPDATE` para usar locking clauses como `SELECT ... FOR UPDATE`, mesmo quando nenhuma coluna é efetivamente alterada.

Conceder `UPDATE` em `contractings` apenas para obter o lock ampliaria a authority da capability de item create sobre a entidade pai sem necessidade funcional. A decisão final preserva zero `UPDATE` na contratação.

### Tabela técnica dedicada

A migration F35 deve criar uma tabela interna equivalente a:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
FK (team_id, contracting_id) -> contractings(team_id, id)
```

O nome exato pode variar. Essa tabela é estado técnico do allocator, não entidade de produto e não entra no read model normal.

Ela deve nascer com RLS habilitada e forçada, grants default-deny e policy somente para a capability F35. Runtime normal não recebe SELECT/INSERT/UPDATE direto nessa tabela.

`last_ordinal` pode ser `NULL` antes da primeira alocação. Não adicionar `CHECK` de positividade.

### Algoritmo

Depois de autorizar a contratação por leitura protegida, a primitive deve:

1. garantir que exista a row técnica do allocator para `team_id + contracting_id`, usando `INSERT ... ON CONFLICT DO NOTHING` com `last_ordinal = NULL`;
2. bloquear exatamente essa row do allocator com `SELECT ... FOR UPDATE`;
3. após obter o lock, revalidar que a contratação continua visível, ativa e autorizada;
4. obter `MAX(contracting_items.ordinal)` considerando todos os itens da contratação, inclusive `retired_at IS NOT NULL`;
5. calcular o maior valor entre `last_ordinal` e o máximo persistido, preservando `NULL` quando ambos inexistirem;
6. se ambos forem `NULL`, usar próximo ordinal `1`; caso contrário, usar `maior + 1`;
7. atualizar `last_ordinal` da row técnica para o ordinal alocado;
8. inserir item e evento na mesma transação.

A comparação com `MAX(ordinal)` após o lock protege contra allocator recém-criado sobre itens preexistentes e contra estado técnico atrasado em relação a dados já existentes.

A operação não reutiliza gaps. O allocator retém o maior ordinal já alocado mesmo se um item for retirado. Falha posterior do item/evento reverte também a atualização do allocator.

Overflow de `integer` falha fechado como erro técnico; F34 não inventa regra de negócio para alterar o tipo físico nesta slice.

### Concorrência na mesma contratação

Duas ou mais criações da mesma contratação convergem para a mesma row do allocator:

- a primeira bloqueia a row, calcula/aloca o próximo ordinal, insere item + evento e conclui;
- a seguinte aguarda;
- após adquirir o lock, revalida autorização e lê o estado já comprometido antes de alocar o ordinal seguinte.

A constraint `UNIQUE (contracting_id, ordinal)` continua como backstop. O fluxo normal não depende de capturar unique violation e fazer retry cego.

### Concorrência em contratações diferentes

Cada contratação possui row de allocator distinta. Não existe table lock nem advisory lock global. Operações em contratações diferentes devem avançar independentemente.

Qualquer futura boundary operacional que também crie itens deve usar o mesmo allocator ou substituir esta decisão por nova ADR.

## 6. Atomicidade e auditoria

Uma criação bem-sucedida insere exatamente um item e exatamente um evento na mesma transação.

### Estado do item

O item criado recebe:

- `id = itemId` server-side;
- `team_id` derivado da contratação autorizada;
- `contracting_id` derivado da contratação autorizada;
- `ordinal` alocado pela row técnica;
- `description`, `quantity`, `unit` e `catalog_code` conforme payload;
- `created_at = operation_at`;
- `updated_at = operation_at`;
- `retired_at = NULL`.

### Evento

O evento automático usa:

- `event_type = 'item_created'`;
- `team_id` e `contracting_id` derivados da contratação;
- `actor_membership_id` derivado do banco;
- `item_id` igual ao item recém-criado;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `field_key = NULL`;
- `old_value = NULL`;
- `new_value = NULL`;
- `note = NULL`;
- `related_identifier_id = NULL`.

Descrição, quantidade, unidade e catálogo permanecem no estado estruturado do item. O evento não duplica esses campos em texto livre.

`contractings.updated_at` não é alterado por item create. `DATABASE.md` já define que esse timestamp não é sinônimo automático de última movimentação relevante.

Se o evento falhar, o insert do item e o avanço do allocator devem ser revertidos. Nenhum evento é criado em negação ou falha anterior à criação.

## 7. Resultados externos

A primitive pode distinguir internamente apenas:

- `created`;
- `denied`.

A interface server-only da F35 expõe apenas:

- `created`;
- `not-available` para qualquer negação protegida;
- `unavailable` para falha técnica, configuração, conexão, contexto, cast numérico inválido, overflow ou resultado impossível.

A resposta não retorna team, actor, membership, ordinal, item UUID, event UUID, SQL ou detalhe interno. Readback posterior usa o read model protegido.

Não existe fallback para demo ou fixture quando a escrita persistente falha.

## 8. RLS esperada na implementação

A migration F35 deve adicionar somente policies específicas à nova capability.

### Allocator

A tabela técnica deve permitir à capability somente rows cujo `team_id + contracting_id` correspondam a contratação ativa autorizada pelo guard target-team. A capability pode `INSERT`, `SELECT` e `UPDATE(last_ordinal)` nessa tabela, sem `DELETE`.

### Item insert

A policy de `contracting_items FOR INSERT` deve, no mínimo:

- exigir `retired_at IS NULL`;
- exigir contratação correspondente ativa;
- exigir item `team_id` igual ao team canônico da contratação;
- exigir membership ativa do usuário corrente na equipe alvo;
- exigir exatamente uma membership não revogada na equipe alvo.

### Evento insert

A policy de `contracting_events FOR INSERT` deve, no mínimo:

- exigir `event_type = 'item_created'`;
- exigir `item_id IS NOT NULL`;
- exigir `field_key`, `old_value`, `new_value`, `note` e `related_identifier_id` nulos;
- exigir actor membership do usuário corrente na mesma equipe;
- exigir exatamente uma membership não revogada na equipe alvo;
- exigir contratação correspondente ativa;
- exigir que `item_id` referencie o item criado dentro do mesmo `team_id + contracting_id`.

A runtime normal não recebe DML direto.

## 9. Matriz obrigatória da F35

A implementação deve provar em PostgreSQL 17 descartável, além dos gates normais:

1. usuário piloto autorizado cria item + exatamente um evento;
2. team, actor e contracting são derivados do banco;
3. item UUID e event UUID nascem server-side e não existem no input público do adapter;
4. `ordinal` não existe no input do adapter;
5. primeira criação em contratação sem itens recebe ordinal 1;
6. criações sequenciais recebem ordinais crescentes;
7. gaps existentes não são reutilizados;
8. item retirado continua participando do máximo;
9. allocator novo sobre itens preexistentes começa após o maior ordinal real;
10. allocator atrasado em relação a item existente é reconciliado pelo `MAX` após lock;
11. múltiplos creates concorrentes na mesma contratação produzem ordinais distintos e sequenciais, sem retry cego;
12. creates em contratações diferentes não dependem de lock global;
13. falha de item/evento reverte também avanço do allocator;
14. claims ausentes, malformados e desconhecidos falham fechado;
15. usuário desabilitado falha fechado;
16. membership ausente ou revogada falha fechado;
17. segundo membro não revogado na equipe alvo bloqueia, inclusive se seu `app_user` estiver desabilitado;
18. membership adicional do mesmo usuário em outra equipe não bloqueia por si só;
19. cross-team e UUID inexistente são externamente indistinguíveis;
20. contratação arquivada ou cancelada bloqueia, inclusive após espera pelo allocator;
21. `description = ''`, spaces-only e leading/trailing spaces são preservados;
22. `unit` e `catalogCode` preservam `NULL`, vazio e espaços sem normalização;
23. `quantity = NULL`, zero, negativo e fração tecnicamente válida são persistidos sem regra inventada;
24. quantidade de alta precisão não passa por `Number` JavaScript;
25. quantidade não convertível falha sem item/evento e vira somente `unavailable`;
26. event `item_id` referencia o item correto e actor/team/contracting são coerentes;
27. item e evento compartilham o mesmo `operation_at` nos timestamps definidos;
28. negação não cria allocator novo quando a contratação não é autorizada;
29. runtime não possui DML direto de allocator/item/evento/contratação;
30. capability não possui UPDATE em `contractings`;
31. capability não possui LOGIN, SUPERUSER, BYPASSRLS, ownership de tabelas-base ou membership utilizável;
32. capability não consegue atualizar/retirar/reordenar item nem alterar contratação;
33. F26/F29/F32 não ganham item-create authority e a nova capability não ganha authority dessas operações;
34. migrations `0001..0006` permanecem byte-for-byte imutáveis;
35. suites de leitura/RLS/Auth/F24/F26/F29/F32 permanecem verdes;
36. nenhum provider hosted write, secret ou dado real é usado.

## 10. Red-team da decisão

Rejeitados pelo desenho:

- `team_id`, actor, membership, issuer, subject, `ordinal`, item UUID ou event UUID confiados ao browser;
- ordinal vindo do cliente;
- row lock em `contractings` que exija conceder UPDATE desnecessário à capability;
- `MAX(ordinal)+1` sem serialização por contratação;
- retry cego de unique violation como mecanismo primário;
- table lock ou advisory lock global;
- reutilização automática de gap;
- exclusão de item retirado do cálculo do maior ordinal;
- DML direto pela role runtime;
- ampliação de F26/F29/F32;
- capability com login, privilege escalation, ownership de tabela ou `BYPASSRLS`;
- item criado em contratação cross-team, inexistente, arquivada ou cancelada;
- política global de exactly-one-membership da F29 copiada para row com team conhecido;
- regra de quantidade positiva, unidade obrigatória, catálogo obrigatório, trim ou limite de tamanho sem fonte canônica;
- uso de `Number` JavaScript para `numeric` arbitrário;
- evento não atômico ou sem vínculo ao item;
- update de `contractings.updated_at`;
- deduplicação sem chave de negócio aprovada;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real;
- reescrita das migrations aplicadas.

## Consequências

### Positivas

- item create nasce com authority própria e verificável;
- browser não controla scope, actor, UUIDs nem ordem;
- allocator por contratação resolve corrida sem dar UPDATE na contratação pai;
- contratações distintas usam rows de lock distintas;
- gaps e ordinais históricos não são reutilizados;
- item, allocator e auditoria são atômicos;
- quantidade permanece fiel ao tipo `numeric` sem perda por float JS;
- Q-004 e Q-009 continuam abertas.

### Custos

- F35 introduz uma tabela técnica adicional para alocação de ordinal;
- toda criação concorrente na mesma contratação é serializada pela row do allocator;
- não existe deduplicação/idempotência semântica de item nesta decisão;
- a implementação exige nova migration, provisioning, testes PostgreSQL e adapter server-only específicos.

## Fora do escopo

- editar descrição, quantidade, unidade ou catálogo de item existente;
- reordenar item;
- retirar/restaurar item;
- pesquisa de preços ou Q-004;
- política multiusuário Q-009;
- UI/Server Action de item;
- provider hosted;
- dado real.

## Próxima implementação

A F35 deve implementar exatamente esta boundary, sem ampliar escopo: migration nova, tabela técnica do allocator, capability própria, primitive, provisioning, adapter server-only, testes unitários/PostgreSQL/concorrência e workflow/regressões aplicáveis.