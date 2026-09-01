# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. Ele organiza o trabalho da equipe e, futuramente, pode consumir fontes públicas oficiais para auxiliar pesquisa de preços.

## Estado atual

A `Foundation-00`, a `F01 — Fundação Executável`, a `F02 — Central do Setor Prototype` e a `F03 — Detalhe da Contratação Prototype` foram revisadas, validadas e integradas em `main`.

Existe agora uma aplicação executável com uma Central do Setor demonstrativa e uma jornada `Central → detalhe → Central`, usando exclusivamente dados fictícios. A Central possui busca/filtros e o detalhe apresenta contexto operacional, identificadores relacionados, itens e atividade demonstrativa. Não existe banco, autenticação, persistência operacional, integração externa ou deploy de produção.

A próxima ação canônica é `F04-PERSISTENCE-FOUNDATION-DESIGN-01 — Desenhar fundação de persistência segura`.

O repositório está público. Aplicam-se integralmente as restrições de publicação de `AGENTS.md` e `docs/architecture/SECURITY.md`; nenhum dado real ou pré-publicação pode ser usado no protótipo ou na documentação pública.

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
- `docs/architecture/DATABASE.md` — será criado na próxima slice de design de persistência.

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
- evitar complexidade prematura;
- construir por slices pequenas, utilizáveis e verificáveis;
- qualquer incerteza importante aumenta a investigação, nunca autoriza adivinhação.
