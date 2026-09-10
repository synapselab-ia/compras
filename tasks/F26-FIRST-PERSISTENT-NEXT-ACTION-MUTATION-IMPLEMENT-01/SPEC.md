# F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01 — Implementar primeira mutação persistente de próxima ação

**Classe:** T1 — feature normal, com impacto T2 — banco/segurança  
**Estado:** PLANNED / NEXT  
**Dependências:** F25, ADR-003, ADR-005, ADR-009 e ADR-011  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A ADR-011 definiu a fronteira da primeira escrita operacional persistente. O sistema ainda é read-only no domínio normal e não existe capability executável para alterar `contractings.next_action` com histórico atômico.

F26 deve implementar somente essa mutação, mantendo Q-009 aberta e a autorização limitada ao piloto individual.

## Resultado esperado

Entregar uma implementação que:

1. cria migration nova e imutável para a capability de `next_action`;
2. mantém a role runtime sem DML direto nas tabelas protegidas;
3. autoriza somente a identidade corrente quando ela possui a única membership ativa da equipe alvo;
4. falha fechada se existir segundo membro ativo;
5. não aceita `team_id`, actor ou membership do browser como fonte confiável;
6. atualiza `contractings.next_action` e `updated_at` junto com exatamente um `contracting_events` na mesma transação;
7. impede lost update por lock + precondição otimista do valor anterior;
8. trata no-op sem produzir evento/timestamp falso;
9. mantém eventos append-only;
10. preserva todas as fronteiras de Auth/RLS/leitura existentes.

## Implementação obrigatória

### 1. Migration nova

Criar nova migration do domínio, sem alterar `0001`, `0002` ou `0003`.

A migration deve criar uma role técnica equivalente a `compras_next_action_mutation_owner` e uma primitive específica de alteração de `next_action`.

A role capability deve ser:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem ownership de tabelas-base;
- sem membership utilizável em role privilegiada.

O lifecycle de criação/ownership deve aplicar a propriedade de segurança da ADR-005, inclusive em PostgreSQL 17 com principal de migration não-superuser/`CREATEROLE`.

### 2. Grants mínimos

A capability pode receber somente o estritamente necessário para:

- resolver identidade corrente;
- verificar memberships do escopo;
- localizar/lockar a contratação;
- atualizar somente `contractings.next_action` e `contractings.updated_at`;
- inserir somente as colunas necessárias em `contracting_events`;
- executar os helpers de identidade necessários.

A role runtime de domínio recebe somente `EXECUTE` na primitive nova, além dos grants já existentes de leitura.

Proibido dar à role runtime `UPDATE`/`INSERT` direto em `contractings` ou `contracting_events`.

### 3. Primitive específica

Implementar função equivalente a:

```text
mutate_contracting_next_action(
  p_contracting_id uuid,
  p_expected_next_action text,
  p_new_next_action text,
  p_event_id uuid
)
```

Requisitos:

- `SECURITY DEFINER`;
- `search_path` fixo e seguro;
- SQL estático/parametrizado;
- nenhum `team_id`, actor, membership, issuer ou subject como argumento;
- `p_event_id` é fornecido somente pelo servidor confiável;
- não criar regras de trim/tamanho/non-null que não existam no modelo atual;
- `NULL` continua valor suportado para `next_action`.

### 4. Autorização pilot-only

A primitive deve derivar `current_app_user_id()` do contexto de transação e autorizar somente quando:

- usuário interno existe e está ativo;
- alvo existe e pertence a escopo autorizado;
- alvo não está arquivado/cancelado;
- usuário corrente possui membership não revogada na equipe;
- existe exatamente uma membership `revoked_at IS NULL` na equipe alvo.

Uma segunda membership não revogada bloqueia a mutação, mesmo se o usuário dessa membership estiver desabilitado. Q-009 não é resolvida nem inferida.

### 5. Concorrência

A primitive deve:

1. obter lock de linha em `contractings` com `FOR UPDATE` ou equivalente;
2. comparar null-safe o valor atual de `next_action` com `p_expected_next_action`;
3. retornar `conflict` sem update/evento quando a precondição estiver stale.

Não adicionar coluna de versão apenas para esta slice.

Sob duas chamadas concorrentes com o mesmo expected antigo, exatamente uma pode atualizar e criar evento.

### 6. Atomicidade e evento

Em mudança real:

- usar um único timestamp de banco para `updated_at`, `occurred_at` e `created_at`;
- atualizar `next_action`;
- criar exatamente um evento com:
  - `event_type = 'next_action_changed'`;
  - `field_key = 'next_action'`;
  - `old_value` anterior;
  - `new_value` novo;
  - `actor_membership_id` derivado;
  - `team_id` e `contracting_id` derivados da linha;
  - `note`, `related_identifier_id`, `item_id` nulos;
- qualquer falha do insert do evento deve reverter o update.

A capability não recebe `UPDATE`/`DELETE` de `contracting_events`.

### 7. No-op

Se expected estiver atual e o novo valor for null-safe igual ao atual:

- retornar `unchanged`;
- não alterar `updated_at`;
- não inserir evento.

### 8. Adapter de escrita server-side

Criar adapter sibling de `withTrustedDatabaseContext`, equivalente a `withTrustedDatabaseMutationContext`.

Requisitos:

- reutilizar os mesmos safety checks de conexão/role sempre que possível;
- validar identidade Better Auth antes de abrir operação protegida;
- `BEGIN` normal, não read-only;
- contexto `iss/sub` estabelecido com `set_config(..., true)`;
- role runtime não privilegiada;
- `COMMIT` apenas após operação completa;
- `ROLLBACK` em falha;
- conexão/pool incerto não é reutilizado;
- falha externa é sanitizada e mapeada para indisponibilidade;
- sem demo fallback.

### 9. Camada de aplicação

Criar a menor interface server-side necessária para chamar a primitive.

O browser/form pode fornecer somente:

- ID candidato da contratação;
- expected `next_action` observado;
- novo `next_action`.

O event UUID deve ser criado no servidor confiável.

Não implementar mutações de stage/status/responsável/waiting nesta work unit.

Estados externos devem preservar a decisão ADR-011:

- sucesso de alteração;
- unchanged;
- conflict somente após autorização;
- recurso não disponível/sem autorização de forma genérica;
- unavailable em falha técnica.

UUID de outra equipe e UUID inexistente não podem criar side channel de existência.

## Testes obrigatórios

### Unitários / adapter

- identidade ausente falha antes de banco;
- configuração inválida falha fechada;
- role owner/superuser/BYPASSRLS/capability como runtime é rejeitada;
- transaction context contém apenas `iss/sub` e é LOCAL;
- adapter de escrita usa `BEGIN`, não `BEGIN READ ONLY`;
- falha executa rollback e não vaza erro/connection string;
- event UUID nasce no servidor, não do input do browser;
- team/actor/membership não são aceitos como parâmetros confiáveis.

### PostgreSQL 17 efêmero

- migration nova aplica após `0001..0003`;
- capability owner tem atributos seguros e nenhum membership utilizável;
- capability não é owner de tabelas-base;
- runtime não tem `UPDATE`/`INSERT` direto;
- runtime consegue somente `EXECUTE` da primitive prevista;
- único membro autorizado atualiza `next_action` e `updated_at`;
- exatamente um evento correto é criado;
- actor/team/contracting são derivados corretamente;
- no-op não altera timestamp nem cria evento;
- missing/malformed claims -> deny/no mutation;
- unknown/disabled app_user -> deny/no mutation;
- sem membership/revogada -> deny/no mutation;
- cross-team UUID -> deny/no mutation;
- UUID inexistente -> mesmo resultado externo de cross-team;
- segundo membro ativo -> deny/no mutation;
- archived/cancelled -> deny/no mutation;
- stale expected -> conflict/no mutation/event;
- concorrência real com mesmo expected -> exatamente um winner e um evento;
- falha forçada no insert do evento -> update revertido;
- capability não altera stage/status/responsible/waiting;
- eventos não podem ser update/delete por runtime/capability;
- RLS permanece ativo/forçado;
- role Auth continua sem acesso ao domínio;
- role de domínio continua sem acesso Auth/limiter além das fronteiras já aprovadas.

### Regressão

- lint;
- typecheck;
- testes completos;
- build Next.js;
- todas as suites `database/tests` existentes;
- Auth/F24 PostgreSQL tests;
- F22 private-preview preflight.

## Red-team obrigatório

Rejeitar PASS se:

- browser puder escolher actor/team/membership confiável;
- qualquer membership ativa virar permissão geral multiusuário;
- segundo membro ativo não bloquear;
- runtime receber DML direto amplo;
- capability/runtime tiver ownership, superuser, `BYPASSRLS` ou `CREATEROLE` incompatível;
- função `SECURITY DEFINER` tiver search path inseguro;
- update puder ocorrer sem evento;
- evento puder persistir sem update correspondente;
- race produzir dois updates/eventos a partir do mesmo expected;
- stale write for aceito silenciosamente;
- no-op gerar evento;
- UUID de outra equipe revelar existência de modo distinto do inexistente;
- migration aplicada for reescrita;
- outras colunas operacionais forem abertas para escrita;
- dado real/interno for usado;
- provider hosted for alterado.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados fictícios;
- nenhum provider hosted write;
- F21 permanece ON HOLD até seu `resume_when` objetivo;
- Q-009 permanece aberta;
- autenticação não é autorização;
- RLS permanece autoritativa;
- estado e evento são atômicos;
- eventos continuam append-only;
- sem CRUD amplo;
- migrations aplicadas são imutáveis;
- runtime normal permanece não privilegiado.

## Fora do escopo

- permitir segundo membro editar;
- definir perfis/papéis multiusuário;
- alterar stage/status/responsável/aguardando;
- mutação de itens/identificadores;
- criar contratação;
- UI ampla de edição;
- provider hosted;
- retomar F21;
- dado real;
- Data API pública.

## Critério de encerramento

F26 fecha quando a primeira mutação persistente de `next_action` estiver implementada por capability estreita, provada em PostgreSQL 17 real contra autorização, atomicidade, rollback e concorrência adversarial, com todas as regressões em PASS e exatamente uma nova `NEXT_ACTION` canônica.
