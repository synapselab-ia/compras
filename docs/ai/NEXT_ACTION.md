# Next Action — Compras

## F08-SERVER-TRUST-ADAPTER-01 — Integrar sessão server-side e contexto transacional

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** implementar o primeiro adaptador server-only que use a API oficial atual do provedor de Auth para obter uma sessão validada, derive `issuer + subject` sem aceitar identidade do browser e estabeleça esse contexto `LOCAL` dentro de uma transação PostgreSQL compatível com ADR-003 e as policies de F07, sem provisionar infraestrutura nem expor login/signup nesta slice.

## Fonte da tarefa

Executar conforme `tasks/F08-SERVER-TRUST-ADAPTER-01/SPEC.md` e `docs/decisions/ADR-003-trusted-identity-rls-boundary.md`.

## Resultado esperado

Ao final, o repositório deve possuir:

- revalidação em documentação oficial atual das APIs server-side de Managed Better Auth e do driver PostgreSQL/Neon usados;
- dependências externas somente se necessárias e confirmadas oficialmente no momento da execução;
- módulo `server-only` que obtenha a sessão pela API oficial real do SDK e retorne identidade externa somente após validação bem-sucedida;
- `auth_issuer` vindo exclusivamente de configuração confiável do servidor e `auth_subject` vindo da sessão validada;
- nenhum parâmetro de browser capaz de escolher `issuer`, `subject`, `app_user_id`, `membership_id` ou `team_id`;
- adaptador de banco server-only que abra a unidade transacional e defina `request.jwt.claims` com `SET LOCAL`/`set_config(..., true)` de forma parametrizada antes da consulta protegida;
- conexão operacional planejada/instanciada sem owner, superuser ou `BYPASSRLS` como fluxo normal;
- fail-closed quando sessão, issuer configurado, subject ou contexto transacional não puderem ser obtidos com segurança;
- testes unitários/adversariais que provem a fronteira sem secrets ou recurso hospedado real;
- nenhuma rota/UI de login ou signup e nenhuma leitura persistente apresentada ao usuário ainda.

## Regras obrigatórias

- revalidar documentação oficial atual antes de afirmar comportamento do SDK/Auth/driver;
- produção deve chamar a API real do SDK server-side; não criar um provider fictício como caminho principal;
- testes podem usar mocks/fakes somente nas bordas externas;
- não provisionar Neon, Auth, Data API, Vercel, banco ou recurso externo;
- não criar, solicitar, versionar ou logar secret, cookie secret, JWT real ou connection string real;
- variáveis de ambiente devem ser server-only e nunca possuir prefixo/exposição pública quando contiverem segredo;
- não expor signup/login nesta slice;
- não auto-provisionar `app_users` ou memberships;
- não enviar membership/team/user interno para o contexto como identidade confiável;
- contexto PostgreSQL deve ser local à transação e não sobreviver a reutilização de conexão;
- SQL que estabelece contexto deve ser parametrizado; não interpolar claims em comando SQL;
- não usar owner, `neondb_owner`, superuser ou `BYPASSRLS` como papel operacional;
- não reduzir ou contornar as policies de F07;
- Q-009 e Q-010 permanecem abertas;
- usar somente fixtures fictícias/sanitizadas.

## Segurança mínima a provar

- sessão ausente ou inválida não produz identidade externa utilizável;
- issuer não pode ser escolhido por header, query, body, cookie arbitrário ou hostname fornecido pelo cliente;
- subject não pode ser substituído por ID enviado pelo browser;
- contexto de banco contém somente `iss + sub` derivados da fronteira confiável;
- falha ao estabelecer transação/contexto impede a consulta protegida;
- o contexto é `LOCAL` e não vaza entre duas operações consecutivas/reutilização de conexão em teste;
- nenhum secret/connection string aparece em bundle client-side, fixture, log ou erro serializado;
- um chamador não consegue injetar `team_id`, `membership_id` ou `app_user_id` para ampliar escopo;
- adapter não funciona com role owner/BYPASSRLS como configuração normal;
- signup público continua não exposto.

## Verificação obrigatória

- documentação oficial atual consultada e registrada quando houver mudança material;
- testes do adaptador de identidade: PASS;
- testes do contexto transacional: PASS;
- red-team de inputs, env, sessão, SQL e reutilização de conexão: PASS;
- migrations `0001 + 0002` e testes de RLS continuam PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI: PASS;
- diff integral sem secret, dado real ou recurso externo provisionado.

## Fora do escopo

Não:

- provisionar projeto Neon/Auth;
- usar credencial real;
- login/signup UI;
- controle de convite/admissão definitivo;
- conectar a Central/detalhe a dados persistentes reais;
- criar auto-provisionamento de usuário/membership;
- policy de escrita ou RPC de mutação;
- perfis/roles da Q-009;
- auditoria de leitura da Q-010;
- deploy;
- dados reais.

## Critério de encerramento

A tarefa termina quando o caminho de produção server-only estiver codificado contra as APIs oficiais atuais, sessão validada for convertida exclusivamente em `issuer + subject`, o contexto transacional for estabelecido de forma local e parametrizada, os testes adversariais provarem fail-closed sem recurso hospedado e existir exatamente uma nova `NEXT_ACTION` executável para conectar uma leitura real da aplicação ou resolver um bloqueio objetivo encontrado.
