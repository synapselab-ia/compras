# Comece aqui - Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui sistemas oficiais. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados. `REAL_DATA_ALLOWED = NO`.

## Estado atual

A fundação já possui:

- Central do Setor e detalhe da contratação;
- PostgreSQL default-deny com `FORCE RLS`;
- identidade confiável `issuer + subject` estabelecida no servidor;
- leituras persistentes protegidas e diretório mínimo da equipe;
- Better Auth self-hosted com signup normal fechado;
- controle distribuído de abuso de sign-in;
- capability persistente estreita para `contractings.next_action` e UI correspondente;
- boundary persistente mínima de criação de `contractings`, pilot-only, auditável e idempotente, com jornada UI/Server Action integrada;
- capability persistente separada para edição de `contractings.object`;
- UI/Server Action persistente de edição de `Objeto` integrada sobre F32;
- ADR-014 aceita para criação persistente mínima de `contracting_items`.

F34 fechou o desenho de item create sem código operacional. A próxima e única frente canônica é F35, implementação PostgreSQL/server-only dessa boundary.

F17 permanece `ON HOLD` histórico. F21 permanece `ON HOLD` antes de secrets até existir control plane Vercel capaz de readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch sem expor valores.

A faixa F18 de demonstração continua exclusivamente fictícia e sem write persistente.

## Auth e sign-in

O runtime privado usa Better Auth self-hosted com PostgreSQL:

- `better-auth@1.6.23` pinado;
- email/senha habilitado;
- signup normal desabilitado;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- subject somente de sessão validada server-side;
- `/api/auth/[...path]` permanece deny-all para superfícies genéricas não usadas;
- sign-in/sign-out passam por Server Actions estreitas.

Migrations Auth ficam em `database/auth/migrations/`. Auth runtime e domain runtime permanecem separados e não privilegiados.

F24 adicionou limiter distribuído PostgreSQL para sign-in. Falha de limiter/configuração/store fecha o acesso; não existe fallback permissivo.

## Leituras e preflight

O modelo persistente usa identidade validada no servidor, contexto transacional LOCAL e RLS/capabilities no PostgreSQL.

O preflight F22 usa somente dados fictícios e prova, entre outros pontos:

- Auth sem autorização interna resulta em zero dados;
- usuário autorizado vê somente a própria equipe;
- UUID cross-team fica invisível;
- claims inválidos falham fechado;
- Auth e domínio permanecem separados;
- signup normal continua fechado;
- capabilities/runtimes não recebem authority indevida.

## F26/F27 - mutação de próxima ação

ADR-011 escolheu primitive PostgreSQL `SECURITY DEFINER` específica para alterar somente `contractings.next_action`.

A capability `compras_next_action_mutation_owner` é não privilegiada e separada. O runtime recebe apenas `EXECUTE` explícito, sem DML direto.

A escrita é pilot-only enquanto Q-009 permanecer aberta. Mudança real cria exatamente um `next_action_changed` na mesma transação; no-op não cria evento; stale expected retorna `conflict`.

F27 expõe essa operação apenas no detalhe persistente, com Server Action estreita, demo read-only e feedback sanitizado.

## F28/F29/F30 - criação persistente mínima de contratação

ADR-012 definiu e F29 implementou a boundary mínima de criação de `contractings`. F30 integrou a jornada UI/Server Action sem ampliar authority.

A boundary aceita somente:

```text
contractingId
object
```

`contractingId` é UUID preparado server-side e chave de idempotência não secreta. `object` é preservado exatamente, sem trim, limite de tamanho ou regra non-empty inventada além do `NOT NULL` físico.

Team, actor e `created_by_membership_id` são derivados da sessão validada e do banco. A criação continua pilot-only e Q-009 permanece aberta.

A capability F29 é própria, separada de F26, e o runtime recebe somente `EXECUTE`. A row inicial e o evento `contracting_created` são atômicos.

## F31/F32/F33 - edição persistente de objeto

ADR-013 definiu e F32 implementou capability PostgreSQL própria para editar somente `contractings.object`, sem ampliar F26/F29.

A boundary aceita somente:

```text
contractingId
expectedObject
newObject
```

Event UUID nasce server-side. Team, actor, membership, issuer e subject não vêm do browser. `SELECT ... FOR UPDATE` e comparação exata do expected value evitam lost update. String vazia e espaços são preservados. No-op não altera timestamp nem cria evento. Mudança real atualiza somente `object`/`updated_at` e cria exatamente um `object_changed` atômico.

F33 conecta essa boundary ao detalhe persistente por Server Action/UI estreita. Conflito força readback/revisão e nunca sobrescreve silenciosamente. Demo permanece read-only.

F33 foi integrada em `main` pela PR `#49`, merge `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`. O checkpoint posterior foi integrado pela PR `#50`, merge `bfa9a65fae06ef8c3cc29586287160be3ab29d31`.

## F34 - desenho de criação persistente de item

ADR-014 define a próxima boundary sem implementar SQL nesta slice.

### Payload da futura boundary

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` será transportada como `string | null` no adapter server-only e convertida apenas pelo parâmetro PostgreSQL `numeric`, evitando precisão perdida por `Number` JavaScript.

Item UUID e event UUID nascem server-side. Team, actor, membership, issuer, subject e ordinal não são confiados ao browser.

Não existem regras novas de trim, empty-to-NULL, descrição non-empty, quantidade positiva, unidade obrigatória, catálogo obrigatório, limite de tamanho ou escala de negócio. Q-004 continua aberta.

### Autorização

Como a contratação alvo já existe, F35 seguirá o guard por equipe alvo de F26/F32:

- identidade interna ativa;
- contratação visível, não arquivada e não cancelada;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. Q-009 continua aberta.

### Ordinal

`ordinal` será atribuído no banco, nunca pelo cliente.

A primitive deverá bloquear a contratação pai com `SELECT ... FOR UPDATE`, depois calcular `MAX(ordinal) + 1`, usando `1` quando ainda não houver item. Itens retirados continuam no máximo e gaps não são reutilizados.

Isso serializa writers da mesma contratação sem criar lock global entre contratações diferentes. A constraint `UNIQUE (contracting_id, ordinal)` permanece como backstop, não como mecanismo de retry cego.

### Capability e auditoria

F35 criará capability própria equivalente a `compras_contracting_item_create_owner`, sem ampliar F26/F29/F32. Runtime normal continuará sem DML direto.

Uma criação bem-sucedida inserirá exatamente um item e exatamente um evento `item_created` na mesma transação. Falha do evento reverte o item. `contractings.updated_at` não será alterado por esta operação.

A futura boundary server-only exporá somente `created`, `not-available` e `unavailable`.

O desenho completo está em `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md` e a implementação em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01 - Implementar criação persistente mínima de item`.

F35 deve implementar exclusivamente ADR-014: migration `0007`, capability própria, primitive, provisioning, adapter server-only, matriz PostgreSQL 17, teste real de concorrência e workflow dedicado.

UI e Server Action de item permanecem fora dessa slice.

## Modos da aplicação

### Demo

Quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`:

- somente fixtures fictícias;
- nenhuma consulta/mutação operacional;
- banner explícito de protótipo.

### Persistente

Somente com todos os gates Auth/banco/configuração/autorização válidos:

```text
sessão Better Auth validada
-> issuer + subject
-> contexto transacional LOCAL
-> role de domínio não privilegiada
-> RLS / capability estreita
-> somente registros e operações autorizados
```

Falha protegida nunca vira demo silenciosamente.

## Banco canônico

Migrations imutáveis do domínio atualmente integradas:

- `0001_core_foundation.sql`;
- `0002_trusted_identity_read_policies.sql`;
- `0003_team_member_directory.sql`;
- `0004_next_action_mutation.sql`;
- `0005_contracting_create.sql`;
- `0006_contracting_object_mutation.sql`.

Migration aplicada não é reescrita. F35 deverá acrescentar `0007`, sem modificar a história anterior.

## Fonte de verdade

GitHub é canônico. Chat é descartável.

Startup mínimo:

1. `AGENTS.md`;
2. `docs/00-START-HERE.md`;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. abrir SPEC/ADR/código exigidos pela tarefa ativa.

## Fontes principais

Produto: `PROJECT_DESIGN.md`, `DOMAIN_MODEL.md`, `BUSINESS_WORKFLOW.md`, `OPEN_QUESTIONS.md`.

Arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, ADR-010, ADR-011, ADR-012, ADR-013, ADR-014.

Operação por IA: `SOURCE_OF_TRUTH.md`, `WORK_PROTOCOL.md`, `CONTEXT_MANIFEST.md`, `CURRENT_STATE.md`, `NEXT_ACTION.md`.

Qualidade: `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- segurança nunca é reduzida para fazer passar;
- autenticação não é autorização;
- RLS/autorização crítica permanecem no servidor/banco;
- cliente nunca define identidade/escopo;
- signup público não é criado por conveniência;
- dado real/interno/pré-publicação não entra no repositório público;
- role privilegiada nunca é runtime normal;
- secrets nunca vão para Git/chat/URL/log/artifact público;
- blocker externo objetivo entra `ON HOLD` sem paralisar trabalho independente;
- falha protegida nunca cai para demo;
- migrations aplicadas são imutáveis;
- construir por slices pequenas, verificáveis e reversíveis.