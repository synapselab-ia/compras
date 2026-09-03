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

A F17 está `ON HOLD` por capacidade externa objetiva. Não há ação manual de login/credencial pendente.

## F18 — demonstração hospedada

O protocolo canônico determina que uma frente `ON HOLD` não deve bloquear uma work unit independente. Por isso a ADR-008 criou uma faixa hospedada de **DEMO / PUBLIC DATA** que não usa Auth interno, banco ou secrets e não altera os requisitos do futuro preview privado.

A F18 publicou com sucesso um deployment Vercel Preview da aplicação Next.js usando apenas o modo demo já versionado:

- deployment `READY`;
- target Preview (`null`), não Production;
- Vercel Authentication permaneceu na frente da URL;
- nenhum `DATABASE_URL`, `NEON_AUTH_*`, token ou secret;
- nenhum recurso Neon;
- `COMPRAS_PERSISTENT_READ_ENABLED` não habilitado;
- somente fixtures explicitamente fictícias;
- Git auto-deploy restaurado para `false` após a publicação deliberada.

Uma tentativa preliminar havia revelado dois riscos reais e foi encerrada fail-closed: a Vercel classificou o primeiro push como Production e, com preset `Other`, o build falhou procurando diretório `public`. Nenhum secret/dado foi anexado. A F18 corrigiu o framework por configuração versionada `framework: "nextjs"` e a publicação efetiva ocorreu como Preview.

Essa demo hospedada é apenas uma superfície de UI com dados fictícios. Ela **não** significa que Auth, PostgreSQL hospedado, RLS hospedado ou dados reais estejam liberados.

`REAL_DATA_ALLOWED = NO` permanece absoluto.

## Próxima frente

A única `NEXT_ACTION` está em `docs/ai/NEXT_ACTION.md`:

`F19-AUTH-PORTABILITY-DESIGN-01 — Desenhar Better Auth self-hosted para remover dependência do signup controlado pelo Neon`.

A hipótese deve ser provada, não presumida. A documentação oficial atual do Better Auth expõe PostgreSQL, `emailAndPassword.disableSignUp`, `trustedOrigins` e schema/migrations controláveis pela aplicação. A F19 deve decidir se isso permite preservar a fronteira F14/F08/RLS e eliminar o blocker estrutural do Managed Neon Auth.

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
sessão validada no servidor
-> issuer + subject
-> contexto transacional LOCAL
-> PostgreSQL com role runtime não privilegiada
-> RLS
-> somente registros autorizados
```

Falha de Auth/banco/configuração não pode cair silenciosamente para demo.

## Banco canônico

Migrations imutáveis atuais:

- `database/migrations/0001_core_foundation.sql` — schema + default-deny/`FORCE RLS`;
- `database/migrations/0002_trusted_identity_read_policies.sql` — helpers de identidade e primeiras policies de leitura;
- `database/migrations/0003_team_member_directory.sql` — capability view mínima do diretório da equipe.

Mudança estrutural nova usa nova migration; migration aplicada não é reescrita.

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
- `docs/decisions/ADR-008-public-demo-hosted-lane.md`.

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
- provider role privilegiada nunca é runtime normal;
- secrets nunca vão para Git, chat, URL, log, summary ou artifact público;
- documentação de provider não substitui readback real quando o controle é crítico;
- blocker externo objetivo entra `ON HOLD`; não deve paralisar work independente;
- falha protegida não vira sucesso demonstrativo silenciosamente;
- toda mudança arquitetural relevante recebe ADR;
- construir por slices pequenas, verificáveis e reversíveis.
