# F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01 — Implementar boundary de criação persistente mínima

**Classe:** T1 — feature normal, com impacto T2 — autorização/banco  
**Estado:** PLANNED / NEXT  
**Dependências:** F28, ADR-003, ADR-005, ADR-009, ADR-011 e ADR-012  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A ADR-012 fechou o desenho da primeira criação persistente de `contractings`, mas nenhuma migration, primitive ou interface server-side de criação existe ainda.

A próxima slice deve materializar somente essa boundary, provar sua segurança/idempotência em PostgreSQL 17 descartável e manter Server Action/UI de cadastro fora do escopo.

## Objetivo

Implementar a capability pilot-only `create contracting` definida na ADR-012, mantendo:

- runtime normal sem DML direto;
- team/actor/created_by derivados exclusivamente da identidade confiável + banco;
- payload mínimo `contractingId + object`;
- estado inicial esparso sem stage/status/responsável/waiting/next_action inventados;
- evento `contracting_created` atômico;
- replay/double-submit idempotente pelo UUID estável da contratação;
- Q-001/Q-002/Q-006/Q-009 abertas.

## Entregas obrigatórias

### 1. Migration nova

Criar `database/migrations/0005_contracting_create.sql` sem modificar `0001..0004`.

A migration deve criar/validar role técnica equivalente a `compras_contracting_create_owner` com:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- `rolconfig IS NULL`;
- sem ownership de tabelas-base;
- sem membership utilizável.

O lifecycle deve seguir ADR-005 e tolerar somente a aresta administrativa automática PostgreSQL 17 para o principal de migration nas condições `ADMIN TRUE`, `SET FALSE`, `INHERIT FALSE`.

A migration deve criar uma primitive conceitualmente equivalente a:

```text
public.create_contracting_minimal(
  p_contracting_id uuid,
  p_object text,
  p_event_id uuid
) -> text
```

Requisitos:

- `SECURITY DEFINER`;
- `search_path = pg_catalog` fixo;
- SQL estático;
- `PUBLIC EXECUTE` revogado;
- owner técnico dedicado;
- nenhum argumento de team/actor/membership/issuer/subject/created_by;
- nenhuma dependência de provider hosted.

### 2. Grants e RLS mínimos

A capability recebe somente o necessário para:

- resolver identidade atual;
- ler memberships para derivar a única membership ativa do usuário e contar o guard da equipe;
- verificar a equipe e `archived_at`;
- verificar candidate `contracting_id` para idempotência;
- inserir apenas colunas aprovadas da contratação;
- inserir apenas colunas aprovadas do evento;
- executar helpers de identidade necessários.

O `INSERT` em `contractings` deve ser coluna-a-coluna e limitado a:

```text
id
team_id
object
created_by_membership_id
created_at
updated_at
```

O `INSERT` em `contracting_events` deve ser coluna-a-coluna e limitado a:

```text
id
team_id
contracting_id
actor_membership_id
event_type
occurred_at
created_at
```

A capability não pode receber `UPDATE`/`DELETE` de `contractings` nem `UPDATE`/`DELETE` de eventos.

Policies específicas devem manter `FORCE RLS` autoritativo e impedir:

- team divergente da membership derivada;
- actor/created_by divergente;
- preenchimento de colunas fora do formato aprovado;
- evento diferente de `contracting_created` pela capability.

### 3. Regra pilot-only de criação

A primitive só cria quando:

1. `current_app_user_id()` resolve;
2. o usuário possui exatamente uma membership `revoked_at IS NULL` em todo o banco;
3. a equipe derivada existe e `archived_at IS NULL`;
4. a equipe possui exatamente uma membership `revoked_at IS NULL`.

Toda segunda membership não revogada na equipe conta para o bloqueio, ainda que o `app_user` correspondente esteja desabilitado.

Múltiplas memberships não revogadas do próprio usuário também bloqueiam a operação por escopo ambíguo.

### 4. Estado e evento atômicos

Em criação nova:

- `object` é preservado exatamente;
- `team_id` e `created_by_membership_id` vêm do banco;
- `created_at` e `updated_at` usam o mesmo `operation_at`;
- responsible/stage/status/waiting/next_action/archived/cancelled ficam `NULL`;
- exatamente um evento `contracting_created` é inserido;
- actor/team/contracting do evento são derivados da operação/banco;
- `occurred_at` e `event.created_at` usam o mesmo `operation_at` da contratação;
- `field_key`, `old_value`, `new_value`, `note`, `related_identifier_id` e `item_id` ficam `NULL`.

Falha do evento deve reverter o `INSERT` da contratação.

### 5. Idempotência e concorrência

O UUID da contratação funciona como identidade estável e idempotency key da solicitação preparada.

A primitive deve retornar estado equivalente a `already-created` somente quando, após a autorização corrente, uma linha já existente com o candidate UUID possuir exatamente:

- `team_id` derivado;
- `created_by_membership_id` derivado;
- `object` igual ao solicitado.

Campos mutáveis posteriores não entram na comparação.

Se a correspondência não puder ser provada, retornar `denied`/estado equivalente genérico.

O caso concorrente com múltiplas chamadas usando o mesmo UUID deve provar:

- exatamente uma contratação;
- exatamente um evento de criação;
- exatamente um resultado `created`;
- demais resultados `already-created`;
- nenhuma duplicação silenciosa.

Uma corrida de primary key pode ser tratada por subtransação/`unique_violation` + releitura autorizada ou mecanismo PostgreSQL equivalente, sem converter colisão não equivalente em sucesso.

### 6. Provisionamento separado

Criar `database/provisioning/grant_contracting_create_runtime.sql` seguindo o padrão de F26.

O asset deve:

- exigir nome explícito da role runtime;
- rejeitar runtime owner/superuser/`BYPASSRLS`/`CREATEROLE`/atributos inseguros;
- conceder somente `EXECUTE` da primitive de criação;
- não conceder DML direto;
- usar lifecycle transacional que não deixe membership `SET ROLE` persistente para a capability;
- falhar fechado em estado inesperado.

### 7. Interface server-only

Criar módulo server-only de criação, preferencialmente em `src/features/contracting-create/` ou estrutura equivalente, com interface conceitual:

```text
createPersistentContracting({ contractingId, object })
```

A interface:

- valida `contractingId` como UUID candidato;
- exige `object` como string, sem trim/limite/regra non-empty inventada;
- gera `eventId` por `randomUUID()` no servidor;
- chama somente a primitive parametrizada;
- reutiliza `withTrustedDatabaseMutationContext`;
- nunca aceita team/actor/membership/issuer/subject/created_by/eventId externos;
- mapeia `created` e `already-created` diretamente;
- mapeia `denied` para `not-available`;
- mapeia falha técnica inesperada para `unavailable`;
- não possui demo fallback;
- não loga payload, claims, connection string ou erro sensível.

Também criar helper server-only para gerar o candidate UUID que uma futura UI poderá preparar antes da submissão. Esse UUID não é token de autorização.

### 8. Testes PostgreSQL/adversariais

Criar matriz dedicada, por exemplo `database/tests/contracting_create.sql`, e testes TypeScript necessários.

Provar no mínimo:

1. sole user + sole team membership → `created`;
2. row possui team/created_by derivados e `object` exato;
3. stage/status/responsible/waiting/next_action/archived/cancelled = `NULL`;
4. exatamente um evento `contracting_created` com actor derivado e campos auxiliares nulos;
5. quatro timestamps da criação usam o mesmo instante;
6. claims ausentes/malformados → deny;
7. identidade desconhecida → deny;
8. usuário desabilitado → deny;
9. zero membership ativa → deny;
10. membership revogada → deny;
11. usuário com múltiplas memberships não revogadas → deny;
12. equipe arquivada → deny;
13. segundo membro não revogado → deny, inclusive se seu usuário estiver desabilitado;
14. replay sequencial idêntico → `already-created`, sem novo evento;
15. replay com mesmo UUID e `object` diferente → deny;
16. candidate UUID existente cross-team → deny externamente indistinguível;
17. corrida de pelo menos 8 writers do mesmo candidate → 1 `created`, 7 `already-created`, 1 row, 1 event;
18. falha forçada de evento → zero row nova;
19. runtime sem DML direto;
20. capability sem privileges de UPDATE/DELETE e sem colunas de INSERT não aprovadas;
21. capability F26 continua sem `INSERT` de criação;
22. capability de criação não recebe UPDATE de `next_action` nem `EXECUTE` F26 por conveniência;
23. Auth/read-only runtimes não recebem a nova `EXECUTE`;
24. `PUBLIC EXECUTE` revogado;
25. owner/search_path/static SQL/postflight seguros;
26. `0001..0004` imutáveis;
27. apenas dados fictícios.

### 9. CI/regressão

Atualizar os workflows apenas no necessário para provar F29 em PostgreSQL 17 descartável.

Gates obrigatórios:

- lint PASS;
- typecheck PASS;
- testes PASS;
- build PASS;
- CI database PASS;
- F26 mutation/RLS/concorrência continua PASS;
- Auth/F24 continua PASS;
- F22 Private Preview Preflight continua PASS;
- diff integral sem secrets/dados reais/provider hosted write.

## Red-team obrigatório

Rejeitar PASS se:

- browser/API de criação conseguir escolher team/actor/membership/issuer/subject/created_by confiável;
- usuário com >1 membership ativa conseguir criar;
- equipe com >1 membership não revogada conseguir criar;
- equipe arquivada aceitar nova contratação;
- runtime receber `INSERT` direto;
- capability de criação ganhar `UPDATE` de linhas existentes;
- F26 ganhar novos grants de criação;
- `next_action`, stage, status, responsible ou waiting forem preenchidos automaticamente;
- `object` for trimado/limitado por regra não aprovada;
- criação existir sem evento;
- replay idêntico criar segundo evento;
- collision mismatch virar `already-created`;
- cross-team UUID revelar existência;
- erro interno/secrets aparecer em retorno/log;
- migrations aplicadas forem reescritas;
- provider hosted ou dado real for usado.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS permanece autoritativa;
- runtime normal permanece não privilegiado e sem CRUD amplo;
- ADR-012 é a fonte da decisão;
- `0001..0004` são imutáveis;
- F27 continua sendo a única UI de write persistente integrada durante F29.

## Fora do escopo

- Server Action/UI de cadastro;
- adicionar `next_action` no payload de criação;
- stage/status/responsável/waiting;
- itens e identificadores relacionados;
- arquivamento/cancelamento;
- edição de `object`;
- política multiusuário;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F29 fecha quando a boundary ADR-012 estiver implementada e provada em PostgreSQL 17 real contra autorização, least privilege, atomicidade, rollback e idempotência concorrente, com regressões F22/F26/Auth verdes e exatamente uma nova `NEXT_ACTION` para tornar o cadastro utilizável pela aplicação.
