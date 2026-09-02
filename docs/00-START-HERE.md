# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. Ele organiza o trabalho da equipe e, futuramente, pode consumir fontes públicas oficiais para auxiliar pesquisa de preços.

## Estado atual

A `Foundation-00` e as work units F01 a F11 foram revisadas e integradas em `main`.

Existe uma aplicação executável com jornada demonstrativa `Central → detalhe → Central`, exclusivamente com dados fictícios. A Central também possui um caminho de leitura persistente server-side, desabilitado por padrão e ativável somente por `COMPRAS_PERSISTENT_READ_ENABLED=true`. Esse caminho usa a fronteira confiável implementada em F08: sessão validada no servidor → `issuer + subject` → contexto transacional LOCAL → PostgreSQL/RLS.

O núcleo relacional possui as migrations imutáveis:

- `database/migrations/0001_core_foundation.sql` — schema + `FORCE RLS` default-deny;
- `database/migrations/0002_trusted_identity_read_policies.sql` — helpers de identidade e primeiras policies somente de `SELECT`;
- `database/migrations/0003_team_member_directory.sql` — capability view mínima para diretório de responsáveis da mesma equipe.

A CI preserva provas separadas do estado `0001`, do estado `0001 + 0002`, do desenho adversarial F10 e da migration `0001 + 0002 + 0003` com role de migration não-superuser, além de testar preexistência insegura da capability e reutilização da role cluster-level em segundo database.

A F11 transformou ADR-004 em runtime: `public.team_member_directory` expõe somente `team_id`, `membership_id` e `display_name`, com owner técnico `NOLOGIN`/`NOBYPASSRLS`, grants coluna-a-coluna e policies direcionadas. A Central persistente usa exclusivamente essa view para resolver nomes de responsáveis colegas e o adaptador F08 rejeita a capability como credencial operacional.

ADR-005 registra uma nuance de PostgreSQL 17 necessária à implementação: um `CREATEROLE` não-superuser recebe uma concessão administrativa automática sobre a role que cria. O desenho aceita somente essa relação `ADMIN TRUE / SET FALSE / INHERIT FALSE` para o principal de migration; qualquer membership utilizável ou membership da capability em outra role falha fechado.

Ainda não existe banco/Auth/Vercel hospedado, login/signup, usuário operacional real, secret real ou deploy. O modo persistente existe e é testado somente com dados artificiais; `REAL_DATA_ALLOWED` permanece `NO`.

O limite funcional atual é o detalhe: `/contratacoes/[id]` ainda usa fixture demonstrativa. A próxima ação canônica é `F12-PERSISTENT-CONTRACTING-DETAIL-READ-01 — Conectar detalhe à leitura persistente protegida`. Ela deve completar a jornada persistente de leitura sem criar escrita nem infraestrutura.

O repositório está público. Aplicam-se integralmente as restrições de publicação de `AGENTS.md` e `docs/architecture/SECURITY.md`; nenhum dado real ou pré-publicação pode ser usado.

## Fonte de verdade

GitHub é canônico. Chat é descartável.

A hierarquia detalhada está em `docs/ai/SOURCE_OF_TRUTH.md`.

## Ordem de leitura para uma nova sessão

1. `AGENTS.md`;
2. `docs/00-START-HERE.md`;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. documentação específica da tarefa;
8. código, migrations e testes relacionados, quando existirem.

## Documentos principais

### Produto

- `docs/product/PROJECT_DESIGN.md` — visão e limites do produto;
- `docs/product/DOMAIN_MODEL.md` — entidades e invariantes iniciais;
- `docs/product/BUSINESS_WORKFLOW.md` — workflow sanitizado inicial;
- `docs/product/OPEN_QUESTIONS.md` — questões que não podem ser resolvidas por inferência.

### Arquitetura e segurança

- `docs/architecture/ARCHITECTURE.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md` — contrato da fundação persistente;
- `docs/decisions/ADR-002-persistence-foundation.md` — fundação relacional/default-deny;
- `docs/decisions/ADR-003-trusted-identity-rls-boundary.md` — fronteira de identidade confiável e autorização de leitura;
- `docs/decisions/ADR-004-team-directory-rls-capability-view.md` — desenho do diretório mínimo;
- `docs/decisions/ADR-005-directory-capability-role-lifecycle.md` — lifecycle seguro da role cluster-level.

### Operação por IA

- `docs/ai/SOURCE_OF_TRUTH.md`;
- `docs/ai/WORK_PROTOCOL.md`;
- `docs/ai/CONTEXT_MANIFEST.md`;
- `docs/ai/CURRENT_STATE.md`;
- `docs/ai/NEXT_ACTION.md`.

### Qualidade

- `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- modelar o processo real, não copiar planilhas literalmente;
- contratação é a unidade operacional principal;
- separar etapa, status, responsável, aguardando quem e próxima ação;
- histórico relevante deve ser rastreável;
- nenhuma regra crítica existe somente na interface;
- privacidade e segurança entram desde a primeira tabela;
- persistência nasce relacional, portátil e deny-by-default;
- autenticação não é autorização; escopo deriva de membership ativa no banco;
- IDs fornecidos pelo cliente nunca definem identidade ou escopo por si só;
- contexto de identidade no banco só é confiável quando estabelecido por servidor autenticador controlado;
- capability técnica de leitura não é credencial operacional e não pode ser assumida pelo aplicativo;
- falha de leitura protegida não pode ser convertida silenciosamente em sucesso demonstrativo;
- evitar complexidade prematura;
- construir por slices pequenas, utilizáveis e verificáveis;
- qualquer incerteza importante aumenta a investigação, nunca autoriza adivinhação.
