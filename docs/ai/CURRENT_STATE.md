# Current State — Compras

**PROJECT_STATUS:** READY_FOR_PERSISTENT_DETAIL_READ  
**CURRENT_PHASE:** F12 — Persistent Contracting Detail Read  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_PERSISTENT_READ_WITH_TEAM_DIRECTORY_IMPLEMENTED_OPT_IN  
**DATABASE_STATUS:** TEAM_DIRECTORY_CAPABILITY_IMPLEMENTED_AND_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** SERVER_TRUST_ADAPTER_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `41f069fb0c5e52ec2b92fdf3223ed75c842afd67`  
**LAST_GOOD_CI_RUN:** `33663331813`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01` foi concluída e integrada à `main` pela PR #13.

O caminho persistente da Central continua opt-in por `COMPRAS_PERSISTENT_READ_ENABLED=true`, usa exclusivamente a fronteira F08 (`sessão validada -> issuer + subject -> contexto transacional LOCAL -> PostgreSQL/RLS`) e agora consegue resolver com segurança o nome de outro membro responsável da mesma equipe por uma projeção mínima de diretório.

Nenhum banco/Auth/Vercel hospedado foi provisionado. O modo persistente continua desabilitado por padrão e somente dados fictícios/sanitizados são permitidos nesta fase.

## F11 — capability do diretório de equipe

A migration imutável `database/migrations/0003_team_member_directory.sql` foi adicionada depois de `0001` e `0002`.

Ela implementa:

- role cluster-level `compras_team_directory_view_owner` com `NOLOGIN`, `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT`, `NOREPLICATION` e `NOBYPASSRLS`;
- preflight fail-closed para role preexistente com atributos/configuração incompatíveis;
- rejeição de qualquer membership em que a capability seja membro de outra role;
- rejeição de qualquer concessão persistente que permita `SET ROLE` ou herança da capability;
- grants coluna-a-coluna somente em `memberships(id, team_id, user_id, revoked_at)` e `app_users(id, display_name, disabled_at)`;
- nenhuma leitura de `auth_issuer`/`auth_subject` pela capability;
- policies `SELECT` direcionadas somente à capability para membership não revogada e app_user não desabilitado;
- view `public.team_member_directory` com `security_barrier=true`, `security_invoker=false`, owner dedicado e somente `team_id`, `membership_id`, `display_name`;
- escopo do diretório derivado exclusivamente de `current_app_user_id()` + membership ativa do chamador no mesmo `team_id`;
- `FORCE ROW LEVEL SECURITY` intacto nas sete tabelas-base;
- nenhuma policy de escrita.

## ADR-005 — lifecycle da role cluster-level

Durante a implementação foi revalidada uma nuance material de PostgreSQL 17: um principal não-superuser com `CREATEROLE` recebe automaticamente uma concessão administrativa sobre uma role recém-criada com `ADMIN TRUE`, `SET FALSE` e `INHERIT FALSE`.

A ADR-005 registra o refinamento seguro da ADR-004: a propriedade exigida é **zero membership utilizável**, não literalmente zero linhas em `pg_auth_members`.

A única relação tolerada é a concessão administrativa automática para o mesmo principal de migration, sem `SET` e sem herança. Para transferir ownership da view, a migration cria uma concessão `SET TRUE` adicional somente dentro da própria transação, transfere o owner e revoga essa concessão antes do commit. O postflight falha se qualquer concessão utilizável persistir.

Isso evita exigir superuser de produção e também rejeita uma capability criada por caminho de provedor que a coloque como membro de role privilegiada.

## Integração da Central

`src/features/sector-central/persistent-read.ts` deixou de consultar `memberships`/`app_users` diretamente para descobrir responsável.

A consulta agora faz `LEFT JOIN public.team_member_directory` por `team_id + responsible_membership_id` e usa somente `display_name` da projeção autorizada.

Com isso:

- responsável ativo da mesma equipe pode ser exibido pelo nome;
- `responsible_membership_id IS NULL` continua `Sem responsável`;
- referência que o diretório corretamente não exponha continua `Responsável não disponível`;
- nenhuma identidade ou escopo é recebida do browser;
- `MAX(contracting_events.occurred_at)` continua sendo a última movimentação;
- `updated_at` continua não sendo tratado como evento.

O adaptador F08 passou a rejeitar explicitamente `compras_team_directory_view_owner` como role operacional, além de continuar rejeitando superuser, `BYPASSRLS`, owner das tabelas protegidas e `neondb_owner`.

## Red-team de F11

A CI prova deliberadamente:

- role homônima preexistente com `LOGIN`: migration rejeitada;
- role homônima preexistente com `BYPASSRLS`: migration rejeitada;
- concessão `SET TRUE` da capability a outro principal: migration/regras estruturais rejeitam;
- migration completa executada por database owner não-superuser com `CREATEROLE`;
- mesma capability cluster-level reutilizada com segurança ao aplicar `0001 + 0002 + 0003` em segundo database do mesmo cluster;
- papel operacional real simulado com `SET SESSION AUTHORIZATION` não consegue `SET ROLE` para a capability;
- capability não consegue selecionar `auth_issuer`/`auth_subject`;
- remoção de `security_barrier`, ativação de `security_invoker` e owner incorreto são detectados;
- A1 vê A1/A2 da equipe A e não B1, mesmo conhecendo seu UUID;
- target revogado/desabilitado não aparece;
- caller sem contexto, desconhecido, sem membership, desabilitado ou revogado recebe diretório vazio;
- acesso direto operacional a `memberships`/`app_users` continua self-only;
- nenhuma policy de escrita foi criada.

## Verificação de F11

- recuperação de `main`, branches e PRs: PASS;
- `CONTEXT_MANIFEST` comparado ao tree de `main`: PASS;
- fontes estáveis mantiveram os blobs esperados: `CONTEXT_STATUS = VALID`;
- documentação PostgreSQL 17 e Neon relativa a roles/membership/ownership revalidada antes da decisão ADR-005: PASS;
- diff integral da PR #13 revisado: PASS;
- CI da PR #13 run `33663106823`: PASS — `verify` e `database`;
- PR #13 squash-merged em `41f069fb0c5e52ec2b92fdf3223ed75c842afd67`;
- CI da `main` após merge run `33663331813`: PASS — `verify` e `database`;
- `npm ci`, lint, typecheck, testes e build: PASS;
- prova isolada de `0001` default-deny: PASS;
- regressões `0001 + 0002`/F07/F08/F10: PASS;
- preflight adversarial F11 e `0001 + 0002 + 0003`: PASS;
- secret real, dado interno/pré-publicação ou infraestrutura externa: NÃO ENCONTRADOS.

## Limite atual

A Central possui caminho persistente de leitura completo para os campos já modelados e diretório mínimo de responsáveis. O detalhe em `/contratacoes/[id]`, porém, ainda usa exclusivamente fixtures demonstrativas; por isso o modo persistente ainda não deve navegar para uma tela que pareça mostrar o mesmo registro persistente.

A próxima fronteira independente é conectar o detalhe, em modo opt-in, às mesmas policies RLS e à mesma fronteira server-only, mantendo o modo demo separado e sem provisionar infraestrutura.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. Nenhuma foi resolvida por inferência em F11.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F11. ADR-005, migration `0003`, testes, código runtime, `CURRENT_STATE` e `NEXT_ACTION` são lidos ao vivo pelo protocolo.

## Last good

`41f069fb0c5e52ec2b92fdf3223ed75c842afd67` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33663331813` com `verify` e `database` em PASS.

## Próxima ação

Executar `F12-PERSISTENT-CONTRACTING-DETAIL-READ-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F12-PERSISTENT-CONTRACTING-DETAIL-READ-01/SPEC.md`.
