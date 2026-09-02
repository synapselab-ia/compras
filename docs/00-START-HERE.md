# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. Ele organiza o trabalho da equipe e, futuramente, pode consumir fontes públicas oficiais para auxiliar pesquisa de preços.

## Estado atual

A `Foundation-00` e as work units F01 a F10 foram revisadas e integradas em `main`.

Existe uma aplicação executável com jornada demonstrativa `Central → detalhe → Central`, exclusivamente com dados fictícios. A Central também possui um primeiro caminho de leitura persistente server-side, desabilitado por padrão e ativável somente por configuração server-only explícita. Esse caminho usa a fronteira confiável de F08: sessão validada no servidor → `issuer + subject` → contexto transacional LOCAL → PostgreSQL/RLS.

O núcleo relacional possui as migrations imutáveis `database/migrations/0001_core_foundation.sql` e `database/migrations/0002_trusted_identity_read_policies.sql`. A CI prova separadamente o estado `0001` totalmente default-deny e o estado `0001 + 0002` com policies somente de `SELECT`, usando PostgreSQL descartável e papéis não privilegiados.

F09 conectou a Central a esse adaptador por um modo persistente opt-in. A leitura já respeita escopo de equipe das contratações, mas as policies atuais de `memberships`/`app_users` são deliberadamente self-only, de modo que o runtime ainda não consegue resolver o nome de um responsável colega da mesma equipe sem uma projeção adicional.

F10 estudou e provou essa projeção em PostgreSQL 17. ADR-004 rejeita policy autorreferente por recursão, confirma que uma view `security_invoker` isolada continua self-only e escolhe uma **capability view**: role técnica `NOLOGIN`/`NOBYPASSRLS`, grants coluna-a-coluna sem identificadores externos de Auth, policies `SELECT` exclusivas da capability e uma security-barrier view que devolve somente `team_id`, `membership_id` e `display_name` quando o usuário corrente possui membership ativa no mesmo escopo.

Esse desenho foi validado somente em ambiente descartável. Nenhuma migration de produção, role persistente de diretório ou alteração da consulta runtime foi introduzida pela F10. A próxima ação canônica é `F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01 — Implementar capability view do diretório de equipe`, que transformará o padrão em migration `0003`, endurecerá a rejeição da capability no adaptador operacional e fará a Central consultar a projeção mínima.

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
- `docs/decisions/ADR-004-team-directory-rls-capability-view.md` — diretório mínimo de equipe por capability view sob RLS.

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
- capability técnica não é credencial operacional e não substitui controle de role/RLS;
- minimização de dados é requisito: diretórios não devem expor identificadores externos de Auth sem necessidade;
- falha de leitura protegida não pode ser convertida silenciosamente em sucesso demonstrativo;
- evitar complexidade prematura;
- construir por slices pequenas, utilizáveis e verificáveis;
- qualquer incerteza importante aumenta a investigação, nunca autoriza adivinhação.
