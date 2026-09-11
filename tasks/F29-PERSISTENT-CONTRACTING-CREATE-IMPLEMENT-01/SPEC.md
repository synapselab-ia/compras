# F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01 — Implementar boundary de criação persistente mínima

**Classe:** T1 — feature normal, com impacto T2 — autorização/banco  
**Estado:** COMPLETED / PASS  
**Dependências:** F28, ADR-003, ADR-005, ADR-009, ADR-011 e ADR-012  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Resultado

F29 materializou a ADR-012 sem adicionar Server Action/UI de cadastro.

Foram implementados:

- `database/migrations/0005_contracting_create.sql`;
- `database/provisioning/grant_contracting_create_runtime.sql`;
- `database/tests/contracting_create.sql`;
- `src/features/contracting-create/persistent-create.ts`;
- testes unitários e PostgreSQL de concorrência;
- workflow dedicado `.github/workflows/f29-contracting-create.yml`.

`0001..0004` permaneceram imutáveis. Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## Boundary implementada

### Capability e least privilege

A criação possui owner técnico próprio `compras_contracting_create_owner`, separado da F26.

A migration valida que a role é:

- `NOLOGIN`;
- `NOINHERIT`;
- não superuser;
- sem `BYPASSRLS`, `CREATEDB`, `CREATEROLE` ou replication;
- sem `rolconfig`;
- sem ownership de tabelas-base;
- sem membership utilizável.

O lifecycle segue ADR-005 e admite somente a aresta administrativa PostgreSQL 17 permitida para o migrator. O owner não é credencial operacional.

A primitive `public.create_contracting_minimal(uuid,text,uuid)` é `SECURITY DEFINER`, possui `search_path = pg_catalog`, `PUBLIC EXECUTE` revogado e grants coluna-a-coluna.

O runtime normal continua sem `INSERT`/`UPDATE`/`DELETE` direto. `grant_contracting_create_runtime.sql` concede somente `EXECUTE` explicitamente e remove toda aresta temporária de `SET ROLE` antes do commit.

Auth/read-only runtimes não recebem essa capability.

### Payload e confiança

A interface server-only aceita semanticamente somente:

```text
contractingId
object
```

O candidate UUID é preparado no servidor por `preparePersistentContractingCandidateId()`. O UUID do evento é gerado por `randomUUID()` dentro do adapter e não pode vir do browser.

Team, actor, membership, issuer, subject e `created_by_membership_id` não são argumentos da primitive nem dados confiáveis do adapter. Eles são derivados exclusivamente da identidade Better Auth validada + contexto PostgreSQL LOCAL + banco.

`object` é preservado exatamente. Não foi introduzido trim, tamanho máximo ou regra non-empty; string vazia continua distinta e permitida pelo contrato físico atual.

### Regra pilot-only

A primitive só cria quando:

1. `current_app_user_id()` resolve para usuário interno ativo;
2. esse usuário possui exatamente uma membership não revogada em todo o banco;
3. a equipe derivada existe e não está arquivada;
4. a equipe possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia mesmo quando o `app_user` correspondente está desabilitado. Múltiplas memberships do próprio usuário bloqueiam por ambiguidade. Q-009 permanece aberta.

### Estado inicial e evento

Criação nova persiste somente:

```text
id
team_id
object
created_by_membership_id
created_at
updated_at
```

Responsável, stage, status, waiting, `next_action`, archived/cancelled permanecem `NULL`.

Na mesma transação nasce exatamente um evento `contracting_created`, com team/actor/contracting derivados. `contractings.created_at`, `contractings.updated_at`, `event.occurred_at` e `event.created_at` usam o mesmo `operation_at` do banco.

Falha do evento reverte a nova contratação integralmente.

### Idempotência

O candidate UUID é a chave de idempotência não secreta da solicitação preparada.

Após a autorização corrente:

- criação inédita → `created`;
- mesmo UUID + mesmo team derivado + mesmo creator derivado + mesmo `object` → `already-created`;
- mismatch ou colisão cross-team → `denied` genérico.

Campos mutáveis posteriores não participam do replay.

O teste concorrente com oito writers do mesmo candidate prova exatamente:

- 1 `created`;
- 7 `already-created`;
- 1 row;
- 1 evento.

## Matriz adversarial comprovada

Os testes PostgreSQL/TypeScript cobrem:

- claims ausentes/malformados;
- identidade desconhecida;
- usuário desabilitado;
- zero membership ativa;
- membership revogada;
- usuário com múltiplas memberships;
- equipe arquivada;
- segundo membro não revogado, inclusive usuário desabilitado;
- derivação de team/actor/created_by;
- estado inicial esparso;
- evento único e timestamps atômicos;
- replay sequencial;
- mismatch de `object`;
- colisão cross-team;
- falha forçada de evento com rollback da row;
- concorrência de oito writers;
- runtime sem DML direto;
- owner sem privilégios de UPDATE/DELETE ou colunas extras de INSERT;
- capability F29 sem `EXECUTE` F26;
- Auth/read-only runtimes sem `EXECUTE` F29;
- PUBLIC EXECUTE revogado;
- owner/search_path/static SQL seguros;
- rejection preflight de owner LOGIN, `BYPASSRLS` e membership SET-capable;
- novo capability owner rejeitado como runtime operacional normal.

Campos extras forjados no adapter — team, actor, membership, created_by, issuer, subject e eventId — não atravessam a boundary.

## Red-team

A revisão integral não encontrou mecanismo que permita:

- browser escolher autoridade de team/actor/created_by;
- escopo ambíguo criar;
- segundo membro ampliar permissão;
- runtime obter DML direto;
- F29 ampliar F26;
- F29 atualizar `next_action` ou linhas existentes;
- criação preencher stage/status/responsável/waiting/next_action;
- replay exato criar segundo evento;
- mismatch/cross-team virar sucesso;
- falha protegida cair para demo;
- erro técnico ser devolvido pelo adapter.

O diff contém somente valores CI claramente fictícios/localhost para PostgreSQL descartável. Não contém credencial/provider real, dado interno ou hosted write.

## Verificação funcional

Primeira execução F29 no head `b801adccf16bb8717a95b5228765c7f86fd2b723`:

- CI `34636645870`: PASS;
- F22 Private Preview Preflight `34636645825`: PASS;
- F29 Contracting Create `34636645932`: FAIL por erro sintático no postflight da migration (`pg_catalog.position(...)`).

A falha foi corrigida sem reduzir enforcement. O head funcional `d35edbd54e516de9c2eac943d3c854a30ed729a9` ficou integralmente verde:

- CI `34637119318`: PASS;
- F22 Private Preview Preflight `34637119381`: PASS;
- F29 Contracting Create `34637119319`: PASS, incluindo preflight adversarial, migration 0005, provisionamento, matriz SQL e concorrência PostgreSQL 17.

Os commits documentais de checkpoint posteriores devem manter os mesmos gates verdes antes do merge.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua não privilegiado e sem CRUD amplo;
- migrations `0001..0004` não foram reescritas;
- Server Action/UI de criação permanecem fora de F29.

## Próxima ação

A única próxima ação é `F30-PERSISTENT-CONTRACTING-CREATE-UI-01`, que deve tornar a boundary F29 utilizável pela aplicação com candidate UUID server-side, Server Action estreita e UI mínima, mantendo demo read-only e sem ampliar o payload.

## Critério de encerramento

F29 está encerrada porque a boundary ADR-012 foi implementada e comprovada em PostgreSQL 17 contra least privilege, autorização pilot-only, RLS, atomicidade, rollback, replay e concorrência, com regressões F22/F26/Auth verdes.
