# ADR-011 — Primeira mutação persistente rastreável de próxima ação

**Status:** Accepted  
**Data:** 2026-09-10  
**Escopo:** primeira escrita operacional persistente de `contractings.next_action`; design apenas nesta work unit  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

O núcleo persistente já possui:

- identidade externa validada no servidor e transportada à transação PostgreSQL somente como `iss + sub`;
- `app_users` separado de `memberships`;
- RLS `FORCE ROW LEVEL SECURITY` e leitura escopada por membership ativa;
- `contractings.next_action` e `contractings.updated_at`;
- `contracting_events` append-only para fatos históricos relevantes;
- role operacional não privilegiada;
- proibição de CRUD amplo como atalho.

`DATABASE.md` exige que uma alteração rastreável atualize estado e evento na mesma transação lógica. Q-009 permanece aberta: quando o produto deixar de ser piloto individual, ainda não está decidido se todos os membros poderão editar todas as contratações ou se haverá perfis/escopos distintos.

A primeira escrita não pode transformar a existência de uma membership em uma política multiusuário inventada.

## Caso concreto

A primeira mutação será somente a alteração de `contractings.next_action`.

Esse campo já existe no modelo e não depende de fechar taxonomias de etapa/status. A operação permite provar, em uma slice pequena, autorização, atomicidade, histórico e concorrência antes de abrir outras mutações.

F25 não implementa migration, função, Server Action nem UI de escrita. A implementação pertence à F26.

## Alternativas avaliadas

### A. Transação server-side com DML direto limitado

Fluxo possível:

```text
sessão verificada
-> BEGIN
-> contexto LOCAL iss/sub
-> SELECT/lock autorizado
-> UPDATE contractings
-> INSERT contracting_events
-> COMMIT
```

**Vantagens:** simples de compreender e reutiliza o adaptador server-side já existente.

**Riscos/custos:** a role runtime precisaria receber `UPDATE`/`INSERT` diretos ou uma combinação de grants/policies de escrita mais ampla que a única operação aprovada. Isso aumenta a superfície de erro acidental e torna mais difícil provar que nenhuma outra coluna/tabela pode ser mutada pela mesma credencial.

### B. Primitive PostgreSQL estreita com capability dedicada

Fluxo:

```text
sessão Better Auth validada no servidor
-> BEGIN
-> contexto LOCAL iss/sub
-> role de domínio não privilegiada
-> EXECUTE primitive específica de next_action
-> primitive deriva usuário/membership/team do banco
-> lock + autorização + precondição de concorrência
-> UPDATE next_action/updated_at + INSERT evento
-> COMMIT
```

A primitive é `SECURITY DEFINER` somente para confinar a capability; possui `search_path` fixo, SQL estático e owner técnico `NOLOGIN` não privilegiado.

**Vantagens:** o runtime mantém zero DML direto para a escrita; a capability fica limitada a uma função e às colunas/tabelas necessárias; estado+evento ficam atomicamente acoplados no banco; testes conseguem provar que o caller não pode editar outras colunas.

**Custos:** exige nova migration, role de capability e lifecycle rigoroso de ownership/grants.

## Decisão

Adotar a alternativa **B: primitive PostgreSQL estreita**.

A primeira implementação deve expor ao runtime somente `EXECUTE` sobre uma função específica para `next_action`. Não haverá policy/grant genérico de CRUD para a role runtime.

## Fronteira de confiança

A aplicação continua seguindo ADR-003 e ADR-009:

```text
cookie/sessão Better Auth
-> validação server-side
-> issuer fixo + subject validado
-> transação PostgreSQL
-> SET LOCAL do contexto mínimo iss/sub
-> primitive de mutação
```

O browser não é fonte confiável para:

- `issuer`;
- `subject`;
- `app_user_id`;
- `team_id`;
- `membership_id`;
- `actor_membership_id`.

O `contracting_id` fornecido pela chamada é apenas seletor candidato do recurso. Conhecer um UUID não concede autorização.

## Contrato mínimo da primitive

A implementação deve criar função equivalente conceitualmente a:

```text
mutate_contracting_next_action(
  p_contracting_id uuid,
  p_expected_next_action text,
  p_new_next_action text,
  p_event_id uuid
)
```

O nome exato pode variar sem alterar esta decisão.

### Parâmetros

- `p_contracting_id`: seletor candidato não confiável;
- `p_expected_next_action`: precondição otimista de concorrência, não sinal de autorização;
- `p_new_next_action`: novo valor solicitado;
- `p_event_id`: identificador opaco gerado pelo servidor confiável para o evento.

A função **não aceita** `team_id`, actor, membership, issuer ou subject como argumento.

`p_event_id` deve ser gerado por código server-side confiável, por exemplo UUID criptograficamente aleatório, e nunca recebido do form/browser. Não é token de autorização.

Não criar limite de tamanho, trim, obrigatoriedade ou outra regra de negócio para `next_action` que o modelo atual não sustente. `NULL` continua permitido porque a coluna canônica é nullable.

## Autorização pilot-only

Q-009 continua aberta. Portanto a capability só autoriza a mutação quando todas as condições forem verdadeiras:

1. a identidade corrente resolve para `current_app_user_id()` ativo;
2. a contratação existe e é visível no escopo derivado do banco;
3. a contratação não está arquivada nem cancelada;
4. existe membership ativa (`revoked_at IS NULL`) do usuário corrente na equipe da contratação;
5. essa membership é a **única membership ativa da equipe**.

Se houver uma segunda membership não revogada na equipe, a mutação falha fechada para todos por esta primitive. Isso não declara que o segundo membro pode ou não editar; apenas impede que uma regra de piloto individual seja reutilizada como política multiusuário.

Para o guard de unicidade, qualquer membership com `revoked_at IS NULL` conta como ativa, mesmo se o `app_user` correspondente estiver desabilitado. Esse comportamento deliberadamente conservador evita conceder escrita com base em limpeza incompleta de membership. A correção operacional é revogar a membership; não ampliar a capability.

Antes de admitir escrita multiusuário, Q-009 precisa de decisão explícita e nova migration/policy.

## Capability owner e grants

A implementação deve criar uma role técnica equivalente a:

`compras_next_action_mutation_owner`

A role deve permanecer:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem ownership de tabelas-base;
- sem membership utilizável em role privilegiada.

O lifecycle deve seguir a propriedade de segurança da ADR-005: nenhuma concessão persistente pode permitir `SET ROLE`/herança da capability. A concessão administrativa automática do PostgreSQL 17 ao principal de migration só é aceitável nas mesmas condições de `ADMIN TRUE`, `SET FALSE`, `INHERIT FALSE` já documentadas.

A capability recebe apenas o necessário para executar a primitive, por exemplo:

- `USAGE` no schema;
- leitura mínima de `app_users`, `memberships` e `contractings` para identidade/guard/lock;
- `UPDATE` somente das colunas `next_action` e `updated_at` em `contractings`;
- `INSERT` somente das colunas necessárias de `contracting_events`;
- `EXECUTE` nos helpers de identidade usados.

A role runtime de domínio não recebe esses DMLs. Ela recebe somente `EXECUTE` da primitive, além dos grants de leitura já existentes.

A migration deve incluir policies/capabilities estritamente necessárias para a role técnica sob `FORCE RLS`; não pode usar `BYPASSRLS` como substituto de autorização.

## Atomicidade e histórico

A primitive deve executar autorização, lock, precondição, update e evento dentro da mesma transação do caller.

Quando a mudança é aplicada:

- `contractings.next_action` recebe o novo valor;
- `contractings.updated_at` recebe o timestamp da operação;
- exatamente um `contracting_events` é inserido;
- update e evento usam o mesmo `team_id`/`contracting_id` derivados da linha bloqueada;
- `actor_membership_id` é a membership autorizada derivada do banco;
- `event_type = 'next_action_changed'`;
- `field_key = 'next_action'`;
- `old_value` é o valor bloqueado anterior;
- `new_value` é o valor solicitado;
- `occurred_at` e `created_at` usam o mesmo instante da operação;
- `note`, `related_identifier_id` e `item_id` ficam `NULL` nesta mutação.

`next_action_changed` é somente a chave mínima desta operação. Não cria taxonomia geral de eventos nem fecha Q-001/Q-002.

Se o `INSERT` do evento falhar, o `UPDATE` deve ser revertido. Se o update não ocorrer, nenhum evento correspondente pode permanecer.

`contracting_events` continua append-only: a capability não recebe `UPDATE` nem `DELETE` de eventos.

## No-op

Se a precondição estiver atual e `p_new_next_action IS NOT DISTINCT FROM current next_action`, a operação retorna estado equivalente a `unchanged`:

- não altera `updated_at`;
- não cria evento.

Isso evita produzir histórico falso para uma operação sem mudança de estado e não introduz regra de negócio adicional.

## Concorrência e lost update

Não adicionar coluna de versão apenas para esta primeira mutação.

A implementação deve combinar:

1. lock pessimista da contratação com `SELECT ... FOR UPDATE`;
2. precondição otimista do valor antigo usando semântica null-safe, equivalente a `IS NOT DISTINCT FROM` entre o valor persistido e `p_expected_next_action`.

Exemplo com duas chamadas concorrentes partindo do mesmo valor esperado:

- chamada A obtém o lock, atualiza e cria um evento;
- chamada B espera;
- após adquirir o lock, B observa que o valor atual não coincide com sua precondição e retorna `conflict` sem update/evento.

Assim só uma alteração vence e nenhum write silenciosamente sobrescreve outro.

Usar o valor anterior de `next_action` como precondição evita criar versionamento prematuro e evita problemas de precisão/serialização de timestamp no cliente. Se futuramente várias colunas forem editadas em conjunto, a estratégia de versionamento deve ser reavaliada.

## Semântica de resultado e side channels

A camada interna pode distinguir estados equivalentes a:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

`conflict` e `unchanged` só podem ser produzidos depois de a identidade e o guard pilot-only terem autorizado a contratação.

Os seguintes casos devem ter o mesmo comportamento externo genérico de indisponibilidade/não acesso ao recurso, sem revelar existência:

- contratação inexistente;
- UUID de outra equipe;
- identidade desconhecida;
- `app_user` desabilitado;
- ausência de membership ativa;
- membership revogada;
- segundo membro ativo no escopo;
- contratação arquivada ou cancelada.

Falha de configuração, conexão, transaction/context ou execução da primitive deve resultar em `unavailable`, sem fallback de escrita e sem fallback para demo.

## Adapter server-side de escrita

A F26 deve criar um sibling do adaptador de leitura, equivalente a `withTrustedDatabaseMutationContext`.

Ele deve reutilizar a mesma fronteira de confiança e safety checks de role:

- validar sessão/identidade primeiro;
- validar `DATABASE_URL` server-only;
- abrir `BEGIN` normal, nunca `READ ONLY`;
- rejeitar owner, superuser, `BYPASSRLS` e roles de capability como runtime;
- estabelecer somente `iss/sub` com `set_config(..., true)`;
- chamar apenas operação parametrizada;
- `COMMIT` em sucesso;
- `ROLLBACK` em qualquer falha;
- destruir conexão/pool de estado incerto;
- nunca aceitar identidade/escopo do browser.

A credencial runtime continua incapaz de DML direto sobre `contractings` e `contracting_events`.

## Matriz obrigatória para F26

A implementação seguinte deve provar em PostgreSQL 17 descartável, além de lint/typecheck/test/build:

1. único membro ativo autorizado altera `next_action`, `updated_at` e cria exatamente um evento;
2. actor, team e contracting do evento são derivados do banco/identidade, não do browser;
3. valor idêntico retorna `unchanged`, sem timestamp/evento novo;
4. claims ausentes/malformados, identidade desconhecida ou usuário desabilitado não alteram nada;
5. sem membership ou membership revogada não altera nada;
6. UUID conhecido de outra equipe e UUID inexistente não alteram nada e são indistinguíveis externamente;
7. segundo membro ativo bloqueia a capability pilot-only;
8. contratação arquivada/cancelada bloqueia;
9. precondição stale retorna `conflict` sem evento;
10. duas ou mais chamadas concorrentes com o mesmo expected produzem exatamente um vencedor e um evento;
11. falha forçada no insert do evento reverte o update;
12. runtime não possui `UPDATE`/`INSERT` diretos, ownership, superuser, `BYPASSRLS` ou `CREATEROLE`;
13. capability owner é `NOLOGIN`, não privilegiada, selada e não possui tabelas-base;
14. função tem `search_path` fixo e não usa SQL dinâmico controlável pelo caller;
15. a capability não consegue editar stage/status/responsável/waiting ou outras colunas;
16. eventos permanecem sem `UPDATE`/`DELETE` para runtime/capability;
17. suites RLS/leitura/F22/F24 continuam PASS;
18. somente identidades/dados fictícios e nenhum provider hosted write.

## Red-team da decisão

Rejeitados:

- confiar em `team_id`, actor ou membership enviados pelo browser;
- interpretar membership ativa como permissão geral multiusuário;
- permitir escrita se houver segundo membro ativo;
- dar DML direto amplo à role runtime;
- usar owner/superuser/`BYPASSRLS` como runtime normal;
- dar à capability ownership de tabelas-base;
- `SECURITY DEFINER` com `search_path` controlável;
- update sem evento atômico;
- evento sem update correspondente;
- concorrência last-write-wins silenciosa;
- adicionar coluna de versão sem necessidade nesta slice;
- gerar evento para no-op;
- reescrever migrations já aplicadas;
- alterar stage/status/responsável/aguardando;
- resolver Q-009 globalmente;
- depender de F21/Vercel hosted para provar a implementação;
- usar dado/identidade real.

## Consequências

### Positivas

- primeira escrita nasce com capability mínima em vez de CRUD genérico;
- estado e histórico são inseparáveis atomicamente;
- actor e escopo vêm da identidade verificada e do banco;
- Q-009 permanece aberta e o piloto individual falha fechado ao detectar segundo membro;
- concorrência tem conflito explícito em vez de lost update;
- a role runtime continua fortemente limitada.

### Custos e limites

- a próxima implementação precisa de migration e owner técnico adicional;
- o guard de piloto individual impede escrita em equipes com mais de uma membership ativa, inclusive quando uma membership não revogada pertence a usuário desabilitado;
- `expected_next_action` protege somente este campo; expansão para formulário multi-campo deve reavaliar versionamento/conflitos;
- onboarding multiusuário exige nova decisão antes de liberar escrita.

## Rollback

Rollback da aplicação volta ao último código sem superfície de mutação; não se abre DML direto como fallback.

Objetos de banco já aplicados permanecem historicamente versionados. Se a capability precisar ser retirada, nova migration deve revogar `EXECUTE` e/ou substituir a função; migration aplicada não é reescrita.

Nenhum rollback pode remover RLS, elevar role runtime ou usar `BYPASSRLS` para manter a escrita funcionando.

## Próxima implementação

Implementar esta decisão em `F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01`, exclusivamente com dados fictícios e PostgreSQL 17 descartável/CI, sem provider hosted write.
