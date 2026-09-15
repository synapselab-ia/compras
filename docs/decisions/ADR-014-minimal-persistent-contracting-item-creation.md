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

Criar uma capability `NOLOGIN` específica, com primitive `SECURITY DEFINER`, grants coluna-a-coluna, RLS específica e evento atômico.

**Adotada.** Mantém as authorities existentes seladas e permite provar item create isoladamente.

## Decisão

A criação persistente de item será uma operação específica, pilot-only, auditável e serializada por contratação, executada por uma capability PostgreSQL própria.

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

A interface server-only da F35 deve aceitar somente os valores de negócio que já existem no schema:

```text
contractingId

description
quantity
unit
catalogCode
```

Semântica esperada na camada TypeScript:

- `contractingId`: seletor candidato de contratação, nunca authority;
- `description`: `string`, porque `description` é `text NOT NULL`;
- `quantity`: `string | null`, para evitar perda de precisão por `Number` JavaScript e delegar a representação numérica ao tipo PostgreSQL `numeric`;
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

`quantity` é valor numérico, não texto auditável. A F35 deve passar a string recebida diretamente como parâmetro para conversão PostgreSQL `numeric`, sem normalização de aplicação. `NULL`, zero, negativos e frações continuam tecnicamente permitidos enquanto nenhuma regra de negócio os proibir. Entrada que não seja convertível para `numeric` falha fechada como erro técnico sanitizado na boundary, sem criar item ou evento.

## 2. UUIDs e semântica de repetição

`itemId` e `eventId` são gerados no servidor confiável dentro da tentativa de criação e nunca aceitos da UI.

Esta operação não cria idempotência semântica baseada em descrição, quantidade, unidade ou catálogo, pois nenhuma chave de negócio canônica define quando duas linhas são duplicadas. Cada invocação autorizada e concluída representa uma criação distinta.

A futura UI deve evitar submissão repetida acidental por estado pending, mas F34 não inventa deduplicação persistente. Um mecanismo de idempotência adicional exigirá decisão própria se uso real demonstrar necessidade.

## 3. Autorização pilot-only por equipe alvo

Como a contratação alvo já existe e possui `team_id` canônico, a autorização segue o padrão target-team de F26/F32, não o guard global de criação F29.

A capability só autoriza quando:

1. `current_app_user_id()` resolve para usuário interno ativo;
2. a contratação candidata existe e é visível pelo escopo derivado da identidade;
3. a contratação está ativa, com `archived_at IS NULL` e `cancelled_at IS NULL`;
4. existe membership `revoked_at IS NULL` do usuário corrente na equipe da contratação;
5. essa membership é a única membership `revoked_at IS NULL` da equipe alvo.

Uma segunda membership não revogada na equipe alvo bloqueia a capability, inclusive quando o `app_user` correspondente estiver desabilitado. A correção operacional continua sendo revogar a membership.

Outra membership não revogada do mesmo usuário em equipe diferente não bloqueia por si só. A linha alvo já define o team canônico, portanto não existe a ambiguidade global da F29.

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
- localizar e bloquear a contratação alvo;
- ler `ordinal` dos itens da contratação para calcular a próxima posição;
- inserir as colunas aprovadas de `contracting_items`;
- inserir as colunas aprovadas de `contracting_events`;
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

## 5. Atribuição de `ordinal`

`ordinal` não é input confiável do caller. Ele é calculado pela primitive dentro da mesma transação da criação.

A estratégia adotada é:

1. localizar e bloquear a contratação autorizada com `SELECT ... FOR UPDATE`;
2. somente depois do lock, obter `MAX(ordinal)` de todos os itens da contratação, incluindo itens com `retired_at` preenchido;
3. se não existir item, usar `1`;
4. caso contrário, usar `MAX(ordinal) + 1`;
5. inserir o novo item com esse ordinal.

A operação não reutiliza gaps. Itens retirados continuam participando do máximo, preservando identidade ordinal histórica e respeitando a constraint física `UNIQUE (contracting_id, ordinal)`.

O valor inicial `1` é uma convenção técnica da boundary, não uma nova constraint global de positividade. F34 não adiciona `CHECK (ordinal > 0)` e não reinterpreta dados administrativos que eventualmente tenham outra origem.

### Concorrência na mesma contratação

Duas ou mais criações pela mesma boundary na mesma contratação competem pelo lock da mesma linha pai.

- A primeira obtém o lock, calcula o próximo ordinal, insere item + evento e conclui;
- a próxima aguarda o lock;
- ao prosseguir no `READ COMMITTED` usado pelo adapter canônico, recalcula o máximo já comprometido e recebe o ordinal seguinte.

A constraint única continua como backstop, mas a estratégia não depende de retry cego de violação de unicidade para funcionar.

A F35 deve provar essa propriedade com múltiplos writers reais em PostgreSQL 17.

### Concorrência em contratações diferentes

Cada criação bloqueia somente a linha da contratação alvo. Criações em contratações diferentes não usam table lock nem advisory lock global e devem poder avançar independentemente.

Qualquer futura boundary operacional que também insira itens deve respeitar o mesmo lock da contratação pai ou substituir esta decisão por nova ADR. DML administrativo fora das boundaries normais não é parte do contrato de concorrência operacional.

## 6. Atomicidade e auditoria

Uma criação bem-sucedida insere exatamente um item e exatamente um evento na mesma transação.

### Estado do item

O item criado recebe:

- `id = itemId` server-side;
- `team_id` derivado da contratação bloqueada;
- `contracting_id` derivado da contratação bloqueada;
- `ordinal` calculado no banco;
- `description`, `quantity`, `unit` e `catalog_code` conforme payload;
- `created_at = operation_at`;
- `updated_at = operation_at`;
- `retired_at = NULL`.

### Evento

O evento automático usa:

- `event_type = 'item_created'`;
- `team_id` e `contracting_id` derivados da contratação bloqueada;
- `actor_membership_id` derivado do banco;
- `item_id` igual ao item recém-criado;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `field_key = NULL`;
- `old_value = NULL`;
- `new_value = NULL`;
- `note = NULL`;
- `related_identifier_id = NULL`.

Descrição, quantidade, unidade e catálogo permanecem no estado estruturado do item. O evento não duplica esses campos em `old_value`, `new_value` ou `note`.

`contractings.updated_at` não é alterado por item create nesta slice. `DATABASE.md` já define que esse timestamp não é sinônimo automático de última movimentação relevante; a timeline de `contracting_events` registra o fato. Evitar esse update também impede ampliar a nova capability com `UPDATE` na contratação pai.

Se o evento falhar, o insert do item deve ser revertido. Nenhum evento é criado em negação ou falha anterior ao insert do item.

## 7. Resultados externos

A primitive pode distinguir internamente apenas:

- `created`;
- `denied`.

A interface server-only da F35 expõe apenas:

- `created`;
- `not-available` para qualquer negação protegida;
- `unavailable` para falha técnica, configuração, conexão, contexto, cast numérico inválido ou resultado impossível.

A resposta não retorna team, actor, membership, ordinal, item UUID, event UUID, SQL ou detalhe interno. Readback posterior usa o read model protegido.

Não existe fallback para demo ou fixture quando a escrita persistente falha.

## 8. RLS esperada na implementação

A migration F35 deve adicionar somente policies específicas à nova capability.

A policy de `contracting_items FOR INSERT` deve, no mínimo:

- exigir `retired_at IS NULL` por formato da operação;
- exigir que `team_id + contracting_id` correspondam a uma contratação ativa visível para a identidade corrente;
- exigir membership ativa do usuário corrente na equipe alvo;
- exigir exatamente uma membership não revogada na equipe alvo.

A policy de `contracting_events FOR INSERT` deve, no mínimo:

- exigir `event_type = 'item_created'`;
- exigir `item_id IS NOT NULL`;
- exigir `field_key`, `old_value`, `new_value`, `note` e `related_identifier_id` nulos;
- exigir actor membership do usuário corrente na mesma equipe;
- exigir exatamente uma membership não revogada na equipe alvo;
- exigir contratação ativa correspondente;
- exigir que `item_id` referencie o item criado dentro do mesmo `team_id + contracting_id`.

A primitive continua sendo a única forma operacional de escolher `ordinal` e UUIDs. A runtime normal não recebe insert direto.

## 9. Matriz obrigatória da F35

A implementação deve provar em PostgreSQL 17 descartável, além dos gates normais:

1. usuário piloto autorizado cria item + exatamente um evento;
2. team, actor e contracting são derivados do banco;
3. item UUID e event UUID nascem server-side e não existem no input público do adapter;
4. `ordinal` não existe no input do adapter;
5. primeira criação recebe ordinal 1;
6. criações sequenciais recebem ordinais crescentes;
7. gaps existentes não são reutilizados;
8. item retirado continua participando do máximo;
9. múltiplos creates concorrentes na mesma contratação produzem ordinais distintos e contíguos a partir do máximo observado, sem retry cego;
10. creates em contratações diferentes não dependem de lock global;
11. claims ausentes, malformados e desconhecidos falham fechado;
12. usuário desabilitado falha fechado;
13. membership ausente ou revogada falha fechado;
14. segundo membro não revogado na equipe alvo bloqueia, inclusive se seu `app_user` estiver desabilitado;
15. membership adicional do mesmo usuário em outra equipe não bloqueia por si só;
16. cross-team e UUID inexistente são externamente indistinguíveis;
17. contratação arquivada ou cancelada bloqueia;
18. `description = ''`, spaces-only e leading/trailing spaces são preservados;
19. `unit` e `catalogCode` preservam `NULL`, vazio e espaços sem normalização;
20. `quantity = NULL`, zero, negativo e fração tecnicamente válida são persistidos sem regra de negócio inventada;
21. quantidade de alta precisão não passa por `Number` JavaScript e preserva o valor PostgreSQL `numeric`;
22. quantidade não convertível falha sem item/evento e vira somente `unavailable` na boundary;
23. exatamente um `item_created` é criado por criação bem-sucedida;
24. event `item_id` referencia o item correto e actor/team/contracting são coerentes;
25. item e evento compartilham o mesmo `operation_at` nos timestamps definidos;
26. falha forçada do insert de evento reverte o item;
27. negação não cria item nem evento;
28. runtime não possui DML direto de item/evento/contratação;
29. capability não possui LOGIN, SUPERUSER, BYPASSRLS, ownership de tabelas-base ou membership utilizável;
30. capability não consegue atualizar/retirar/reordenar item nem alterar contratação;
31. F26/F29/F32 não ganham item-create authority e a nova capability não ganha authority dessas operações;
32. migrations `0001..0006` permanecem byte-for-byte imutáveis;
33. suites de leitura/RLS/Auth/F24/F26/F29/F32 permanecem verdes;
34. nenhum provider hosted write, secret ou dado real é usado.

## 10. Red-team da decisão

Rejeitados pelo desenho:

- `team_id`, actor, membership, issuer, subject, `ordinal`, item UUID ou event UUID confiados ao browser;
- ordinal vindo do cliente;
- `MAX(ordinal)+1` sem serialização da contratação pai;
- retry cego de unique violation como mecanismo primário de concorrência;
- table lock global para todas as contratações;
- reutilização automática de gap;
- exclusão de item retirado do cálculo do próximo ordinal;
- DML direto pela role runtime;
- ampliação de F26/F29/F32;
- capability com login, privilege escalation, ownership de tabela ou `BYPASSRLS`;
- item criado em contratação cross-team, inexistente, arquivada ou cancelada;
- política global de exactly-one-membership do usuário copiada da F29 para uma row com team conhecido;
- regra de quantidade positiva, unidade obrigatória, catálogo obrigatório, trim ou limite de tamanho sem fonte canônica;
- uso de `Number` JavaScript para `numeric` arbitrário;
- evento não atômico ou sem vínculo ao item;
- update desnecessário de `contractings.updated_at`;
- deduplicação sem chave de negócio aprovada;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real;
- reescrita das migrations aplicadas.

## Consequências

### Positivas

- item create nasce com authority própria e verificável;
- browser não controla scope, actor, UUIDs nem ordem;
- parent-row lock resolve corrida de ordinal sem lock global;
- gaps e ordinais históricos não são reutilizados;
- item e auditoria são inseparáveis;
- quantidade permanece fiel ao tipo `numeric` sem perda por float JS;
- Q-004 e Q-009 continuam explicitamente abertas.

### Custos

- toda criação concorrente na mesma contratação é serializada pela row pai;
- mutações F26/F32 na mesma contratação também podem aguardar esse row lock;
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

A F35 deve implementar exatamente esta boundary, sem ampliar escopo: migration nova, capability própria, primitive, provisioning, adapter server-only, testes unitários/PostgreSQL/concorrência e workflow/regressões aplicáveis.