# ADR-005 — Lifecycle da role de capability do diretório em PostgreSQL 17

**Status:** Accepted  
**Data:** 2026-09-02  
**Escopo:** refinamento de implementação da ADR-004 para criação/reuso seguro da role cluster-level

## Contexto

A ADR-004 escolheu uma capability view com owner técnico dedicado para expor somente `team_id`, `membership_id` e `display_name` de membros ativos da mesma equipe, sem abrir `auth_issuer`/`auth_subject`, sem `BYPASSRLS` e sem tornar o papel operacional owner das tabelas protegidas.

Na implementação F11 foi revalidada a semântica atual de PostgreSQL 17 para `CREATEROLE`, membership e transferência de ownership:

- `ALTER VIEW ... OWNER TO` exige que o principal que altera o owner possa `SET ROLE` para o novo owner e que o novo owner tenha `CREATE` no schema;
- um não-superuser com `CREATEROLE` que cria uma nova role recebe automaticamente uma concessão administrativa dessa role com `ADMIN TRUE`, `SET FALSE` e `INHERIT FALSE`;
- essa concessão automática é registrada pelo bootstrap superuser e não pode ser removida/modificada pelo próprio `CREATEROLE` que criou a role;
- uma membership com `SET FALSE` e `INHERIT FALSE` não permite usar os privilégios da role por herança nem por `SET ROLE`.

Fontes oficiais revalidadas em 2026-09-02:

- PostgreSQL 17 — Role Attributes: https://www.postgresql.org/docs/17/role-attributes.html
- PostgreSQL 17 — Role Membership: https://www.postgresql.org/docs/17/role-membership.html
- PostgreSQL 17 — GRANT: https://www.postgresql.org/docs/17/sql-grant.html
- PostgreSQL 17 — REVOKE: https://www.postgresql.org/docs/17/sql-revoke.html
- PostgreSQL 17 — SET ROLE: https://www.postgresql.org/docs/17/sql-set-role.html
- PostgreSQL 17 — ALTER VIEW: https://www.postgresql.org/docs/17/sql-alterview.html

Também foi revalidado que, em Neon, roles criadas pelo Console/CLI/API são associadas à role `neon_superuser`, enquanto roles criadas por SQL seguem a semântica normal do PostgreSQL. A F11 não provisiona Neon, mas essa diferença importa para a futura aplicação da migration.

## Problema encontrado

A formulação literal da prova F10 exigia zero linhas em `pg_auth_members` relacionadas à capability. Isso é possível quando um superuser cria a role, mas não é uma propriedade portável para um principal normal com `CREATEROLE` em PostgreSQL 17: o próprio PostgreSQL cria a concessão administrativa descrita acima.

Exigir zero linhas levaria a uma destas alternativas inadequadas:

1. tornar superuser um requisito da migration;
2. criar a role por um mecanismo externo privilegiado sem provar seus memberships;
3. abandonar o owner dedicado e usar o owner das tabelas-base;
4. aceitar silenciosamente uma role privilegiada do provedor.

Todas contradizem o objetivo de segurança da ADR-004.

## Decisão

A propriedade de segurança é refinada de **“zero membership rows”** para **“zero membership utilizável”**.

No estado final, `compras_team_directory_view_owner` deve:

- permanecer `NOLOGIN`, `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` e `NOREPLICATION`;
- não ser membro de nenhuma outra role;
- não possuir nenhuma concessão com `SET TRUE` ou `INHERIT TRUE` para qualquer principal;
- não ser concedida a nenhum papel operacional;
- aceitar, quando criada por um principal não-superuser `CREATEROLE`, somente a concessão administrativa automática para o mesmo principal de migration, com `ADMIN TRUE`, `SET FALSE` e `INHERIT FALSE`;
- falhar fechado se existir qualquer outra forma de membership, inclusive membership da capability em role privilegiada do provedor.

O principal de migration é administrativo e não pode ser a credencial operacional validada por F08.

## Transferência de ownership

Para um principal não-superuser que criou/administra a capability:

1. a migration verifica primeiro que a única concessão existente é a administração-only esperada;
2. dentro da mesma transação, o principal concede a si próprio uma concessão adicional com `SET TRUE`, explicitamente `GRANTED BY CURRENT_USER`;
3. transfere o owner da view para a capability;
4. revoga integralmente essa concessão adicional antes do commit;
5. um postflight confirma que nenhum `SET TRUE`/`INHERIT TRUE` ficou persistido.

Se qualquer etapa falhar, a transação inteira é revertida. Não existe janela persistida em que a aplicação possa assumir a capability.

Se a role já existir e o principal de migration não possuir a administração necessária para realizar a transferência de ownership, a migration falha fechado. A solução futura deve ser corrigir o principal de migration/provisionamento; não usar owner, superuser ou `BYPASSRLS` como credencial operacional.

## Neon / provedor hospedado

A F11 continua sem provisionar infraestrutura. Para uma futura implantação em Neon:

- a capability não deve ser criada por um caminho que a torne membro de `neon_superuser`;
- a migration contém preflight que rejeita qualquer membership da capability em outra role;
- a forma efetiva de criação/aplicação deve ser provada no ambiente descartável/preview antes de produção;
- `neondb_owner` continua proibido como `DATABASE_URL` operacional pelo adaptador F08.

## Consequências

### Positivas

- a migration funciona com um database owner não-superuser que possua `CREATEROLE`, modelo mais próximo de serviço PostgreSQL gerenciado;
- ownership continua separado das tabelas-base;
- nenhuma role operacional pode herdar ou assumir a capability;
- não é necessário exigir superuser de produção;
- uma capability criada por control plane com membership privilegiada é rejeitada em vez de aceita pelo nome.

### Custo

- o principal de migration mantém a concessão administrativa automática que o próprio PostgreSQL 17 impõe;
- a segurança precisa verificar `admin_option`, `set_option`, `inherit_option`, membro e direção do relacionamento, não apenas contar linhas em `pg_auth_members`;
- trocar o principal de migration posteriormente pode exigir ação administrativa explícita antes de reaplicar migrations em outro banco do mesmo cluster.

## Relação com ADR-004

ADR-004 continua válida quanto à arquitetura do diretório, RLS, grants coluna-a-coluna, owner dedicado e proibição de acesso operacional privilegiado.

Esta ADR substitui somente a interpretação literal de “nenhuma membership” por uma condição executável e mais forte sobre **capacidade real de uso da role**: nenhuma concessão persistente pode permitir `SET ROLE` ou herança da capability.
