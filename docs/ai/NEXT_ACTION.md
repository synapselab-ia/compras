# Next Action — Compras

## F07-SERVER-IDENTITY-READ-RLS-01 — Contexto de identidade server-only e policies de leitura

**Classe:** `T2 — banco/segurança`  
**Estado:** READY  
**Objetivo:** implementar e provar, somente em PostgreSQL descartável, a camada de identidade contextual e as primeiras policies permissivas de `SELECT` definidas por ADR-003, sem conectar Auth real, banco hospedado ou UI.

## Fonte da tarefa

Executar conforme `tasks/F07-SERVER-IDENTITY-READ-RLS-01/SPEC.md` e `docs/decisions/ADR-003-trusted-identity-rls-boundary.md`.

## Resultado esperado

Ao final, o repositório deve possuir:

- nova migration ordenada, preferencialmente `database/migrations/0002_trusted_identity_read_policies.sql`;
- helpers portáveis que leiam somente `issuer + subject` do contexto transacional estabelecido pelo servidor;
- resolução do `app_user` corrente sem aceitar `user_id`, `membership_id` ou `team_id` do cliente;
- policy de `app_users` que exponha apenas a própria identidade interna ativa sem recursão de RLS;
- policies de `memberships` e `teams` baseadas em membership ativa;
- policies `SELECT` de `contractings`, `related_identifiers`, `contracting_items` e `contracting_events` limitadas aos `team_id` autorizados;
- zero policy permissiva de `INSERT`, `UPDATE` ou `DELETE`;
- testes adversariais reproduzíveis com papel não owner e `NOBYPASSRLS`;
- CI preservando a prova separada da fundação `0001` default-deny e validando `0001 + 0002`.

## Regras obrigatórias

- não reescrever `0001_core_foundation.sql`;
- não instalar nem conectar `@neondatabase/auth` nesta slice;
- não provisionar Neon, Data API, Vercel ou qualquer recurso externo;
- não criar secret, cookie real, JWT real, connection string ou usuário real;
- `request.jwt.claims` em teste é somente transporte artificial; não declarar que uma variável configurável por cliente SQL é identidade confiável;
- helpers de identidade não recebem IDs de autorização como argumentos;
- preferir `STABLE`, `SECURITY INVOKER` e `search_path` deliberado; não usar `SECURITY DEFINER` para contornar RLS;
- não usar owner, superuser, `neondb_owner` ou `BYPASSRLS` como caminho normal ou prova de autorização;
- Q-009 permanece aberta; membership ativa não cria perfil/role de edição;
- Q-010 permanece aberta; não adicionar auditoria de leitura;
- não criar auto-provisionamento de `app_users` ou memberships;
- usar exclusivamente UUIDs e textos artificiais/sanitizados.

## Segurança mínima a provar

- ausência de contexto autenticado resulta em zero linhas internas;
- contexto ausente, incompleto, inválido ou identidade desconhecida falha fechado;
- `app_user` desabilitado não recebe acesso;
- usuário conhecido sem membership não lê equipes nem dados operacionais;
- membership ativa permite apenas o próprio escopo;
- membership revogada deixa de autorizar sem depender de novo login;
- conhecer UUID válido de outra equipe não amplia acesso em nenhuma tabela operacional;
- `app_users` não expõe outros usuários;
- o papel operacional não consegue escrever por inexistência de policy/grant permissivo de escrita;
- a policy de `app_users` não entra em recursão com helper de usuário corrente.

## Verificação obrigatória

- migrations `0001 + 0002` aplicadas em PostgreSQL descartável: PASS;
- prova isolada do estado default-deny de `0001`: PASS;
- suíte adversarial de leitura/RLS: PASS;
- red-team de policies, grants, funções e fixtures: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes da aplicação: PASS;
- build: PASS;
- CI: PASS;
- nenhum secret, dado real ou recurso externo no diff.

## Fora do escopo

Não:

- Auth/login/signup real;
- controle de admissão/convite;
- banco hospedado;
- Data API operacional;
- integração server-side com sessão real;
- CRUD persistente da aplicação;
- policy de escrita ou RPC de mutação;
- perfis/roles da Q-009;
- auditoria de leitura da Q-010;
- deploy;
- dados reais.

## Critério de encerramento

A tarefa termina quando a camada PostgreSQL de leitura autorizada estiver reproduzível em CI, todos os cenários adversariais previstos passarem sem papel privilegiado, a fundação `0001` continuar verificável e o checkpoint deixar exatamente uma nova `NEXT_ACTION` executável para a próxima fronteira necessária.
