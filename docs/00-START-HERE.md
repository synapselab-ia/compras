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
- primeira capability persistente de escrita limitada a `contractings.next_action`;
- UI do detalhe persistente capaz de editar somente `Próxima ação` por Server Action estreita.

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

O preflight também verifica que runtimes Auth/read-only não herdam `EXECUTE` da capability de mutação F26.

## F26 — primeira mutação persistente integrada

ADR-011 escolheu uma primitive PostgreSQL específica `SECURITY DEFINER` para alterar somente `contractings.next_action`.

Objetos principais:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- `database/tests/next_action_mutation.sql`;
- `src/server/database/trusted-mutation-context.ts`;
- `src/features/contracting-detail/persistent-mutation.ts`.

A capability owner `compras_next_action_mutation_owner` é `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. A função tem `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

O runtime normal permanece sem `UPDATE`/`INSERT` direto; recebe somente `EXECUTE` explícito da primitive.

Q-009 permanece aberta. A escrita é pilot-only: a identidade corrente precisa possuir a única membership `revoked_at IS NULL` da equipe alvo. Segundo membro ativo bloqueia a mutação.

Mudança real atualiza `next_action`/`updated_at` e cria exatamente um `next_action_changed` na mesma transação. No-op não cria evento; expected stale retorna `conflict`. O teste concorrente com oito writers prova exatamente um winner/evento.

F26 foi integrada pela PR `#42`, merge `1e9e03eddeac9584ee6044a2393fe6b1e9a31726`. Pós-merge:

- CI `34611660963`: PASS;
- F22 Private Preview Preflight `34611660927`: PASS.

## F27 — edição de Próxima ação no detalhe

A PR `#43` implementa a jornada utilizável sobre a boundary F26.

### Modo demo

- continua estritamente read-only;
- nenhum form/textarea de write persistente é renderizado;
- a Server Action também recusa execução quando o modo persistente não está exatamente habilitado;
- query state forjado não produz feedback de write no detalhe demo.

### Modo persistente

Somente `Próxima ação` é editável.

O read model preserva `nextActionValue: string | null` separadamente do texto humano, mantendo SQL `NULL` distinto de string vazia e fornecendo a precondição correta para concorrência F26.

A Server Action recebe/encaminha somente:

```text
contractingId
expectedNextAction
newNextAction
```

Actor, team, membership, issuer, subject, event UUID e redirect não vêm do browser como autoridade.

Ausência deliberada do campo representa `NULL`; string vazia permanece string vazia. Sucesso/conflito revalidam apenas a rota local do detalhe. Falha é sanitizada e nunca cai para demo.

A UI possui valor atual visível, textarea, ação explícita de limpar para `NULL`, pending/disabled e feedback para `updated`, `unchanged`, `conflict`, `not-available`, `unavailable`. Não existem controles de edição de stage/status/responsável/waiting nesta slice.

Head funcional F27 `96eae1dfa3a6105e87f80b2b103c509b897c4db6`:

- CI `34613166500`: PASS;
- F22 Private Preview Preflight `34613166498`: PASS;
- lint/typecheck/test/build: PASS;
- F26 PostgreSQL/RLS/concorrência e Auth/F24: PASS.

O head documental final da PR ainda deve receber os mesmos gates antes do merge.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01 — Desenhar criação persistente mínima de contratação`.

F28 é design-only. Deve produzir ADR para criação de `contractings` definindo:

- payload mínimo sem inventar taxonomias abertas;
- derivação pilot-only de team/actor/created_by;
- capability/grants mínimos;
- evento inicial atômico;
- IDs e idempotência/double-submit;
- matriz adversarial para a implementação posterior.

Q-001/Q-002/Q-006/Q-009 não devem ser resolvidas silenciosamente.

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

Migrations imutáveis do domínio:

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

Arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, ADR-010, ADR-011.

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
- construir por slices pequenas, verificáveis e reversíveis.
