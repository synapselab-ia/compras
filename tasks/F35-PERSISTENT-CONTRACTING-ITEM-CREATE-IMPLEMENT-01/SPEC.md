# F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01 - Implementar criação persistente mínima de item

**Classe:** T2 - banco, autorização e escrita server-side  
**Estado:** READY após integração da F34  
**Dependências:** ADR-014, ADR-003, ADR-005, ADR-009, F26, F29, F32 e schema `contracting_items`  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

ADR-014 definiu a boundary mínima para adicionar um item a uma contratação existente. Ainda não existe migration, capability, primitive, provisioning ou adapter server-only que materialize essa decisão.

A implementação precisa provar least privilege, autorização pilot-only, ordinal concorrente por contratação e evento atômico sem ampliar capabilities existentes e sem inventar regras de quantidade, unidade, catálogo ou pesquisa de preços.

## Resultado esperado

Ao final da F35, uma camada server-only deve conseguir criar um único `contracting_item` em uma contratação autorizada por primitive PostgreSQL estreita, recebendo somente:

```text
contractingId
description
quantity
unit
catalogCode
```

A boundary gera item UUID e event UUID no servidor, deriva team/actor/membership exclusivamente do contexto confiável e banco, aloca `ordinal` por um allocator técnico escopado à contratação e retorna somente estado sanitizado.

Não existe UI ou Server Action nesta slice.

## Arquitetura obrigatória

### Migration nova

Criar somente nova migration ordenada, prevista como:

`database/migrations/0007_contracting_item_create.sql`

Migrations `0001..0006` permanecem byte-for-byte imutáveis.

A migration deve criar:

- tabela técnica de allocator de ordinal;
- capability dedicada;
- RLS/policies específicas;
- primitive de criação de item;
- revogações/grants mínimos necessários.

### Allocator técnico

Criar tabela interna equivalente a:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
FK (team_id, contracting_id) -> contractings(team_id, id)
```

O nome exato pode variar.

Requisitos:

- é infraestrutura técnica, não entidade de produto;
- não entra no read model normal;
- `ENABLE ROW LEVEL SECURITY` e `FORCE ROW LEVEL SECURITY`;
- grants default-deny;
- runtime normal sem SELECT/INSERT/UPDATE/DELETE direto;
- capability F35 pode somente SELECT/INSERT/UPDATE de `last_ordinal` conforme policies específicas;
- sem DELETE para a capability;
- `last_ordinal` nullable, sem `CHECK` de positividade inventado.

### Capability dedicada

Criar role equivalente a:

`compras_contracting_item_create_owner`

Ela deve ser selada conforme ADR-005/011/012/013:

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

PostgreSQL 17 pode conservar somente a aresta administrativa automática ao principal de migration nas condições já provadas pelo repositório: `ADMIN TRUE`, `SET FALSE`, `INHERIT FALSE`.

### Primitive

Criar função conceitualmente equivalente a:

```text
public.create_contracting_item(
  p_contracting_id uuid,
  p_description text,
  p_quantity numeric,
  p_unit text,
  p_catalog_code text,
  p_item_id uuid,
  p_event_id uuid
) returns text
```

Requisitos:

- `SECURITY DEFINER`;
- `SET search_path = pg_catalog`;
- SQL estático/parametrizado;
- `PUBLIC EXECUTE` revogado;
- runtime recebe somente `EXECUTE` por provisioning separado;
- team, actor, membership, issuer, subject e ordinal não existem na assinatura;
- `p_item_id`/`p_event_id` existem apenas entre adapter server-only e primitive, nunca no contrato público do adapter.

### Provisioning

Criar script separado equivalente a:

`database/provisioning/grant_contracting_item_create_runtime.sql`

O script deve:

- receber explicitamente a role runtime candidata;
- recusar owner/superuser/BYPASSRLS/capability/role insegura pelos mesmos padrões das boundaries existentes;
- conceder somente `EXECUTE` da primitive F35;
- não conceder DML direto nem authority F26/F29/F32 adicional.

## Contrato server-only

Criar adapter server-only, previsto como:

`src/features/contracting-detail/persistent-item-create.ts`

API conceitual:

```text
createPersistentContractingItem({
  contractingId,
  description,
  quantity,
  unit,
  catalogCode
})
```

Tipos:

```text
contractingId: string
description: string
quantity: string | null
unit: string | null
catalogCode: string | null
```

O adapter deve:

- ser importável apenas no servidor;
- reutilizar `withTrustedDatabaseMutationContext`;
- gerar `itemId` e `eventId` server-side em cada tentativa;
- não aceitar overload/opção que permita fornecer esses UUIDs;
- não aceitar team, actor, membership, issuer, subject ou ordinal;
- não usar `Number`, `parseFloat` ou normalização para quantidade;
- passar `quantity` como parâmetro destinado a PostgreSQL `numeric`;
- não trimar `description`, `unit` ou `catalogCode`;
- mapear primitive `created` para `created`;
- mapear primitive `denied` para `not-available`;
- mapear configuração/conexão/cast/overflow/driver/resultado impossível para `unavailable`;
- nunca expor SQL, driver, claims, connection string, UUID interno ou ordinal;
- nunca cair para fixtures/demo.

Resultado público do adapter:

- `created`;
- `not-available`;
- `unavailable`.

## Autorização pilot-only

A primitive segue o guard target-team de F26/F32.

Ordem mínima antes de tocar o allocator:

1. rejeitar argumentos estruturais impossíveis, como `contractingId`, `description`, item UUID ou event UUID nulos;
2. resolver `current_app_user_id()`;
3. localizar a contratação candidata ativa sob RLS por leitura, sem locking clause que exija UPDATE na tabela pai;
4. derivar `team_id` da row autorizada;
5. derivar a membership ativa do usuário nessa equipe;
6. exigir exatamente uma membership `revoked_at IS NULL` na equipe alvo;
7. somente então criar/bloquear a row do allocator.

Após adquirir o lock do allocator, a primitive deve revalidar contratação ativa, identidade/membership e guard pilot-only antes de calcular/inserir.

Segundo membro não revogado na equipe alvo bloqueia inclusive se seu `app_user` estiver desabilitado.

Outra membership ativa do mesmo usuário em equipe diferente não bloqueia por si só.

Cross-team, inexistente, usuário desabilitado, membership ausente/revogada, segundo membro, arquivada e cancelada retornam o mesmo `denied` interno e `not-available` externo.

Q-009 continua aberta.

## Grants e RLS

A capability pode receber somente:

- `USAGE` no schema necessário;
- SELECT mínimo em `app_users` para identity helper;
- SELECT mínimo em `memberships` para guard;
- SELECT mínimo em `contractings` para localizar/revalidar a row alvo;
- zero `UPDATE` em `contractings`;
- SELECT mínimo em `contracting_items` para obter ordinais e validar event policy;
- INSERT coluna-a-coluna em `contracting_items` apenas para `id`, `team_id`, `contracting_id`, `ordinal`, `description`, `quantity`, `unit`, `catalog_code`, `created_at`, `updated_at`;
- INSERT coluna-a-coluna em `contracting_events` apenas para `id`, `team_id`, `contracting_id`, `actor_membership_id`, `event_type`, `occurred_at`, `item_id`, `created_at`;
- SELECT/INSERT e UPDATE somente de `last_ordinal` no allocator técnico;
- EXECUTE somente nos identity helpers necessários.

A capability não recebe `UPDATE` ou `DELETE` em `contracting_items`, `contractings` ou `contracting_events`.

### Policy do allocator

Criar policies específicas para a capability que exijam:

- row `team_id + contracting_id` correspondente a contratação ativa;
- membership do usuário corrente não revogada nessa equipe;
- exatamente uma membership não revogada na equipe alvo;
- update limitado à row do mesmo scope.

Não criar allocator para target negado. Runtime normal não recebe grant direto nessa tabela.

### Policy de item insert

Criar policy específica que exija:

- `retired_at IS NULL`;
- contratação correspondente ativa;
- item `team_id` igual ao team canônico da contratação;
- membership do usuário corrente não revogada nessa equipe;
- exatamente uma membership não revogada na equipe alvo.

### Policy de evento insert

Criar policy específica que exija:

- `event_type = 'item_created'`;
- `item_id IS NOT NULL`;
- `field_key IS NULL`;
- `old_value IS NULL`;
- `new_value IS NULL`;
- `note IS NULL`;
- `related_identifier_id IS NULL`;
- actor membership do usuário corrente na mesma equipe;
- exatamente uma membership não revogada na equipe alvo;
- contratação correspondente ativa;
- item correspondente existente no mesmo `team_id + contracting_id`.

Eventos continuam sem UPDATE/DELETE.

## Ordinal e concorrência

A implementação deve seguir ADR-014 exatamente.

### Algoritmo

Após autorização inicial:

1. `INSERT` da row do allocator para `team_id + contracting_id` com `last_ordinal = NULL`, usando `ON CONFLICT DO NOTHING`;
2. `SELECT ... FOR UPDATE` somente da row do allocator;
3. revalidar contratação ativa e guard pilot-only;
4. obter `MAX(contracting_items.ordinal)` de todos os itens, incluindo retired;
5. obter o maior entre `last_ordinal` e o máximo real, com semântica correta para `NULL`;
6. se ambos forem `NULL`, alocar `1`; caso contrário, alocar `maior + 1`;
7. `UPDATE` do allocator para esse ordinal;
8. inserir item e evento;
9. concluir tudo na mesma transação.

Não receber ordinal do caller. Não reutilizar gaps.

A constraint `UNIQUE (contracting_id, ordinal)` continua como backstop, mas o fluxo normal não pode depender de capturar unique violation e fazer retry cego.

Não usar row locking em `contractings`: PostgreSQL exige privilégio UPDATE para locking clauses, e ADR-014 deliberadamente preserva zero UPDATE da capability sobre a contratação pai.

Concorrência na mesma contratação é serializada pela row do allocator. Contratações diferentes usam rows distintas e não dependem de table lock/advisory lock global.

Se qualquer etapa posterior falhar, inclusive item/evento, o avanço de `last_ordinal` deve ser revertido pela mesma transação.

## Estado e auditoria

Uma criação bem-sucedida deve usar um único `operation_at` de banco para:

- `contracting_items.created_at`;
- `contracting_items.updated_at`;
- `contracting_events.occurred_at`;
- `contracting_events.created_at`.

O item recebe exatamente os valores aprovados e `retired_at = NULL`.

O evento recebe:

```text
event_type = item_created
field_key = NULL
old_value = NULL
new_value = NULL
note = NULL
related_identifier_id = NULL
item_id = item recém-criado
```

`contractings.updated_at` não é alterado.

Falha do evento deve reverter integralmente item e allocator. Negação não cria item, evento ou allocator para target não autorizado.

## Semântica de dados

### Description

`description` é `NOT NULL`, mas não existe regra non-empty.

Devem permanecer válidos e exatos:

- `''`;
- spaces-only;
- leading/trailing spaces.

### Unit e catalogCode

Preservar exatamente:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

Não converter vazio para `NULL`.

### Quantity

`quantity` é `numeric NULL`.

Não impor:

- positivo;
- maior que zero;
- inteiro;
- escala máxima de negócio;
- precisão de negócio;
- vínculo com unidade.

O adapter usa string para evitar float JS. A suite deve provar `NULL`, zero, negativo, fração e alta precisão válida.

Valor textual não convertível para PostgreSQL `numeric` deve resultar em rollback/ausência de item+evento e retorno `unavailable`, sem detalhe do cast.

Overflow de ordinal inteiro também falha como `unavailable`, sem wraparound ou regra nova.

## Testes obrigatórios

### Unitários do adapter

Provar:

- contrato aceita somente os cinco campos definidos;
- item/event UUID são gerados internamente;
- nenhum input consegue fornecer team/actor/membership/issuer/subject/ordinal/UUID interno;
- description/unit/catalogCode não sofrem trim/normalização;
- quantity não passa por `Number`/`parseFloat`;
- `created`, `not-available` e `unavailable` são os únicos resultados externos;
- erro interno é sanitizado;
- modo/configuração sem persistence não vira demo write.

### PostgreSQL

Provar pelo menos:

1. único membro autorizado cria item e um evento;
2. primeira criação sem itens recebe ordinal 1;
3. sequenciais recebem ordinais crescentes;
4. gap não é reutilizado;
5. retired participa do máximo;
6. allocator criado sobre itens preexistentes começa após o maior ordinal real;
7. allocator atrasado é reconciliado pelo máximo real após lock;
8. team/actor/contracting/item são coerentes e derivados;
9. UUIDs do item/evento não alteram scope;
10. claims ausentes/malformados/desconhecidos negam;
11. app_user desabilitado nega;
12. membership ausente/revogada nega;
13. segundo membro não revogado nega, inclusive app_user desabilitado;
14. membership adicional do mesmo usuário em outra equipe não bloqueia a row alvo;
15. cross-team e inexistente são externamente indistinguíveis;
16. archived/cancelled negam antes do allocator;
17. archived/cancelled ou guard alterado enquanto espera allocator é revalidado e nega antes do insert;
18. description vazio/espaços é exato;
19. unit/catalog NULL/vazio/espaços é exato;
20. quantity NULL/zero/negativo/fração/alta precisão válida persiste;
21. exactly one event por create;
22. event failure reverte item e avanço do allocator;
23. denied não cria item/evento/allocator em target não autorizado;
24. `contractings.updated_at` permanece inalterado;
25. capability não possui UPDATE em `contractings`;
26. capability não consegue UPDATE/DELETE/reorder/retire de item;
27. runtime não tem DML direto;
28. F26/F29/F32 não têm authority item-create;
29. nova capability não tem authority F26/F29/F32.

### Concorrência real

Criar teste PostgreSQL/Node que dispare no mínimo 8 writers concorrentes na mesma contratação, todos autorizados pelo mesmo piloto.

Resultado obrigatório:

- 8 `created`;
- 8 itens novos;
- 8 eventos `item_created`;
- ordinais únicos e sequenciais a partir do maior valor anterior/allocator reconciliado;
- nenhum unique violation exposto;
- nenhum retry cego.

Também provar com pelo menos duas contratações diferentes que rows distintas do allocator não criam lock global.

## Preflight adversarial de role/capability

Workflow/testes devem rejeitar:

- capability com LOGIN/SUPERUSER/BYPASSRLS/CREATEROLE/ownership indevido;
- membership utilizável da capability;
- runtime com INSERT/UPDATE/DELETE direto no allocator, `contracting_items`, `contracting_events` ou `contractings`;
- capability com UPDATE em `contractings`;
- capability com UPDATE/DELETE de item/evento;
- `PUBLIC EXECUTE` na primitive;
- `search_path` inseguro;
- SQL dinâmico controlável por caller;
- F26/F29/F32 ampliadas.

## Workflow e regressão

Criar workflow dedicado previsto como:

`.github/workflows/f35-contracting-item-create.yml`

Ele deve executar PostgreSQL 17 descartável, migrations `0001..0007`, provisioning adversarial, matriz SQL e teste real de concorrência.

Antes de promover:

- lint PASS;
- typecheck PASS;
- testes completos PASS;
- build PASS;
- CI database PASS;
- auth-database/F24 PASS;
- F22 Private Preview Preflight PASS;
- F29 Contracting Create PASS;
- F32 Contracting Object Mutation PASS;
- novo F35 workflow PASS.

## Red-team obrigatório

Rejeitar PASS se:

- browser/caller público puder controlar team, actor, membership, issuer, subject, ordinal, item UUID ou event UUID;
- ordinal depender de input do cliente;
- capability precisar de UPDATE em `contractings` para serializar item create;
- allocator for criado antes de autorização do target;
- allocator não revalidar autorização após lock;
- corrida for tratada por retry cego de unique violation;
- table lock/advisory lock global serializar contratações diferentes;
- gaps forem reutilizados;
- retired for ignorado no maior ordinal;
- runtime ganhar DML direto;
- capability ganhar UPDATE/DELETE de item/evento ou authority das outras primitives;
- F26/F29/F32 forem ampliadas;
- Q-004/Q-009 forem resolvidas implicitamente;
- quantidade positiva/unidade obrigatória/catálogo obrigatório/trim/limite de tamanho forem inventados;
- quantidade passar por JS Number;
- item sobreviver à falha do evento;
- allocator avançar após rollback do item/evento;
- evento existir sem item;
- parent `updated_at` for alterado;
- falha protegida cair para demo;
- migrations `0001..0006` forem alteradas;
- provider hosted, secret ou dado real forem usados.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` sob seu `resume_when`;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- migrations aplicadas são imutáveis;
- demo continua sem escrita operacional.

## Fora do escopo

- UI ou Server Action de item;
- editar/reordenar/retirar/restaurar item;
- idempotência semântica/deduplicação de item;
- pesquisa de preços/evidências/Q-004;
- política multiusuário/Q-009;
- provider hosted;
- dado real.

## Critério de encerramento

F35 fecha quando a criação mínima de item estiver implementada e provada em PostgreSQL 17 com capability dedicada, allocator técnico por contratação, auditoria atômica, adapter server-only sanitizado e todas as regressões verdes, sem UI e sem ampliar as capabilities anteriores.