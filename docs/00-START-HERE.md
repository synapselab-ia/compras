# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados.

## Estado atual

A `Foundation-00` e F01..F14 entregaram protótipo Central → detalhe, PostgreSQL default-deny com `FORCE RLS`, identidade confiável `issuer + subject`, leituras persistentes protegidas, diretório mínimo da equipe e admissão Auth privada.

A trilha posterior está assim:

- F17 permanece `ON HOLD` histórico para a antiga rota Managed Neon Auth;
- F18 mantém demonstração hospedada apenas com fixtures fictícias e Vercel Authentication;
- F19/F20 adotaram e implementaram Better Auth self-hosted;
- F21 permanece `ON HOLD` antes de secrets, aguardando control plane Vercel capaz de readback de proteção/bypasses e CRUD de sensitive Preview env vars escopadas à branch;
- F22 criou seed/smoke reproduzíveis exclusivamente fictícios;
- F23/F24 desenharam e implementaram controle distribuído de abuso de sign-in;
- F25 definiu pela ADR-011 a primeira escrita persistente rastreável;
- F26 implementou essa primeira escrita exclusivamente para `contractings.next_action` por capability PostgreSQL estreita.

Tudo continua `REAL_DATA_ALLOWED = NO`.

## Auth e proteção do sign-in

O runtime privado usa Better Auth self-hosted com PostgreSQL:

- `better-auth@1.6.23` pinado;
- email/senha habilitado;
- signup normal desabilitado;
- nenhum OAuth/OTP/Admin exposto pela rota genérica;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- subject somente de sessão validada server-side;
- `/api/auth/[...path]` permanece deny-all;
- sign-in e sign-out passam por Server Actions estreitas.

Migrations Auth ficam separadas em `database/auth/migrations/`:

- `0001_better_auth_1_6_23.sql`;
- `0002_auth_runtime_boundary.sql`;
- `0003_signin_abuse_limiter.sql`.

A role Auth runtime é não privilegiada e não recebe acesso às tabelas de domínio. A role de domínio não recebe acesso às tabelas Auth/limiter fora das fronteiras aprovadas.

O limiter F24 usa PostgreSQL compartilhado como store autoritativo, buckets HMAC não reversíveis e política versionada. Falha de limiter/configuração/store fecha o sign-in; nenhum fallback permissivo existe.

## F21 — preview persistente ON HOLD

F21 parou antes de secrets e antes de criar banco dedicado porque a superfície Vercel autenticada disponível não expunha os dois gates externos obrigatórios:

1. readback completo de Deployment Protection/Vercel Authentication e bypasses relevantes;
2. CRUD de sensitive Preview environment variables escopadas à branch sem expor os valores.

`resume_when`: uma sessão autenticada puder executar e provar esses controles. Não reduzir proteção para contornar o blocker.

## F22 — seed e smoke reproduzíveis

O preflight fictício:

- exige modo explícito e dados `example.invalid`;
- usa UUIDs determinísticos e nomes sintéticos;
- separa criação da identidade Auth de `app_user`/membership;
- prova usuário sem autorização → zero dados;
- prova usuário autorizado → somente própria equipe;
- prova UUID conhecido de outra equipe → invisível;
- prova claims ausentes/malformados/errados → fail-closed;
- prova separação de runtimes Auth/domínio.

F26 estendeu esse preflight para aplicar a migration de mutação e provar que Auth/read-only runtimes não herdam `EXECUTE` da capability de escrita.

## F25/F26 — primeira mutação persistente

A ADR-011 escolheu uma primitive PostgreSQL específica `SECURITY DEFINER` para a primeira escrita de `contractings.next_action`.

F26 materializou a decisão em:

- `database/migrations/0004_next_action_mutation.sql`;
- `database/provisioning/grant_next_action_runtime.sql`;
- `database/tests/next_action_mutation.sql`;
- `src/server/database/trusted-mutation-context.ts`;
- `src/features/contracting-detail/persistent-mutation.ts`;
- testes unitários, PostgreSQL 17 e concorrência real.

### Fronteira de autoridade

A role runtime continua sem DML direto em `contractings` ou `contracting_events`.

A capability owner `compras_next_action_mutation_owner` é técnica `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável. A função possui `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

O runtime recebe somente `EXECUTE` da primitive por provisionamento transacional estreito. O provisionamento falha fechado se runtime/capability não satisfizerem os requisitos de segurança.

### Autorização pilot-only

Q-009 permanece aberta. A escrita só é permitida quando a identidade corrente:

- resolve para `app_user` ativo;
- possui membership não revogada na equipe da contratação;
- é a única membership `revoked_at IS NULL` da equipe.

Uma segunda membership ativa bloqueia a mutação, inclusive se o usuário correspondente estiver desabilitado. Isso evita inferir permissão multiusuário não aprovada.

Browser não fornece actor, `team_id`, membership, issuer ou subject confiáveis. O `contracting_id` é apenas seletor candidato.

### Atomicidade e histórico

Mudança real:

- atualiza `next_action` e `updated_at`;
- insere exatamente um `contracting_events` com `event_type = 'next_action_changed'` e `field_key = 'next_action'`;
- deriva actor/team/contracting no banco;
- usa um único instante de banco para estado e evento.

Falha do evento reverte o update. No-op não altera timestamp e não cria evento. `contracting_events` permanece append-only.

### Concorrência

A primitive usa `SELECT ... FOR UPDATE` + precondição null-safe do valor antigo.

O teste concorrente PostgreSQL 17 executa oito writers com o mesmo expected antigo e comprova exatamente 1 `updated`, 7 `conflict` e 1 evento, sem lost update silencioso.

### Fail-closed

Cross-team, inexistente, identidade desconhecida/desabilitada, membership ausente/revogada, equipe multi-member e contratação arquivada/cancelada colapsam para não disponibilidade genérica antes de conflito/no-op.

Falha de Auth/banco/configuração/contexto retorna indisponibilidade; nunca existe fallback para demo.

## Verificação F26

Head funcional validado: `ca670b05cdc2f0c80b520f0573c05032c4a73cc6`.

- CI `34605291444`: PASS — lint, typecheck, testes, build, migrations/RLS/F26 e Auth/F24;
- F22 Private Preview Preflight `34605291428`: PASS.

A PR `#42` contém o checkpoint F26 e deve ser mergeada apenas após os mesmos gates ficarem verdes no head documental final.

## Próxima frente

A única `NEXT_ACTION` está em `docs/ai/NEXT_ACTION.md`:

`F27-PERSISTENT-NEXT-ACTION-DETAIL-UI-01 — Integrar edição persistente de próxima ação no detalhe`.

F27 deve tornar utilizável apenas a capability F26 no detalhe persistente por Server Action estreita, mantendo:

- demo estritamente read-only;
- browser limitado a candidate ID + expected + novo `next_action`;
- actor/team/membership/event UUID fora do input confiável;
- conflito explícito sem overwrite silencioso;
- cross-team/inexistente sem side channel;
- nenhuma escrita de stage/status/responsável/aguardando;
- nenhuma nova autoridade.

## Modos da aplicação

### Demo

Padrão quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`.

- somente fixtures fictícias;
- nenhuma consulta ou mutação operacional;
- banner explícito de protótipo fictício.

### Persistente

Só existe quando todos os gates Auth/banco/configuração/autorização estiverem satisfeitos.

Fluxo de confiança:

```text
sessão Better Auth validada no servidor
-> issuer + subject
-> contexto transacional LOCAL
-> PostgreSQL com role de domínio não privilegiada
-> RLS/capability estreita
-> somente registros/operações autorizados
```

Falha protegida nunca cai silenciosamente para demo.

## Banco canônico

Migrations imutáveis do domínio:

- `database/migrations/0001_core_foundation.sql`;
- `database/migrations/0002_trusted_identity_read_policies.sql`;
- `database/migrations/0003_team_member_directory.sql`;
- `database/migrations/0004_next_action_mutation.sql`.

Migrations aplicadas não são reescritas; correções futuras usam nova migration.

## Fonte de verdade

GitHub é canônico. Chat é descartável.

Ordem mínima para nova sessão:

1. `AGENTS.md`;
2. `docs/00-START-HERE.md`;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. abrir SPEC/ADR/código exigidos pela tarefa ativa.

## Documentos principais

Produto:

- `docs/product/PROJECT_DESIGN.md`;
- `docs/product/DOMAIN_MODEL.md`;
- `docs/product/BUSINESS_WORKFLOW.md`;
- `docs/product/OPEN_QUESTIONS.md`.

Arquitetura/segurança:

- `docs/architecture/ARCHITECTURE.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- `docs/decisions/ADR-003-trusted-identity-rls-boundary.md`;
- `docs/decisions/ADR-005-directory-capability-role-lifecycle.md`;
- `docs/decisions/ADR-009-self-hosted-better-auth.md`;
- `docs/decisions/ADR-010-private-signin-abuse-control.md`;
- `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`.

Operação por IA:

- `docs/ai/SOURCE_OF_TRUTH.md`;
- `docs/ai/WORK_PROTOCOL.md`;
- `docs/ai/CONTEXT_MANIFEST.md`;
- `docs/ai/CURRENT_STATE.md`;
- `docs/ai/NEXT_ACTION.md`.

Qualidade:

- `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- segurança nunca é reduzida para “fazer passar”;
- autenticação não é autorização;
- autorização crítica vive no servidor/banco e RLS permanece autoritativa;
- IDs do cliente nunca definem identidade/escopo;
- signup público não é aceito por conveniência;
- dado real/interno/pré-publicação não entra no repositório público nem na faixa demo;
- role privilegiada nunca é runtime normal;
- secrets nunca vão para Git, chat, URL, log, summary ou artifact público;
- blocker externo objetivo entra `ON HOLD` e não paralisa trabalho independente;
- falha protegida não vira sucesso demonstrativo silenciosamente;
- migrations aplicadas são imutáveis;
- construir por slices pequenas, verificáveis e reversíveis.
