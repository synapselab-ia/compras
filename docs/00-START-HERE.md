# Comece aqui - Compras

## Missão

Construir um sistema operacional para equipes de compras públicas acompanharem contratações de ponta a ponta em uma única fonte de verdade, com foco em velocidade, rastreabilidade, segurança e redução de trabalho manual.

O sistema não substitui sistemas oficiais. O repositório continua público; somente código/documentação sanitizados e dados fictícios podem ser usados. `REAL_DATA_ALLOWED = NO`.

## Estado atual

A fundação possui:

- Central do Setor e detalhe da contratação;
- PostgreSQL default-deny com `FORCE RLS`;
- identidade confiável `issuer + subject` estabelecida no servidor;
- leituras persistentes protegidas e diretório mínimo da equipe;
- Better Auth self-hosted com signup normal fechado;
- limiter distribuído de sign-in;
- edição persistente de `contractings.next_action` e UI correspondente;
- criação mínima persistente de `contractings`, auditável e idempotente, com UI correspondente;
- edição persistente de `contractings.object` e UI correspondente;
- criação mínima persistente de `contracting_items`, com allocator concorrente e UI correspondente;
- edição persistente server-side dos quatro campos de item, ainda sem UI;
- correção aditiva da concorrência F29 em migration `0008`;
- migrations de domínio `0001..0009` integradas e imutáveis.

F38 foi integrada pela PR `#59`, merge `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`, com CI, F22, F29, F32, F35 e o novo gate F38 verdes no head final e após o merge.

A próxima e única frente canônica é:

`F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01 - Integrar edição persistente de item no detalhe`.

F17 permanece `ON HOLD` histórico. F21 permanece `ON HOLD` até existir control plane Vercel capaz de readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch sem expor valores.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário continuam abertas. Enquanto Q-009 estiver aberta, as boundaries de escrita permanecem pilot-only.

## Auth e sign-in

O runtime privado usa Better Auth self-hosted com PostgreSQL:

- `better-auth@1.6.23` pinado;
- email/senha habilitado;
- signup normal desabilitado;
- issuer fixo `urn:compras:better-auth:self-hosted:v1`;
- subject somente de sessão validada server-side;
- `/api/auth/[...path]` permanece deny-all para superfícies genéricas não usadas;
- sign-in/sign-out passam por Server Actions estreitas.

Auth runtime e domain runtime permanecem separados e não privilegiados. Falha de limiter/configuração/store fecha o acesso; não há fallback permissivo.

## Boundaries persistentes integradas

### F26/F27 - próxima ação

ADR-011 define primitive específica para `contractings.next_action`. Runtime recebe apenas `EXECUTE`, sem DML direto. A operação é auditável, pilot-only e usa optimistic concurrency. F27 expõe a boundary no detalhe.

### F28/F29/F30 - criação de contratação

ADR-012 define capability separada para criação mínima de `contractings`. O browser fornece somente candidato `contractingId + object`; team/actor/creator são derivados no banco. Row e evento `contracting_created` são atômicos.

A migration `0008_contracting_create_concurrency_repair.sql` corrigiu, de forma aditiva, a corrida entre a PK `id` e a unique `(team_id,id)`. `0005_contracting_create.sql` permaneceu imutável. O replay só é reconhecido depois da prova exata e autorizada da row existente.

### F31/F32/F33 - edição de objeto

ADR-013 define capability própria para editar somente `contractings.object`. O contrato é `contractingId + expectedObject + newObject`; `SELECT ... FOR UPDATE` e expected value impedem lost update. F33 integra a boundary ao detalhe.

### F34/F35/F36 - criação mínima de item

ADR-014/F35 implementam criação de `contracting_items` por capability dedicada. O payload server-only é:

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` é `string | null` até PostgreSQL `numeric`. Item/event UUIDs e ordinal são gerados/derivados internamente. F36 integra a criação ao detalhe persistente. Demo permanece read-only.

O allocator técnico por contratação serializa writers sem conceder UPDATE em `contractings`:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
```

Gaps não são reutilizados. Falha de item/evento reverte também o avanço do allocator.

### F37/F38 - edição mínima de item

ADR-015 e F38 definem e implementam a primeira mutation persistente de item.

Campos alteráveis:

```text
description
quantity
unit
catalog_code
```

Contrato server-only:

```text
contractingId
itemId
expectedDescription
expectedQuantity
expectedUnit
expectedCatalogCode
newDescription
newQuantity
newUnit
newCatalogCode
```

Team, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs não são authority do caller público. Quatro event UUIDs são gerados server-side.

A capability `compras_contracting_item_mutation_owner` pode atualizar somente:

```text
description
quantity
unit
catalog_code
updated_at
```

Ela não pode criar/deletar item, alterar ordinal/retired/scope, atualizar `contractings`, tocar allocator nem atualizar/deletar eventos. Runtime normal recebe somente EXECUTE da primitive F38 por provisioning separado.

A primitive bloqueia somente a row do item, revalida parent/membership depois do lock e exige snapshot esperado dos quatro campos. Se qualquer expected estiver stale, retorna `conflict` antes de no-op. Com expected atual e new igual ao current, retorna `unchanged` sem timestamp/evento. Mudança real retorna `updated`.

A auditoria gera um `item_changed` por campo efetivamente alterado, com old/new escalares, mesmo `operation_at` e rollback integral se qualquer evento falhar.

A suíte F38 prova oito writers concorrentes com o mesmo snapshot: exatamente um `updated`, sete `conflict` e somente o histórico do vencedor.

Resultado e verificação completos: `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/RESULT.md`.

## Semântica de item

Não foi criada regra de:

- trim;
- descrição non-empty;
- quantidade positiva;
- unidade obrigatória;
- catálogo obrigatório;
- escala/precisão de negócio;
- tamanho máximo;
- pesquisa de preços.

`description`, `unit` e `catalogCode` preservam texto exato. `unit` e `catalogCode` distinguem `NULL`, `''` e espaços. `quantity` não passa por `Number`/`parseFloat`; no read model é obtida por `numeric::text`.

Numeric inválido falha fechado e é sanitizado como `unavailable` na boundary server-only.

## Próxima frente F39

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01 - Integrar edição persistente de item no detalhe`.

F39 deve integrar somente a boundary F38, sem alterar authority PostgreSQL.

Pontos obrigatórios:

- o read model protegido deve fornecer snapshot bruto de `description`, `quantity`, `unit`, `catalogCode` para cada item editável;
- é proibido reconstruir expected de `label`, `note`, ordinal, timestamp ou DOM;
- a Server Action deve enviar sempre os quatro expected values e os quatro new values para F38;
- unit/catalog precisam de codificação explícita `text` versus `NULL`, pois vazio é um valor textual distinto;
- quantity permanece input textual e `string | null`;
- action não executa SQL/DML e não aceita authority de team/actor/membership/event UUID;
- `conflict` não gera retry automático;
- feedback/navegação permanecem sanitizados e locais;
- pending reduz double-submit acidental;
- demo permanece read-only;
- migrations `0001..0009` permanecem imutáveis;
- reorder, retire/restore, delete e pesquisa de preços ficam fora de escopo.

A SPEC está em `tasks/F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01/SPEC.md`.

## Modos da aplicação

### Demo

Quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`:

- somente fixtures fictícias;
- nenhuma consulta/mutação operacional;
- banner explícito de protótipo;
- nenhuma UI de escrita persistente deve ser renderizada.

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

Migrations de domínio integradas e imutáveis:

- `0001_core_foundation.sql`;
- `0002_trusted_identity_read_policies.sql`;
- `0003_team_member_directory.sql`;
- `0004_next_action_mutation.sql`;
- `0005_contracting_create.sql`;
- `0006_contracting_object_mutation.sql`;
- `0007_contracting_item_create.sql`;
- `0008_contracting_create_concurrency_repair.sql`;
- `0009_contracting_item_mutation.sql`.

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

Fontes de produto: `PROJECT_DESIGN.md`, `DOMAIN_MODEL.md`, `BUSINESS_WORKFLOW.md`, `OPEN_QUESTIONS.md`.

Fontes de arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009 a ADR-015.

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
