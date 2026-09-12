# ADR-013 - Edição persistente rastreável de `contractings.object`

**Status:** Accepted  
**Data:** 2026-09-12  
**Escopo:** desenho da boundary persistente exclusiva para edição de `contractings.object`; implementação pertence à work unit seguinte  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

F30 tornou utilizável a criação persistente mínima de uma contratação, mas `contractings.object` ainda só pode ser definido no nascimento da linha. O núcleo funcional prevê edição da contratação, e o banco canônico já separa estado atual em `contractings` de histórico append-only em `contracting_events`.

As decisões anteriores estabeleceram propriedades que não devem ser diluídas:

- ADR-011/F26 usa uma primitive PostgreSQL estreita para editar apenas `next_action`, com runtime sem DML direto, autorização pilot-only, lock, precondição otimista e evento atômico;
- ADR-012/F29 usa capability própria para criação, sem reutilizar a authority de F26;
- F27/F30 expõem Server Actions estreitas sem confiar identidade, escopo, actor ou redirect enviados pelo browser;
- Q-009 permanece aberta e não autoriza inferir uma política multiusuário geral.

`contractings.object` é `text NOT NULL`. As fontes atuais não definem trim, tamanho máximo, conteúdo mínimo ou proibição de string vazia. A edição deve preservar exatamente essa semântica.

F31 é design-only. Nenhuma migration, primitive, adapter, Server Action ou UI é implementada nesta work unit.

## Alternativas avaliadas

### A. Reutilizar a capability F26

A role `compras_next_action_mutation_owner` poderia receber `UPDATE (object)` e permitir que a mesma primitive ou uma nova função sob o mesmo owner alterasse `object`.

**Rejeitada.** F26 foi provada como authority exclusiva de `next_action` e `updated_at`. Acrescentar `object` ampliaria uma capability já selada, reduziria isolamento de falhas e tornaria mais difícil provar que cada mutação possui apenas os privilégios necessários.

### B. Reutilizar a capability F29

A role `compras_contracting_create_owner` poderia receber `UPDATE` para editar linhas já existentes.

**Rejeitada.** F29 existe somente para criação mínima e atualmente não recebe `UPDATE`/`DELETE`. Dar authority de edição à capability de criação misturaria dois ciclos de vida distintos e quebraria a propriedade de least privilege aceita em ADR-012.

### C. DML direto pela role runtime

A aplicação poderia executar `UPDATE contractings` e `INSERT contracting_events` diretamente em uma transação server-side.

**Rejeitada.** Isso exigiria conceder DML direto ao runtime normal e abriria authority maior que a única operação aprovada.

### D. Capability própria para edição de `object`

Criar uma nova primitive `SECURITY DEFINER`, com owner técnico próprio, grants coluna-a-coluna e policies específicas.

**Adotada.** Mantém F26 e F29 inalteradas, permite testar a edição de `object` isoladamente e preserva o runtime sem DML direto.

## Decisão

A edição persistente de `contractings.object` será uma operação específica, pilot-only e rastreável, executada por capability PostgreSQL própria.

A implementação seguinte deve materializar uma primitive conceitualmente equivalente a:

```text
mutate_contracting_object(
  p_contracting_id uuid,
  p_expected_object text,
  p_new_object text,
  p_event_id uuid
)
```

O nome exato pode variar sem alterar a decisão.

A função não aceita `team_id`, `app_user_id`, membership, actor, creator, issuer ou subject como argumentos.

## 1. Fronteira de confiança

O fluxo permanece:

```text
sessão Better Auth validada no servidor
-> issuer fixo + subject validado
-> transação PostgreSQL
-> contexto LOCAL iss/sub
-> current_app_user_id()
-> row/membership derivadas do banco
-> capability de edição de object
```

O browser pode solicitar apenas:

- `contractingId` como seletor candidato;
- `expectedObject` como precondição de concorrência;
- `newObject` como novo conteúdo solicitado.

Nenhum desses valores concede autorização.

O browser não é fonte confiável para:

- `team_id`;
- actor;
- membership;
- creator;
- issuer;
- subject;
- event UUID.

O event UUID deve nascer no código server-only confiável em cada tentativa e não pode vir do form/browser.

## 2. Payload mínimo e semântica de `object`

A interface server-only da implementação deve receber somente:

```text
contractingId
expectedObject
newObject
```

`expectedObject` e `newObject` são strings porque a coluna canônica é `NOT NULL`.

A implementação não deve:

- aplicar `trim`;
- impor limite de tamanho não existente no schema;
- exigir conteúdo non-empty;
- transformar string vazia em `NULL`;
- normalizar espaços;
- alterar encoding/conteúdo por conveniência de UI.

String vazia e espaços nas extremidades são valores válidos segundo o contrato físico atual e devem ser persistidos/comparados exatamente.

A edição não altera `next_action`, stage, status, responsável, waiting, creator, archived/cancelled nem qualquer outro campo operacional além de `object` e `updated_at`.

## 3. Autorização pilot-only

A atualização de uma linha existente deve seguir o padrão de F26, não o guard global de F29.

A capability só autoriza quando:

1. `current_app_user_id()` resolve para usuário interno ativo;
2. a contratação candidata existe e é visível no escopo derivado do banco;
3. a contratação não está arquivada nem cancelada;
4. existe membership `revoked_at IS NULL` do usuário corrente na equipe da contratação;
5. essa membership é a única membership `revoked_at IS NULL` da equipe alvo.

Qualquer segunda membership não revogada na equipe alvo bloqueia a operação, inclusive quando o `app_user` correspondente estiver desabilitado. A correção operacional continua sendo revogar a membership, não ampliar a capability.

### Múltiplas memberships do próprio usuário em equipes diferentes

A edição de uma linha já existente possui `team_id` canônico, portanto não existe a ambiguidade de escopo presente antes do `INSERT` da F29.

Ter outra membership ativa em outra equipe não bloqueia, por si só, a edição de uma contratação autorizada na equipe alvo. O guard é por equipe alvo, como em F26. Copiar o requisito global de exatamente uma membership de F29 inventaria uma restrição que só foi necessária para derivar o team durante criação.

Isso não resolve Q-009. Continua proibido admitir segundo membro na mesma equipe sem decisão explícita posterior.

## 4. Capability e least privilege

A implementação deve criar role técnica equivalente a:

`compras_contracting_object_mutation_owner`

Ela deve permanecer:

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

O lifecycle deve seguir ADR-005 e os padrões já provados por F26/F29. Nenhuma aresta persistente pode permitir `SET ROLE` ou herança da capability. A role normal da aplicação nunca usa essa capability como identidade operacional.

A primitive deve ser `SECURITY DEFINER`, possuir `search_path = pg_catalog` fixo, `PUBLIC EXECUTE` revogado e SQL estático/parametrizado.

### Grants máximos esperados

A capability pode receber somente o necessário para:

- resolver a identidade corrente;
- ler memberships necessárias ao guard pilot-only;
- localizar e bloquear a contratação candidata;
- atualizar somente `contractings.object` e `contractings.updated_at`;
- inserir somente as colunas necessárias do evento de mudança;
- executar helpers de identidade necessários.

A role runtime normal permanece sem `UPDATE`/`INSERT` direto nas tabelas protegidas. O provisionamento por ambiente concede somente `EXECUTE` da nova primitive ao runtime explicitamente validado.

F26 continua sem `UPDATE` de `object`. F29 continua sem `UPDATE` de linhas existentes. A nova capability não recebe authority de criação nem authority de `next_action`.

RLS continua autoritativa sob `FORCE ROW LEVEL SECURITY`. A migration de implementação pode criar somente policies estritamente necessárias à nova capability e deve provar que a role não consegue alterar outras colunas.

## 5. Concorrência e lost update

Não adicionar coluna de versão nesta slice.

A primitive deve combinar:

1. `SELECT ... FOR UPDATE` sobre a contratação autorizada;
2. comparação exata/null-safe do valor persistido com `p_expected_object`.

Mesmo sendo `object NOT NULL`, usar semântica equivalente a `IS DISTINCT FROM` torna a precondição explícita e defensiva.

Fluxo de duas chamadas concorrentes com o mesmo expected antigo:

- A obtém o lock, autoriza, atualiza e cria um evento;
- B espera;
- B adquire o lock, observa que `object` atual difere de `p_expected_object` e retorna `conflict`;
- B não atualiza nem cria evento.

Não existe last-write-wins silencioso.

### Ordem de avaliação

A primitive deve avaliar negação/autorização antes de expor semântica de conflito ou no-op.

Depois de autorizada:

1. se `current_object IS DISTINCT FROM p_expected_object`, retornar `conflict`;
2. se `current_object IS NOT DISTINCT FROM p_new_object`, retornar `unchanged`;
3. caso contrário, aplicar a mudança.

Assim, uma precondição stale nunca é convertida em sucesso apenas porque outro write chegou ao mesmo valor final.

## 6. No-op e propriedades de retry

Se expected estiver atual e `newObject` for exatamente igual ao `object` corrente:

- retornar `unchanged`;
- não alterar `updated_at`;
- não criar evento.

A mutação não adota replay-idempotency de sucesso como a criação F29. O mecanismo é optimistic concurrency:

- uma repetição idêntica após um primeiro update bem-sucedido encontra expected stale e retorna `conflict`;
- não cria segundo evento;
- após readback do valor atual, uma nova submissão pode decidir conscientemente se há nova alteração.

Essa semântica é a mesma propriedade de segurança usada por F26 e evita tratar como sucesso uma repetição cuja causalidade já não pode ser provada.

## 7. Estado e evento atômicos

Em mudança real:

- `contractings.object` recebe `p_new_object` exatamente;
- `contractings.updated_at` recebe `operation_at`;
- exatamente um `contracting_events` é inserido;
- `team_id` e `contracting_id` vêm da linha bloqueada;
- `actor_membership_id` vem da membership autorizada derivada do banco;
- `event_type = 'object_changed'`;
- `field_key = 'object'`;
- `old_value = current_object`;
- `new_value = p_new_object`;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `note`, `related_identifier_id` e `item_id` ficam `NULL`.

`object_changed` é somente a chave específica desta operação. Não cria taxonomia geral de eventos.

O update e o evento pertencem à mesma transação do caller. Falha no `INSERT` do evento deve reverter integralmente a alteração de `object`/`updated_at`.

Eventos continuam append-only. A capability não recebe `UPDATE` nem `DELETE` de eventos.

## 8. Semântica de resultado e side channels

A primitive pode distinguir internamente:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

A interface server-side expõe:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para `denied`;
- `unavailable` para falha técnica/configuração/conexão/contexto/resultado impossível.

`conflict` e `unchanged` só podem existir depois de autorização da contratação.

Devem colapsar para a mesma resposta externa genérica `not-available`:

- contratação inexistente;
- UUID de outra equipe;
- identidade desconhecida;
- usuário interno desabilitado;
- ausência de membership ativa na equipe alvo;
- membership revogada;
- segundo membro não revogado na equipe alvo;
- contratação arquivada;
- contratação cancelada.

Nenhuma resposta externa inclui SQL, claims, connection string, team, actor, membership ou detalhe que funcione como oracle cross-team. Falha protegida nunca cai para demo.

## 9. Adapter server-only

A implementação deve reutilizar `withTrustedDatabaseMutationContext`.

A interface equivalente a `mutatePersistentContractingObject` deve:

- validar candidate UUID;
- exigir `expectedObject` e `newObject` como strings sem transformação;
- gerar event UUID no servidor;
- executar somente a primitive parametrizada;
- mapear `denied` para `not-available`;
- mapear falha inesperada para `unavailable`;
- não aceitar nem encaminhar team/actor/membership/issuer/subject/eventId;
- não executar SQL/DML alternativo;
- não possuir fallback para demo.

A futura Server Action/UI pertence a slice posterior e não entra na implementação F32.

## 10. Matriz adversarial mínima da implementação

A work unit seguinte deve provar, em PostgreSQL 17 descartável e testes TypeScript, no mínimo:

1. único membro não revogado na equipe alvo altera `object`, `updated_at` e cria exatamente um evento;
2. `object` com string vazia e espaços é preservado byte-for-byte segundo a semântica textual do PostgreSQL/driver, sem trim/normalização da aplicação;
3. actor, team e contracting do evento são derivados do banco/identidade, não do browser;
4. valor idêntico com expected atual retorna `unchanged`, sem novo timestamp/evento;
5. expected stale retorna `conflict`, sem update/evento;
6. conflito é avaliado antes de no-op, inclusive quando o valor corrente já coincide com `newObject`;
7. duas ou mais chamadas concorrentes com o mesmo expected antigo produzem exatamente um `updated` e um evento; as demais retornam `conflict`;
8. replay técnico da mesma chamada após o primeiro sucesso não cria segundo evento;
9. falha forçada no insert do evento reverte update e `updated_at`;
10. claims ausentes/malformados, identidade desconhecida ou usuário desabilitado não alteram nada;
11. sem membership ou membership revogada não altera nada;
12. UUID cross-team e UUID inexistente não alteram nada e são indistinguíveis externamente;
13. segundo membro não revogado na equipe alvo bloqueia, inclusive se seu `app_user` estiver desabilitado;
14. contratação arquivada/cancelada bloqueia;
15. usuário com memberships ativas em equipes diferentes continua elegível para a contratação da equipe alvo quando essa equipe satisfaz o guard pilot-only;
16. runtime normal não possui DML direto;
17. capability owner é selada, não privilegiada, sem ownership de tabelas-base e com `search_path` fixo;
18. capability só consegue `UPDATE` de `object` e `updated_at` e não consegue criar contratação, alterar `next_action`, stage, status, responsável, waiting, creator, archived/cancelled;
19. capability não consegue `UPDATE`/`DELETE` de eventos;
20. F26 continua incapaz de atualizar `object` e F29 continua incapaz de atualizar linhas existentes;
21. Auth/read-only runtimes não herdam `EXECUTE` da nova capability;
22. migrations `0001..0005` permanecem byte-identical;
23. suites F22/F26/F29/Auth continuam verdes;
24. somente identidades/dados fictícios e nenhum provider hosted write.

## 11. Rollback e failure atomicity

A transação do caller é a unidade de rollback.

Qualquer exception durante update/evento deve provocar `ROLLBACK` por `withTrustedDatabaseMutationContext`. Em estado transacional incerto, a conexão/pool deve ser descartada conforme o adapter já implementado.

Nenhum mecanismo de compensação manual ou evento posterior é aceitável como substituto da atomicidade.

## 12. Migration e isolamento

A implementação deve usar nova migration, esperada como `0006_...sql`. Migrations `0001..0005` são história aplicada e permanecem imutáveis.

A nova migration deve incluir postflight estrutural suficiente para falhar se:

- owner ficar privilegiado;
- existir membership utilizável na capability;
- `PUBLIC EXECUTE` existir;
- runtime receber DML direto;
- grants permitirem atualizar colunas fora de `object`/`updated_at`;
- eventos deixarem de ser append-only;
- F26/F29 receberem authority nova por acidente.

Provisionamento de `EXECUTE` ao runtime deve permanecer asset separado da migration, seguindo os padrões já usados por F26/F29.

## 13. Fora do escopo

Não pertence a esta decisão nem à implementação imediata F32:

- UI/Server Action de edição;
- alteração de `next_action`;
- stage/status/responsável/waiting;
- itens/identificadores;
- arquivamento/cancelamento;
- política multiusuário;
- resolução de Q-001/Q-002/Q-006/Q-009;
- provider hosted;
- retomada F21;
- dado real.

## Red-team da decisão

A decisão é rejeitada se permitir qualquer uma das condições abaixo:

- browser escolher team, actor, membership, creator, issuer, subject ou event UUID confiável;
- F26 ou F29 ganhar authority adicional de `object` por conveniência;
- runtime normal ganhar DML direto;
- capability própria conseguir alterar outra coluna operacional;
- alteração de estado sem evento atômico;
- evento sem alteração correspondente;
- trim, limite, regra non-empty ou empty-to-NULL não sustentados;
- stale write virar last-write-wins silencioso;
- stale expected virar `unchanged` só porque `newObject` coincide com estado corrente;
- cross-team/inexistente produzir oracle;
- segundo membro da equipe alvo ser tratado como autorização multiusuário;
- copiar o guard global de membership da criação F29 para a edição sem necessidade de escopo;
- reescrever migrations aplicadas;
- usar provider hosted, secret ou dado real.

## Consequências

### Positivas

- `object` ganha uma authority isolada e auditável;
- F26 e F29 permanecem com contratos imutáveis e verificáveis;
- runtime continua sem CRUD amplo;
- concorrência protege contra lost update;
- histórico preserva old/new exatos;
- Q-009 continua aberta sem bloquear o piloto individual.

### Custos

- nova capability, migration, provisionamento e matriz PostgreSQL dedicada;
- mais uma primitive específica em vez de um CRUD genérico;
- retry após sucesso incerto pode aparecer como `conflict`, exigindo readback antes de nova decisão consciente.

Esses custos são aceitos em troca de least privilege, auditabilidade e isolamento de authority.

## Próxima work unit

`F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01` deve implementar somente a boundary PostgreSQL/server-only definida nesta ADR. UI/Server Action fica para work unit posterior.