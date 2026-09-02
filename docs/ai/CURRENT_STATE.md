# Current State — Compras

**PROJECT_STATUS:** READY_FOR_TEAM_DIRECTORY_RLS_DESIGN  
**CURRENT_PHASE:** F10 — Team Member Directory / RLS Design  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_PERSISTENT_READ_PATH_IMPLEMENTED_OPT_IN  
**DATABASE_STATUS:** TRUSTED_READ_RLS_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** SERVER_TRUST_ADAPTER_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `cb2a37f6813e4e8cc64cfc8925710693fd26b249`  
**LAST_GOOD_CI_RUN:** `33645580200`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

As work units F08 e F09 estão concluídas e integradas em `main` pelas PRs #10 e #11.

### F08 — fronteira server-only

O caminho de produção agora possui:

- `@neondatabase/auth@0.5.0-beta` fixado em versão exata nesta fronteira;
- resolução de sessão server-side via API oficial `createNeonAuth(...).getSession()`;
- `issuer` derivado exclusivamente de `NEON_AUTH_BASE_URL` server-only;
- `subject` derivado exclusivamente da sessão validada;
- adaptador `withTrustedDatabaseContext()` que abre `BEGIN READ ONLY`, rejeita role superuser, `BYPASSRLS`, owner de tabela protegida ou `neondb_owner`, define somente `{iss, sub}` por `set_config(..., true)` parametrizado e executa a operação na mesma transação;
- falha fechada e descarte da conexão quando identidade, configuração, role ou contexto não são seguros;
- nenhuma rota/UI de login ou signup e nenhum auto-provisionamento de usuário/membership.

### F09 — primeira leitura persistente da Central

A Central possui agora dois modos explicitamente separados:

- `COMPRAS_PERSISTENT_READ_ENABLED` ausente ou `false`: fixtures demonstrativas;
- exatamente `true`: leitura persistente server-side por `withTrustedDatabaseContext()`;
- qualquer valor inválido ou falha da leitura protegida: estado indisponível, sem fallback silencioso para demo.

A consulta persistente:

- não recebe `team_id`, `membership_id`, `app_user_id`, issuer ou subject do chamador;
- lê somente `contractings` ativas que a RLS já autoriza;
- usa `MAX(contracting_events.occurred_at)` para última movimentação e não trata `updated_at` como evento;
- mantém filtros no Client Component somente depois que o servidor entregou o conjunto já autorizado;
- não cria link para detalhe persistente, porque essa rota ainda é demonstrativa;
- não amplia RLS para descobrir identidade de colegas.

## Limite revelado pela primeira leitura

As policies atuais de `app_users` e `memberships` expõem somente a própria identidade/membership. Isso é suficiente para autorização de equipe das contratações, mas não constitui um diretório de membros.

Consequência deliberada na F09:

- sem responsável: `Sem responsável`;
- responsável igual à própria membership visível: o próprio `display_name` pode ser mostrado;
- outra membership responsável: `Responsável não disponível`.

Não foi usado owner, `BYPASSRLS`, `SECURITY DEFINER`, claim de `team_id` nem abertura ampla de `app_users` para contornar essa limitação. A próxima work unit deve desenhar uma projeção/diretório de equipe seguro que permita à Central identificar responsáveis sem expor `auth_issuer`/`auth_subject` nem criar recursão de RLS.

## Verificação de F09

- `main` recuperada no commit anterior `3ab588bc4c31642dc1a8e4b3cca5cf69f8c35b28`; nenhuma PR concorrente aberta: PASS;
- `CONTEXT_MANIFEST` validado contra o tree de `main`; todos os blobs estáveis coincidiram: PASS;
- implementação em branch `f09-first-persistent-read`, PR #11: PASS;
- primeira CI da PR `33645231039`: encontrou regressão de tipos após extração de `SectorCentralRecord`; correção aplicada sem alterar escopo;
- CI final da PR `33645383647`: PASS — `npm ci`, lint, typecheck, testes, build e database;
- PostgreSQL `0001` isolada/default-deny: PASS;
- PostgreSQL `0001 + 0002`, suites de RLS/red-team e transporte LOCAL F08: PASS;
- PR #11 revisada integralmente e integrada por squash: PASS;
- CI da `main` após merge: run `33645580200`, jobs `verify` e `database`: PASS;
- dados reais, secrets ou infraestrutura externa no diff: NÃO ENCONTRADOS.

## Red-team de F09

1. **Escopo vindo do browser:** a API de leitura aceita zero argumentos; teste adversarial passa `team_id`, membership e user forjados por cast e a query continua sem parâmetros de escopo.
2. **Fallback enganoso:** modo persistente com erro não retorna fixtures demonstrativas; retorna somente `unavailable`.
3. **Erro sensível:** teste injeta erro artificial com connection string e prova que o valor retornado não serializa detalhes.
4. **Identidade de colega:** a query respeita as policies atuais; não usa papel privilegiado nem abertura de tabela para obter nomes invisíveis.
5. **Histórico:** `updated_at` não é usado como última movimentação; a consulta agrega somente eventos.
6. **Mistura demo/persistente:** detalhe persistente permanece desabilitado na Central para não navegar a uma tela alimentada por fixture demo.
7. **Configuração client-side:** nenhuma variável `NEXT_PUBLIC_*` foi introduzida.

## Segurança e limites atuais

Nenhum banco/Auth hospedado, secret, usuário operacional real ou dado pré-publicação foi criado. O modo persistente existe em código, mas permanece desabilitado por padrão e não autoriza uso de dados reais enquanto infraestrutura, admissão/login controlado e política de dados não forem revisados.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F08/F09. Os hashes continuam válidos. `CURRENT_STATE`, `NEXT_ACTION`, migrations, testes e código são lidos ao vivo pelo protocolo.

## Last good

`cb2a37f6813e4e8cc64cfc8925710693fd26b249` é o `LAST_GOOD_COMMIT`, validado pela CI de `main` run `33645580200` com os jobs `verify` e `database` em PASS.

## Próxima ação

Executar `F10-TEAM-DIRECTORY-RLS-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F10-TEAM-DIRECTORY-RLS-DESIGN-01/SPEC.md`.
