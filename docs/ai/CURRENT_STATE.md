# Current State — Compras

**PROJECT_STATUS:** FOUNDATION_REVIEWED  
**CURRENT_PHASE:** Foundation-00 — Public Bootstrap  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** NOT_INITIALIZED  
**DATABASE_STATUS:** NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID_AFTER_REVIEW  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A Foundation-00 foi revisada em red-team de produto, continuidade e segurança antes da promoção para `main`.

A revisão confirmou como baseline suficiente para iniciar a fundação executável:

- visão do produto;
- `Contratação` como entidade central;
- Central do Setor como experiência principal;
- separação entre etapa, status, responsável, aguardando e próxima ação;
- modelo de domínio inicial;
- workflow público sanitizado;
- questões abertas preservadas sem inferência;
- arquitetura de referência;
- baseline de segurança;
- Definition of Done;
- protocolo FLOW-IA;
- fast context por manifest;
- regra de uma `NEXT_ACTION` por sessão.

## Red-team da Foundation-00

A revisão encontrou um endurecimento necessário: em repositório público, o risco não se limita ao conteúdo commitado. Issues, PRs, reviews, GitHub Actions logs/summaries/artifacts e outras superfícies públicas também devem ser tratadas como potencialmente divulgáveis.

`AGENTS.md`, `SECURITY.md`, `WORK_PROTOCOL.md` e `ADR-001` foram endurecidos para refletir essa regra.

Não foi identificado outro conflito material entre Project Design, Domain Model, Business Workflow, Security e Source of Truth que impeça o bootstrap técnico.

## Guardrail de visibilidade

Enquanto o repositório permanecer público:

- somente dados fictícios/sanitizados;
- nenhum documento interno real;
- nenhum processo real sensível;
- nenhuma credencial;
- nenhum segredo;
- nenhuma fixture derivada de dado interno;
- nenhum dado sensível em Issues/PRs/comments/workflow logs/artifacts.

## Ainda não feito

- nenhuma aplicação Next.js criada;
- nenhuma dependência instalada;
- nenhum banco criado/conectado;
- nenhuma autenticação implementada;
- nenhuma migration;
- nenhuma integração com fonte pública;
- nenhum deploy;
- nenhuma importação de planilha/dado real.

## Verificação da revisão

- recuperação do estado real de `main`, branch `foundation-00` e PR #1: PASS;
- validação dos blobs do `CONTEXT_MANIFEST` antes da revisão: PASS;
- revisão cruzada Project Design × Domain Model × Workflow × Security × Source of Truth: PASS após hardening;
- gate de informação pública/sensível no conteúdo da Foundation-00: PASS;
- lint/typecheck/test/build: SKIPPED — aplicação ainda não inicializada;
- browser: SKIPPED — não existe aplicação.

## Last good

Ainda não existe `LAST_GOOD_COMMIT` de aplicação executável. A Foundation-00 revisada constitui a baseline documental para a próxima fase.

## Próxima ação

Executar `F01-BOOTSTRAP-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F01-BOOTSTRAP-01/SPEC.md`.
