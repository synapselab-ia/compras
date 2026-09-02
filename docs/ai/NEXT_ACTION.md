# Next Action — Compras

## F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01 — Implementar capability view do diretório de equipe

**Classe:** `T2 — banco/segurança` com impacto de `T5 — arquitetura`  
**Estado:** READY  
**Objetivo:** transformar o desenho validado pela F10 em migration canônica segura e integrar a Central persistente ao diretório mínimo de responsáveis, sem abrir identidade externa, aceitar escopo do browser, criar escrita ou usar papel operacional privilegiado.

## Fonte da tarefa

Executar conforme `tasks/F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01/SPEC.md` e `docs/decisions/ADR-004-team-directory-rls-capability-view.md`.

## Resultado esperado

Ao final, o repositório deve possuir:

- migration ordenada `database/migrations/0003_team_member_directory.sql`;
- capability role técnica dedicada, preferencialmente `compras_team_directory_view_owner`, com `NOLOGIN`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE` e `NOINHERIT`;
- validação fail-closed se uma role homônima cluster-level já existir com atributos incompatíveis;
- grants coluna-a-coluna mínimos sobre `memberships` e `app_users`, sem acesso a `auth_issuer`/`auth_subject`;
- policies `SELECT` dirigidas somente à capability para memberships não revogadas e app_users não desabilitados;
- view `public.team_member_directory`, de propriedade da capability, `security_barrier=true`, `security_invoker=false`, contendo somente `team_id`, `membership_id`, `display_name`;
- escopo da view derivado de `current_app_user_id()` + membership ativa do chamador no mesmo `team_id`, sem parâmetro ou claim de escopo;
- adaptador F08 rejeitando explicitamente a capability como role operacional normal;
- Central persistente resolvendo `responsible_membership_id` pela view mínima, sem abrir `memberships`/`app_users` diretamente para colegas;
- testes PostgreSQL e de aplicação cobrindo ownership, role isolation, revogação, desabilitação, cross-team e regressões anteriores.

## Regras obrigatórias

- não reescrever migrations `0001` ou `0002`;
- tratar roles PostgreSQL como cluster-level e não confiar somente no nome de uma role preexistente;
- falhar fechado se a capability preexistente tiver `LOGIN`, superuser, `BYPASSRLS`, `CREATEDB`, `CREATEROLE` ou configuração incompatível;
- não conceder membership permanente do principal de migration ou do papel operacional à capability;
- capability não pode ser owner de `memberships`, `app_users` nem qualquer tabela protegida;
- manter `FORCE ROW LEVEL SECURITY` nas tabelas-base;
- não criar `SECURITY DEFINER` para contornar o desenho aprovado;
- não criar policy permissiva de `INSERT`, `UPDATE`, `DELETE` ou `ALL`;
- não conceder `SELECT` de `auth_issuer` ou `auth_subject` à capability;
- não adicionar `team_id`, `membership_id` ou `app_user_id` ao contexto confiável;
- não aceitar IDs de escopo/identidade do browser;
- não usar owner, superuser, `neondb_owner`, `BYPASSRLS` ou a capability como credencial operacional da aplicação;
- Q-009 e Q-010 permanecem abertas;
- usar somente fixtures artificiais/sanitizadas;
- nenhum recurso externo, secret ou dado real.

## Segurança mínima a provar

- migration `0001 + 0002 + 0003` aplica do zero em PostgreSQL descartável;
- capability possui exatamente os atributos de segurança esperados e nenhuma membership incompatível;
- capability não possui ownership de tabelas protegidas;
- view possui owner correto, `security_barrier=true` e semântica owner (`security_invoker=false`);
- capability não consegue selecionar `auth_issuer`/`auth_subject`;
- papel operacional autenticado de teste não consegue `SET ROLE` para capability;
- sem contexto, identidade desconhecida, usuário sem membership, usuário desabilitado ou caller com membership revogada recebem diretório vazio;
- A1 ativo vê A1 e A2 ativos da equipe A e não vê B1, mesmo conhecendo UUID;
- membership target revogada e usuário target desabilitado não aparecem;
- SELECT direto do papel operacional em `memberships`/`app_users` continua self-only;
- nenhuma nova policy de escrita existe;
- `assertOperationalRole()` rejeita explicitamente a capability;
- a Central usa somente a view para nome de responsável colega.

## Verificação obrigatória

- prova isolada de `0001` default-deny: PASS;
- regressões `0001 + 0002`/F07/F08: PASS;
- migration `0001 + 0002 + 0003`: PASS;
- suíte adversarial do diretório: PASS;
- testes da leitura persistente F09/F11: PASS;
- red-team de role preexistente insegura, ownership, grants, `SET ROLE`, auth columns, cross-team e adapter: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI: PASS;
- diff integral sem secret, dado real ou infraestrutura provisionada.

## Fora do escopo

Não:

- policy de escrita ou RPC de mutação;
- CRUD de membership/app_user;
- perfil/role funcional da Q-009;
- auditoria de leitura da Q-010;
- login/signup/admissão;
- criação de usuários reais;
- banco/Auth/Data API/Vercel hospedados;
- detalhe persistente;
- deploy;
- dados reais.

## Critério de encerramento

A tarefa termina quando a capability role + view estiverem versionadas em migration segura, a Central persistente resolver responsáveis ativos da própria equipe exclusivamente pela projeção mínima, o papel operacional continuar incapaz de ler identidade externa ou assumir a capability, todos os gates passarem e o checkpoint deixar exatamente uma nova `NEXT_ACTION` executável para a próxima fronteira necessária.
