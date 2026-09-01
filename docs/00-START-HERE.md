# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. Ele organiza o trabalho da equipe e, futuramente, pode consumir fontes públicas oficiais para auxiliar pesquisa de preços.

## Estado atual

A `Foundation-00`, a fundação executável, a Central do Setor, o detalhe demonstrativo, a fundação PostgreSQL, o desenho da fronteira de identidade/RLS e a primeira abertura seletiva de leitura por RLS foram revisados e integrados em `main`.

Existe uma aplicação executável com jornada demonstrativa `Central → detalhe → Central`, exclusivamente com dados fictícios. O núcleo relacional possui as migrations imutáveis `database/migrations/0001_core_foundation.sql` e `database/migrations/0002_trusted_identity_read_policies.sql`. A CI prova separadamente o estado `0001` totalmente default-deny e o estado `0001 + 0002` com policies apenas de `SELECT`, usando PostgreSQL descartável e papéis não privilegiados.

ADR-003 registra a fronteira aprovada: sessão externa validada no servidor → `issuer + subject` confiáveis → `app_user` → membership ativa → escopo de equipe no PostgreSQL. F07 implementou somente a camada PostgreSQL dessa fronteira. Ainda não há Auth ligado à aplicação, conexão operacional server-side, banco hospedado, Data API operacional, secret ou deploy.

A próxima ação canônica é `F08-SERVER-TRUST-ADAPTER-01 — Integrar sessão server-side e contexto transacional`. Ela implementará o caminho server-only que obtém sessão pela API oficial atual do SDK, deriva somente `issuer + subject` confiáveis e estabelece esse contexto localmente na transação PostgreSQL, sem provisionar infraestrutura, expor login/signup ou usar credenciais reais nesta slice.

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
- `docs/decisions/ADR-003-trusted-identity-rls-boundary.md` — fronteira de identidade confiável e autorização de leitura.

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
- evitar complexidade prematura;
- construir por slices pequenas, utilizáveis e verificáveis;
- qualquer incerteza importante aumenta a investigação, nunca autoriza adivinhação.
