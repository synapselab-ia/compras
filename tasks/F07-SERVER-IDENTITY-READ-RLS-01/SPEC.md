# F07-SERVER-IDENTITY-READ-RLS-01 — Contexto de identidade server-only e policies de leitura

**Classe:** T2 — banco/segurança  
**Estado:** READY após conclusão de F06  
**Dependência:** ADR-003 e migration `0001_core_foundation.sql`  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

O núcleo já possui RLS `default-deny`, mas ainda não existe caminho de leitura autorizado. F06 definiu uma fronteira portável em que o servidor valida a sessão externa e transmite apenas `issuer + subject` como contexto local da transação. A próxima slice deve implementar e provar a parte PostgreSQL dessa fronteira sem provisionar Auth, Neon ou qualquer recurso hospedado.

## 2. Resultado esperado

Criar uma nova migration, sem reescrever `0001_core_foundation.sql`, que implemente:

- helpers portáveis para ler issuer/subject do contexto transacional verificado;
- resolução do `app_user` corrente por `auth_issuer + auth_subject`, excluindo usuário desabilitado;
- policies `SELECT` mínimas nas sete tabelas do núcleo;
- autorização por membership ativa para dados de equipe;
- ausência total de policy permissiva de escrita;
- testes SQL adversariais em PostgreSQL descartável.

Nome esperado da migration:

```text
database/migrations/0002_trusted_identity_read_policies.sql
```

Se o nome precisar mudar por convenção técnica, manter ordenação e finalidade explícitas.

## 3. Contrato de contexto

O banco não valida a sessão externa nesta slice. Ele recebe apenas contexto já estabelecido por servidor confiável.

Nos testes, o transporte pode usar `request.jwt.claims` com JSON artificial contendo apenas os campos necessários (`iss`, `sub`), porque esse mecanismo é reproduzível em PostgreSQL comum.

Regras:

- helpers não recebem `user_id`, `membership_id` ou `team_id` como argumento;
- contexto ausente, vazio, inválido ou incompleto deve retornar `NULL`/nenhum usuário e falhar fechado;
- helpers devem ser `STABLE`, `SECURITY INVOKER` e ter `search_path` deliberado quando aplicável;
- não usar `SECURITY DEFINER` para contornar RLS;
- não criar BYPASSRLS;
- não alegar que `request.jwt.claims` é confiável por si só: a autenticidade permanece responsabilidade da camada server-side definida por ADR-003.

## 4. Policies de leitura

Implementar somente `SELECT`.

### `app_users`

Permitir apenas a própria linha quando:

- `auth_issuer` corresponde ao issuer do contexto;
- `auth_subject` corresponde ao subject do contexto;
- `disabled_at IS NULL`.

A policy de `app_users` não deve chamar helper que consulte `app_users` e cause recursão de RLS.

### `memberships`

Permitir somente memberships do usuário corrente com `revoked_at IS NULL`.

### `teams`

Permitir somente equipes para as quais o usuário corrente possua membership ativa.

### Tabelas operacionais

`contractings`, `related_identifiers`, `contracting_items` e `contracting_events` devem permitir leitura somente quando a linha pertence a `team_id` com membership ativa do usuário corrente.

Não inferir role/perfil. Q-009 continua aberta.

## 5. Grants

A migration não deve conceder leitura a `PUBLIC`, papel anônimo ou papel privilegiado amplo.

Para exercitar RLS, os testes podem criar um papel operacional artificial `NOLOGIN`, `NOBYPASSRLS`, não owner, e conceder somente os grants necessários no banco descartável.

Nenhum grant de `INSERT`, `UPDATE` ou `DELETE` de produção entra nesta slice.

## 6. Testes obrigatórios

A suíte deve provar, no mínimo:

- migration `0001` + `0002` aplicam do zero em PostgreSQL descartável;
- sem contexto autenticado, nenhuma linha interna é legível pelo papel operacional;
- contexto sem `iss`, sem `sub`, com JSON inválido ou identidade desconhecida falha fechado;
- usuário interno desabilitado não lê sua linha nem dados de equipe;
- usuário autenticado conhecido sem membership não lê equipe/dados operacionais;
- membership ativa permite leitura da própria equipe;
- membership revogada não permite leitura;
- membership de uma equipe não permite ler UUID conhecido de outra equipe;
- `app_users` expõe somente a própria linha, não outros usuários;
- `memberships` expõe somente vínculos ativos do próprio usuário;
- `teams` expõe somente equipes autorizadas;
- as quatro tabelas operacionais respeitam o mesmo escopo;
- não existem policies `INSERT`, `UPDATE` ou `DELETE` permissivas;
- o papel operacional não consegue escrever mesmo conhecendo UUID válido;
- owner/BYPASSRLS não é usado como prova de autorização;
- todos os fixtures são artificiais.

## 7. CI

Manter a estratégia atual de PostgreSQL efêmero e adicionar a nova migration/testes ao job de banco.

Gates:

- `0001` + `0002` em banco vazio: PASS;
- testes antigos de integridade/default-deny continuam PASS quando executados no ponto apropriado;
- novos testes de leitura/RLS: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes da aplicação: PASS;
- build: PASS.

Se a ordem dos testes antigos precisar ser separada porque `0002` passa a criar policies permissivas de leitura, preservar explicitamente uma prova da fundação `0001` default-deny em banco/etapa isolada; não apagar o teste para fazer a suíte passar.

## 8. Red-team obrigatório

Antes de promover:

- tentar forjar `iss`/`sub` via dados do browser no código — não deve existir caminho de confiança implementado aqui;
- tentar contexto vazio/parcial/inválido;
- tentar identidade válida sem `app_user`;
- tentar `app_user` desabilitado;
- tentar membership revogada;
- tentar UUID conhecido cross-team em cada tabela operacional;
- tentar explorar recursão de policy entre `app_users` e `memberships`;
- procurar `SECURITY DEFINER`, owner/BYPASSRLS, `USING (true)`, grant a `PUBLIC` ou escrita permissiva;
- confirmar que RLS, e não apenas ausência de grant, explica o isolamento nos testes de leitura;
- procurar resolução silenciosa de Q-009/Q-010;
- revisar fixtures/logs por aparência de dado real;
- revisar migration completa, testes e CI.

## 9. Fora do escopo

Não:

- instalar `@neondatabase/auth`;
- conectar Managed Better Auth real;
- provisionar Neon/Data API/Vercel;
- criar secret/cookie real;
- expor login/signup;
- criar `app_user` ou membership automaticamente no login;
- implementar admissão/convite;
- implementar escrita persistente;
- definir roles/perfis da Q-009;
- implementar auditoria de leitura da Q-010;
- usar dados reais.

## 10. Critério de encerramento

A tarefa termina quando a camada PostgreSQL de leitura autorizada estiver reproduzível em CI, todos os cenários adversariais passarem sem papel privilegiado, a fundação `0001` continuar verificável, e existir exatamente uma nova `NEXT_ACTION` para integrar a sessão server-side real ou para corrigir um bloqueio técnico concreto descoberto pela implementação.
