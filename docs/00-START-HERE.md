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
- capability persistente de escrita limitada a `contractings.next_action`;
- UI persistente do detalhe capaz de editar somente `Próxima ação` por Server Action estreita.

F27 está integrada em `main`. F28 também está integrada e definiu pela ADR-012 a fronteira da primeira criação persistente mínima de contratação. A implementação da boundary fica para F29.

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

O preflight também verifica que runtimes Auth/read-only não herdam `EXECUTE` da capability F26.

## F26/F27 — primeira mutação persistente utilizável

ADR-011 escolheu uma primitive PostgreSQL `SECURITY DEFINER` específica para alterar somente `contractings.next_action`.

Objetos principais F26:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- `database/tests/next_action_mutation.sql`;
- `src/server/database/trusted-mutation-context.ts`;
- `src/features/contracting-detail/persistent-mutation.ts`.

A capability owner `compras_next_action_mutation_owner` é `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. A função tem `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

O runtime normal permanece sem `UPDATE`/`INSERT` direto; recebe somente `EXECUTE` explícito da primitive.

Q-009 permanece aberta. A escrita é pilot-only: a identidade corrente precisa possuir a única membership `revoked_at IS NULL` da equipe alvo. Segundo membro não revogado bloqueia a mutação.

Mudança real atualiza `next_action`/`updated_at` e cria exatamente um `next_action_changed` na mesma transação. No-op não cria evento; expected stale retorna `conflict`. Teste concorrente prova um único winner/evento.

F27 tornou a capability utilizável no detalhe persistente:

- somente `Próxima ação` é editável;
- demo permanece estritamente read-only;
- Server Action encaminha somente candidate ID + expected + novo valor;
- browser não define actor/team/membership/issuer/subject/event UUID;
- `NULL` e string vazia permanecem distintos;
- conflito não sobrescreve silenciosamente;
- feedback é sanitizado e falha protegida não cai para demo.

F27 foi integrada pela PR `#43`, merge `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`. Pós-merge:

- CI `34615115211`: PASS;
- F22 Private Preview Preflight `34615115289`: PASS.

## F28 — criação persistente mínima desenhada

A ADR-012 define a primeira boundary de criação de `contractings` sem ainda implementá-la.

### Payload

A futura criação aceita semanticamente apenas:

```text
contractingId
object
```

`contractingId` é UUID preparado pelo servidor antes da submissão e também funciona como idempotency key da solicitação preparada. Não é segredo nem autorização.

`object` é preservado exatamente, sem trim/tamanho/non-empty inventados além do `NOT NULL` físico.

`next_action` permanece para F26/F27 após a linha existir. Stage, status, responsável, waiting, itens e identificadores ficam fora da criação inicial; campos nullable nascem `NULL`.

### Escopo pilot-only

Team, actor e `created_by_membership_id` são derivados exclusivamente da sessão Better Auth validada e do banco.

A criação exige:

- usuário interno ativo;
- exatamente uma membership não revogada do usuário em todo o banco;
- team derivado não arquivado;
- exatamente uma membership não revogada no team.

Múltiplas memberships do usuário ou segundo membro não revogado no team bloqueiam. O segundo membro conta mesmo quando seu app_user está desabilitado. Q-009 continua aberta.

### Capability própria

Criação recebe owner técnico próprio equivalente a `compras_contracting_create_owner`; F26 não é ampliada.

A futura primitive deve ser `SECURITY DEFINER`, com `search_path = pg_catalog`, SQL estático, `PUBLIC EXECUTE` revogado e grants coluna-a-coluna. Runtime normal continua sem DML direto e recebe apenas `EXECUTE` explícito.

### Estado, evento e idempotência

A row inicial persiste somente ID, team derivado, `object`, creator derivado e timestamps. Responsible/stage/status/waiting/next_action/archived/cancelled ficam `NULL`.

Na mesma transação nasce exatamente um evento `contracting_created`; row/event compartilham o mesmo instante de banco e falha do evento reverte o cadastro.

Replay do mesmo candidate UUID só vira `already-created` se, depois da autorização corrente, houver correspondência exata de team derivado + creator derivado + `object`. Colisão diferente/cross-team vira negação genérica.

Double-submit concorrente deve produzir uma única row e um único evento. Não existe deduplicação por texto de `object` nem infraestrutura externa de idempotência.

F28 foi integrada pela PR `#44`, merge `04b3e063314180e683e76adbe7c9c5affd53e14f`.

Gates finais da PR:

- CI `34616939065`: PASS;
- F22 Private Preview Preflight `34616938983`: PASS.

Pós-merge:

- CI `34617114461`: PASS;
- F22 Private Preview Preflight `34617114500`: PASS.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01 — Implementar boundary de criação persistente mínima`.

F29 deve materializar ADR-012 com:

- migration `0005_contracting_create.sql`;
- capability/grants/policies mínimos;
- primitive específica e provisionamento de `EXECUTE` separado;
- interface server-only candidate UUID + `object`;
- evento atômico;
- replay e concorrência idempotentes;
- matriz PostgreSQL adversarial;
- regressões F22/F26/Auth.

Server Action/UI de cadastro continuam fora da F29.

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
- `0004_next_action_mutation.sql`.

Migration aplicada não é reescrita; correção usa nova migration.

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
