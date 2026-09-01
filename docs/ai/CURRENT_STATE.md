# Current State — Compras

**PROJECT_STATUS:** READY_FOR_EXECUTABLE_FOUNDATION  
**CURRENT_PHASE:** F01 — Fundação Executável  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** NOT_INITIALIZED  
**DATABASE_STATUS:** NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A Foundation-00 foi revisada, endurecida e integrada à `main` pela PR #2.

A baseline aprovada define:

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

A revisão encontrou e corrigiu um gap de segurança: enquanto o repositório estiver público, o risco não se limita ao conteúdo commitado. Issues, PRs, reviews, GitHub Actions logs/summaries/artifacts e outras superfícies públicas também devem ser tratadas como potencialmente divulgáveis.

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

- recuperação do estado real de `main`, branch e PR: PASS;
- validação dos blobs do `CONTEXT_MANIFEST` antes e após hardening: PASS;
- revisão cruzada Project Design × Domain Model × Workflow × Security × Source of Truth: PASS após hardening;
- gate de informação pública/sensível no conteúdo da Foundation-00: PASS;
- promoção para `main`: PASS via PR #2 / squash merge `40c3297094d700552896d2945e10b18b982186da`;
- lint/typecheck/test/build: SKIPPED — aplicação ainda não inicializada;
- browser: SKIPPED — não existe aplicação.

## Last good

Ainda não existe `LAST_GOOD_COMMIT` de aplicação executável. `40c3297094d700552896d2945e10b18b982186da` é a baseline documental aprovada.

## Próxima ação

Executar `F01-BOOTSTRAP-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F01-BOOTSTRAP-01/SPEC.md`.
