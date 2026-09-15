# Comece aqui - Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui sistemas oficiais. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados. `REAL_DATA_ALLOWED = NO`.

## Estado atual

A fundação já possui:

- Central do Setor e detalhe da contratação;
- PostgreSQL default-deny com `FORCE RLS`;
- identidade confiável `issuer + subject` estabelecida no servidor;
- leituras persistentes protegidas e diretório mínimo da equipe;
- Better Auth self-hosted com signup normal fechado;
- controle distribuído de abuso de sign-in;
- capability persistente estreita para `contractings.next_action` e UI correspondente;
- boundary persistente mínima de criação de `contractings`, pilot-only, auditável e idempotente, com jornada UI/Server Action integrada;
- capability persistente separada para edição de `contractings.object` e UI correspondente;
- boundary persistente mínima de criação de `contracting_items`, pilot-only, auditável e concorrente, ainda sem UI.

F35 foi integrada pela PR `#52`, merge `879902c9e55c60ae514e0ce961f9246202c5c9f8`, com gates pós-merge verdes. A próxima e única frente canônica é F36, integração da criação mínima de item no detalhe persistente.

F17 permanece `ON HOLD` histórico. F21 permanece `ON HOLD` antes de secrets até existir control plane Vercel capaz de readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch sem expor valores.

A faixa F18 de demonstração continua exclusivamente fictícia e sem write persistente.

## Auth e sign-in

O runtime privado usa Better Auth self-hosted com PostgreSQL:

- `better-auth@1.6.23` pinado;
- email/senha habilitado;
- signup normal desabilitado;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- subject somente de sessão validada server-side;
- `/api/auth/[...path]` permanece deny-all para superfícies genéricas não usadas;
- sign-in/sign-out passam por Server Actions estreitas.

Migrations Auth ficam em `database/auth/migrations/`. Auth runtime e domain runtime permanecem separados e não privilegiados.

F24 adicionou limiter distribuído PostgreSQL para sign-in. Falha de limiter/configuração/store fecha o acesso; não existe fallback permissivo.

## Boundaries persistentes integradas

### F26/F27 - próxima ação

ADR-011 definiu primitive PostgreSQL específica para `contractings.next_action`. Runtime recebe apenas `EXECUTE`, sem DML direto. A escrita é pilot-only, auditável e usa optimistic concurrency. F27 expõe a operação por Server Action/UI estreita.

### F28/F29/F30 - criação de contratação

ADR-012 definiu capability separada para criação mínima de `contractings`. O payload é somente `contractingId + object`; team/actor/creator são derivados do banco. A row e `contracting_created` são atômicos e a operação possui replay idempotente pelo candidate UUID preparado server-side.

### F31/F32/F33 - edição de objeto

ADR-013 definiu capability própria para editar somente `contractings.object`. O payload é `contractingId + expectedObject + newObject`, preservado exatamente. `SELECT ... FOR UPDATE` + expected value evita lost update. F33 integra a boundary ao detalhe persistente sem ampliar authority PostgreSQL.

### F34/F35 - criação mínima de item

ADR-014 e F35 definem e implementam uma capability separada para adicionar item a contratação existente.

Payload server-only:

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` é `string | null` até PostgreSQL `numeric`. Item UUID e event UUID são gerados server-side. Team, actor, membership, issuer, subject e ordinal nunca são authority do browser.

A capability `compras_contracting_item_create_owner` permanece selada e sem UPDATE em `contractings`. Runtime normal recebe somente `EXECUTE` da primitive F35 por provisioning separado.

## Allocator de ordinal F35

A criação de item usa a tabela técnica:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
```

Fluxo:

1. autorizar a contratação por leitura protegida;
2. criar a row do allocator somente após autorização;
3. bloquear apenas a row do allocator;
4. revalidar autorização após o lock;
5. reconciliar `last_ordinal` com `MAX(contracting_items.ordinal)` real, incluindo retired;
6. alocar `1` ou `maior + 1`;
7. atualizar allocator e inserir item + evento `item_created` na mesma transação.

Gaps não são reutilizados. Contratações distintas usam rows distintas, sem lock global. Falha do evento reverte item e allocator. `contractings.updated_at` não é alterado.

A suíte F35 provou 8 writers concorrentes na mesma contratação com ordinais únicos/sequenciais, ausência de bloqueio global entre contratações e revalidação de target após espera no allocator.

## Semântica de dados F35

Não foi criada regra de:

- trim;
- descrição non-empty;
- quantidade positiva;
- unidade obrigatória;
- catálogo obrigatório;
- escala/precisão de negócio;
- tamanho máximo;
- pesquisa de preços.

`description`, `unit` e `catalogCode` preservam texto exato. `quantity` não passa por `Number`/`parseFloat`. `NULL`, zero, negativo, fração e alta precisão válida foram provados. Cast inválido e overflow de ordinal falham fechados e sanitizados.

Q-004 continua aberta. Q-009 continua aberta, portanto a escrita permanece pilot-only.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01 - Integrar criação persistente de item no detalhe`.

F36 deve:

- adicionar somente Server Action/UI sobre F35;
- manter `0001..0007`, grants, policies, capabilities e primitives imutáveis;
- manter demo read-only;
- encaminhar apenas `contractingId`, `description`, `quantity`, `unit`, `catalogCode`;
- preservar strings exatas e quantity como string/null;
- fazer readback pelo modelo protegido após `created`;
- sanitizar `not-available`/`unavailable` sem oracle cross-team;
- usar pending para reduzir double-submit acidental sem inventar idempotência persistente;
- não adicionar update/reorder/retire de item nem pesquisa de preços.

A SPEC está em `tasks/F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01/SPEC.md`.

## Modos da aplicação

### Demo

Quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`:

- somente fixtures fictícias;
- nenhuma consulta/mutação operacional;
- banner explícito de protótipo.

### Persistente

Somente com todos os gates Auth/banco/configuração/autorização válidos:

```text
sessão Better Auth validada
-> issuer + subject
-> contexto transacional LOCAL
-> role de domínio não privilegiada
-> RLS / capability estreita
-> somente registros e operações autorizados
```

Falha protegida nunca vira demo silenciosamente.

## Banco canônico

Migrations imutáveis atualmente integradas:

- `0001_core_foundation.sql`;
- `0002_trusted_identity_read_policies.sql`;
- `0003_team_member_directory.sql`;
- `0004_next_action_mutation.sql`;
- `0005_contracting_create.sql`;
- `0006_contracting_object_mutation.sql`;
- `0007_contracting_item_create.sql`.

Migration aplicada não é reescrita. Correção futura exige migration aditiva.

## Fonte de verdade

GitHub é canônico. Chat é descartável.

Startup mínimo:

1. `AGENTS.md`;
2. `docs/00-START-HERE.md`;
3. `docs/ai/CURRENT_STATE.md`;
4. `docs/ai/NEXT_ACTION.md`;
5. `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md`;
7. abrir SPEC/ADR/código exigidos pela tarefa ativa.

## Fontes principais

Produto: `PROJECT_DESIGN.md`, `DOMAIN_MODEL.md`, `BUSINESS_WORKFLOW.md`, `OPEN_QUESTIONS.md`.

Arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, ADR-010, ADR-011, ADR-012, ADR-013, ADR-014.

Operação por IA: `SOURCE_OF_TRUTH.md`, `WORK_PROTOCOL.md`, `CONTEXT_MANIFEST.md`, `CURRENT_STATE.md`, `NEXT_ACTION.md`.

Qualidade: `docs/qa/DEFINITION_OF_DONE.md`.

## Princípios permanentes

- segurança nunca é reduzida para fazer passar;
- autenticação não é autorização;
- RLS/autorização crítica permanecem no servidor/banco;
- cliente nunca define identidade/escopo;
- signup público não é criado por conveniência;
- dado real/interno/pré-publicação não entra no repositório público;
- role privilegiada nunca é runtime normal;
- secrets nunca vão para Git/chat/URL/log/artifact público;
- blocker externo objetivo entra `ON HOLD` sem paralisar trabalho independente;
- falha protegida nunca cai para demo;
- migrations aplicadas são imutáveis;
- construir por slices pequenas, verificáveis e reversíveis.