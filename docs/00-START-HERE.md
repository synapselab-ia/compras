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
- capability persistente estreita para `contractings.next_action`;
- UI persistente do detalhe capaz de editar somente `Próxima ação`;
- boundary persistente mínima de criação de `contractings`, pilot-only, auditável e idempotente;
- jornada UI/Server Action mínima de criação persistente integrada por F30;
- ADR-013 integrada, definindo capability separada para futura edição persistente de `contractings.object`.

F31 está integrada em `main` pela PR `#47`, merge `b541592aa4a392dfab439389daaddcd4c811c5e5`, com CI, F22 Private Preview Preflight e F29 Contracting Create verdes antes e depois do merge.

A próxima frente canônica é F32, que implementará somente a boundary PostgreSQL/server-only de edição de `object`, sem UI/Server Action nesta slice.

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

## F28/F29 - criação persistente mínima

ADR-012 definiu e F29 implementou a boundary de criação mínima de `contractings`.

A boundary aceita somente:

```text
contractingId
object
```

`contractingId` é UUID preparado server-side e idempotency key não secreta. `object` é preservado exatamente, sem trim, limite de tamanho ou regra non-empty inventados além do `NOT NULL` físico.

Team, actor e `created_by_membership_id` são derivados da sessão Better Auth validada e do banco. A criação continua pilot-only e Q-009 permanece aberta.

`database/migrations/0005_contracting_create.sql` introduz capability própria, separada de F26. O runtime recebe somente `EXECUTE` explícito, sem DML direto.

A row inicial e o evento `contracting_created` são atômicos. Replay autorizado do mesmo candidate UUID retorna `already-created` somente quando os dados canônicos coincidem exatamente. Colisão/mismatch/cross-team retorna negação genérica.

## F30 - criação persistente utilizável

F30 conecta a aplicação à boundary F29 sem ampliar authority:

- entrada `Cadastrar nova contratação` somente no modo persistente;
- `/contratacoes/nova` falha fechado em demo/configuração inválida;
- candidate UUID preparado server-side antes da submissão;
- formulário sem controles de team/actor/membership/creator/event/stage/status/responsável/waiting/next_action;
- Server Action lê cada scalar confiável uma única vez e rejeita duplicatas;
- somente `{ contractingId, object }` chega a `createPersistentContracting`;
- `object` é preservado exatamente, inclusive string vazia;
- forged authority/callback/redirect/event fields não são encaminhados;
- redirects usam somente rotas locais fixas e estado público sanitizado;
- `useFormStatus` bloqueia repetição acidental enquanto pendente;
- retry após resultado técnico incerto preserva o mesmo candidate UUID validado para manter a idempotência da ADR-012.

Gates finais da PR #46:

- CI `34700169464`: PASS;
- F22 Private Preview Preflight `34700169506`: PASS;
- F29 Contracting Create `34700169547`: PASS.

Pós-merge `c0f6e822253e9e324f00bc674f4805f52cbca16c`:

- CI `34700243224`: PASS;
- F22 Private Preview Preflight `34700243225`: PASS;
- F29 Contracting Create `34700243158`: PASS.

## F31 - desenho da edição persistente de object

ADR-013 define a próxima mutação sem ampliar F26/F29.

A decisão adota uma capability PostgreSQL própria, equivalente a `compras_contracting_object_mutation_owner`, com primitive conceitualmente equivalente a:

```text
mutate_contracting_object(
  contractingId,
  expectedObject,
  newObject,
  eventId server-only
)
```

Propriedades decididas:

- browser não define team/actor/membership/creator/issuer/subject/event UUID;
- `object` continua `text NOT NULL` e é preservado exatamente, inclusive string vazia e espaços;
- autorização pilot-only segue F26 por equipe alvo;
- segundo membro não revogado na equipe alvo bloqueia, inclusive app_user desabilitado;
- membership adicional do mesmo usuário em outra equipe não bloqueia por si só, pois a row existente já define o team;
- `SELECT ... FOR UPDATE` + expected object exato evitam lost update;
- `conflict` é avaliado antes de `unchanged`;
- no-op não altera timestamp nem cria evento;
- mudança real atualiza somente `object`/`updated_at` e cria exatamente um `object_changed` atômico;
- falha do evento reverte o update;
- runtime continua sem DML direto;
- F26 permanece exclusiva de `next_action`;
- F29 permanece exclusiva de criação mínima;
- Q-009 continua aberta.

F31 não implementou migration, SQL, adapter, Server Action ou UI.

Gates finais da PR #47:

- CI `34702329753`: PASS;
- F22 Private Preview Preflight `34702329739`: PASS;
- F29 Contracting Create `34702329761`: PASS.

Pós-merge `b541592aa4a392dfab439389daaddcd4c811c5e5`:

- CI `34702460575`: PASS;
- F22 Private Preview Preflight `34702460564`: PASS;
- F29 Contracting Create `34702460571`: PASS.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01 - Implementar boundary persistente de edição do objeto`.

F32 deve materializar somente PostgreSQL/server-only:

- nova migration `0006_...sql` sem reescrever `0001..0005`;
- capability própria e least privilege;
- primitive `SECURITY DEFINER` com `search_path` fixo;
- concorrência por expected object;
- evento `object_changed` atômico;
- adapter server-only sanitizado;
- matriz adversarial e concorrência PostgreSQL 17;
- regressões F22/F26/F29/Auth verdes.

UI/Server Action de edição fica para work unit posterior.

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
- `0005_contracting_create.sql`.

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
