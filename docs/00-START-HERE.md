# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. Ele organiza o trabalho da equipe e, futuramente, pode consumir fontes públicas oficiais para auxiliar pesquisa de preços.

## Estado atual

A `Foundation-00` e as work units F01 a F09 foram revisadas e integradas em `main`.

Existe uma aplicação executável com jornada demonstrativa `Central → detalhe → Central`, exclusivamente com dados fictícios. A Central também possui agora um primeiro caminho de leitura persistente server-side, desabilitado por padrão e ativável somente por configuração server-only explícita. Esse caminho usa a fronteira confiável implementada em F08: sessão validada no servidor → `issuer + subject` → contexto transacional LOCAL → PostgreSQL/RLS.

O núcleo relacional possui as migrations imutáveis `database/migrations/0001_core_foundation.sql` e `database/migrations/0002_trusted_identity_read_policies.sql`. A CI prova separadamente o estado `0001` totalmente default-deny e o estado `0001 + 0002` com policies apenas de `SELECT`, usando PostgreSQL descartável e papéis não privilegiados.

A F08 adicionou o adaptador server-only de Auth/PostgreSQL sem provisionar infraestrutura: identidade externa é derivada apenas de configuração confiável e sessão validada, o contexto contém somente `iss + sub`, a transação é `READ ONLY` e o caminho operacional rejeita owner, superuser e `BYPASSRLS`.

A F09 conectou a Central a esse adaptador por um modo persistente opt-in. Falha de sessão, banco ou configuração no modo persistente não é mascarada por fixtures demo. A primeira leitura também revelou um limite real das policies atuais: elas autorizam contratações por equipe, mas `memberships`/`app_users` expõem somente a própria identidade, então a Central ainda não pode resolver com segurança o nome de outro membro responsável.

A próxima ação canônica é `F10-TEAM-DIRECTORY-RLS-DESIGN-01 — Projetar leitura segura do diretório de responsáveis`. Ela deve definir — e implementar quando seguro — a menor projeção de membros necessária à Central, sem expor identificadores externos de Auth, sem aceitar escopo do cliente e sem enfraquecer RLS.

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
- falha de leitura protegida não pode ser convertida silenciosamente em sucesso demonstrativo;
- evitar complexidade prematura;
- construir por slices pequenas, utilizáveis e verificáveis;
- qualquer incerteza importante aumenta a investigação, nunca autoriza adivinhação.
