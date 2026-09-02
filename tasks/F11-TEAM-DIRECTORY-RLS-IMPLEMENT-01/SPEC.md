# F11-TEAM-DIRECTORY-RLS-IMPLEMENT-01 — Implementar capability view do diretório de equipe

**Classe:** T2 — banco/segurança, com impacto de T5 — arquitetura  
**Estado:** READY após conclusão de F10  
**Dependências:** ADR-004, F07, F08, F09 e migrations `0001`/`0002`  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

F10 provou em PostgreSQL 17 que:

- policy autorreferente de `memberships` entra em recursão;
- view `security_invoker` não amplia as policies self-only da F07;
- uma capability role `NOLOGIN`/`NOBYPASSRLS`, dona apenas de uma security-barrier view e com policies/grants coluna-a-coluna próprios, consegue expor somente `team_id + membership_id + display_name` de membros ativos da mesma equipe sem abrir `auth_issuer`/`auth_subject` ao papel operacional.

F11 deve transformar esse padrão provado em migration canônica e integrar a Central persistente, sem adicionar escrita, Auth real ou infraestrutura hospedada.

## 2. Resultado esperado

Criar a migration ordenável:

```text
database/migrations/0003_team_member_directory.sql
```

A migration deve implementar uma capability equivalente à prova da F10, com nome de role técnico estável e explícito, preferencialmente:

```text
compras_team_directory_view_owner
```

E criar uma view pública mínima, preferencialmente:

```text
public.team_member_directory
```

com somente:

- `team_id`;
- `membership_id`;
- `display_name`.

A query persistente da Central deve passar a resolver `responsible_membership_id` exclusivamente por essa view, eliminando `Responsável não disponível` quando o responsável for um membro ativo/não desabilitado da mesma equipe.

## 3. Capability role

A role técnica deve ser separada de qualquer credencial operacional e possuir, no estado final:

- `NOLOGIN`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOINHERIT`;
- nenhuma membership concedida a ela;
- nenhum papel operacional como membro dela;
- nenhuma ownership de `memberships`, `app_users` ou outras tabelas protegidas.

Ela pode ser owner somente da view de diretório e de objetos auxiliares estritamente necessários ao mesmo boundary.

A implementação deve considerar que roles PostgreSQL são cluster-level. Se a role já existir:

- validar atributos antes de reutilizar;
- falhar fechado se houver `LOGIN`, superuser, `BYPASSRLS`, `CREATEDB`, `CREATEROLE` ou configuração incompatível;
- não assumir que uma role homônima é segura apenas pelo nome;
- não conceder membership permanente ao principal de migration apenas para transferir ownership.

Se a transferência de ownership exigir privilégio de migration que não possa ser representado de forma portável/segura na migration, registrar o bloqueio objetivo e não substituir a capability por owner/superuser operacional.

## 4. Grants e policies da capability

A capability deve receber somente os grants de coluna necessários:

### `memberships`

- `id`;
- `team_id`;
- `user_id`;
- `revoked_at`.

### `app_users`

- `id`;
- `display_name`;
- `disabled_at`.

Ela não deve possuir `SELECT` em `auth_issuer` ou `auth_subject`.

Criar policies `SELECT` direcionadas apenas à capability que permitam:

- `memberships` somente quando `revoked_at IS NULL`;
- `app_users` somente quando `disabled_at IS NULL`.

As policies F07 para o papel operacional normal permanecem intactas.

Não criar policy permissiva de `INSERT`, `UPDATE`, `DELETE` ou `ALL`.

## 5. View de diretório

A view deve:

- ser de propriedade da capability role;
- usar `security_barrier=true`;
- usar explicitamente `security_invoker=false`/semântica de owner aprovada em ADR-004;
- retornar somente `team_id`, `membership_id`, `display_name`;
- não conter nem depender de coluna retornável `auth_issuer`/`auth_subject`;
- filtrar target membership revogada e target user desabilitado;
- exigir `EXISTS` de membership ativa do `current_app_user_id()` no mesmo `team_id`;
- não aceitar IDs/escopo como parâmetro;
- não depender de `team_id` em claim novo.

A segurança da view depende do conjunto completo role + grants + policies + ownership. Não implementar somente o SELECT isolado.

## 6. Integração F08/F09

### Adaptador F08

Endurecer `assertOperationalRole()` para que a capability role de diretório nunca seja aceita como credencial operacional normal, mesmo sendo `NOLOGIN`/`NOBYPASSRLS`.

Não reduzir os checks atuais de superuser, `BYPASSRLS`, owner protegido ou `neondb_owner`.

### Central F09

Atualizar `src/features/sector-central/persistent-read.ts` para:

- remover joins diretos usados apenas para resolver a própria membership;
- fazer `LEFT JOIN public.team_member_directory` por `team_id + responsible_membership_id`;
- usar o `display_name` da view como nome de responsável autorizado;
- manter `Sem responsável` quando `responsible_membership_id IS NULL`;
- manter fallback genérico somente para inconsistência/indisponibilidade de uma membership que a view corretamente não exponha;
- preservar filtro de ativos e `MAX(contracting_events.occurred_at)` como última movimentação;
- continuar sem link para detalhe persistente enquanto o detalhe continuar demonstrativo.

Nenhum argumento de escopo entra na API de leitura.

## 7. Testes PostgreSQL obrigatórios

Em banco descartável, aplicar `0001 + 0002 + 0003` do zero e provar:

- role capability possui todos os atributos seguros esperados;
- capability não possui membership e não é owner de tabelas protegidas;
- view é propriedade da capability;
- view possui `security_barrier=true` e `security_invoker=false` explicitamente;
- capability não possui privilégio de coluna sobre `auth_issuer`/`auth_subject`;
- papel operacional não pode `SET ROLE` para capability;
- sem contexto: diretório vazio;
- identidade desconhecida: vazio;
- usuário ativo sem membership: vazio;
- usuário desabilitado: vazio;
- membership revogada do chamador: vazio;
- A1 ativo vê A1 e A2 ativos da equipe A;
- A1 não vê B1 da equipe B, inclusive por UUID conhecido;
- target membership revogada não aparece;
- target app_user desabilitado não aparece;
- SELECT direto de `memberships`/`app_users` pelo papel operacional continua self-only;
- a view não possui colunas `auth_issuer`/`auth_subject`;
- zero policy de escrita nova;
- `FORCE ROW LEVEL SECURITY` permanece nas tabelas-base.

Preservar também as provas isoladas de `0001` e `0001 + 0002` existentes.

## 8. Testes de aplicação obrigatórios

Adicionar/ajustar testes para provar:

- a query persistente usa `team_member_directory` e não recebe parâmetros de identidade/escopo;
- responsável colega retornado pela view é mapeado para o `display_name` correto;
- `responsible_membership_id = null` continua `Sem responsável`;
- membership não exposta pela view continua fallback genérico, sem tentativa de contornar RLS;
- erro do banco continua serializado somente como estado indisponível no boundary existente;
- `assertOperationalRole()` rejeita explicitamente a capability role;
- nenhum segredo/connection string aparece em erro/log/bundle.

## 9. Red-team obrigatório

Tentar deliberadamente:

- aplicar migration quando a role homônima preexiste com `LOGIN` ou `BYPASSRLS`;
- conceder membership da capability ao papel de teste e verificar que o desenho detecta a condição insegura;
- consultar `auth_issuer`/`auth_subject` usando a capability;
- usar view owner igual ao owner/superuser das tabelas-base;
- remover `security_barrier` ou transformar a view em `security_invoker=true` e confirmar que a estrutura de teste detecta;
- obter B1 por UUID conhecido usando A1;
- visualizar membership revogada ou usuário desabilitado;
- usar a capability como `DATABASE_URL`/papel operacional no adapter;
- introduzir `team_id`, membership ou user em claims/input de browser;
- criar policy de escrita ou resolver Q-009/Q-010 por acidente.

## 10. CI e gates

Obrigatórios:

- migration `0001 + 0002 + 0003` do zero: PASS;
- suíte do diretório: PASS;
- regressões F05/F07/F08/F09: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI: PASS;
- diff integral revisado;
- nenhum secret, dado real ou recurso externo provisionado.

## 11. Fora do escopo

Não:

- policy de escrita;
- CRUD/mutação de membership ou usuário;
- role funcional/perfil da Q-009;
- auditoria de leitura da Q-010;
- login/signup/admissão;
- criação de usuários reais;
- banco/Auth hospedado;
- detalhe persistente;
- deploy;
- dados reais.

## 12. Critério de encerramento

A tarefa termina quando a capability role + view estiverem versionadas em migration segura, a Central persistente resolver responsáveis ativos da própria equipe somente pela projeção mínima, todos os cenários adversariais passarem sem owner/superuser/BYPASSRLS operacional e existir exatamente uma nova `NEXT_ACTION` executável para a próxima fronteira do produto.
