# Comece aqui — Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui sistemas oficiais. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados.

## Estado atual

A `Foundation-00` e F01–F14 estabeleceram protótipo Central → detalhe, PostgreSQL default-deny/`FORCE RLS`, identidade confiável `issuer + subject`, leituras persistentes protegidas, diretório mínimo, sign-in/sign-out por Server Actions e `/api/auth/[...path]` deny-all.

F15/F16 prepararam a fronteira de preview privado. F17 ficou `ON HOLD` historicamente após provar que o Managed Neon Auth observado não oferecia o enforcement/readback de signup exigido. F18 mantém demonstração hospedada fictícia atrás de Vercel Authentication, sem banco/Auth interno/secrets.

F19 adotou Better Auth self-hosted pela ADR-009; F20 implementou essa decisão. F21 permanece `ON HOLD` antes de secrets por ausência, na superfície Vercel autenticada disponível, de readback/CRUD suficiente para Deployment Protection/bypasses e sensitive Preview environment variables por branch.

F22 criou seed/smoke fictícios reproduzíveis. F23 definiu controle distribuído de abuso pela ADR-010. F24 implementou limiter PostgreSQL distribuído e foi integrada pela PR `#40`.

F25 definiu, pela ADR-011, a primeira mutação persistente rastreável. A próxima implementação é F26.

`REAL_DATA_ALLOWED = NO` permanece invariável.

## Autenticação e limiter

O runtime privado usa Better Auth self-hosted:

- `better-auth@1.6.23` pinado;
- email/senha habilitado, signup desabilitado;
- nenhum provider social/método lateral;
- trusted origin exata;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- sessão/subject validados server-side;
- catch-all Auth deny-all.

Migrations Auth/custom guard:

- `database/auth/migrations/0001_better_auth_1_6_23.sql`;
- `database/auth/migrations/0002_auth_runtime_boundary.sql`;
- `database/auth/migrations/0003_signin_abuse_limiter.sql`.

O limiter F24 usa namespace `auth_guard`, PostgreSQL compartilhado, HMAC/HKDF e buckets fixos:

- `source`: 120/15 min;
- `identifier`: 20/15 min;
- `pair`: 8/5 min.

`compras_auth_runtime` permanece não privilegiada e sem DML direto no limiter. Origem hosted aceita somente `x-forwarded-for` único sob runtime Vercel explícito. `rejected`/`unavailable` nunca chamam Better Auth. A prova concorrente executa 32 chamadas no mesmo pair e obtém exatamente 8 `allowed` e 24 `rejected`.

## Persistência e RLS

Migrations canônicas do domínio:

- `database/migrations/0001_core_foundation.sql` — schema + RLS default-deny;
- `database/migrations/0002_trusted_identity_read_policies.sql` — helpers de identidade e policies SELECT;
- `database/migrations/0003_team_member_directory.sql` — capability view do diretório.

O caminho confiável é:

```text
sessão Better Auth validada no servidor
-> issuer + subject
-> contexto LOCAL da transação
-> role PostgreSQL não privilegiada
-> RLS
-> somente linhas autorizadas
```

Autenticação não cria `app_user`/membership automaticamente. Browser não escolhe identidade, team ou membership confiáveis. UUID conhecido nunca substitui autorização.

## F25 — primeira mutação persistente desenhada

ADR-011: `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`.

A primeira escrita operacional será exclusivamente `contractings.next_action`.

### Capability escolhida

A implementação F26 usará primitive PostgreSQL específica `SECURITY DEFINER`, com owner técnico `NOLOGIN` não privilegiado, `search_path` fixo e grants mínimos.

A role runtime de domínio continuará sem `UPDATE`/`INSERT` direto nas tabelas protegidas e receberá somente `EXECUTE` na primitive de `next_action`.

O browser não poderá fornecer como confiáveis:

- actor;
- `team_id`;
- membership;
- issuer/subject.

Esses valores são derivados da sessão validada e do banco.

### Q-009 permanece aberta

A escrita é **pilot-only**.

Para mutar uma contratação, a identidade atual precisa possuir uma membership não revogada na equipe alvo e essa precisa ser a única membership `revoked_at IS NULL` da equipe.

Se existir segunda membership ativa, a primitive falha fechada. Isso evita transformar o piloto individual em permissão multiusuário por inferência. Q-009 só será resolvida por decisão futura explícita.

### Estado + evento atômicos

Uma mudança real deverá:

- atualizar `contractings.next_action`;
- atualizar `contractings.updated_at`;
- inserir exatamente um `contracting_events` com actor/team/contracting derivados do banco;
- usar `event_type = 'next_action_changed'` e `field_key = 'next_action'`;
- usar old/new value auditáveis;
- usar o mesmo timestamp de banco para update/evento.

Falha do evento reverte o estado. `contracting_events` continua append-only.

No-op com valor idêntico não altera `updated_at` e não cria evento.

### Concorrência

A ADR combina:

- `SELECT ... FOR UPDATE` na contratação;
- precondição otimista null-safe do valor anterior de `next_action`.

Duas chamadas concorrentes com o mesmo expected antigo produzem no máximo um vencedor. A segunda detecta stale state e retorna conflito sem update/evento. Não foi criada coluna de versão prematura.

### Fail-closed

Inexistente, cross-team, identidade desconhecida/desabilitada, membership ausente/revogada, segundo membro ativo ou contratação arquivada/cancelada não podem produzir escrita nem side channel de existência antes da autorização.

Falha de configuração/banco/contexto retorna indisponibilidade e não cai para demo.

## F21 — permanece ON HOLD

F21 continua bloqueada até existir superfície Vercel autenticada que permita, sem expor valores:

1. readback completo de Deployment Protection/Vercel Authentication e bypasses relevantes;
2. CRUD/readback de sensitive Preview environment variables escopadas à branch;
3. prova operacional protegida sem ampliar exposição.

Nenhum secret ou recurso hosted é criado como workaround.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01 — Implementar primeira mutação persistente de próxima ação`.

F26 deve materializar ADR-011 em PostgreSQL 17 descartável/CI, com capability owner segura, adapter server-side de escrita, grants mínimos, guard pilot-only, atomicidade estado+evento, concorrência adversarial e regressão integral. Nenhum provider hosted write.

## Modos da aplicação

### Demo

Padrão quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente/false:

- somente fixtures fictícias;
- nenhuma consulta operacional ao banco;
- banner explícito de protótipo.

### Persistente

Só pode existir quando os gates de Auth, banco, secrets e autorização estiverem satisfeitos. Falha protegida nunca cai silenciosamente para demo.

## Fonte de verdade e startup

GitHub é canônico; chat é descartável.

Ordem mínima de retomada:

1. `AGENTS.md`;
2. este arquivo;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. abrir a SPEC/ADR/código exigidos pela tarefa ativa.

## Documentos principais

Produto: `PROJECT_DESIGN.md`, `DOMAIN_MODEL.md`, `BUSINESS_WORKFLOW.md`, `OPEN_QUESTIONS.md`.

Arquitetura/segurança: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-002–ADR-011 conforme aplicáveis.

Operação por IA: `SOURCE_OF_TRUTH.md`, `WORK_PROTOCOL.md`, `CONTEXT_MANIFEST.md`, `CURRENT_STATE.md`, `NEXT_ACTION.md`.

Qualidade: `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- segurança nunca é reduzida para fazer passar;
- autenticação não é autorização;
- autorização crítica vive no servidor/banco; RLS permanece autoritativa;
- IDs do cliente nunca definem identidade/escopo;
- signup público não é aceito por conveniência;
- dado real/interno/pré-publicação não entra no repositório público/demo;
- role privilegiada nunca é runtime normal;
- secrets nunca vão para Git, chat, URL, log, summary ou artifact público;
- blocker externo objetivo entra `ON HOLD` e não paralisa trabalho independente;
- falha protegida não vira sucesso demonstrativo;
- toda mudança arquitetural relevante recebe ADR;
- construir por slices pequenas, verificáveis e reversíveis.
