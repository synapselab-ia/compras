# Current State — Compras

**PROJECT_STATUS:** READY_FOR_CONTRACTING_DETAIL_PROTOTYPE  
**CURRENT_PHASE:** F03 — Detalhe da Contratação Prototype  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** SECTOR_CENTRAL_PROTOTYPE  
**DATABASE_STATUS:** NOT_PROVISIONED  
**AUTH_STATUS:** NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `b6362213ef36f776c9f1353699c820233e3fae38`  
**LAST_GOOD_CI_RUN:** `33542675552`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F02-CENTRAL-PROTOTYPE-01` foi concluída e integrada à `main` pela PR #4.

A aplicação agora apresenta uma primeira Central do Setor demonstrativa com:

- múltiplos registros estritamente fictícios `DEMO-*`;
- busca client-side por identificador, objeto e responsável;
- normalização básica de caixa e acentos na busca;
- filtros demonstrativos por responsável, etapa e status;
- limpeza de filtros e estado claro de zero resultados;
- tabela densa no desktop;
- cards responsivos como estratégia deliberada para telas menores;
- responsável, etapa, status, aguardando, próxima ação e última movimentação visíveis;
- sinalização explícita de que não há persistência, base interna ou conexão com sistemas oficiais;
- lógica pura de busca/filtro coberta por testes automatizados.

Os valores de etapa e status utilizados continuam sendo `PROVISIONAL_DEMO_VALUES`; a slice não resolveu as taxonomias abertas.

## Verificação de F02

- recuperação do estado real, PRs/branches e `main`: PASS;
- validação integral do `CONTEXT_MANIFEST`: PASS — todos os blobs estáveis coincidem;
- inspeção do código e spec ativos: PASS;
- `npm ci`: PASS em CI;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI da PR #4: PASS — run `33542561064`;
- CI da `main` após merge: PASS — run `33542675552`;
- red-team do diff completo: PASS;
- dados reais/internos/sensíveis no diff: NÃO ENCONTRADOS;
- dependências novas: nenhuma;
- persistência ou botão que simule gravação inexistente: não introduzidos;
- regra definitiva de inatividade: não introduzida;
- taxonomia definitiva de etapa/status: não introduzida;
- browser visual: SKIPPED — não houve ambiente de navegador disponível nesta work unit; responsividade foi revisada em código e compilada, mas não é declarada como visualmente validada.

## Red-team

A revisão adversarial confirmou que:

- o dataset usa somente identificadores, pessoas, setores, objetos e momentos explicitamente demonstrativos;
- os filtros são comportamento de interface, não regra de negócio canônica;
- Q-001, Q-002, Q-003, Q-004, Q-005 e Q-009 permanecem abertas;
- nenhum banco, Auth, RLS, integração externa, pesquisa de preços, timeline persistente ou edição foi antecipado;
- o repositório público continua sem conteúdo operacional real.

## Segurança e limites atuais

O repositório continua público e a aplicação continua sem autenticação. Portanto:

- somente dados fictícios/sanitizados podem existir na aplicação, testes, Issues, PRs, logs e artifacts;
- nenhum uso operacional com dados reais é permitido;
- não existe banco, Auth, RLS, deploy ou integração externa;
- a Central atual é um protótipo de experiência, não um ambiente autorizado para informações internas.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F02 e todos os blobs foram revalidados antes da implementação. O manifest permanece válido.

## Last good

`b6362213ef36f776c9f1353699c820233e3fae38` é o `LAST_GOOD_COMMIT` atual da aplicação, validado pela CI da `main` run `33542675552`.

## Próxima ação

Executar `F03-CONTRATACAO-DETAIL-PROTOTYPE-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F03-CONTRATACAO-DETAIL-PROTOTYPE-01/SPEC.md`.
