# F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01 — Desenhar criação persistente mínima de contratação

**Classe:** T5 — decisão/arquitetura, com impacto T2 — autorização/banco  
**Estado:** DESIGN COMPLETE / VERIFYING  
**Dependências:** F27, ADR-003, ADR-005, ADR-009 e ADR-011  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

Após F27, o piloto consegue consultar contratações persistentes e alterar somente `Próxima ação`, mas ainda não consegue cadastrar uma nova contratação. O cadastro pertence ao núcleo funcional inicial, porém Q-001/Q-002/Q-006/Q-009 permanecem abertas e não podem ser resolvidas silenciosamente para viabilizar criação.

F28 é design-only e fecha a fronteira arquitetural antes de qualquer nova migration/Server Action/UI.

## Recuperação e inspeção executadas

A sessão recuperou o estado real do GitHub e primeiro fechou a frente anterior:

- F27 PR `#43` recebeu gates finais verdes;
- merge F27 em `main`: `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`;
- CI pós-merge `34615115211`: PASS;
- F22 Private Preview Preflight pós-merge `34615115289`: PASS.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 blobs estáveis e permaneceu `VALID`.

A inspeção F28 cobriu diretamente:

- PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW e OPEN_QUESTIONS;
- SECURITY e DATABASE;
- ADR-003, ADR-005, ADR-009 e ADR-011;
- migrations `0001..0004`;
- constraints atuais de `contractings`/`contracting_events`;
- boundary F26/F27 e testes adversariais;
- Definition of Done.

Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## Resultado da decisão

A decisão completa está em `docs/decisions/ADR-012-minimal-persistent-contracting-creation.md`.

### Payload mínimo

A criação inicial aceita semanticamente somente:

- `contractingId` — UUID opaco gerado pelo servidor antes da submissão e ecoado como selector/idempotency key;
- `object` — texto obrigatório pelo schema, preservado exatamente, sem trim/limite/non-empty inventados.

`next_action` **não** nasce no payload de criação; permanece para F26/F27 depois que a contratação existe.

Também não entram stage, status, responsável, waiting, itens ou identificadores. Esses campos ficam `NULL` quando nullable.

### Escopo e ator pilot-only

A capability deriva tudo de `issuer + subject` validados e do banco.

Criação exige simultaneamente:

1. `current_app_user_id()` ativo;
2. exatamente uma membership `revoked_at IS NULL` do usuário em todo o banco;
3. team derivado não arquivado;
4. exatamente uma membership não revogada nesse team.

A mesma membership define `team_id`, `created_by_membership_id` e actor do evento.

Múltiplas memberships do usuário → deny por ambiguidade. Segundo membro não revogado na equipe → deny, inclusive se o usuário correspondente estiver desabilitado. Q-009 continua aberta.

### Capability própria

Foi escolhida capability técnica dedicada, equivalente a `compras_contracting_create_owner`, em vez de reutilizar F26.

Razão: criação precisa de `INSERT` em colunas específicas de `contractings`/`contracting_events`; ampliar a owner F26 violaria least privilege e misturaria duas autoridades independentes.

A nova role deve seguir ADR-005, permanecer `NOLOGIN`/`NOINHERIT`/não privilegiada, sem base-table ownership e sem membership utilizável. A primitive é `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

O runtime normal continua sem DML direto e recebe apenas `EXECUTE` explícito por provisionamento separado.

### Estado/evento

Criação nova persiste somente as colunas:

```text
id
team_id
object
created_by_membership_id
created_at
updated_at
```

Responsável, stage, status, waiting, next_action, archived/cancelled ficam `NULL`.

Na mesma transação nasce exatamente um evento:

```text
event_type = contracting_created
actor_membership_id = membership derivada
field_key = NULL
old_value = NULL
new_value = NULL
note = NULL
related_identifier_id = NULL
item_id = NULL
```

`created_at`, `updated_at`, `occurred_at` e `event.created_at` usam o mesmo `operation_at`. Falha do evento reverte a contratação.

### UUID/idempotência

O UUID da contratação é preparado pelo servidor antes do form e também funciona como idempotency key da solicitação preparada. Não é segredo nem autorização.

O event UUID é gerado server-side em cada tentativa e nunca vem do browser.

Replay com mesmo candidate UUID só retorna `already-created` quando, após autorização corrente, a linha existente prova exatamente:

- mesmo team derivado;
- mesmo `created_by_membership_id` derivado;
- mesmo `object`.

Colisão não equivalente ou cross-team vira `denied`/`not-available` genérico.

Double-submit concorrente do mesmo UUID deve produzir exatamente uma linha e um evento; um caller recebe `created` e os demais `already-created`.

Não foi criada infraestrutura/tabela externa de idempotência. A PK UUID existente é suficiente para a primeira jornada.

## Matriz resumida

| Caso | Resultado |
| --- | --- |
| identidade ativa + 1 membership + team solo não arquivado | criação elegível |
| zero membership | deny |
| >1 membership do usuário | deny |
| team com segundo membro não revogado | deny |
| team arquivado | deny |
| mesmo UUID/team/actor/object já criado | `already-created`, sem novo evento |
| mesmo UUID sem correspondência exata | deny genérico |
| falha do evento | rollback integral |
| falha técnica/configuração | `unavailable`, sem demo fallback |

## Red-team da decisão

O desenho rejeita explicitamente:

- team/actor/membership/issuer/subject/created_by confiáveis vindos do browser;
- seleção silenciosa entre múltiplas memberships;
- autorização multiusuário implícita;
- runtime com `INSERT` direto;
- reutilização/ampliação da capability F26;
- criador automaticamente responsável;
- stage/status/waiting/next_action obrigatórios na criação;
- evento fora da transação;
- idempotência por segredo client-side;
- deduplicação por texto de `object` sem regra aprovada;
- colisão cross-team distinguível;
- reescrita de migrations `0001..0004`;
- dado real/provider hosted/secrets.

## Questões preservadas

F28 não resolve:

- Q-001 — etapas;
- Q-002 — status;
- Q-006 — Pendência;
- Q-009 — permissões multiusuário.

## Implementação seguinte preparada

A SPEC `tasks/F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01/SPEC.md` define a implementação PostgreSQL/server-only da ADR-012, incluindo migration `0005`, capability/grants, idempotência concorrente, atomicidade e matriz adversarial.

Server Action/UI de cadastro continuam fora da F29 e deverão receber slice própria depois da boundary ser provada.

## Gates documentais pendentes

Antes de promover F28 para `COMPLETED / PASS` e avançar a `NEXT_ACTION`, a PR deve receber os gates de CI aplicáveis. Ausência de evidência não será convertida em PASS.

## Critério de encerramento

F28 fecha após ADR-012 + SPEC F29 passarem pelos gates do repositório e o checkpoint canônico avançar para exatamente uma nova `NEXT_ACTION`.
