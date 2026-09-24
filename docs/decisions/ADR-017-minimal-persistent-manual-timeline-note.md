# ADR-017 - Criação persistente mínima e idempotente de nota manual na timeline

**Status:** Accepted  
**Data:** 2026-09-24  
**Escopo:** desenho da primeira criação persistente de nota manual em `contracting_events`; implementação na F44  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

O DOMAIN_MODEL prevê `nota manual` como evento da timeline e o DATABASE admite que esse evento use `note` sem `field_key`. A tabela `contracting_events` já é append-only, possui RLS forçada e contém todos os campos necessários.

A operação deve registrar uma observação manual sem alterar `contractings`, itens ou identificadores relacionados. F43 é design-only e não cria código operacional, migration, policy, grant, provisioning, adapter, Server Action ou UI.

Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas. Enquanto Q-009 estiver aberta, a escrita continua pilot-only.

## Decisão

A primeira nota manual será uma operação específica que insere exatamente um evento. A implementação F44 deve materializar primitive equivalente a:

```text
create_manual_timeline_note(
  p_contracting_id uuid,
  p_event_id uuid,
  p_note text
) returns text
```

`event_type` não é parâmetro. A capability sempre grava `manual_note_added`. Essa chave identifica somente este fato e não cria taxonomia geral de eventos.

## Payload e authority

O contrato server-only aceita apenas `contractingId`, `eventId` e `note: string | null`.

`contractingId` é seletor candidato, nunca authority. `eventId` é UUID técnico preparado por código server-side antes da primeira tentativa e preservado nos retries da mesma intenção. Uma futura UI pode apenas ecoar esse candidate; conhecer ou forjar um UUID não concede scope, actor ou autorização.

Team, actor, membership, issuer, subject, `event_type`, timestamps, `field_key`, old/new, item e related identifier são sempre derivados ou fixos fora da authority do browser.

## Shape fechado

Um sucesso insere somente:

```text
id = eventId
team_id = team derivado da contratação autorizada
contracting_id = contratação autorizada
actor_membership_id = membership derivada
event_type = 'manual_note_added'
occurred_at = operation_at
field_key = NULL
old_value = NULL
new_value = NULL
note = p_note exata
related_identifier_id = NULL
item_id = NULL
created_at = operation_at
```

`operation_at` é gerado dentro da primitive. `contractings.updated_at` não é alterado, pois a movimentação já está representada na timeline.

## Semântica de `note`

A coluna é `text NULL` e não existe regra canônica non-empty. A boundary preserva distintamente `NULL`, `''`, spaces-only e leading/trailing spaces. Não há trim, empty-to-NULL, case-folding, limite arbitrário, sanitização de persistência, contrato Markdown/HTML, categoria ou prioridade.

Permitir esses estados é preservação do contrato físico, não decisão de UX. Renderização futura deve escapar conteúdo conforme o contexto sem reescrever o valor persistido.

## Idempotência, replay e concorrência

O próprio evento é a entidade criada. Gerar novo UUID a cada retry poderia duplicar a mesma intenção, enquanto deduplicar por texto inventaria chave de negócio. Por isso, `eventId` é estável por intenção.

Depois de autorizar novamente a contratação candidata, um evento já existente com o mesmo `eventId` só é replay válido quando forem provados simultaneamente: mesmo team e contracting derivados, mesmo actor membership, `event_type = 'manual_note_added'`, `note IS NOT DISTINCT FROM p_note`, field/old/new/related/item nulos e `created_at = occurred_at`.

Se a prova falhar, a colisão é negação sanitizada. Dois IDs diferentes com a mesma nota podem criar dois eventos, pois não há deduplicação por conteúdo.

Chamadas concorrentes com mesmo `eventId` e payload devem produzir exatamente um evento, uma resposta `created` e as demais `already-added` após prova exata. Mesmo ID com nota diferente não faz overwrite. Colisão cross-team, em outra contratação ou com outro `event_type` não pode virar oracle.

A PK de `contracting_events(id)` é o backstop técnico. A F44 pode usar `INSERT ... ON CONFLICT DO NOTHING` e releitura autorizada, ou mecanismo equivalente, desde que conflito não equivalente nunca vire sucesso.

## Autorização pilot-only

Usar o guard target-team já adotado em F26/F32/F35/F38/F41. A operação exige: app_user corrente ativo; contratação candidata visível e ativa; membership não revogada do usuário na equipe alvo; e exatamente uma membership não revogada nessa equipe.

Uma segunda membership não revogada bloqueia, mesmo se o respectivo app_user estiver desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia por si só. Isso preserva Q-009 aberta.

Inexistente, cross-team, usuário desabilitado, membership ausente/revogada, segundo membro, contratação arquivada/cancelada e colisão sem replay exato devem colapsar para a mesma negação protegida.

## Capability e least privilege

A F44 deve criar capability dedicada equivalente a `compras_manual_timeline_note_create_owner`, selada como `NOLOGIN`, `NOINHERIT`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE` e `NOREPLICATION`, sem `rolconfig`, ownership de tabela-base ou membership utilizável.

A primitive deve ser `SECURITY DEFINER`, fixar `search_path = pg_catalog`, usar SQL estático e ter `PUBLIC EXECUTE` revogado. Runtime normal recebe somente `EXECUTE` por provisioning separado.

Grants máximos: resolução mínima de identidade; leitura das memberships do guard; leitura mínima da contratação alvo; leitura mínima de `contracting_events` para replay; e INSERT coluna-a-coluna apenas de `id`, `team_id`, `contracting_id`, `actor_membership_id`, `event_type`, `occurred_at`, `note` e `created_at`.

A capability não recebe UPDATE/DELETE de eventos, DML em `contractings`, itens, identifiers ou allocator, nem authority de primitives anteriores. F26/F29/F32/F35/F38/F41 não recebem grants novos.

## RLS esperada

A migration F44 deve adicionar somente policies específicas necessárias à capability. Memberships precisam permitir à role selada contar memberships não revogadas. A contratação deve ficar restrita ao alvo ativo autorizado pelo guard pilot-only.

A leitura de eventos usada no replay deve ser restrita a `manual_note_added` em contratações ativas e autorizadas. A policy de INSERT deve exigir actor corrente, único membro não revogado na equipe alvo, contratação ativa, event type fixo, field/old/new/related/item nulos e `created_at = occurred_at`. `note` permanece sem restrição de conteúdo adicional.

## Resultados

A primitive distingue apenas `created`, `already-added` e `denied`. O adapter server-only expõe `created`, `already-added`, `not-available` para negação protegida e `unavailable` para falha técnica, configuração, contexto, UUID inválido ou resultado impossível.

Nenhum resultado expõe team, actor, membership, timestamps, SQL ou motivo específico da negação. Falha persistente nunca cai para demo.

## Verificação obrigatória da F44

A implementação deve provar autorização positiva e negativa, opacidade cross-team/inexistente/inativa, segundo membro, preservação de NULL/vazio/espaços, shape fechado, ausência de DML runtime, capability selada, replay exato, colisões divergentes, concorrência real com um único evento, não deduplicação por texto e regressões F22/F29/F32/F35/F38/F41.

Migrations `0001..0010` devem permanecer byte-for-byte. F44 começa em migration aditiva `0011`.

## Red-team

Rejeitar qualquer implementação que transforme nota em primitive genérica, aceite authority de scope/actor/timestamps/event type do browser, gere novo ID automaticamente em todo retry, deduplique por texto, reconheça colisão sem replay exato, amplie capabilities anteriores, conceda DML direto à runtime, permita UPDATE/DELETE de eventos, mute estado estruturado, normalize texto sem fonte, invente categoria/prioridade/Pendência, altere `contractings.updated_at` apenas para sinalizar nota, reescreva migrations, resolva questão aberta implicitamente ou dependa de provider hosted, secret ou dado real.

## Fora do escopo

UI, Server Action, edição/exclusão de evento, evento genérico configurável, mutations de responsável/etapa/status/waiting/próxima ação, Pendência, edição/desvínculo de identificador, pesquisa de preços, política multiusuário, auditoria de leitura, provider hosted e dado real permanecem fora.

## Próxima implementação

A F44 deve implementar exatamente esta boundary com migration aditiva `0011`, capability dedicada, RLS/grants mínimos, primitive, provisioning, adapter server-only, helper de preparo do `eventId`, testes SQL adversariais, prova PostgreSQL concorrente e workflow/regressões aplicáveis.
