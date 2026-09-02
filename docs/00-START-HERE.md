# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui os sistemas oficiais de processo administrativo, requisição ou publicação. Ele organiza o trabalho da equipe e, futuramente, pode consumir fontes públicas oficiais para auxiliar pesquisa de preços.

## Estado atual

A `Foundation-00` e as work units F01 a F14 foram concluídas/revisadas e integradas pelo fluxo canônico.

A F15 (`Hosted Preview Provisioning`) foi executada até o preflight obrigatório e **parou com blocker seguro antes de qualquer provisionamento**. Nenhum projeto/deployment/banco/Auth/secret de Compras foi criado.

Existe uma aplicação executável com jornada `Central → detalhe → Central` em dois modos separados:

- **demo**, padrão e exclusivamente fictício;
- **persistente**, opt-in somente quando `COMPRAS_PERSISTENT_READ_ENABLED=true`.

O caminho persistente usa a fronteira confiável implementada em F08: sessão validada no servidor → `issuer + subject` → contexto transacional LOCAL → PostgreSQL/RLS. A Central e o detalhe usam a mesma semântica de ativação e falham fechados: configuração inválida ou falha protegida não é mascarada por fixture demo.

O núcleo relacional possui as migrations imutáveis:

- `database/migrations/0001_core_foundation.sql` — schema + `FORCE RLS` default-deny;
- `database/migrations/0002_trusted_identity_read_policies.sql` — helpers de identidade e primeiras policies somente de `SELECT`;
- `database/migrations/0003_team_member_directory.sql` — capability view mínima para diretório de responsáveis da mesma equipe.

A F11 implementou `public.team_member_directory`, que expõe somente `team_id`, `membership_id` e `display_name` por uma capability técnica `NOLOGIN`/`NOBYPASSRLS`. A Central e o detalhe persistentes usam somente essa projeção para resolver responsáveis colegas.

A F12 conectou `/contratacoes/[id]` à leitura persistente protegida. O ID da rota é validado e usado apenas como seletor UUID parametrizado; RLS continua sendo a fronteira autoritativa. Identificadores relacionados, itens e eventos são lidos somente das tabelas protegidas existentes. UUID de outra equipe permanece indistinguível de inexistente e falha de banco/sessão/configuração resulta em indisponibilidade genérica.

A F13 definiu na ADR-006 a fronteira do primeiro preview hospedado privado: Deployment Protection obrigatório, secrets branch-specific, nenhuma production surface pública sem proteção compatível, papéis PostgreSQL separados para bootstrap/migration/runtime, Managed Better Auth com signup desabilitado e dados exclusivamente fictícios.

A F14 implementou a admissão privada no repositório. A aplicação possui sign-in email/senha e sign-out por Server Actions server-side. O catch-all `/api/auth/[...path]` é deliberadamente deny-all e não delega a `auth.handler()`, impedindo signup, OAuth, OTP, reset, Admin API ou endpoints laterais na superfície HTTP da aplicação. Em modo persistente, ausência de sessão é detectada antes da consulta ao banco e leva ao sign-in; falha do provider/configuração permanece indisponibilidade genérica sem fallback demo. Login não cria `app_users`, memberships ou permissões.

A ADR-007 mantém como requisito independente para o preview real que o Managed Better Auth esteja configurado com `disable_sign_up=true` e métodos adicionais desabilitados. A fronteira F08 e o enforcement PostgreSQL/RLS não foram substituídos.

## Blocker atual do preview hospedado

O preflight F15 revalidou estado real dos providers e encontrou duas lacunas de control-plane:

- **Vercel:** a conta acessível está em Hobby e não existe projeto `compras`; a integração atual permite inspeção/deploy genérico, mas não permite criar/importar projeto com alvo controlado, configurar/verificar `ssoProtection`, gravar env vars Preview/branch-specific nem deprovisionar de forma verificável. Não é seguro fazer o primeiro deploy e tentar proteger depois.
- **Neon:** a organização acessível está em Free e não existe projeto `compras`; a integração atual consegue provisionar Auth e ler configuração, porém não expõe escrita dos campos necessários para definir e provar provider-side `disable_sign_up=true` e métodos adicionais desabilitados.

Por isso F15 não avançou para projeto, banco, Auth, migrations, seed, secrets ou deploy. O blocker está registrado em `docs/ai/CURRENT_STATE.md`.

A CI da `main` após F14, run `33670574481`, permanece o last-good funcional. `REAL_DATA_ALLOWED` continua `NO`.

A próxima ação canônica é `F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01 — Desbloquear o control-plane seguro do preview hospedado`. Ela deve obter e provar as capacidades faltantes sem colar tokens/secrets em GitHub ou chat e sem relaxar ADR-006/ADR-007.

O repositório está público. Aplicam-se integralmente as restrições de publicação de `AGENTS.md` e `docs/architecture/SECURITY.md`; nenhum dado real ou pré-publicação pode ser usado.

## Fonte de verdade

GitHub é canônico. Chat é descartável.

A hierarquia detalhada está em `docs/ai/SOURCE_OF_TRUTH.md`.

## Ordem de leitura para uma nova sessão

1. `AGENTS.md`;
2. `docs/00-START-HERE.md`;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. documentação específica da tarefa;
8. código, migrations e testes relacionados, quando existirem.

## Documentos principais

### Produto

- `docs/product/PROJECT_DESIGN.md` — visão e limites do produto;
- `docs/product/DOMAIN_MODEL.md` — entidades e invariantes iniciais;
- `docs/product/BUSINESS_WORKFLOW.md` — workflow sanitizado inicial;
- `docs/product/OPEN_QUESTIONS.md` — questões que não podem ser resolvidas por inferência.

### Arquitetura e segurança

- `docs/architecture/ARCHITECTURE.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md` — contrato da fundação persistente;
- `docs/decisions/ADR-002-persistence-foundation.md` — fundação relacional/default-deny;
- `docs/decisions/ADR-003-trusted-identity-rls-boundary.md` — fronteira de identidade confiável e autorização de leitura;
- `docs/decisions/ADR-004-team-directory-rls-capability-view.md` — desenho do diretório mínimo;
- `docs/decisions/ADR-005-directory-capability-role-lifecycle.md` — lifecycle seguro da role cluster-level;
- `docs/decisions/ADR-006-hosted-preview-boundary.md` — fronteira do primeiro preview privado fictício;
- `docs/decisions/ADR-007-private-auth-admission.md` — admissão privada por Server Actions sem proxy Auth genérico.

### Operação por IA

- `docs/ai/SOURCE_OF_TRUTH.md`;
- `docs/ai/WORK_PROTOCOL.md`;
- `docs/ai/CONTEXT_MANIFEST.md`;
- `docs/ai/CURRENT_STATE.md`;
- `docs/ai/NEXT_ACTION.md`.

### Qualidade

- `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- modelar o processo real, não copiar planilhas literalmente;
- contratação é a unidade operacional principal;
- separar etapa, status, responsável, aguardando quem e próxima ação;
- histórico relevante deve ser rastreável;
- nenhuma regra crítica existe somente na interface;
- privacidade e segurança entram desde a primeira tabela;
- persistência nasce relacional, portátil e deny-by-default;
- autenticação não é autorização; escopo deriva de membership ativa no banco;
- IDs fornecidos pelo cliente nunca definem identidade ou escopo por si só;
- contexto de identidade no banco só é confiável quando estabelecido por servidor autenticador controlado;
- capability técnica de leitura não é credencial operacional e não pode ser assumida pelo aplicativo;
- falha protegida não pode ser convertida silenciosamente em sucesso demonstrativo;
- signup público deve ser impedido no enforcement da aplicação e também no provider hospedado;
- endpoints de Auth não utilizados permanecem fechados por padrão;
- preview privado exige proteção efetiva e não apenas URL obscura;
- roles privilegiadas do provider nunca são credencial runtime;
- infraestrutura externa deve ser revalidada antes de provisionamento;
- ausência de ferramenta de controle é blocker, não autorização para ordem insegura;
- evitar complexidade prematura;
- construir por slices pequenas, utilizáveis e verificáveis;
- qualquer incerteza importante aumenta a investigação, nunca autoriza adivinhação.
