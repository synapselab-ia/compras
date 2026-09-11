# ADR-012 — Criação persistente mínima e idempotente de contratação

**Status:** Accepted  
**Data:** 2026-09-11  
**Escopo:** desenho da primeira criação persistente de `contractings`; implementação pertence à work unit seguinte  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

O produto já possui leitura persistente protegida e uma única escrita operacional integrada: alteração de `contractings.next_action` por capability PostgreSQL estreita, com evento atômico e autorização pilot-only. A F27 tornou essa mutação utilizável no detalhe.

`PROJECT_DESIGN.md` inclui cadastro de contratação no núcleo funcional inicial, mas a criação não pode reutilizar automaticamente a política de uma linha já existente: antes do `INSERT` ainda não há `team_id` persistido do qual derivar escopo.

As fontes canônicas preservam questões relevantes abertas:

- Q-001 — taxonomia final de etapas;
- Q-002 — taxonomia final de status;
- Q-006 — quando `próxima ação` vira uma entidade `Pendência`;
- Q-009 — política de edição quando houver múltiplos membros.

O schema atual também foi deliberadamente permissivo na criação: `object` é `NOT NULL`, enquanto responsável, etapa, status, waiting e `next_action` são nullable porque o instante em que se tornam obrigatórios não foi definido.

A criação precisa, portanto, provar quatro propriedades sem fechar essas perguntas por conveniência:

1. escopo e ator derivados somente da identidade confiável + banco;
2. capability mínima, separada da mutação F26;
3. linha e evento inicial inseparáveis;
4. retry/double-submit sem duplicação silenciosa.

## Alternativas avaliadas

### A. `INSERT` direto pela role runtime

A aplicação poderia validar a sessão e executar `INSERT` em `contractings` e `contracting_events` na mesma transação.

**Rejeitada.** A role runtime precisaria receber DML direto amplo o suficiente para construir a linha e o evento. Isso ampliaria a superfície de autoridade além da única operação aprovada e enfraqueceria a propriedade já adotada em ADR-011: a credencial normal deve possuir apenas capabilities específicas.

### B. Reutilizar `compras_next_action_mutation_owner`

A capability F26 poderia receber os novos `INSERT` necessários.

**Rejeitada.** A role existe para uma operação diferente, com grants e policies limitados a `next_action`. Acrescentar criação faria uma capability já provada ganhar autoridade sobre novas colunas e novos fatos, tornando mais difícil demonstrar least privilege e regressão independente.

### C. Capability própria para criação mínima

Criar uma nova primitive `SECURITY DEFINER`, com owner técnico próprio, grants coluna-a-coluna e policies específicas para a criação.

**Adotada.** Mantém F26 inalterada, permite provar a criação isoladamente e preserva runtime sem DML direto.

## Decisão

A primeira criação persistente será uma operação específica, pilot-only e idempotente, executada por capability PostgreSQL própria.

A implementação seguinte deverá materializar uma primitive conceitualmente equivalente a:

```text
create_contracting_minimal(
  p_contracting_id uuid,
  p_object text,
  p_event_id uuid
)
```

O nome exato pode variar sem alterar esta decisão.

A função não aceita `team_id`, `app_user_id`, membership, actor, `created_by_membership_id`, issuer ou subject como argumento.

## 1. Payload mínimo

A primeira criação aceita semanticamente apenas:

- `contractingId` — UUID opaco preparado pelo servidor e ecoado pelo formulário como seletor/idempotency key, nunca como autoridade;
- `object` — texto solicitado para `contractings.object`.

`object` é obrigatório porque o schema físico é `NOT NULL`. A implementação não deve inventar trim, tamanho máximo, regra de conteúdo ou proibição de string vazia que as fontes atuais não sustentam. O valor deve ser preservado exatamente.

A criação **não** recebe nesta slice:

- `next_action`;
- `stage_key`;
- `status_key`;
- `responsible_membership_id`;
- `waiting_type`;
- `waiting_reference`;
- `waiting_since`;
- `waiting_reason`;
- `archived_at`;
- `cancelled_at`.

Esses campos nascem `NULL`. `next_action` permanece para a capability F26/F27 após a contratação existir. Essa separação evita transformar um campo atualmente nullable em requisito implícito de cadastro e não fecha Q-006.

A criação também não inclui itens ou identificadores relacionados.

## 2. Fronteira de confiança e escopo pilot-only

O fluxo de confiança permanece o de ADR-003/ADR-009:

```text
sessão Better Auth validada no servidor
-> issuer fixo + subject validado
-> contexto PostgreSQL LOCAL iss/sub
-> current_app_user_id()
-> memberships do banco
-> capability de criação
```

O browser não é fonte confiável de escopo. Campos extras equivalentes a `team_id`, actor, membership, issuer, subject ou `created_by_membership_id` não podem atravessar a interface server-side.

### Regra de elegibilidade

A criação só é autorizada quando, no instante da operação:

1. `current_app_user_id()` resolve para usuário interno ativo;
2. esse usuário possui **exatamente uma** membership com `revoked_at IS NULL` em todo o banco;
3. a equipe dessa membership existe e `archived_at IS NULL`;
4. essa equipe possui **exatamente uma** membership com `revoked_at IS NULL`.

A membership derivada torna-se simultaneamente:

- escopo de `team_id`;
- `created_by_membership_id` da contratação;
- `actor_membership_id` do evento inicial.

A contagem da equipe considera toda membership não revogada, inclusive quando o `app_user` correspondente estiver desabilitado, seguindo a postura conservadora da ADR-011. Limpeza incompleta de membership não amplia permissão.

### Por que múltiplas memberships do usuário falham fechadas

Mesmo que apenas uma das equipes pareça apta por outra heurística, escolher silenciosamente entre duas memberships ativas transformaria uma convenção do piloto em política de escopo. Enquanto Q-009 permanecer aberta, duas ou mais memberships não revogadas do usuário tornam a criação ambígua e a operação é negada.

### Por que segundo membro bloqueia

Uma equipe com segunda membership não revogada também bloqueia a criação por esta primitive. Isso não declara que o segundo membro pode ou não criar no futuro; apenas impede que uma regra de piloto individual vire autorização multiusuário por inércia.

Antes de permitir criação multiusuário, Q-009 exige decisão explícita e nova evolução da capability.

## 3. Capability dedicada e grants

A implementação deve criar role técnica equivalente a:

`compras_contracting_create_owner`

Ela deve permanecer:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem configuração de role persistente;
- sem ownership de tabelas-base;
- sem membership utilizável em outra role.

O lifecycle segue ADR-005: PostgreSQL 17 pode conservar apenas a aresta administrativa automática ao principal de migration, com `ADMIN TRUE`, `SET FALSE`, `INHERIT FALSE`. Nenhuma aresta persistente pode permitir `SET ROLE` ou herança da capability.

A primitive deve ser `SECURITY DEFINER`, possuir `search_path = pg_catalog` fixo e usar somente SQL estático/parametrizado.

### Grants máximos esperados

A capability pode receber somente o necessário para:

- resolver a identidade atual;
- ler memberships suficientes para derivar escopo e contar o guard pilot-only;
- verificar a equipe derivada e seu estado de arquivamento;
- verificar um `contracting_id` candidato para idempotência;
- inserir apenas as colunas aprovadas da nova contratação;
- inserir apenas as colunas aprovadas do evento de criação;
- executar helpers de identidade necessários.

O `INSERT` em `contractings` deve ser coluna-a-coluna, limitado a:

- `id`;
- `team_id`;
- `object`;
- `created_by_membership_id`;
- `created_at`;
- `updated_at`.

O `INSERT` em `contracting_events` deve ser coluna-a-coluna, limitado a:

- `id`;
- `team_id`;
- `contracting_id`;
- `actor_membership_id`;
- `event_type`;
- `occurred_at`;
- `created_at`.

Não há `UPDATE`/`DELETE` de `contractings` ou eventos para essa capability. Ela não recebe `EXECUTE` da primitive F26 por necessidade da criação.

A role runtime normal continua sem `INSERT` direto em `contractings`/`contracting_events`; cada ambiente concede apenas `EXECUTE` da nova primitive por provisionamento explícito e separado da migration.

RLS continua autoritativa sob `FORCE ROW LEVEL SECURITY`. A migration de implementação deve criar apenas policies específicas necessárias à role da capability e provar que valores inseridos não conseguem escolher outro team/actor nem preencher colunas fora do formato aprovado.

## 4. Estado inicial da contratação

Em uma criação real, a linha deve nascer com:

- `id = p_contracting_id`;
- `team_id` derivado da única membership elegível;
- `object = p_object` sem transformação;
- `created_by_membership_id` derivado da mesma membership;
- `created_at = operation_at`;
- `updated_at = operation_at`;
- `responsible_membership_id = NULL`;
- `stage_key = NULL`;
- `status_key = NULL`;
- todos os campos waiting = `NULL`;
- `next_action = NULL`;
- `archived_at = NULL`;
- `cancelled_at = NULL`.

Não assumir que o criador é automaticamente `responsible_membership_id`: criação e responsabilidade operacional são conceitos distintos no modelo.

## 5. Evento inicial atômico

Cada criação nova deve inserir exatamente um evento com:

- `event_type = 'contracting_created'`;
- `team_id` igual ao escopo derivado;
- `contracting_id` igual à linha recém-criada;
- `actor_membership_id` igual à membership derivada;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `field_key = NULL`;
- `old_value = NULL`;
- `new_value = NULL`;
- `note = NULL`;
- `related_identifier_id = NULL`;
- `item_id = NULL`.

`contracting_created` é apenas a chave específica desta operação e não cria uma taxonomia geral de eventos.

`field_key`/`old_value`/`new_value` permanecem nulos porque o evento representa o nascimento da entidade, não a alteração de um campo escalar isolado. O `object` já está no estado estruturado e não precisa ser duplicado em texto de auditoria para provar a criação.

A linha e o evento pertencem à mesma transação. Falha do evento reverte integralmente o `INSERT` de `contractings`.

## 6. UUID e idempotência

### UUID da contratação

O UUID da contratação é gerado pelo servidor confiável **antes da submissão**, quando a futura jornada prepara o formulário. O browser apenas o ecoa.

Esse UUID tem duas funções técnicas:

1. identidade estável da futura contratação;
2. chave de idempotência da solicitação preparada.

Ele não é segredo e não concede autorização. Um browser pode adulterá-lo; a consequência permitida é apenas mudar o seletor candidato. Team/actor continuam derivados do banco.

### UUID do evento

O UUID do evento é gerado no servidor no momento da chamada à interface de persistência e nunca vem do browser.

Não precisa ser estável entre retries porque uma repetição bem-sucedida da mesma criação não insere novo evento.

### Replay idempotente

Se já existir `contracting` com o mesmo `p_contracting_id`, a primitive só pode retornar resultado equivalente a `already-created` quando, **após a autorização pilot-only corrente**, a linha existente corresponder exatamente aos identificadores imutáveis da solicitação original:

- mesmo `team_id` derivado;
- mesmo `created_by_membership_id` derivado;
- mesmo `object` por comparação exata.

Campos que podem mudar posteriormente, como `next_action`, não participam do reconhecimento do replay.

Se o UUID já existir mas essa correspondência não puder ser provada, o resultado é genérico de negação/não disponibilidade. Não revelar se houve colisão cross-team, criação de outro ator ou objeto diferente.

### Corrida de double-submit

Duas chamadas concorrentes com o mesmo UUID preparado podem ambas observar ausência inicial. O banco deve continuar sendo a autoridade de unicidade pela primary key.

A implementação deve tratar a corrida para que:

- no máximo uma chamada insira a contratação e o evento;
- a outra, após a resolução da unicidade, reconheça o mesmo replay autorizado e retorne `already-created`;
- não apareça segundo evento;
- uma colisão não equivalente não seja convertida em sucesso.

A implementação pode usar tratamento transacional de `unique_violation`/releitura autorizada ou mecanismo PostgreSQL equivalente, desde que preserve as propriedades acima e o rollback atômico do evento.

Não será criada tabela/serviço externo de idempotência nesta etapa. O próprio UUID estável da entidade + PK do PostgreSQL são suficientes para a primeira jornada.

### Limite da idempotência

Dois formulários preparados independentemente recebem UUIDs diferentes. Criar duas contratações com o mesmo texto de `object` não é automaticamente duplicata: nenhuma regra de unicidade semântica por objeto foi aprovada. A idempotência protege retries da **mesma solicitação preparada**, não deduplicação de negócio por conteúdo.

## 7. Semântica de resultado

A primitive pode distinguir internamente estados equivalentes a:

- `created` — linha + evento inseridos;
- `already-created` — replay idempotente exato da mesma solicitação autorizada;
- `denied` — identidade/escopo não elegível ou colisão que não pode ser provada como replay;
- falha técnica — exception/estado impossível.

A camada server-side expõe somente:

- `created`;
- `already-created`;
- `not-available` para `denied`;
- `unavailable` para falha técnica/configuração/conexão/contexto.

Nenhum erro externo expõe SQL, claims, connection string, team, actor, membership ou existência cross-team. Falha protegida nunca cai para demo.

`already-created` só é retornado depois de provar autorização corrente e correspondência exata do replay; portanto ele não funciona como oracle de UUID arbitrário.

## 8. Matriz de confiança, autorização e idempotência

| Entrada/estado | Fonte de autoridade | Decisão |
| --- | --- | --- |
| `object` | browser solicita conteúdo; não define escopo | preservado exatamente se a operação for autorizada |
| `contractingId` | servidor prepara; browser ecoa | seletor/idempotency key, nunca autorização |
| issuer/subject | sessão Better Auth validada server-side | única identidade externa aceita |
| `app_user` | banco por `current_app_user_id()` | deve existir e estar ativo |
| memberships do usuário | banco | exatamente 1 não revogada; 0 ou >1 → deny |
| team | derivado da única membership | deve existir e não estar arquivado |
| memberships do team | banco | exatamente 1 não revogada; >1 → deny |
| actor/created_by | mesma membership derivada | browser não escolhe |
| mesmo UUID + mesmo team/actor/object | banco, após autorização | `already-created`, sem novo evento |
| mesmo UUID com correspondência não provada | banco | `denied`/`not-available` |
| evento não persiste | banco/transação | rollback da contratação |
| falha de sessão/configuração/banco | boundary server-side | `unavailable`, sem demo fallback |

## 9. Critérios adversariais obrigatórios para a implementação

A work unit seguinte deve provar em PostgreSQL 17 descartável, além de lint/typecheck/test/build:

1. identidade válida, exatamente uma membership não revogada e equipe com exatamente um membro não revogado → criação permitida;
2. `team_id`, actor, membership, issuer, subject e `created_by` forjados não chegam à primitive como autoridade;
3. `object` é preservado exatamente, sem trim/regra de tamanho inventada;
4. `next_action`, stage, status, responsável e waiting nascem `NULL`;
5. `created_by_membership_id`, `team_id` e actor do evento são derivados do banco;
6. `created_at`, `updated_at`, `occurred_at` e `event.created_at` usam o mesmo instante da operação;
7. criação gera exatamente um `contracting_created` com campos auxiliares nulos;
8. falha forçada no evento reverte a contratação;
9. identidade ausente/malformada/desconhecida ou usuário desabilitado → deny sem write;
10. zero membership ativa → deny;
11. membership revogada → deny;
12. duas ou mais memberships não revogadas do mesmo usuário → deny por escopo ambíguo;
13. equipe derivada arquivada → deny;
14. segundo membro não revogado na equipe bloqueia, inclusive se o `app_user` dele estiver desabilitado;
15. replay sequencial exato do mesmo UUID/team/actor/object retorna `already-created` sem novo registro/evento;
16. double-submit concorrente do mesmo UUID gera exatamente uma linha, um evento e somente resultados `created`/`already-created`;
17. mesmo UUID com objeto diferente não é tratado como replay;
18. UUID já existente fora do escopo não revela existência e não altera dados;
19. runtime normal não possui `INSERT`/`UPDATE`/`DELETE` direto em `contractings`/`contracting_events` e recebe somente `EXECUTE` explícito da nova primitive;
20. capability de criação é selada, não privilegiada, não possui tabelas-base e não consegue atualizar registros existentes;
21. capability F26 não ganha `INSERT`; capability de criação não ganha authority para `next_action` update nem outras mutations;
22. Auth runtime e runtimes read-only não herdam a nova `EXECUTE`;
23. `PUBLIC EXECUTE` permanece revogado e `search_path` da primitive é fixo;
24. migrations `0001..0004` permanecem byte-for-byte imutáveis;
25. somente dados/identidades fictícios e nenhum provider hosted write.

## 10. Red-team da decisão

Foram rejeitados pelo desenho:

- `team_id` escolhido pelo formulário;
- actor/created_by enviado pelo cliente;
- selecionar silenciosamente uma de múltiplas memberships do usuário;
- permitir criação em equipe com segundo membro enquanto Q-009 está aberta;
- tornar criador automaticamente responsável interno;
- exigir stage/status/waiting/next_action para cadastrar;
- reutilizar a capability F26 e ampliar seus grants;
- dar `INSERT` direto à role runtime;
- owner/superuser/`BYPASSRLS` como runtime normal;
- criação sem evento ou evento fora da transação;
- idempotência baseada em segredo no browser;
- deduplicar por texto de `object` sem regra de negócio;
- criar infraestrutura externa de idempotência sem necessidade;
- retornar colisão cross-team distinguível;
- resolver Q-001/Q-002/Q-006/Q-009 nesta ADR;
- reescrever migrations aplicadas;
- depender de F21/provider hosted/dado real para provar a implementação.

## Consequências

### Positivas

- cadastro mínimo pode ser implementado sem taxonomias ainda abertas;
- escopo de criação é derivado de identidade/banco e falha fechado em ambiguidade;
- Q-009 continua explicitamente pilot-only;
- F26 permanece uma capability independente e não ganha novos poderes;
- criação e histórico nascem atomicamente juntos;
- retry da mesma solicitação preparada é idempotente sem serviço adicional;
- o runtime normal continua sem CRUD amplo.

### Custos

- o piloto com múltiplas memberships não poderá criar até existir política explícita;
- qualquer segundo membro não revogado na equipe bloqueia a capability de criação;
- o formulário futuro precisa ser preparado pelo servidor com UUID estável;
- cadastro inicial é intencionalmente esparso e exige mutações posteriores para preencher `next_action` ou outros campos quando essas journeys existirem;
- a implementação exige nova migration, capability, policies, provisionamento e matriz PostgreSQL adversarial.

## Questões que permanecem abertas

Esta decisão **não** resolve:

- Q-001 — taxonomia final de etapas;
- Q-002 — taxonomia final de status;
- Q-006 — entidade `Pendência`;
- Q-009 — permissões multiusuário.

Também não define unicidade semântica de `object`, criação de itens/identificadores, arquivamento/cancelamento ou edição de outros campos.

## Próxima implementação permitida

A próxima work unit pode implementar a boundary definida aqui em PostgreSQL 17 descartável e código server-only:

- migration nova, sem reescrever `0001..0004`;
- capability `compras_contracting_create_owner`;
- primitive específica de criação;
- asset de provisionamento de `EXECUTE` para runtime não privilegiado;
- interface server-side que gera `event_id`, aceita apenas candidate UUID + `object` e usa `withTrustedDatabaseMutationContext`;
- testes unitários, PostgreSQL, concorrência/idempotência e regressões F22/F26/Auth.

Server Action e UI de cadastro continuam fora dessa implementação de boundary e devem receber slice própria depois que a capability estiver provada.
