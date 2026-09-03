# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados.

## Estado atual

A `Foundation-00` e as work units F01 a F14 estão integradas. Elas entregaram:

- protótipo Central → detalhe → Central;
- fundação PostgreSQL default-deny com `FORCE RLS`;
- identidade confiável `issuer + subject` estabelecida no servidor;
- leituras persistentes protegidas e diretório mínimo da equipe;
- sign-in email/senha e sign-out por Server Actions;
- `/api/auth/[...path]` deny-all para signup/OAuth/OTP/Admin e superfícies laterais não usadas.

A F15/F16 prepararam a fronteira do primeiro preview privado. A F17 executou prova real nos consoles Vercel e Neon:

- **Vercel:** PASS para Deployment Protection e variável Preview + branch, com rollback;
- **Neon Managed Better Auth:** BLOCKED porque a superfície observada permite signup por padrão e não permite aplicar/read-back `disable_sign_up=true`; o Auth/projeto descartáveis foram removidos.

A F17 permanece `ON HOLD` como evidência do blocker externo, mas deixou de ser caminho crítico depois da F19.

## F18 — demonstração hospedada

A ADR-008 criou uma faixa independente de **DEMO / PUBLIC DATA** sem Auth interno, banco ou secrets.

A F18 publicou com sucesso um deployment Vercel Preview da aplicação Next.js usando apenas o modo demo:

- deployment `READY`;
- target Preview (`null`), não Production;
- Vercel Authentication na frente da URL;
- nenhum `DATABASE_URL`, `NEON_AUTH_*`, token ou secret;
- nenhum recurso Neon;
- `COMPRAS_PERSISTENT_READ_ENABLED` não habilitado;
- somente fixtures fictícias;
- Git auto-deploy restaurado para `false`.

Essa faixa não é ambiente operacional e não autoriza dados reais.

## F19 — Better Auth self-hosted adotado

A F19 revalidou documentação oficial Better Auth v1.6 e executou prova local/efêmera real.

A prova demonstrou:

- `disableSignUp=true` rejeita signup;
- social providers/plugins laterais podem permanecer ausentes;
- migrations Auth podem ser controladas pela aplicação;
- bootstrap one-shot não roteável consegue criar somente a identidade fictícia necessária ao laboratório;
- ao voltar para configuração fechada, novo signup continua negado;
- usuário existente autentica por server API;
- cookie emitido resolve sessão server-side;
- sign-out emite invalidação de cookie.

A CI passou em lint, typecheck, testes, build e toda a suíte PostgreSQL/RLS existente.

A ADR-009 registrou **ADOPT**: o primeiro preview privado deve substituir Managed Neon Auth por Better Auth self-hosted.

Neon pode continuar como PostgreSQL hospedado; a política de Auth passa a ser controlada e versionada pela aplicação.

Fronteira escolhida:

- catch-all Auth continua deny-all;
- sign-in/sign-out continuam Server Actions;
- `disableSignUp=true` no motor;
- nenhum social provider/plugin de método lateral;
- trusted origins estritos;
- sessão validada server-side;
- issuer estável `urn:compras:better-auth:self-hosted:v1`;
- `subject` vem de `Better Auth user.id` validado;
- Auth user não cria `app_user`/membership automaticamente;
- schema Auth dedicado `auth`;
- role Auth runtime separada, sem superuser/BYPASSRLS/ownership e sem grants no domínio;
- `AUTH_DATABASE_URL` separado de `DATABASE_URL`;
- secrets exclusivamente server-side;
- migrations Auth geradas da versão pinada e versionadas antes de hospedagem.

## Próxima frente

A única `NEXT_ACTION` está em `docs/ai/NEXT_ACTION.md`:

`F20-SELF-HOSTED-AUTH-IMPLEMENT-01 — Implementar Better Auth self-hosted mantendo a fronteira F14/F08`.

A F20 deve transformar a decisão F19 em código e migrations reproduzíveis, ainda somente em local/CI efêmero e sem provisionamento hosted persistente.

## Modos da aplicação

### Demo

É o padrão quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`.

- somente fixtures fictícias;
- nenhuma consulta operacional ao banco;
- banner explícito `Protótipo com dados fictícios`;
- permitido na faixa F18.

### Persistente

Só existe quando `COMPRAS_PERSISTENT_READ_ENABLED=true` e todos os preflight/gates de Auth, banco, secrets e autorização estiverem satisfeitos.

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

F20 adicionará uma trilha separada de migrations Auth; não reescreverá as migrations do domínio.

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
