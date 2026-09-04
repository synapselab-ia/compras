# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados.

## Estado atual

A `Foundation-00` e as work units F01 a F14 estão integradas e entregaram:

- protótipo Central → detalhe → Central;
- fundação PostgreSQL default-deny com `FORCE RLS`;
- identidade confiável `issuer + subject` estabelecida no servidor;
- leituras persistentes protegidas e diretório mínimo da equipe;
- sign-in email/senha e sign-out por Server Actions;
- `/api/auth/[...path]` deny-all para signup/OAuth/OTP/Admin e superfícies laterais não usadas.

F15/F16 prepararam a fronteira do primeiro preview privado. F17 provou o control plane Vercel, mas o Managed Neon Auth observado não permitia aplicar/read-back do enforcement obrigatório de signup restrito; essa rota permanece `ON HOLD` apenas como evidência histórica.

A F18 mantém uma faixa independente de demonstração hospedada, protegida por Vercel Authentication, usando somente fixtures fictícias, sem banco/Auth interno/secrets e sem `COMPRAS_PERSISTENT_READ_ENABLED`.

A F19 adotou Better Auth self-hosted pela ADR-009.

A F20 transformou essa decisão em implementação e a F22 acrescentou assets reproduzíveis de bootstrap/seed/smoke para o futuro preview persistente, todos ainda exclusivamente fictícios e provados em PostgreSQL descartável/CI.

## F20 — Better Auth self-hosted implementado

O runtime privado usa Better Auth self-hosted com PostgreSQL:

- `better-auth@1.6.23` é dependência direta e pinada;
- `@neondatabase/auth` saiu do runtime;
- `emailAndPassword.enabled=true`;
- `disableSignUp=true`;
- `socialProviders={}`;
- nenhum plugin de método lateral;
- trusted origin HTTPS exata;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- `subject` nasce somente da sessão validada no servidor;
- cookie cache não foi habilitado;
- `/api/auth/[...path]` continua deny-all.

Sign-in e sign-out continuam exclusivamente por Server Actions estreitas. O transporte de cookies é explícito e o código somente declara sucesso depois de provar readback da sessão ou revogação real.

## Banco Auth

Há uma trilha separada de migrations:

- `database/auth/migrations/0001_better_auth_1_6_23.sql`;
- `database/auth/migrations/0002_auth_runtime_boundary.sql`.

A role `compras_auth_runtime` deve ser login não privilegiado, sem ownership, superuser, `BYPASSRLS`, `CREATEDB`, `CREATEROLE` ou replication.

A CI provou:

- Auth runtime não lê tabelas do domínio;
- role de domínio não lê tabelas Auth;
- autenticação não cria `app_users` nem membership automaticamente;
- signup permanece fechado;
- sign-in, sessão e sign-out funcionam com identidade fictícia;
- toda a suíte PostgreSQL/RLS existente continua em PASS.

## Bootstrap fictício

Existe bootstrap one-shot administrativo e não roteável para laboratório/preflight:

- precisa de modo explícito `FICTITIOUS_ONE_SHOT`;
- aceita somente identidade `example.invalid`;
- cria somente identidade Better Auth;
- não concede autorização interna;
- não deve permanecer habilitado após a operação.

Nenhuma execução hospedada desse bootstrap ocorreu até o checkpoint atual.

## F21 — preview persistente ON HOLD antes de secrets

A F21 recuperou o estado real de GitHub, Vercel e Neon e revalidou a documentação oficial vigente.

Foi confirmado que:

- o Preview fictício F18 continua `READY` e atrás da barreira de autenticação Vercel;
- a criação da branch F21 não disparou novo deployment automático;
- não existe projeto Neon dedicado a Compras e nenhum recurso Neon foi criado para F21;
- Vercel suporta Deployment Protection e sensitive Preview environment variables escopadas por branch.

A execução parou fail-closed porque a superfície Vercel autenticada disponível na sessão não expõe o readback/CRUD necessário para os dois gates externos obrigatórios: estado completo da proteção/bypasses e environment variables sensíveis de Preview por branch.

Nenhum secret ou recurso hosted novo foi criado. F21 fica `ON HOLD` até essa capacidade de control plane estar disponível; a proteção não será reduzida para contornar o blocker.

## F22 — seed e smoke reproduzíveis

A F22 materializou o pacote operacional fictício que a F21 precisará quando puder ser retomada.

O seed `server-only`:

- exige modo exato `FICTITIOUS_EPHEMERAL`;
- usa somente UUIDs determinísticos, nomes sintéticos e email `example.invalid`;
- cria duas equipes e duas contratações artificiais;
- recebe o `subject` do bootstrap Better Auth e verifica a identidade persistida antes de criar autorização;
- cria `app_user` e membership em etapa administrativa separada do Auth;
- não concede membership à equipe adversarial;
- executa postflight e retorna apenas status sanitizado.

O harness PostgreSQL descartável prova:

- Auth sem `app_user`/membership → zero dados;
- usuário autorizado → somente própria equipe;
- UUID conhecido da outra equipe → invisível;
- claims ausentes/malformados ou issuer/subject errados → fail-closed;
- signup normal continua fechado;
- sign-in, sessão e sign-out permanecem funcionais;
- Auth runtime e domínio runtime continuam separados e não privilegiados;
- Auth não lê domínio e domínio não lê Auth.

A composição do preflight aplica as migrations na ordem:

```text
domínio 0001
-> domínio 0002
-> Auth 0001
-> Auth 0002
-> domínio 0003
```

Essa ordem preserva a ownership dedicada da view `team_member_directory`. Nenhuma migration canônica foi reescrita. Depois da view ser criada, um postflight exige que a role Auth continue sem `SELECT` sobre ela.

O workflow F22 usa apenas PostgreSQL 17 descartável. Credenciais operacionais são geradas no job e mascaradas; nenhum recurso Vercel/Neon hosted é criado.

## Próxima frente

A única `NEXT_ACTION` está em `docs/ai/NEXT_ACTION.md`:

`F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01 — Fechar desenho de controle de abuso do sign-in privado`.

A F23 deve fechar, sem provisionamento hosted, a arquitetura de rate limiting/controle de abuso distribuído do Server Action de sign-in: confiança dos sinais de origem, política de chaveamento, concorrência, indisponibilidade, privacidade, observabilidade e testes adversariais. F21 continua `ON HOLD` até seu `resume_when` externo.

## Modos da aplicação

### Demo

É o padrão quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`.

- somente fixtures fictícias;
- nenhuma consulta operacional ao banco;
- banner explícito `Protótipo com dados fictícios`;
- permitido na faixa F18.

### Persistente

Só existe quando `COMPRAS_PERSISTENT_READ_ENABLED=true` e todos os gates de Auth, banco, secrets e autorização estiverem satisfeitos.

Fluxo de confiança:

```text
sessão Better Auth validada no servidor
-> issuer + subject
-> contexto transacional LOCAL
-> PostgreSQL com role de domínio não privilegiada
-> RLS
-> somente registros autorizados
```

Falha de Auth/banco/configuração não pode cair silenciosamente para demo.

## Banco canônico

Migrations imutáveis do domínio:

- `database/migrations/0001_core_foundation.sql` — schema + default-deny/`FORCE RLS`;
- `database/migrations/0002_trusted_identity_read_policies.sql` — helpers de identidade e primeiras policies de leitura;
- `database/migrations/0003_team_member_directory.sql` — capability view mínima do diretório da equipe.

Migrations Auth ficam separadas em `database/auth/migrations/` e não reescrevem a trilha do domínio.

Assets F22 de preflight ficam em `src/server/preflight/` e não são migrations de produção.

## Fonte de verdade

GitHub é canônico. Chat é descartável.

Ordem mínima para uma nova sessão:

1. `AGENTS.md`;
2. `docs/00-START-HERE.md`;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. abrir a SPEC/ADR/código exigidos pela tarefa ativa.

## Documentos principais

### Produto

- `docs/product/PROJECT_DESIGN.md`;
- `docs/product/DOMAIN_MODEL.md`;
- `docs/product/BUSINESS_WORKFLOW.md`;
- `docs/product/OPEN_QUESTIONS.md`.

### Arquitetura e segurança

- `docs/architecture/ARCHITECTURE.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- `docs/decisions/ADR-002-persistence-foundation.md`;
- `docs/decisions/ADR-003-trusted-identity-rls-boundary.md`;
- `docs/decisions/ADR-004-team-directory-rls-capability-view.md`;
- `docs/decisions/ADR-005-directory-capability-role-lifecycle.md`;
- `docs/decisions/ADR-006-hosted-preview-boundary.md`;
- `docs/decisions/ADR-007-private-auth-admission.md`;
- `docs/decisions/ADR-008-public-demo-hosted-lane.md`;
- `docs/decisions/ADR-009-self-hosted-better-auth.md`.

### Operação por IA

- `docs/ai/SOURCE_OF_TRUTH.md`;
- `docs/ai/WORK_PROTOCOL.md`;
- `docs/ai/CONTEXT_MANIFEST.md`;
- `docs/ai/CURRENT_STATE.md`;
- `docs/ai/NEXT_ACTION.md`.

### Qualidade

- `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- segurança nunca é reduzida para “fazer passar”;
- autenticação não é autorização;
- autorização crítica vive no servidor/banco e RLS permanece autoritativa;
- IDs do cliente nunca definem identidade/escopo;
- signup público não é aceito por conveniência;
- dado real/interno/pré-publicação não entra no repositório público nem na faixa demo;
- role privilegiada nunca é runtime normal;
- secrets nunca vão para Git, chat, URL, log, summary ou artifact público;
- documentação de provider não substitui prova/readback quando o controle é crítico;
- blocker externo objetivo entra `ON HOLD`; não deve paralisar trabalho independente;
- falha protegida não vira sucesso demonstrativo silenciosamente;
- toda mudança arquitetural relevante recebe ADR;
- construir por slices pequenas, verificáveis e reversíveis.
