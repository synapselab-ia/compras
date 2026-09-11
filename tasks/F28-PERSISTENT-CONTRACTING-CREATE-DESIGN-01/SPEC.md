# F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01 — Desenhar criação persistente mínima de contratação

**Classe:** T5 — decisão/arquitetura, com impacto T2 — autorização/banco  
**Estado:** COMPLETED / PASS  
**Dependências:** F27, ADR-003, ADR-005, ADR-009 e ADR-011  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Resultado

F28 produziu e aprovou a `ADR-012-minimal-persistent-contracting-creation.md`, definindo a primeira criação persistente de `contractings` sem implementar migration, Server Action ou UI.

A implementação executável seguinte está especificada em `tasks/F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01/SPEC.md`.

## Recuperação e contexto

Antes de iniciar F28, a sessão fechou a frente anterior:

- F27 PR `#43`: MERGED;
- merge F27: `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`;
- CI pós-merge F27 `34615115211`: PASS;
- F22 Private Preview Preflight pós-merge F27 `34615115289`: PASS.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 blobs estáveis e permaneceu `VALID`.

A inspeção F28 cobriu PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, SECURITY, DATABASE, ADR-003/005/009/011, migrations `0001..0004`, constraints de `contractings`/`contracting_events`, boundary/testes F26/F27 e Definition of Done.

Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## Decisões fechadas pela ADR-012

### Payload mínimo

A solicitação de criação possui somente:

- `contractingId` — UUID opaco preparado server-side antes da submissão e ecoado como selector/idempotency key, nunca como autoridade;
- `object` — texto estruturalmente obrigatório e preservado exatamente, sem trim, limite de tamanho ou regra non-empty inventada.

`next_action` fica fora da criação inicial e permanece para F26/F27 após a linha existir. Stage, status, responsável, waiting, itens e identificadores também não entram na criação e os campos nullable nascem `NULL`.

### Escopo/ator pilot-only

A criação deriva tudo da sessão Better Auth validada + contexto LOCAL `iss/sub` + banco.

É elegível somente quando:

1. `current_app_user_id()` resolve para usuário ativo;
2. o usuário possui exatamente uma membership `revoked_at IS NULL` em todo o banco;
3. a equipe derivada não está arquivada;
4. a equipe possui exatamente uma membership não revogada.

A membership derivada define `team_id`, `created_by_membership_id` e actor do evento.

Múltiplas memberships do usuário bloqueiam por ambiguidade. Segundo membro não revogado na equipe bloqueia, inclusive se seu app_user estiver desabilitado. Q-009 continua aberta.

### Capability própria

Criação recebe owner técnico dedicado equivalente a `compras_contracting_create_owner`; F26 não é ampliada.

A role deve seguir ADR-005: `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. A primitive deve ser `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

Runtime normal permanece sem `INSERT` direto e recebe somente `EXECUTE` explícito por provisionamento separado.

### Estado e histórico

A contratação nova persiste apenas:

```text
id
team_id
object
created_by_membership_id
created_at
updated_at
```

Responsável, stage, status, waiting, next_action, archived/cancelled ficam `NULL`.

Na mesma transação nasce exatamente um `contracting_created`, com actor/team/contracting derivados e `field_key`, old/new, note, related_identifier e item nulos.

`contractings.created_at`, `contractings.updated_at`, `event.occurred_at` e `event.created_at` usam o mesmo instante. Falha do evento reverte a contratação.

### Idempotência

O candidate UUID da contratação também é a idempotency key da solicitação preparada. Não é segredo nem autorização.

O event UUID é gerado server-side em cada tentativa e não vem do browser.

Replay só retorna `already-created` quando, após autorização corrente, a linha existente prova mesmo team derivado, mesmo created_by derivado e mesmo `object`. Campos mutáveis posteriores não entram na comparação.

Colisão não equivalente ou cross-team retorna negação genérica.

Double-submit concorrente com o mesmo candidate UUID deve resultar em exatamente uma linha, um evento, um `created` e os demais `already-created`.

Não existe deduplicação semântica por `object`: formulários preparados independentemente recebem UUIDs diferentes e não são considerados a mesma solicitação.

## Matriz adversarial fechada

A implementação seguinte deve provar, entre outros:

- team/actor/membership/issuer/subject/created_by não vêm do browser;
- zero ou múltiplas memberships do usuário → deny;
- team arquivado → deny;
- segundo membro não revogado → deny;
- runtime sem DML direto;
- capability de criação sem UPDATE/DELETE e sem authority F26;
- F26 sem INSERT de criação;
- estado inicial deixa campos não aprovados `NULL`;
- evento único e atômico;
- rollback em falha de evento;
- replay sequencial idempotente;
- concorrência do mesmo request → 1 row/1 event;
- mismatch/cross-team não vira `already-created` nem side channel;
- `0001..0004` imutáveis;
- Auth/read-only runtimes não herdam nova capability;
- nenhum secret/dado real/provider hosted.

## Red-team F28

Foram rejeitados no desenho:

- browser escolher team/actor/created_by;
- selecionar silenciosamente uma membership entre várias;
- resolver Q-009 implicitamente;
- reutilizar/ampliar a capability F26;
- `INSERT` direto no runtime;
- criador virar responsável automaticamente;
- tornar stage/status/waiting/next_action obrigatórios;
- criar sem evento atômico;
- idempotência por segredo client-side;
- deduplicação por conteúdo sem regra aprovada;
- colisão cross-team distinguível;
- reescrita de migrations aplicadas.

Q-001, Q-002, Q-006 e Q-009 permanecem abertas.

## Verificação final

Head final da PR `#44`: `d58f811eda8b99dd8c4dc28d1adc7f2b7d0e91ca`.

- CI PR `34616939065`: PASS;
  - verify: PASS — lint, typecheck, testes e build;
  - database: PASS — foundation/RLS/F26;
  - auth-database: PASS — Better Auth/F24;
- F22 Private Preview Preflight PR `34616938983`: PASS.

PR `#44`: MERGED em `04b3e063314180e683e76adbe7c9c5affd53e14f`.

Pós-merge:

- CI `34617114461`: PASS — verify, database e auth-database;
- F22 Private Preview Preflight `34617114500`: PASS.

O diff final F28 continha somente documentação/SPEC. A revisão não encontrou connection strings, hostnames de provider, secrets, dados reais, migration reescrita, runtime alterado ou provider hosted write.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- somente exemplos fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS continua autoritativa;
- runtime normal continua sem CRUD amplo;
- migrations `0001..0004` permanecem imutáveis;
- F26/F27 continuam sendo a única escrita executável integrada até F29.

## Próxima ação

A única próxima ação é `F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01`, que deve implementar e provar em PostgreSQL 17 descartável a boundary definida pela ADR-012, sem Server Action/UI de cadastro nesta slice.

## Critério de encerramento

F28 está encerrada porque ADR-012 define payload, escopo/ator, capability, evento e idempotência de forma executável, a SPEC F29 materializa a implementação seguinte e todos os gates de PR e pós-merge permaneceram verdes.
