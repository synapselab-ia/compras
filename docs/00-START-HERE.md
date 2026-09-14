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
- UI/Server Action persistente de edição de `Objeto` integrada sobre a boundary F32, sem ampliar authority PostgreSQL.

F33 está integrada em `main` pela PR `#49`, merge `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`. CI, F22 Private Preview Preflight, F29 Contracting Create e F32 Contracting Object Mutation passaram antes e depois do merge.

A próxima e única frente canônica é F34, design-only para criação persistente mínima de item dentro de uma contratação existente.

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

## F22 - preflight fictício

O preflight descartável prova:

- bootstrap somente fictício/`example.invalid`;
- Auth sem autorização interna resulta em zero dados;
- usuário autorizado vê somente a própria equipe;
- UUID cross-team fica invisível;
- claims inválidos falham fechado;
- Auth e domínio permanecem separados;
- signup normal continua fechado;
- capabilities/runtimes persistentes não recebem authority indevida.

## F26/F27 - mutação de próxima ação

ADR-011 escolheu primitive PostgreSQL `SECURITY DEFINER` específica para alterar somente `contractings.next_action`.

A capability `compras_next_action_mutation_owner` é não privilegiada e separada. O runtime recebe apenas `EXECUTE` explícito, sem DML direto.

Q-009 permanece aberta. A escrita é pilot-only. Mudança real cria exatamente um `next_action_changed` na mesma transação; no-op não cria evento; stale expected retorna `conflict`.

F27 expõe essa operação apenas no detalhe persistente, com Server Action estreita, demo read-only e feedback sanitizado.

## F28/F29/F30 - criação persistente mínima

ADR-012 definiu e F29 implementou a boundary de criação mínima de `contractings`. F30 integrou a jornada UI/Server Action sem ampliar authority.

A boundary aceita somente:

```text
contractingId
object
```

`contractingId` é UUID preparado server-side e idempotency key não secreta. `object` é preservado exatamente, sem trim, limite de tamanho ou regra non-empty inventados além do `NOT NULL` físico.

Team, actor e `created_by_membership_id` são derivados da sessão Better Auth validada e do banco. A criação continua pilot-only e Q-009 permanece aberta.

`database/migrations/0005_contracting_create.sql` introduz capability própria, separada de F26. O runtime recebe somente `EXECUTE` explícito, sem DML direto.

A row inicial e o evento `contracting_created` são atômicos. Replay autorizado do mesmo candidate UUID retorna `already-created` somente quando os dados canônicos coincidem exatamente. Colisão/mismatch/cross-team retorna negação genérica.

## F31/F32/F33 - edição persistente de objeto

ADR-013 definiu e F32 implementou capability PostgreSQL própria para editar somente `contractings.object`, sem ampliar F26/F29.

Objetos principais da boundary:

- `database/migrations/0006_contracting_object_mutation.sql`;
- `database/provisioning/grant_contracting_object_mutation_runtime.sql`;
- `database/tests/contracting_object_mutation.sql`;
- `src/features/contracting-detail/persistent-object-mutation.ts`;
- `.github/workflows/f32-contracting-object-mutation.yml`.

A boundary aceita somente:

```text
contractingId
expectedObject
newObject
```

Event UUID nasce server-side. Team, actor, membership, issuer e subject não vêm do browser. `SELECT ... FOR UPDATE` + comparação exata do expected value evitam lost update. String vazia e espaços são preservados. No-op não altera timestamp nem cria evento. Mudança real atualiza somente `object`/`updated_at` e cria exatamente um `object_changed` atômico. Falha do evento reverte o update.

F33 conecta essa boundary ao detalhe persistente:

- Server Action lê somente `contractingId`, `expectedObject` e `newObject`;
- scalars duplicados/ausentes falham fechado;
- team/actor/membership/issuer/subject/event UUID/callback não são authority do browser;
- erro inesperado vira somente `unavailable`;
- revalidação/redirect usam rota local fixa;
- feedback externo é limitado a `updated`, `unchanged`, `conflict`, `not-available` e `unavailable`;
- conflito força readback/revisão e nunca sobrescreve silenciosamente;
- demo permanece read-only e ignora feedback forjado;
- nenhuma migration, grant, policy, capability ou primitive foi alterada.

PR F33 `#49`, head `81f926b91657fe6de458d4ad01aee15f62672592`:

- CI `34850892351`: PASS;
- F22 Private Preview Preflight `34850892414`: PASS;
- F29 Contracting Create `34850892361`: PASS;
- F32 Contracting Object Mutation `34850892323`: PASS.

Pós-merge `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`:

- CI `34851216964`: PASS;
- F22 Private Preview Preflight `34851216895`: PASS;
- F29 Contracting Create `34851216887`: PASS;
- F32 Contracting Object Mutation `34851217022`: PASS.

Nenhum provider hosted write, secret ou dado real foi usado.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item`.

F34 deve permanecer design-only e partir do schema já integrado de `contracting_items`:

- `id` UUID;
- `contracting_id` + `team_id`;
- `ordinal` inteiro único por contratação;
- `description text NOT NULL`;
- `quantity`, `unit` e `catalog_code` nullable;
- timestamps e `retired_at`.

A slice deve decidir payload mínimo, UUIDs server-side, autorização por equipe alvo, atribuição concorrente de `ordinal`, capability least-privilege, evento atômico e matriz adversarial da futura F35.

Não pode inventar validações de quantidade/unidade/catálogo nem resolver Q-004 de pesquisa de preços ou Q-009 de política multiusuário.

A SPEC é `tasks/F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01/SPEC.md`.

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

Migration aplicada não é reescrita; correção futura usa nova migration.

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

Arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, ADR-010, ADR-011, ADR-012, ADR-013.

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