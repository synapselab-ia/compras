# Current State — Compras

**PROJECT_STATUS:** READY_FOR_PERSISTENCE_FOUNDATION_DESIGN  
**CURRENT_PHASE:** F04 — Persistence Foundation Design  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_AND_DETAIL_PROTOTYPE  
**DATABASE_STATUS:** NOT_PROVISIONED  
**AUTH_STATUS:** NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `3c8958ae5e7126db7711c9dbcb57751e89fbd7bf`  
**LAST_GOOD_CI_RUN:** `33544518950`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F03-CONTRATACAO-DETAIL-PROTOTYPE-01` foi concluída e integrada à `main` pela PR #5.

A aplicação agora possui uma jornada demonstrativa `Central do Setor → detalhe → Central` com:

- links acessíveis de cada registro `DEMO-*` para rota estável de detalhe;
- cabeçalho do detalhe reutilizando os campos operacionais da Central;
- responsável, etapa/status provisórios, aguardando, próxima ação e última movimentação;
- identificadores relacionados explicitamente demo;
- itens explicitamente demo, sem quantidade, preço ou conteúdo derivado de contratação real;
- atividade recente explicitamente demo;
- tratamento seguro de identificador inexistente por not-found, sem fallback para outro registro;
- navegação clara de retorno à Central;
- lookup demo separado de JSX e coberto por teste;
- estratégia responsiva em código para desktop e larguras menores.

Q-001, Q-002 e Q-003 continuam abertas. A estrutura visual criada não fecha taxonomias nem semântica definitiva de processos relacionados.

## Verificação de F03

- recuperação do estado real, branches, PRs e `main`: PASS;
- validação integral do `CONTEXT_MANIFEST`: PASS — todos os blobs estáveis coincidem;
- inspeção da spec e do código da Central antes de edição: PASS;
- red-team do diff completo e dos fixtures demonstrativos: PASS após correção descrita abaixo;
- CI inicial da PR: FAIL — run `33544319890`, porque o novo teste Vitest não resolvia o alias `@/` usado pelo módulo de lookup;
- correção: o módulo compartilhado passou a importar a fonte demo por caminho relativo, sem alterar configuração global nem criar bypass;
- CI final da PR #5: PASS — run `33544431444`;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI da `main` após squash merge: PASS — run `33544518950`;
- dados reais/internos/sensíveis no diff: NÃO ENCONTRADOS;
- dependências novas: nenhuma;
- persistência/edição/criação/exclusão: não introduzidas;
- semântica definitiva de relacionamento: não introduzida;
- browser visual: SKIPPED — não houve ferramenta/ambiente de navegador nesta work unit; responsividade foi revisada em código e compilada, mas não é declarada visualmente validada.

## Red-team

A revisão adversarial confirmou que:

- todos os identificadores adicionados seguem padrões `DEMO`, `REF-DEMO`, `ITEM-DEMO` ou `EVENT-DEMO`;
- textos e pessoas permanecem genéricos;
- uma rota desconhecida não expõe outro registro nem consulta fonte interna;
- o detalhe não contém ações que sugiram persistência inexistente;
- o dado base da Central não foi duplicado no detalhe: o lookup combina o registro central com contexto demo adicional;
- Q-001, Q-002, Q-003, Q-004, Q-005, Q-006 e Q-009 permanecem abertas;
- não foi criado banco, Auth, RLS, integração externa ou dado operacional real.

## Segurança e limites atuais

O repositório continua público e a aplicação continua sem autenticação. Portanto:

- somente dados fictícios/sanitizados podem existir na aplicação, testes, Issues, PRs, logs e artifacts;
- nenhum uso operacional com dados reais é permitido;
- não existe banco, Auth, RLS, deploy operacional ou integração externa;
- Central e detalhe atuais são protótipos de experiência, não ambiente autorizado para informações internas.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F03 e todos os blobs foram revalidados antes da implementação. O manifest permanece válido.

## Last good

`3c8958ae5e7126db7711c9dbcb57751e89fbd7bf` é o `LAST_GOOD_COMMIT` atual da aplicação, validado pela CI da `main` run `33544518950`.

## Próxima ação

Executar `F04-PERSISTENCE-FOUNDATION-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F04-PERSISTENCE-FOUNDATION-DESIGN-01/SPEC.md`.
