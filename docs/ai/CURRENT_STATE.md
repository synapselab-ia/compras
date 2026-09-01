# Current State — Compras

**PROJECT_STATUS:** READY_FOR_SECTOR_CENTRAL_PROTOTYPE  
**CURRENT_PHASE:** F02 — Central do Setor Prototype  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** EXECUTABLE_FOUNDATION  
**DATABASE_STATUS:** NOT_PROVISIONED  
**AUTH_STATUS:** NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `c2e756cecdbbbc1e3b43a1cb8da570dcf4fe04b5`  
**LAST_GOOD_CI_RUN:** `33541243573`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F01-BOOTSTRAP-01` foi concluída e integrada à `main` pela PR #3.

A aplicação agora possui uma fundação executável mínima com:

- Next.js App Router e React;
- TypeScript em modo estrito;
- CSS global mínimo, sem design system prematuro;
- shell inicial neutro, sem dados operacionais;
- módulo compartilhado mínimo fora da camada React;
- teste unitário real com Vitest;
- ESLint configurado para a cadeia atual do Next.js;
- scripts reais de `lint`, `typecheck`, `test` e `build`;
- `package-lock.json` canônico;
- CI read-only com `npm ci` em Pull Requests e pushes na `main`;
- README técnico com instruções reproduzíveis.

## Ajustes descobertos pela verificação

A implementação inicial tentou versões mais novas do tooling e a própria CI revelou incompatibilidades upstream:

- TypeScript 7 não era suportado pela cadeia atual de `typescript-eslint` usada pelo `eslint-config-next`;
- ESLint 10 ainda conflitava com `eslint-plugin-react` transitivo do `eslint-config-next`.

Nenhum bypass foi aplicado. A fundação foi estabilizada em TypeScript `6.0.2` e ESLint `9.39.5`, mantendo os demais gates ativos.

## Verificação de F01

- recuperação do estado real e validação do `CONTEXT_MANIFEST`: PASS;
- documentação oficial atual das ferramentas externas: CONSULTADA;
- instalação inicial e geração do lockfile em ambiente limpo: PASS;
- `npm ci` a partir do lockfile: PASS;
- lint: PASS;
- typecheck: PASS;
- teste unitário: PASS;
- build: PASS;
- CI da PR #3: PASS — run `33541085153`;
- CI da `main` após merge: PASS — run `33541243573`;
- red-team do diff e gate de conteúdo público/sensível: PASS;
- browser visual: SKIPPED — não houve execução em navegador nesta work unit; nenhuma conclusão de fidelidade visual é declarada.

## Segurança e limites atuais

O repositório continua público e a aplicação ainda não possui autenticação. Portanto:

- somente dados fictícios/sanitizados podem existir na aplicação, testes, Issues, PRs, logs e artifacts;
- nenhum uso operacional com dados reais é permitido;
- não existe banco, Auth, RLS, deploy ou integração externa;
- a fundação executável não deve ser confundida com ambiente autorizado para informações internas.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F01. O manifest permanece válido.

## Last good

`c2e756cecdbbbc1e3b43a1cb8da570dcf4fe04b5` é o primeiro `LAST_GOOD_COMMIT` de aplicação executável, validado pela CI da `main`.

## Próxima ação

Executar `F02-CENTRAL-PROTOTYPE-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F02-CENTRAL-PROTOTYPE-01/SPEC.md`.
