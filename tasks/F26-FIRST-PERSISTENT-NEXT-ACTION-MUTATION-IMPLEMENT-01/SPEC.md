# F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01 — Implementar primeira mutação persistente de próxima ação

**Classe:** T1 — feature normal, com impacto T2 — banco/segurança  
**Estado:** COMPLETED / PASS  
**Dependências:** F25, ADR-003, ADR-005, ADR-009 e ADR-011  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A ADR-011 definiu a fronteira da primeira escrita operacional persistente. F26 deveria implementar somente a alteração de `contractings.next_action`, mantendo Q-009 aberta, runtime sem DML direto e histórico atômico.

## Resultado entregue

F26 implementou a primeira mutação persistente do domínio por capability PostgreSQL estreita.

Entregas principais:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- matriz adversarial `database/tests/next_action_mutation.sql`;
- adapter `withTrustedDatabaseMutationContext`;
- interface server-side `mutatePersistentContractingNextAction`;
- testes unitários, de boundary, PostgreSQL 17 e concorrência real;
- regressão F22 atualizada para provar que runtimes Auth/read-only não herdam `EXECUTE` da mutação.

Nenhum provider hosted, secret, environment variable ou dado real foi criado/alterado.

## Boundary implementada

### Capability owner

A migration cria/valida `compras_next_action_mutation_owner` como role técnica:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem ownership de tabelas-base;
- sem membership utilizável.

O lifecycle segue ADR-005 e tolera somente a aresta administrativa automática do PostgreSQL 17 ao principal de migration nas condições `ADMIN TRUE`, `SET FALSE`, `INHERIT FALSE`.

### Grants mínimos

A capability recebe somente o necessário para:

- resolver a identidade atual;
- verificar memberships;
- localizar e bloquear a contratação;
- atualizar apenas `contractings.next_action` e `updated_at`;
- inserir apenas as colunas necessárias de `contracting_events`;
- executar helpers de identidade.

A role runtime continua sem `UPDATE`/`INSERT` direto nas tabelas protegidas.

`EXECUTE` é concedido ao runtime por asset de provisionamento separado da migration. O provisionamento cria uma aresta `SET ROLE` apenas dentro da mesma transação, executa o grant como owner da função e revoga a aresta antes de `COMMIT`; qualquer falha reverte o estado inteiro. O script falha fechado quando `runtime_role` não é informado ou apresenta atributos/grants inseguros.

### Primitive

A função implementada é:

```text
public.mutate_contracting_next_action(
  p_contracting_id uuid,
  p_expected_next_action text,
  p_new_next_action text,
  p_event_id uuid
)
```

Propriedades provadas:

- `SECURITY DEFINER`;
- `search_path = pg_catalog` fixo;
- SQL estático;
- `PUBLIC EXECUTE` revogado;
- owner técnico selado;
- nenhum `team_id`, actor, membership, issuer ou subject recebido como argumento;
- `NULL` permanece suportado;
- sem trim, limite de tamanho ou regra non-null inventada.

## Autorização pilot-only

A primitive deriva `current_app_user_id()` do contexto LOCAL `iss/sub` e somente autoriza quando:

- identidade interna existe e está ativa;
- contratação existe no escopo autorizado;
- contratação não está arquivada/cancelada;
- usuário possui membership não revogada na equipe;
- essa é a única membership `revoked_at IS NULL` da equipe.

Uma segunda membership não revogada bloqueia a escrita mesmo se o usuário correspondente estiver desabilitado. Q-009 continua aberta.

Inexistente, cross-team, identidade desconhecida/desabilitada, sem membership, membership revogada, equipe multi-member, arquivado e cancelado resultam em negação genérica antes de semântica de conflito/no-op.

## Concorrência

A primitive combina:

1. `SELECT ... FOR UPDATE` sobre a contratação autorizada;
2. comparação null-safe do valor persistido com `p_expected_next_action`.

O teste PostgreSQL concorrente executa oito writers simultâneos com o mesmo expected antigo e prova exatamente:

- 1 resultado `updated`;
- 7 resultados `conflict`;
- 1 valor final;
- 1 evento correspondente.

Não foi criada coluna de versão prematura.

## Atomicidade e histórico

Em mudança real:

- `next_action` é atualizado;
- `updated_at` recebe o instante da operação;
- exatamente um evento `next_action_changed` é inserido;
- `field_key = 'next_action'`;
- `old_value`/`new_value` refletem a transição;
- actor/team/contracting são derivados do banco;
- `updated_at`, `occurred_at` e `created_at` usam o mesmo instante;
- `note`, `related_identifier_id` e `item_id` permanecem nulos.

Falha forçada do `INSERT` do evento reverte o update. No-op retorna `unchanged`, não altera timestamp e não cria evento. Stale expected retorna `conflict`, sem update/evento. Eventos permanecem append-only para runtime/capability.

## Adapter server-side

`withTrustedDatabaseMutationContext` reutiliza a boundary segura do adapter de leitura:

- valida identidade Better Auth antes da operação protegida;
- valida `DATABASE_URL` server-only;
- rejeita principal administrativo/capability inseguro;
- abre `BEGIN` normal;
- estabelece somente `iss/sub` via `set_config(..., true)`;
- executa operação parametrizada;
- `COMMIT` em sucesso;
- `ROLLBACK` em falha;
- destrói conexão/pool de estado incerto;
- sanitiza falha externa.

`mutatePersistentContractingNextAction` aceita somente:

- candidate contracting UUID;
- expected `next_action`;
- novo `next_action`.

O UUID do evento nasce no servidor por `randomUUID()`. Campos forjados de team/actor/membership/subject/event UUID não atravessam a chamada SQL.

## Red-team executado

Foram rejeitados/provados:

- capability com `LOGIN`;
- capability com `BYPASSRLS`;
- capability com grantee capaz de `SET ROLE`/herdar;
- runtime com DML direto;
- capability alterando colunas operacionais fora de `next_action`/`updated_at`;
- `UPDATE`/`DELETE` de eventos;
- `PUBLIC EXECUTE` acidental;
- `SECURITY DEFINER` com owner/search path incorretos ou SQL dinâmico;
- claims ausentes/malformados;
- identidade desconhecida/desabilitada;
- membership ausente/revogada;
- segundo membro ativo;
- cross-team UUID e UUID inexistente;
- arquivado/cancelado;
- stale write;
- no-op com evento falso;
- falha de evento sem rollback do update;
- race com mais de um winner/evento;
- Auth/read-only runtime herdando mutation `EXECUTE`;
- fallback protegido para demo;
- dado real/provider hosted write.

O primeiro CI revelou dois defeitos de harness/provisionamento sem redução de segurança: o migrator já não podia conceder `EXECUTE` depois da transferência de ownership, e a matriz SQL usava `GROUP BY true` inválido em PostgreSQL 17. Ambos foram corrigidos preservando as fronteiras; a execução final ficou integralmente verde.

## Verificação final da PR

Head funcional verificado antes do checkpoint documental: `ca670b05cdc2f0c80b520f0573c05032c4a73cc6`.

Gates executados:

- CI `34605291444`: PASS;
  - `verify`: PASS — lint, typecheck, testes e build;
  - `database`: PASS — migrations/RLS/F26 + teste concorrente PostgreSQL;
  - `auth-database`: PASS — Auth/F24 boundaries;
- F22 Private Preview Preflight `34605291428`: PASS.

Após os commits de checkpoint, os mesmos gates devem permanecer verdes antes do merge.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-009 permanece aberta;
- autenticação não é autorização;
- RLS permanece autoritativa;
- estado e evento são atômicos;
- eventos continuam append-only;
- sem CRUD amplo;
- `0001..0003` não foram reescritas;
- runtime normal permanece não privilegiado.

## Fora do escopo preservado

- permitir segundo membro editar;
- definir perfis/papéis multiusuário;
- alterar stage/status/responsável/aguardando;
- mutação de itens/identificadores;
- criar contratação;
- UI de edição;
- provider hosted;
- retomar F21;
- dado real;
- Data API pública.

## Próxima ação

A implementação de banco/aplicação está concluída, mas a tela de detalhe continua somente leitura. A única próxima ação é `F27-PERSISTENT-NEXT-ACTION-DETAIL-UI-01`, que deve tornar apenas esta mutação utilizável pela jornada persistente sem abrir nova autoridade.

## Critério de encerramento

F26 está encerrada porque a primeira mutação persistente de `next_action` foi implementada por capability estreita e provada em PostgreSQL 17 real contra autorização, atomicidade, rollback e concorrência adversarial, com regressões verdes e uma única nova `NEXT_ACTION` canônica.
