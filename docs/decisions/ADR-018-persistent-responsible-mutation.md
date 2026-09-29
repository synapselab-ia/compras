# ADR-018 - Edição persistente rastreável do responsável interno

**Status:** Accepted  
**Data:** 2026-09-29  
**Escopo:** desenho da boundary persistente exclusiva para `contractings.responsible_membership_id`; implementação pertence à F47  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

O núcleo funcional precisa responder quem é o responsável interno por cada contratação. O schema físico já possui `contractings.responsible_membership_id uuid NULL`, com chave estrangeira composta `(team_id, responsible_membership_id) -> memberships(team_id, id)`, e o read model protegido já resolve o nome do responsável por `team_member_directory`.

A fundação também preserva dois estados importantes:

- ausência de responsável é válida no schema e na criação mínima F29;
- uma referência histórica pode continuar apontando para membership posteriormente revogada ou para app_user posteriormente desabilitado, caso em que o diretório deixa de apresentar o nome e a UI atual mostra "Responsável não disponível".

As decisões anteriores estabeleceram o padrão de escrita que esta boundary não pode diluir:

- identidade confiável vem de sessão validada no servidor e contexto PostgreSQL LOCAL `iss/sub`;
- team e actor são derivados do banco, nunca do browser;
- runtime normal permanece sem DML direto;
- cada mutation possui capability dedicada e least privilege;
- alterações rastreáveis atualizam estado e evento atomicamente;
- optimistic concurrency evita lost update;
- resultados protegidos não viram oracle cross-team;
- enquanto Q-009 permanecer aberta, escrita em contratação existente usa o guard target-team pilot-only.

F46 é design-only. Nenhuma migration, primitive, grant, policy, adapter, Server Action ou UI é criada nesta decisão.

## Evidência canônica relevante

A decisão se apoia diretamente em propriedades já documentadas e implementadas:

1. `DOMAIN_MODEL.md` define responsável interno como pessoa que responde pelo acompanhamento dentro da equipe e exige referência a membros/autorizados, não texto solto.
2. `DATABASE.md` torna `responsible_membership_id` nullable e usa FK composta de mesmo team.
3. ADR-004 define o diretório mínimo como memberships não revogadas cujo app_user não esteja desabilitado.
4. O detalhe persistente faz `LEFT JOIN` nesse diretório. Responsável nulo aparece como "Sem responsável"; referência para membership revogada ou app_user desabilitado aparece como "Responsável não disponível".
5. ADR-011 e ADR-013 definem o guard target-team pilot-only, lock da contratação, expected value, `conflict` antes de `unchanged`, evento atômico e runtime sem DML direto.
6. Q-009 continua aberta. Nenhuma mutation pode transformar a existência de uma segunda membership em autorização multiusuário implícita.

## Decisão

A edição de responsável será uma operação específica, pilot-only, auditável e protegida por optimistic concurrency, executada por capability PostgreSQL própria.

A implementação F47 deve materializar uma primitive conceitualmente equivalente a:

```text
mutate_contracting_responsible(
  p_contracting_id uuid,
  p_expected_responsible_membership_id uuid,
  p_new_responsible_membership_id uuid,
  p_event_id uuid
) returns text
```

`p_expected_responsible_membership_id` e `p_new_responsible_membership_id` são nullable.

O nome exato pode variar sem alterar esta decisão.

## 1. Contrato server-only

A interface server-only da F47 deve aceitar somente:

```text
contractingId: string
expectedResponsibleMembershipId: string | null
newResponsibleMembershipId: string | null
```

Semântica:

- `contractingId` é seletor candidato da contratação, nunca authority;
- `expectedResponsibleMembershipId` é a precondição otimista do estado lido;
- `newResponsibleMembershipId` é somente candidato ao novo vínculo;
- `eventId` é gerado no servidor confiável por tentativa e nunca vem do browser.

O browser não define:

- `team_id`;
- actor;
- actor membership;
- issuer;
- subject;
- `app_user_id`;
- timestamps;
- event type;
- event UUID.

Os IDs de membership aceitos pela interface são candidatos opacos. Conhecer um UUID não concede acesso, não escolhe actor e não escolhe team.

## 2. Semântica de nulidade e limpeza do responsável

Limpar o responsável é permitido.

Essa decisão é sustentada pelo contrato canônico já existente:

- `responsible_membership_id` é nullable;
- F29 cria contratações com responsável `NULL`;
- nenhuma fonte canônica tornou o responsável obrigatório em todo instante do workflow.

Portanto:

- `newResponsibleMembershipId = null` significa remover o responsável atual;
- `expectedResponsibleMembershipId = null` significa que o caller espera que o estado atual esteja sem responsável;
- `NULL` não é string vazia nem UUID sentinela.

A F47 não cria regra de obrigatoriedade, valor default ou autoatribuição ao criador.

## 3. Elegibilidade do candidato a novo responsável

Quando `newResponsibleMembershipId` não for `NULL`, a candidate membership deve ser elegível no instante da mutation.

A primitive deve exigir simultaneamente:

1. a membership existe;
2. pertence ao mesmo `team_id` da contratação bloqueada;
3. `memberships.revoked_at IS NULL`;
4. o `app_user` referenciado existe e `disabled_at IS NULL`.

Esse requisito não cria uma política nova de perfil. Ele aplica a semântica já existente de "membro/autorizado" e coincide com os critérios de visibilidade do diretório mínimo da ADR-004.

A candidate membership nunca participa da prova de autoridade do actor. Ela é somente o valor solicitado para o campo após a contratação e o actor já terem sido autorizados.

Membership cross-team, revogada, inexistente ou cujo app_user esteja desabilitado não pode ser atribuída.

### Estado atual legado ou degradado

O estado atual pode conter referência para membership depois revogada ou app_user depois desabilitado. A boundary não altera esse estado silenciosamente.

Depois de autorização da contratação e validação do snapshot esperado:

- limpar esse responsável continua permitido;
- substituir por candidato elegível continua permitido;
- submeter exatamente o mesmo valor atual é `unchanged`, mesmo que a referência atual já não seja elegível para uma nova atribuição.

Essa última regra é deliberada: um no-op não renova nem valida novamente a atribuição histórica. Ele também não cria evento ou timestamp falso. Uma mudança real para um valor não nulo sempre exige elegibilidade atual do novo candidato.

## 4. Autorização target-team pilot-only

A autorização segue F26/F32/F35/F38/F41/F44 para mutation de target existente.

A operação só prossegue quando:

1. `current_app_user_id()` resolve para app_user ativo;
2. a contratação candidata existe e é visível no escopo derivado do banco;
3. a contratação está ativa, com `archived_at IS NULL` e `cancelled_at IS NULL`;
4. o usuário corrente possui membership `revoked_at IS NULL` na equipe da contratação;
5. a equipe alvo possui exatamente uma membership com `revoked_at IS NULL`.

Uma segunda membership não revogada na equipe alvo bloqueia, inclusive quando o app_user correspondente estiver desabilitado.

Uma membership adicional do mesmo usuário em outra equipe não bloqueia por si só, pois o target já possui team canônico.

### Consequência deliberada do piloto

Enquanto Q-009 estiver aberta, uma equipe elegível para esta capability possui exatamente uma membership não revogada. Logo, durante o piloto, o único novo responsável não nulo normalmente atribuível é a própria membership do actor.

Isso é intencional. A boundary também permite limpar o responsável e corrigir estado nulo/degradado, mas não antecipa transferência entre dois membros ativos da mesma equipe.

Quando a política multiusuário for decidida, a autorização poderá evoluir por nova decisão e nova migration. F46 não escolhe essa política.

## 5. Optimistic concurrency

Não será criada coluna de versão.

A primitive deve:

1. autorizar e bloquear a contratação candidata com `SELECT ... FOR UPDATE`;
2. derivar actor membership e aplicar o guard pilot-only;
3. comparar `responsible_membership_id` atual com `p_expected_responsible_membership_id` usando semântica null-safe;
4. somente depois avaliar no-op e novo candidato.

A ordem de decisão é obrigatória:

1. negação de identidade/target/guard;
2. `conflict` se current divergir de expected;
3. `unchanged` se current for igual ao new;
4. validação do novo candidato não nulo;
5. `updated` quando houver mudança real válida.

Assim:

- stale expected nunca vira no-op apenas porque o novo valor coincide com um estado alcançado por outro writer;
- candidate inválido não mascara conflito de snapshot;
- no-op de referência atual degradada não é reinterpretado como nova atribuição;
- nenhum writer faz last-write-wins silencioso.

Duas chamadas concorrentes com o mesmo expected antigo podem produzir no máximo um `updated`. Depois do primeiro commit, as demais observam `conflict`.

Retry técnico da mesma chamada após sucesso incerto não é replay-success. Se o primeiro write tiver sido comprometido, o expected antigo fica stale e o retry retorna `conflict`, sem segundo evento.

## 6. Estado e auditoria atômicos

Em mudança real:

- `contractings.responsible_membership_id` recebe o novo valor, inclusive `NULL`;
- `contractings.updated_at` recebe `operation_at`;
- exatamente um evento é inserido na mesma transação;
- team e contracting vêm da row bloqueada;
- actor membership vem da identidade confiável e do banco;
- `event_type = 'responsible_changed'`;
- `field_key = 'responsible_membership_id'`;
- `old_value = current_responsible_membership_id::text`, ou `NULL`;
- `new_value = new_responsible_membership_id::text`, ou `NULL`;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `note = NULL`;
- `related_identifier_id = NULL`;
- `item_id = NULL`.

Os UUIDs de membership são a representação auditável estável do vínculo. Nome de exibição é apresentação mutável e não substitui a identidade histórica da membership.

Uma UI futura não deve exibir UUIDs crus como linguagem operacional. A apresentação do evento deve resolver ou rotular o vínculo de forma apropriada sem reescrever o valor persistido. Essa apresentação não pertence à F47.

Se o insert do evento falhar, o update e `updated_at` devem ser revertidos. A capability não recebe UPDATE/DELETE de eventos.

`unchanged`, `conflict` e qualquer negação criam zero eventos e não alteram `updated_at`.

## 7. Capability dedicada e least privilege

A F47 deve criar role técnica equivalente a:

`compras_contracting_responsible_mutation_owner`

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
- sem membership utilizável.

O lifecycle segue ADR-005. Nenhuma concessão persistente pode permitir `SET ROLE` ou herança da capability.

A primitive deve ser `SECURITY DEFINER`, ter `search_path = pg_catalog`, usar SQL estático/parametrizado e manter `PUBLIC EXECUTE` revogado.

### Grants máximos

A capability pode receber somente o necessário para:

- resolver a identidade corrente;
- ler app_users para identidade e elegibilidade do candidato;
- ler memberships para actor, guard e candidato;
- localizar e bloquear a contratação;
- atualizar apenas `contractings.responsible_membership_id` e `contractings.updated_at`;
- inserir somente as colunas aprovadas do evento;
- executar helpers de identidade necessários.

Ela não recebe:

- INSERT ou DELETE em `contractings`;
- UPDATE de `object`, `next_action`, stage, status, waiting, creator, archived/cancelled ou outras colunas;
- INSERT/UPDATE/DELETE em memberships ou app_users;
- UPDATE/DELETE em `contracting_events`;
- DML em itens, identifiers ou allocator;
- EXECUTE das primitives anteriores por necessidade desta operation.

F26/F29/F32/F35/F38/F41/F44 também não recebem authority nova.

A role runtime normal recebe somente `EXECUTE` da primitive por provisioning separado e continua sem DML direto.

## 8. RLS esperada na F47

A migration F47 deve adicionar apenas policies específicas da nova capability.

### Memberships e app_users

A capability precisa enxergar o mínimo necessário para:

- resolver o actor;
- contar toda membership não revogada da equipe, inclusive a de app_user desabilitado;
- provar que o novo candidato não nulo é membership não revogada;
- provar que o app_user do novo candidato não está desabilitado.

Essa leitura não pode virar diretório público nem ampliar a role runtime.

### UPDATE da contratação

A policy deve restringir o target a contratação ativa em equipe onde:

- current app user possui membership não revogada;
- existe exatamente uma membership não revogada no team.

`WITH CHECK` deve preservar as mesmas condições e, quando o novo responsável não for `NULL`, exigir vínculo no mesmo team com membership não revogada e app_user não desabilitado.

A FK composta continua como backstop estrutural de mesmo team, mas não substitui as verificações de revogação/desabilitação.

### INSERT do evento

A policy deve exigir:

- `event_type = 'responsible_changed'`;
- `field_key = 'responsible_membership_id'`;
- actor corrente no mesmo team;
- exatamente uma membership não revogada no team;
- contratação ativa;
- `note IS NULL`;
- `related_identifier_id IS NULL`;
- `item_id IS NULL`;
- `new_value` coerente com o estado já persistido de `responsible_membership_id`;
- timestamps coerentes com a operação.

A policy não precisa reconstruir `old_value` a partir da row já atualizada. O valor antigo é capturado pela primitive antes do update.

## 9. Resultados externos e opacidade

A primitive pode distinguir internamente:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

O adapter server-only expõe somente:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para `denied`;
- `unavailable` para falha técnica, configuração, conexão, contexto, event UUID collision ou resultado impossível.

`conflict` e `unchanged` só podem ser observados depois de autorização do target.

Devem colapsar para `not-available`:

- contratação inexistente;
- UUID cross-team;
- identidade desconhecida;
- app_user corrente desabilitado;
- ausência de membership do actor;
- membership do actor revogada;
- segundo membro não revogado na equipe;
- contratação arquivada ou cancelada;
- novo candidato inexistente;
- novo candidato cross-team;
- novo candidato revogado;
- novo candidato cujo app_user esteja desabilitado.

A resposta não revela qual dessas condições ocorreu.

Um UUID sintaticamente inválido para contratação ou membership candidate deve ser rejeitado antes do SQL sem virar exceção detalhada. Nenhuma resposta externa contém SQL, claims, connection string, team ou membership interna adicional.

Falha protegida nunca cai para demo.

## 10. Concorrência, revogação e rollback

### Concorrência entre writers da contratação

O row lock em `contractings` serializa writers da mesma contratação e o expected value detecta qualquer alteração concorrente de responsável.

### Mudança de candidato ou membership

A F47 deve validar elegibilidade do candidato imediatamente antes do update e manter RLS `WITH CHECK` como segunda barreira no statement de escrita.

Não existe hoje uma boundary operacional de revogação de membership. Quando uma futura mutation de membership for desenhada, ela deverá considerar serialização com atribuições concorrentes se o requisito operacional exigir garantia de exclusão mútua entre revogação e assignment. F46 não inventa uma mutation de membership fora do escopo atual.

### Rollback

A transação do caller é a unidade de atomicidade.

Qualquer exception após o update, inclusive falha do evento, deve resultar em rollback integral. Não existe evento compensatório, update sem histórico, fallback para DML direto ou retry cego dentro da primitive.

## 11. Adapter server-only da F47

A F47 deve reutilizar `withTrustedDatabaseMutationContext`.

A interface equivalente a `mutatePersistentContractingResponsible` deve:

- validar `contractingId` como UUID candidato;
- aceitar expected/new como `string | null`;
- validar sintaxe UUID quando expected/new não forem nulos;
- não transformar string vazia em `NULL`;
- gerar `eventId` por `randomUUID()` no servidor;
- executar somente a primitive parametrizada;
- mapear `denied` para `not-available`;
- mapear falha inesperada para `unavailable`;
- não aceitar team/actor/membership do actor/issuer/subject/timestamps/eventId;
- não executar SQL alternativo;
- não possuir fallback para demo.

A F47 não adiciona Server Action nem UI.

## 12. Matriz adversarial obrigatória da F47

A implementação deve provar em PostgreSQL 17 descartável e testes server-only, no mínimo:

1. piloto autorizado altera `NULL -> própria membership` e cria exatamente um evento;
2. piloto autorizado altera `própria membership -> NULL`;
3. team, actor e contracting do evento são derivados do banco;
4. event UUID nasce server-side;
5. expected/new nullable são transportados sem sentinela textual;
6. current diferente de expected retorna `conflict` sem write/evento;
7. stale expected continua `conflict` mesmo se new coincide com current;
8. expected atual + new igual ao current retorna `unchanged` sem timestamp/evento;
9. current responsável revogado ou com app_user desabilitado pode ser limpo quando expected corresponde;
10. no-op sobre current responsável degradado retorna `unchanged` sem reatribuição/evento;
11. candidato não nulo revogado é negado;
12. candidato não nulo com app_user desabilitado é negado;
13. candidato cross-team é negado;
14. candidato inexistente é negado;
15. a FK composta impede referência cross-team como backstop;
16. claims ausentes/malformados, identidade desconhecida ou app_user corrente desabilitado negam;
17. membership do actor ausente/revogada nega;
18. segundo membro não revogado na equipe alvo bloqueia, inclusive app_user desabilitado;
19. membership adicional do mesmo usuário em outra equipe não bloqueia por si só;
20. target cross-team e inexistente são externamente indistinguíveis;
21. target arquivado/cancelado bloqueia;
22. oito writers concorrentes com mesmo expected produzem exatamente um `updated`, demais `conflict`, e um único evento;
23. retry pós-sucesso não cria segundo evento;
24. falha forçada no evento reverte responsável e `updated_at`;
25. old/new do evento preservam `NULL` e UUID textual corretamente;
26. `event_type`, `field_key`, actor e timestamps têm shape fechado;
27. runtime normal não possui DML direto;
28. capability possui UPDATE somente de `responsible_membership_id` e `updated_at`;
29. capability não altera object, next_action, stage, status, waiting, creator, archived/cancelled;
30. capability não escreve memberships/app_users nem UPDATE/DELETE eventos;
31. capability é selada, não privilegiada e sem ownership de tabela-base;
32. `PUBLIC EXECUTE` permanece revogado e `search_path` é fixo;
33. F26/F29/F32/F35/F38/F41/F44 permanecem com authority original;
34. migrations `0001..0011` permanecem byte-for-byte imutáveis;
35. suites de leitura/Auth/F22/F29/F32/F35/F38/F41/F44 permanecem verdes;
36. somente dados e identidades fictícios, sem provider hosted write.

## 13. Red-team da decisão

O desenho é rejeitado se qualquer implementação:

- aceitar team, actor, issuer, subject ou actor membership do browser;
- usar o candidato a responsável como prova de autorização;
- permitir assignment cross-team;
- permitir nova atribuição para membership revogada;
- permitir nova atribuição para app_user desabilitado;
- tratar segundo membro como autorização multiusuário;
- exigir responsável non-null ou autoatribuir criador sem fonte canônica;
- impedir limpeza para `NULL` apesar do schema/modelo atual;
- validar candidate antes de detectar snapshot stale e mascarar `conflict`;
- transformar stale expected em `unchanged`;
- atualizar estado sem evento atômico;
- criar evento sem mudança correspondente;
- usar DML direto da runtime;
- reutilizar capability existente e ampliar seus grants;
- permitir UPDATE genérico de `contractings`;
- permitir UPDATE/DELETE de eventos;
- mostrar existência cross-team por erro/resultado distinto;
- guardar display_name como substituto da identidade estável do vínculo;
- expor UUID cru como linguagem de UI futura sem necessidade;
- reescrever migrations aplicadas;
- resolver Q-009 implicitamente;
- depender de F21, provider hosted, secret ou dado real.

## Consequências

### Positivas

- responsável interno ganha uma boundary específica e auditável;
- clear para `NULL` preserva o contrato atual;
- candidato não pode escolher scope ou actor;
- assignment novo exige membro atualmente autorizado e usuário ativo;
- referências antigas revogadas/desabilitadas podem ser corrigidas sem mutação silenciosa;
- optimistic concurrency evita lost update;
- evento preserva identidade estável do vínculo;
- runtime continua sem CRUD amplo;
- Q-009 permanece explicitamente aberta.

### Custos

- durante o piloto, o guard target-team impede transferência entre dois membros ativos da mesma equipe;
- uma future UI precisará transportar o snapshot de membership ID protegido sem expor UUID como linguagem operacional;
- a implementação exige nova capability, migration, provisioning, testes PostgreSQL e adapter específicos;
- evolução multiusuário exigirá nova decisão sobre permissões antes de relaxar o guard.

## Fora do escopo

Não pertencem à F46 nem à implementação imediata F47:

- Server Action e UI de responsável;
- política multiusuário definitiva;
- perfis/papéis;
- criação/revogação de memberships;
- edição de etapa/status/waiting;
- arquivamento/cancelamento;
- pesquisa de preços;
- auditoria de leitura;
- provider hosted;
- retomada F21;
- dado real.

## Próxima implementação

A implementação pertence exclusivamente a:

`F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01`.

F47 deve criar migration aditiva `0012`, capability dedicada, policies/grants mínimos, primitive, provisioning, adapter server-only, testes unitários/PostgreSQL/concorrência e workflow/regressões aplicáveis, sem UI.
