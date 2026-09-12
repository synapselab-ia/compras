# Comece aqui — Compras

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
- boundary persistente mínima de criação de `contractings`, pilot-only, auditável e idempotente, integrada por F29.

F29 está integrada em `main` pela PR `#45`, merge `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`, com CI, F22 preflight e workflow F29 verdes pós-merge. A próxima frente é F30, que tornará o cadastro mínimo utilizável pela aplicação sem ampliar a boundary.

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

## F22 — preflight fictício

O preflight descartável prova:

- bootstrap somente fictício/`example.invalid`;
- Auth sem autorização interna → zero dados;
- usuário autorizado → somente própria equipe;
- UUID cross-team → invisível;
- claims inválidos → fail-closed;
- separação Auth/domínio;
- signup normal continua fechado.

O preflight também verifica isolamento das capabilities/runtimes introduzidos nas slices persistentes.

## F26/F27 — primeira mutação persistente utilizável

ADR-011 escolheu uma primitive PostgreSQL `SECURITY DEFINER` específica para alterar somente `contractings.next_action`.

Objetos principais:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- `database/tests/next_action_mutation.sql`;
- `src/server/database/trusted-mutation-context.ts`;
- `src/features/contracting-detail/persistent-mutation.ts`.

A capability `compras_next_action_mutation_owner` é `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. O runtime recebe apenas `EXECUTE` explícito, sem DML direto.

Q-009 permanece aberta. A escrita é pilot-only: identidade corrente deve ser o único membro não revogado da equipe alvo. Mudança real cria exatamente um `next_action_changed` na mesma transação; no-op não cria evento; stale expected retorna `conflict`.

F27 expõe essa operação apenas no detalhe persistente, com Server Action estreita, demo read-only e feedback sanitizado.

## F28/F29 — criação persistente mínima

ADR-012 definiu e F29 implementou a primeira boundary de criação de `contractings`.

### Payload e escopo

A boundary aceita somente:

```text
contractingId
object
```

`contractingId` é UUID preparado server-side e idempotency key não secreta. `object` é preservado exatamente, sem trim/tamanho/non-empty inventados além do `NOT NULL` físico.

Team, actor e `created_by_membership_id` são derivados da sessão Better Auth validada + banco. A criação exige:

- usuário interno ativo;
- exatamente uma membership não revogada do usuário em todo o banco;
- team derivado não arquivado;
- exatamente uma membership não revogada no team.

Múltiplas memberships ou segundo membro não revogado bloqueiam, mesmo se esse segundo `app_user` estiver desabilitado. Q-009 continua aberta.

### Capability própria

`database/migrations/0005_contracting_create.sql` introduz `compras_contracting_create_owner`, separada de F26:

- `NOLOGIN`, `NOINHERIT`, não privilegiada;
- sem ownership de tabelas-base ou membership utilizável;
- primitive `public.create_contracting_minimal(uuid,text,uuid)` `SECURITY DEFINER`;
- `search_path = pg_catalog`;
- `PUBLIC EXECUTE` revogado;
- grants/policies coluna-a-coluna;
- runtime normal sem DML direto.

`database/provisioning/grant_contracting_create_runtime.sql` concede somente `EXECUTE` à role runtime explícita e segura.

### Estado, evento e idempotência

A row inicial persiste somente ID, team derivado, `object`, creator derivado e timestamps. Responsible/stage/status/waiting/next_action/archived/cancelled ficam `NULL`.

Na mesma transação nasce exatamente um `contracting_created`; row/event compartilham o mesmo instante. Falha do evento reverte a criação.

Replay autorizado do mesmo UUID só retorna `already-created` quando team derivado, creator derivado e `object` coincidem exatamente. Mismatch/cross-team retorna negação genérica. Teste concorrente com oito writers prova uma única row, um único evento, um `created` e sete `already-created`.

### Adapter server-only

`src/features/contracting-create/persistent-create.ts` gera candidate/event UUIDs no servidor, chama apenas a primitive via `withTrustedDatabaseMutationContext`, não aceita identidade/escopo do browser, não possui demo fallback e sanitiza falhas técnicas.

O workflow `.github/workflows/f29-contracting-create.yml` executa red-team da capability, migration/provisionamento, matriz SQL e concorrência em PostgreSQL 17 descartável.

Gates finais da PR #45:

- CI `34696792923`: PASS;
- F22 Private Preview Preflight `34696792988`: PASS;
- F29 Contracting Create `34696792903`: PASS.

Pós-merge `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`:

- CI `34696856515`: PASS;
- F22 Private Preview Preflight `34696856531`: PASS;
- F29 Contracting Create `34696856481`: PASS.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F30-PERSISTENT-CONTRACTING-CREATE-UI-01 — Tornar cadastro persistente mínimo utilizável`.

F30 deve conectar somente uma jornada UI/Server Action estreita à boundary F29:

- candidate UUID preparado server-side antes da submissão;
- payload encaminhado estritamente `contractingId + object`;
- nenhuma escolha client-side de team/actor/membership/created_by/event UUID;
- demo e configuração inválida sem write;
- redirects locais fixos e feedback sanitizado;
- migrations `0001..0005` imutáveis;
- regressões F22/F26/F29/Auth verdes.

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

Arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, ADR-010, ADR-011, ADR-012.

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
