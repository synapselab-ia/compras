# Current State — Compras

**PROJECT_STATUS:** READY_FOR_TEAM_DIRECTORY_RLS_IMPLEMENTATION  
**CURRENT_PHASE:** F11 — Team Directory Capability / RLS Implementation  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_PERSISTENT_READ_PATH_IMPLEMENTED_OPT_IN  
**DATABASE_STATUS:** TEAM_DIRECTORY_RLS_DESIGN_VALIDATED_NOT_IMPLEMENTED  
**AUTH_STATUS:** SERVER_TRUST_ADAPTER_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `8c7c77e855b8d6a367a726a0a5c8ad8a010bbcf3`  
**LAST_GOOD_CI_RUN:** `33657182891`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F10-TEAM-DIRECTORY-RLS-DESIGN-01` foi concluída e integrada à `main` pela PR #12.

F08/F09 continuam válidas: a Central possui leitura persistente server-only opt-in pela fronteira sessão validada → `issuer + subject` → contexto transacional LOCAL → PostgreSQL/RLS, sem receber identidade ou escopo do browser. O modo persistente continua desabilitado por padrão e falha fechado sem fallback silencioso para fixtures.

A lacuna revelada por F09 também permanece objetiva: as policies F07 autorizam `contractings` por equipe, mas `memberships` e `app_users` continuam self-only para o papel operacional. Portanto a Central ainda não resolve, em runtime, o `display_name` de uma membership responsável colega da mesma equipe.

## Decisão de F10

ADR-004 (`docs/decisions/ADR-004-team-directory-rls-capability-view.md`) registra o desenho escolhido depois de comparar e provar alternativas em PostgreSQL 17 descartável.

Alternativas descartadas:

- policy autorreferente em `memberships`: PostgreSQL reproduziu `infinite recursion detected in policy` (`42P17`);
- view `security_invoker=true`: segura, mas continua limitada às policies self-only e não resolve colegas;
- segunda consulta server-only com o mesmo papel: continua sujeita às mesmas policies;
- `SECURITY DEFINER`/papel privilegiado: adiciona fronteira privilegiada desnecessária;
- tabela/projeção materializada: duplicaria estado de membership/display name e criaria risco de revogação/desabilitação stale antes de existir lifecycle de escrita autorizado.

O desenho preferido é uma **capability view com owner técnico dedicado**:

1. role técnica `NOLOGIN`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT`, sem membership operacional;
2. grants coluna-a-coluna somente no necessário de `memberships` e `app_users`, sem `auth_issuer`/`auth_subject`;
3. policies `SELECT` direcionadas exclusivamente à capability, limitando targets a membership não revogada e usuário não desabilitado;
4. view `security_barrier=true`, `security_invoker=false`, de propriedade da capability;
5. projeção somente `team_id`, `membership_id`, `display_name`;
6. escopo derivado no banco por `current_app_user_id()` + membership ativa do chamador no mesmo `team_id`;
7. papel operacional lê somente a view e continua self-only ao consultar diretamente `memberships`/`app_users`.

Nenhum `team_id` foi adicionado aos claims. `FORCE ROW LEVEL SECURITY` permanece intacto. Nenhuma policy de escrita ou migration de produção de diretório foi criada por F10.

## Prova descartável de F10

`database/tests/team_directory_rls_design.sql` foi integrado à CI como prova isolada sobre `0001 + 0002`.

A prova confirma:

- view `security_invoker` não amplia as policies F07;
- policy autorreferente de `memberships` falha por recursão e é rejeitada;
- capability role de prova é `NOLOGIN`, não superuser, `NOBYPASSRLS`, não owner das tabelas-base e sem role membership;
- capability não possui privilégio de coluna em `auth_issuer`/`auth_subject`;
- view possui ownership/opções de segurança esperados e não contém colunas de Auth externo;
- um principal operacional real simulado com `SET SESSION AUTHORIZATION` não pode `SET ROLE` para a capability;
- A1 vê A1 e A2 ativos da equipe A;
- UUID conhecido de B1 não amplia escopo;
- target com membership revogada ou `app_user` desabilitado não aparece;
- B1 vê somente a equipe B;
- caller sem membership, desabilitado, revogado ou desconhecido recebe diretório vazio;
- acesso direto do papel operacional a `memberships`/`app_users` continua self-only.

## Red-team e correções

A primeira CI da PR #12 (`33656705847`) encontrou uma deficiência na própria prova: o teste de `SET ROLE` rodava após `SET ROLE compras_directory_probe`, mas a sessão autenticada original ainda era `postgres`; como `SET ROLE` é autorizado em relação ao `session_user`, o superuser conseguia trocar para a capability e invalidava a tentativa de provar isolamento.

O teste foi corrigido para usar `SET SESSION AUTHORIZATION compras_directory_probe`, modelando um principal realmente não privilegiado. A CI seguinte da PR (`33657028400`) passou integralmente, incluindo a impossibilidade de escalar para a capability. Esse achado não exigiu relaxar o desenho; endureceu a validade da prova.

Outros pontos red-team preservados:

- nenhum owner/superuser/`BYPASSRLS` é credencial operacional;
- nenhum `SECURITY DEFINER` entrou no desenho aprovado;
- nenhuma coluna de identidade externa é projetada no diretório;
- nenhum scope ID vem do browser ou de claim adicional;
- revogação/desabilitação são lidas da fonte canônica, sem cópia assíncrona;
- Q-009 e Q-010 não foram resolvidas por inferência;
- somente fixtures artificiais `DEMO-*`/UUIDs sintéticos foram usadas.

## Verificação de F10

- recuperação de `main`, branches, PRs e Issues: PASS;
- nenhuma frente concorrente aberta no início: PASS;
- `CONTEXT_MANIFEST` validado contra o tree de `main`: PASS;
- documentação/código de F07, F08 e F09 revisados diretamente: PASS;
- documentação oficial PostgreSQL 17 para RLS, views, segurança de funções e atributos de roles revalidada: PASS;
- ADR-004 + prova descartável + SPEC da F11: PASS;
- diff final da PR #12: PASS — somente ADR, teste de design, CI e SPEC da próxima work unit;
- secret, dado real/interno ou infraestrutura externa: NÃO ENCONTRADOS;
- migration de produção/policy de escrita/runtime da Central alterado em F10: NÃO;
- primeira CI da PR `33656705847`: FAIL controlado — prova de `SET ROLE` inválida por `session_user` superuser; corrigida;
- CI final da PR `33657028400`: PASS — `verify` e `database`;
- PR #12 squash-merged em `8c7c77e855b8d6a367a726a0a5c8ad8a010bbcf3`;
- CI da `main` após merge: run `33657182891`, jobs `verify` e `database`: PASS;
- prova isolada `0001` default-deny: PASS;
- regressões `0001 + 0002`, RLS/red-team e transporte F08: PASS;
- prova F10 do diretório: PASS;
- `npm ci`, lint, typecheck, testes e build: PASS.

## Limite arquitetural para F11

A implementação real criará uma role PostgreSQL cluster-level e ownership de view. F11 deve tratar explicitamente criação/reuso seguro dessa role, atributos inseguros preexistentes, privilégios necessários ao principal de migration, ausência de memberships, ownership final, grants mínimos e rejeição da capability pelo adaptador F08 como role operacional.

A migration não pode substituir esses invariantes por owner/superuser/BYPASSRLS operacional apenas para simplificar deployment.

## Segurança e limites atuais

Nenhum banco/Auth hospedado, secret, usuário operacional real, deploy ou dado pré-publicação foi criado. O diretório de equipe está **desenhado e provado**, mas ainda não existe como migration/runtime de produção.

`docs/product/OPEN_QUESTIONS.md` permanece canônico para questões não resolvidas; F10 não resolveu taxonomias, regra de preços, inatividade, pendências, permissões funcionais, auditoria de leitura, integrações públicas ou IA.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F10 e os blobs permanecem válidos. ADR-004, testes, CI, CURRENT_STATE e NEXT_ACTION são lidos ao vivo pelo protocolo.

## Last good

`8c7c77e855b8d6a367a726a0a5c8ad8a010bbcf3` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33657182891` com os jobs `verify` e `database` em PASS.

## Próxima ação

Executar `F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01` conforme `docs/ai/NEXT_ACTION.md`, `tasks/F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01/SPEC.md` e ADR-004.
