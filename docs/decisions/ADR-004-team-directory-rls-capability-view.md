# ADR-004 — Diretório mínimo de equipe por capability view sob RLS

**Status:** Accepted for implementation in a dedicated next slice  
**Data:** 2026-09-02  
**Escopo:** desenho e prova em PostgreSQL descartável; nenhuma migration de produção de diretório nesta ADR

## Contexto

A F09 conectou a Central ao caminho persistente server-only e revelou uma lacuna deliberada da F07: `contractings` são visíveis por membership ativa da equipe, mas `memberships` e `app_users` expõem somente a própria linha. Assim, uma contratação pode referenciar `responsible_membership_id` de outro membro autorizado da mesma equipe sem que a Central consiga obter seu `display_name`.

A solução deve preservar todos os invariantes já aprovados:

- identidade continua `issuer + subject -> app_user ativo -> membership ativa -> team_id`;
- `FORCE ROW LEVEL SECURITY` permanece nas tabelas do núcleo;
- o browser não escolhe `team_id`, `membership_id`, `app_user_id`, issuer ou subject;
- o papel operacional normal não é owner, superuser nem `BYPASSRLS`;
- `auth_issuer` e `auth_subject` não podem virar dados de diretório;
- membership revogada e usuário desabilitado devem desaparecer do diretório sem depender de cache ou cópia eventualmente consistente;
- Q-009 e Q-010 continuam abertas.

## Evidência PostgreSQL revalidada

Documentação oficial PostgreSQL 17 consultada em 2026-09-02:

- Row Security Policies: https://www.postgresql.org/docs/17/ddl-rowsecurity.html
- CREATE VIEW: https://www.postgresql.org/docs/17/sql-createview.html
- ALTER VIEW: https://www.postgresql.org/docs/17/sql-alterview.html
- Function Security: https://www.postgresql.org/docs/17/perm-functions.html
- Role Attributes: https://www.postgresql.org/docs/17/role-attributes.html

Pontos relevantes confirmados:

1. RLS é default-deny quando habilitada e não existe policy aplicável; superusers e roles `BYPASSRLS` bypassam RLS, enquanto owner normalmente bypassa salvo `FORCE ROW LEVEL SECURITY`.
2. Uma view `security_invoker=true` usa privilégios e policies do invocador nas tabelas-base. Portanto ela não amplia por si só o conjunto de linhas que o invocador já pode ler.
3. Por padrão, uma view usa privilégios do owner para acessar as relações-base. Quando relações-base possuem RLS, as policies do owner da view são aplicadas; isso torna ownership parte explícita da fronteira de segurança.
4. `security_barrier=true` existe para views usadas como barreira de segurança e evita que predicados do chamador sejam tratados como equivalentes aos predicados internos da view.
5. `SECURITY DEFINER` executa com privilégios do owner da função e aumenta a superfície de confiança; funções e policies também exigem controle rigoroso de ownership e `search_path`.

Além da documentação, `database/tests/team_directory_rls_design.sql` prova as propriedades relevantes em PostgreSQL 17 descartável.

## Alternativas analisadas

### 1. Expandir diretamente a policy de `memberships`

Forma intuitiva:

```sql
USING (
  EXISTS (
    SELECT 1
    FROM memberships AS viewer
    WHERE viewer.team_id = memberships.team_id
      AND viewer.user_id = current_app_user_id()
      AND viewer.revoked_at IS NULL
  )
)
```

Problema: a policy consulta a própria relação protegida. A prova descartável reproduz `infinite recursion detected in policy for relation "memberships"`.

Também não resolve isoladamente `app_users`: abrir as linhas de colegas nessa tabela ampliaria a superfície que contém `auth_issuer` e `auth_subject`.

**Decisão:** rejeitada.

### 2. View `security_invoker`

Uma view contendo somente `team_id`, `membership_id` e `display_name` minimiza colunas, porém `security_invoker=true` aplica as policies atuais do chamador nas tabelas-base.

A prova descartável confirma que, com F07 intacta, essa view continua vendo apenas a própria membership/`app_user`; ela não resolve o responsável colega.

**Decisão:** segura, mas insuficiente.

### 3. Função estreita `SECURITY DEFINER`

Uma função privilegiada poderia encapsular a projeção mínima, mas o problema de escopo não desaparece: ou a função continua sujeita às policies atuais e só enxerga o próprio usuário, ou passa a depender de ownership/bypass/policies especiais. Além disso, uma função `SECURITY DEFINER` cria uma fronteira privilegiada adicional desnecessária se uma view com owner dedicado resolver o caso.

**Decisão:** não preferida nesta fase.

### 4. Tabela/projeção materializada de diretório

Uma tabela com `team_id`, `membership_id` e `display_name` permitiria RLS simples sem recursão. Entretanto passaria a duplicar estado que hoje é canônico em `memberships`/`app_users`.

Para cumprir os requisitos de revogação e desabilitação, a segurança dependeria de sincronização transacional em toda futura criação, revogação, reativação, alteração de nome e desabilitação. Ainda não existe caminho de escrita/admissão autorizado no produto, e adicionar triggers privilegiados ou policy de escrita nesta slice violaria seu limite.

**Decisão:** rejeitada por enquanto; não introduzir projeção potencialmente stale apenas para resolver leitura.

### 5. Resolver apenas no servidor sem alterar RLS

O servidor usa o mesmo papel não privilegiado da F08. Com as policies atuais, uma segunda consulta server-side continua incapaz de ver a membership/`app_user` colega. Trocar para owner, `neondb_owner`, superuser ou `BYPASSRLS` seria justamente contornar o enforcement validado.

**Decisão:** rejeitada.

### 6. Capability view com owner dedicado, não logável e sem bypass

A prova descartável demonstra uma alternativa sem duplicação de dados e sem remover `FORCE RLS`:

1. criar uma role de capability dedicada ao objeto de diretório, com `NOLOGIN`, `NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`, `NOINHERIT` e `NOBYPASSRLS`;
2. não conceder membership dessa role a papéis operacionais;
3. conceder à capability somente `SELECT` das colunas necessárias das relações-base:
   - `memberships(id, team_id, user_id, revoked_at)`;
   - `app_users(id, display_name, disabled_at)`;
4. adicionar policies `SELECT` direcionadas somente a essa capability, permitindo nela apenas memberships não revogadas e usuários não desabilitados;
5. criar uma view `security_barrier=true` e `security_invoker=false`, de propriedade da capability, que retorne exclusivamente:
   - `team_id`;
   - `membership_id`;
   - `display_name`;
6. dentro da view, exigir explicitamente que exista uma membership ativa do `current_app_user_id()` no mesmo `team_id` do membro-alvo;
7. conceder ao papel operacional apenas `SELECT` da view, além dos privilégios já necessários à fronteira F07/F08.

A capability não é papel operacional. Ela não é owner das tabelas protegidas e não possui `BYPASSRLS`. `FORCE RLS` continua ativo nas tabelas-base. As policies amplas existem somente para a role selada que possui a view; o chamador normal continua sujeito às policies F07 quando acessa as tabelas diretamente.

A prova descartável confirma:

- A1 vê A1 e A2 da mesma equipe;
- A1 não vê B1 de outra equipe mesmo conhecendo UUID;
- membership revogada não aparece;
- usuário desabilitado não aparece;
- chamador sem membership, desconhecido ou desabilitado recebe diretório vazio;
- a view não contém `auth_issuer` nem `auth_subject`;
- o papel operacional não consegue `SET ROLE` para a capability;
- a capability é `NOLOGIN`, não superuser e `NOBYPASSRLS`;
- acesso direto do papel operacional a `memberships`/`app_users` continua limitado pelas policies F07.

**Decisão:** alternativa preferida.

## Por que a implementation fica em uma slice própria

Embora o padrão tenha sido provado em PostgreSQL descartável, promovê-lo como migration de produção cria um novo invariante de deployment: uma role cluster-level de capability passa a existir e será owner de um objeto executado no caminho normal de leitura.

Isso exige, na implementação, verificar de forma explícita:

- criação/reuso seguro da role em clusters onde roles são globais;
- requisito de `CREATEROLE`/capacidade de atribuir ownership ao principal de migration;
- ausência de memberships concedidas à capability;
- ownership final da view e grants coluna-a-coluna;
- comportamento quando a migration é aplicada em mais de um banco do mesmo cluster;
- rejeição da capability como credencial operacional no adaptador F08;
- grants mínimos necessários à futura role server-only;
- rollback/fail-closed se a role preexistir com atributos inseguros.

Esses pontos são materialmente arquiteturais e não devem ser escondidos dentro da F10 apenas para eliminar o rótulo genérico da UI. F10 encerra com desenho escolhido e prova executável; F11 implementará a migration e integração da Central.

## Forma esperada da view

A implementação futura deve ser semanticamente equivalente a:

```sql
SELECT
  target.team_id,
  target.id AS membership_id,
  target_user.display_name
FROM public.memberships AS target
JOIN public.app_users AS target_user
  ON target_user.id = target.user_id
WHERE target.revoked_at IS NULL
  AND target_user.disabled_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.memberships AS viewer
    WHERE viewer.team_id = target.team_id
      AND viewer.user_id = public.current_app_user_id()
      AND viewer.revoked_at IS NULL
  );
```

A segurança desse SELECT depende do ownership/policies exclusivos da capability. Copiar somente a query sem esses controles não implementa esta ADR.

## Red-team

### Recursão

Policy autorreferente de `memberships` foi reproduzida e rejeitada; não será usada.

### Owner privilegiado

A capability escolhida não pode ser superuser, `BYPASSRLS`, owner de `memberships`/`app_users` nem role de login. Uma view pertencente ao migration owner/superuser não é equivalente ao desenho aprovado.

### Escalada por `SET ROLE`

Nenhum papel operacional recebe membership na capability. A implementação deve testar `pg_has_role`/membership e tentativa de `SET ROLE`.

### Exposição de Auth

A capability recebe grants coluna-a-coluna e a view não possui `auth_issuer`/`auth_subject`. `SELECT *` da view não pode devolver identidade externa.

### Revogação e desabilitação

A leitura usa diretamente `memberships.revoked_at` e `app_users.disabled_at`; não existe cópia assíncrona a ficar stale.

### Cross-team

O `team_id` do alvo só passa quando existe membership ativa do usuário corrente no mesmo escopo. UUID conhecido não participa como autorização.

### Claim/escopo do browser

Nenhum `team_id` novo entra em `request.jwt.claims`. O escopo continua derivado de `current_app_user_id()` + memberships no banco.

## Consequências

### Positivas

- evita duplicar `display_name`/estado de membership;
- revogação e desabilitação são refletidas imediatamente pela fonte canônica;
- não amplia a tabela `app_users` para o papel operacional;
- mantém `issuer + subject` fora do diretório;
- mantém `FORCE RLS` e não usa `BYPASSRLS`;
- não adiciona `team_id` ao contexto confiável;
- Q-009 permanece totalmente separada de visibilidade de nomes.

### Custos

- introduz uma role técnica dedicada de capability;
- ownership da view vira parte da configuração de segurança e deve ser testado;
- migrations passam a precisar considerar que roles PostgreSQL são cluster-level;
- deployment precisa garantir privilégios adequados ao migration principal sem transformar essa role em credencial operacional.

## Próxima implementação permitida

A próxima slice deve implementar `0003_team_member_directory.sql` conforme esta ADR, provar a role/capability em PostgreSQL descartável, atualizar a query persistente da Central para usar somente a view mínima e endurecer o adaptador F08 para rejeitar essa role como identidade operacional.

Nenhuma policy de escrita, papel funcional da Q-009, auditoria de leitura da Q-010, login/admissão, infraestrutura hospedada ou dado real entra nessa implementação.
