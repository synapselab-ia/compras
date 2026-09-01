# Current State — Compras

**PROJECT_STATUS:** READY_FOR_SERVER_TRUST_ADAPTER  
**CURRENT_PHASE:** F08 — Server Session / Trust Adapter  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_AND_DETAIL_PROTOTYPE  
**DATABASE_STATUS:** TRUSTED_READ_RLS_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** TRUST_BOUNDARY_DESIGNED_NOT_INTEGRATED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `3fbcfd18a65a5ebce3ca28cb0f4ef8889878dc58`  
**LAST_GOOD_CI_RUN:** `33560055900`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F07-SERVER-IDENTITY-READ-RLS-01` foi concluída e integrada à `main` pela PR #9.

O PostgreSQL agora possui a segunda migration imutável, `database/migrations/0002_trusted_identity_read_policies.sql`, que implementa somente a parte de banco da fronteira aprovada em ADR-003:

- `current_auth_issuer()` e `current_auth_subject()` leem `iss`/`sub` do contexto transacional e retornam `NULL` para contexto ausente, vazio ou JSON inválido;
- `current_app_user_id()` resolve o par exato `auth_issuer + auth_subject` para `app_users.id` somente quando o usuário interno não está desabilitado;
- os três helpers são `STABLE`, `SECURITY INVOKER`, fixam `search_path` e tiveram `EXECUTE` revogado de `PUBLIC`;
- a policy de `app_users` compara diretamente `issuer + subject` e não chama `current_app_user_id()`, evitando recursão de RLS;
- `memberships` expõe somente vínculo ativo do usuário corrente;
- `teams`, `contractings`, `related_identifiers`, `contracting_items` e `contracting_events` exigem membership ativa no `team_id` da linha;
- existem exatamente sete policies permissivas e todas são `SELECT`;
- não existe policy permissiva de `INSERT`, `UPDATE` ou `DELETE` nem grant operacional de produção nesta migration.

`request.jwt.claims` continua sendo apenas um transporte reproduzível no teste. A migration não valida sessão externa e não transforma variável de sessão configurável por cliente SQL em identidade confiável. ADR-003 continua exigindo que um servidor confiável valide a sessão e estabeleça o contexto `LOCAL` dentro da transação usando credencial server-only sem `BYPASSRLS`.

A aplicação ainda não possui Auth, conexão operacional com PostgreSQL ou leitura persistente. Nenhum recurso Neon/Data API/Vercel foi provisionado e nenhum secret ou dado real foi introduzido.

## Verificação de F07

- recuperação de `main`, branches e PRs: PASS;
- nenhuma PR concorrente estava aberta no início da work unit: PASS;
- `CONTEXT_MANIFEST` validado contra todos os blobs estáveis: PASS;
- leitura direta de `CURRENT_STATE`, `NEXT_ACTION`, SPEC F07, ADR-003, migration `0001` e CI: PASS;
- migration `0001` isolada + suíte antiga de default-deny/integridade: PASS;
- migrations `0001 + 0002` em PostgreSQL 17 descartável: PASS;
- contexto ausente, inválido, incompleto ou identidade desconhecida: fail-closed — PASS;
- identidade externa composta `issuer + subject`: PASS;
- usuário conhecido sem membership: sem acesso de equipe — PASS;
- `app_user` desabilitado: sem acesso — PASS;
- membership revogada: sem acesso — PASS;
- membership ativa: acesso somente ao próprio escopo — PASS;
- UUID conhecido cross-team em contratação, identificador, item e evento: negado — PASS;
- `app_users` expõe somente a própria linha ativa: PASS;
- papel operacional artificial é não owner, `NOSUPERUSER` e `NOBYPASSRLS`: PASS;
- papel de teste com grants DML amplos não consegue inserir, atualizar ou excluir sem policy de escrita: PASS;
- `PUBLIC` não executa helpers de identidade: PASS;
- PR #9 CI final: PASS — run `33559959109`, jobs `verify` e `database`;
- CI da `main` após squash merge: PASS — run `33560055900`, jobs `verify` e `database`;
- `npm ci`, lint, typecheck, testes da aplicação e build: PASS;
- dados reais, secrets ou recursos externos no diff: NÃO ENCONTRADOS.

## Red-team e correções

A revisão adversarial encontrou e corrigiu antes da promoção:

1. **Normalização silenciosa de identidade:** a primeira versão aplicava `btrim` aos valores de `iss` e `sub`. Como ADR-003 exige comparação exata do par verificado, essa normalização foi removida. Testes adicionais provam que issuer diferente com mesmo subject e valores com espaços não resolvem a identidade existente.
2. **Cobertura integral de negação:** a suíte adicional prova que usuário sem membership, membership revogada e usuário desabilitado não enxergam nenhuma das quatro tabelas operacionais, não apenas a raiz `contractings`.
3. **RLS versus falta de grant:** o papel principal de teste recebe `SELECT/INSERT/UPDATE/DELETE` somente no banco descartável, garantindo que a negação de escrita seja causada pela ausência de policy permissiva e pelo RLS, não por um teste trivial de ACL.
4. **Privilégio do executor:** os helpers permanecem `SECURITY INVOKER`; nenhum `SECURITY DEFINER`, owner ou `BYPASSRLS` foi introduzido.
5. **Fundação preservada:** a CI usa bancos separados para provar `0001` ainda totalmente default-deny antes de testar a abertura seletiva de leitura em `0002`.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. F07 não criou role/perfil de membership, auditoria de leitura, taxonomia ou regra de negócio nova.

## Segurança e limites atuais

As policies de leitura estão executáveis e validadas, mas ainda não existe uma fonte de identidade confiável ligada à aplicação. Portanto, a existência de `0002` não autoriza uso com dados reais nem conexão direta do browser ao banco.

A próxima fronteira precisa integrar a sessão server-side real ao contrato de ADR-003 e garantir que apenas o servidor consiga estabelecer `issuer + subject` na transação. Signup/admissão, banco hospedado e dados reais continuam fora até revisão específica.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados pela F07. Todos os hashes continuam válidos; migrations, testes, CI, `CURRENT_STATE` e `NEXT_ACTION` são lidos ao vivo pelo protocolo.

## Last good

`3fbcfd18a65a5ebce3ca28cb0f4ef8889878dc58` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33560055900` com os jobs `verify` e `database` em PASS.

## Próxima ação

Executar `F08-SERVER-TRUST-ADAPTER-01` conforme `docs/ai/NEXT_ACTION.md`, `tasks/F08-SERVER-TRUST-ADAPTER-01/SPEC.md` e ADR-003.
