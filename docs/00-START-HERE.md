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
- edição persistente de `contractings.next_action` com UI;
- criação mínima persistente de `contractings`, auditável e idempotente, com UI;
- edição persistente de `contractings.object` com UI;
- criação mínima persistente de `contracting_items`, com allocator concorrente e UI;
- edição persistente dos quatro campos de item com UI e optimistic concurrency por snapshot completo;
- migrations de domínio `0001..0009` integradas e imutáveis.

F39 foi integrada pela PR `#61`, merge `09737ac6d11046af5d149b7926997e7e630557cc`. CI, F22, F29, F32, F35 e F38 ficaram verdes no head final e após o merge.

A próxima e única frente canônica é:

`F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01 - Desenhar vínculo persistente mínimo de identificador relacionado`.

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

ADR-012 define capability separada para criação mínima de `contractings`. Team/actor/creator são derivados no banco. Row e evento `contracting_created` são atômicos.

A migration aditiva `0008_contracting_create_concurrency_repair.sql` corrigiu a corrida entre a PK `id` e a unique `(team_id,id)` sem reescrever `0005`.

### F31/F32/F33 - edição de objeto

ADR-013 define capability própria para editar somente `contractings.object`. `SELECT ... FOR UPDATE` e expected value impedem lost update. F33 integra a boundary ao detalhe.

### F34/F35/F36 - criação mínima de item

ADR-014/F35 implementam criação de `contracting_items` por capability dedicada. `quantity` permanece `string | null` até PostgreSQL `numeric`. Item/event UUIDs e ordinal são gerados/derivados internamente. F36 integra a criação ao detalhe persistente.

O allocator técnico por contratação serializa writers sem conceder UPDATE em `contractings`. Gaps não são reutilizados e falha de item/evento reverte também o avanço do allocator.

### F37/F38/F39 - edição mínima de item

ADR-015/F38 implementam a mutation persistente dos campos:

```text
description
quantity
unit
catalog_code
```

F39 expõe essa boundary no detalhe persistente.

Cada item editável recebe um snapshot bruto protegido:

```text
description: string
quantity: string | null
unit: string | null
catalogCode: string | null
```

A UI envia sempre os quatro expected e os quatro new values. Expected vem das colunas protegidas, nunca de label/note/DOM. `conflict` precede `unchanged` no banco e não existe retry automático na UI.

Unit/catalog preservam `NULL`, `''` e espaços por codificação explícita `text|null`. Quantity usa input textual e nunca passa por `Number`, `parseFloat` ou `type=number`.

A capability F38 continua limitada a `description`, `quantity`, `unit`, `catalog_code` e `updated_at`. F39 não ampliou authority, grant, policy, primitive ou provisioning.

Resultado completo da UI: `tasks/F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01/RESULT.md`.

## Próxima frente F40

O núcleo inicial documentado prevê múltiplos processos/identificadores administrativos relacionados à mesma contratação. A tabela `related_identifiers` e a leitura protegida já existem, mas ainda não existe boundary de escrita para criar o vínculo.

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01 - Desenhar vínculo persistente mínimo de identificador relacionado`.

F40 é design-only. Deve definir:

- payload server-only mínimo;
- authority derivada e guard pilot-only;
- capability dedicada e least privilege;
- semântica de `NULL`, vazio e espaços sem regras inventadas;
- atomicidade com evento de vínculo;
- concorrência/idempotência sem deduplicação por valor inventada;
- resultados sanitizados;
- matriz adversarial da futura implementação.

F40 não cria código operacional. Ela deve produzir uma ADR canônica e uma única SPEC de implementação seguinte.

A SPEC está em `tasks/F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01/SPEC.md`.

## Modos da aplicação

### Demo

Quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`:

- somente fixtures fictícias;
- nenhuma consulta/mutação operacional;
- banner explícito de protótipo;
- nenhuma UI de escrita persistente é renderizada.

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

Migration aplicada não é reescrita. Correção ou feature persistente futura exige migration aditiva.

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
