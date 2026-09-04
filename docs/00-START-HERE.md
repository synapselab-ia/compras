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

A F20 transformou essa decisão em implementação e passou integralmente a CI `33869932738`.

## F20 — Better Auth self-hosted implementado

O runtime privado agora usa Better Auth self-hosted com PostgreSQL:

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

Nenhuma execução hospedada desse bootstrap foi feita na F20.

## Próxima frente

A única `NEXT_ACTION` está em `docs/ai/NEXT_ACTION.md`:

`F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01 — Provisionar e provar preview privado fictício com Better Auth self-hosted`.

A F21 deve provar a arquitetura F20 no ambiente hospedado real, ainda exclusivamente com identidade/dados fictícios, com Vercel Authentication antes de secrets e rollback se qualquer gate externo falhar.

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
