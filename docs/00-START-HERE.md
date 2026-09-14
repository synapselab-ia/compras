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
- capability persistente separada para edição de `contractings.object`, com optimistic concurrency, auditoria atômica e adapter server-only.

F32 está integrada em `main` pela PR `#48`, merge `e7f893e8d186853b859dfb281f134d057b0b6e97`. CI, F22 Private Preview Preflight, F29 Contracting Create e F32 Contracting Object Mutation passaram antes e depois do merge.

A próxima e única frente canônica é F33, que conectará a boundary F32 ao detalhe persistente por uma Server Action/UI estreita para editar somente `Objeto`.

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

ADR-011 escolheu uma primitive PostgreSQL `SECURITY DEFINER` específica para alterar somente `contractings.next_action`.

Objetos principais:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- `database/tests/next_action_mutation.sql`;
- `src/server/database/trusted-mutation-context.ts`;
- `src/features/contracting-detail/persistent-mutation.ts`.

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

## F31/F32 - edição persistente de object

ADR-013 definiu e F32 implementou uma capability PostgreSQL própria para editar somente `contractings.object`, sem ampliar F26/F29.

Objetos principais:

- `database/migrations/0006_contracting_object_mutation.sql`;
- `database/provisioning/grant_contracting_object_mutation_runtime.sql`;
- `database/tests/contracting_object_mutation.sql`;
- `src/features/contracting-detail/persistent-object-mutation.ts`;
- `src/features/contracting-detail/persistent-object-mutation.test.ts`;
- `src/features/contracting-detail/persistent-object-mutation.postgres.test.ts`;
- `.github/workflows/f32-contracting-object-mutation.yml`.

A boundary aceita somente:

```text
contractingId
expectedObject
newObject
```

Event UUID nasce server-side. Team, actor, membership, issuer e subject não vêm do browser e são derivados do contexto confiável e do banco.

Propriedades provadas:

- role `compras_contracting_object_mutation_owner` é `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável;
- runtime normal não recebe DML direto e obtém somente `EXECUTE` explícito da primitive;
- autorização pilot-only segue F26 por equipe alvo, não o guard global de criação F29;
- segundo membro não revogado na equipe alvo bloqueia, inclusive quando o respectivo `app_user` está desabilitado;
- outra membership do mesmo usuário em equipe diferente não bloqueia por si só;
- `SELECT ... FOR UPDATE` serializa writers concorrentes;
- `expectedObject` é comparado exatamente e `conflict` é avaliado antes de `unchanged`;
- string vazia, espaços e leading/trailing spaces são preservados exatamente;
- no-op não altera `updated_at` nem cria evento;
- mudança real atualiza somente `object`/`updated_at` e cria exatamente um `object_changed` no mesmo instante de banco;
- falha de inserção do evento reverte estado e timestamp;
- cross-team, inexistente, arquivado, cancelado e demais negações são externamente colapsados;
- teste de 8 writers concorrentes produz exatamente 1 `updated`, 7 `conflict` e 1 evento.

PR `#48`, head `69e304c1fc47e0f548df70f4900b12b9a82d8483`:

- CI `34840241372`: PASS;
- F22 Private Preview Preflight `34840241356`: PASS;
- F29 Contracting Create `34840241361`: PASS;
- F32 Contracting Object Mutation `34840241521`: PASS.

Pós-merge `e7f893e8d186853b859dfb281f134d057b0b6e97`:

- CI `34840505900`: PASS;
- F22 Private Preview Preflight `34840505998`: PASS;
- F29 Contracting Create `34840505896`: PASS;
- F32 Contracting Object Mutation `34840505989`: PASS.

Nenhum provider hosted write, secret ou dado real foi usado.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01 - Integrar edição persistente do objeto no detalhe`.

F33 deve somente expor a authority F32 já integrada:

- Server Action dedicada a `contractingId + expectedObject + newObject`;
- preservação exata do texto, inclusive vazio/espaços;
- nenhum team/actor/membership/issuer/subject/event UUID confiado ao browser;
- feedback sanitizado para `updated`, `unchanged`, `conflict`, `not-available` e `unavailable`;
- conflito sem overwrite silencioso;
- revalidação por rota local fixa;
- demo estritamente read-only;
- editor somente de `Objeto`;
- migrations `0001..0006` e capabilities existentes imutáveis.

A SPEC é `tasks/F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01/SPEC.md`.

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
