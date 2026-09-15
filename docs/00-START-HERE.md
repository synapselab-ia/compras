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
- controle distribuído de abuso de sign-in;
- capability estreita para `contractings.next_action` e UI correspondente;
- criação mínima persistente de `contractings`, pilot-only, auditável e idempotente, com UI/Server Action integrada;
- capability separada para edição de `contractings.object` e UI correspondente;
- criação mínima persistente de `contracting_items`, com allocator concorrente por contratação e UI correspondente;
- correção aditiva da idempotência concorrente F29 em migration `0008`;
- ADR-015 integrada para a primeira edição persistente de item, ainda sem implementation F38.

F36 foi integrada pela PR `#54`, merge `c177e7e8c1b3a46a5d5c3276b4945b81019c706a`.

A regressão concorrencial F29 foi corrigida pela PR `#56`, merge `738666901fae43ce25dd11398904735e15c85da1`, usando somente a migration aditiva `0008_contracting_create_concurrency_repair.sql`.

F37 foi integrada pela PR `#57`, merge `88d7d43f06afe8a9eef4d446331c173a8d238856`, com CI, F22, F29, F32 e F35 verdes no head final e após o merge.

A próxima e única frente canônica é:

`F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item`.

F17 permanece `ON HOLD` histórico. F21 permanece `ON HOLD` até existir control plane Vercel capaz de readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch sem expor valores.

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

ADR-012 definiu capability separada para criação mínima de `contractings`. O payload público é somente `contractingId + object`; team/actor/creator são derivados do banco. A row e `contracting_created` são atômicos e a operação possui replay idempotente pelo candidate UUID preparado server-side.

A migration original `0005_contracting_create.sql` permanece imutável.

#### Reparo concorrencial 0008

`contractings` possui PK em `id` e unique composta `(team_id, id)`. Sob retries simultâneos, `ON CONFLICT (id) DO NOTHING` podia perder a corrida primeiro na unique composta e lançar `23505`.

A migration aditiva `0008_contracting_create_concurrency_repair.sql` substitui somente o corpo da primitive para usar `ON CONFLICT DO NOTHING` e depois exige a mesma correspondência exata e autorizada antes de reconhecer `already-created`.

O owner selado recebe `CREATE` no schema apenas dentro da transaction da migration. Esse privilege é revogado antes do postflight e o postflight prova que não permaneceu. A suíte F29 executa múltiplas rodadas de oito writers concorrentes.

### F31/F32/F33 - edição de objeto

ADR-013 definiu capability própria para editar somente `contractings.object`. O payload é `contractingId + expectedObject + newObject`, preservado exatamente. `SELECT ... FOR UPDATE` + expected value evita lost update. F33 integra a boundary ao detalhe persistente sem ampliar authority PostgreSQL.

### F34/F35/F36 - criação mínima de item

ADR-014 e F35 definem e implementam capability separada para adicionar item a contratação existente. F36 integra essa operação ao detalhe persistente sem alterar a autoridade PostgreSQL.

Payload público F35:

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` é `string | null` até PostgreSQL `numeric`. Item UUID e event UUID são gerados server-side. Team, actor, membership, issuer, subject e ordinal nunca são authority do browser.

A capability `compras_contracting_item_create_owner` permanece selada e sem UPDATE em `contractings`. Runtime normal recebe somente `EXECUTE` da primitive F35 por provisioning separado.

Demo continua sem formulário de criação, inclusive quando estados de query são forjados.

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

Gaps não são reutilizados. Contratações distintas usam rows distintas. Falha do evento reverte item e allocator. `contractings.updated_at` não é alterado.

A suíte F35 provou oito writers concorrentes na mesma contratação com ordinais únicos/sequenciais, ausência de bloqueio global entre contratações e revalidação de target após espera no allocator.

## Semântica de dados de item

Não existe regra de:

- trim;
- descrição non-empty;
- quantidade positiva;
- unidade obrigatória;
- catálogo obrigatório;
- escala/precisão de negócio;
- tamanho máximo;
- pesquisa de preços.

`description`, `unit` e `catalogCode` preservam texto exato. `quantity` não passa por `Number`/`parseFloat`. No read model persistente, `quantity` é lida por `numeric::text`.

Q-004 continua aberta. Q-009 continua aberta, portanto as boundaries de escrita seguem pilot-only.

## ADR-015 - edição persistente mínima de item

F37 integrou apenas o desenho. F38 implementará a boundary.

Campos editáveis definidos:

```text
description
quantity
unit
catalog_code
```

Campos fora dessa authority:

```text
id
team_id
contracting_id
ordinal
created_at
retired_at
```

O adapter F38 receberá:

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

IDs de evento serão gerados somente no servidor.

### Concorrência

A futura primitive bloqueará somente a row do item com `SELECT ... FOR UPDATE`.

Todos os quatro expected values formam uma precondição única. Se qualquer campo estiver stale, o resultado é `conflict` antes de avaliar no-op. Isso impede overwrite silencioso de mudança concorrente em outro campo.

Com expected atual:

- new snapshot idêntico: `unchanged`, sem timestamp/evento;
- mudança real: `updated`.

Retry pós-sucesso retorna `conflict`, não replay-success.

### Autorização

O guard segue target-team de F26/F32/F35:

- identidade interna ativa;
- item vinculado ao `contractingId` candidato e não retired;
- parent ativo no mesmo team;
- membership não revogada do usuário no team;
- exatamente uma membership não revogada no team.

Segundo membro não revogado bloqueia, inclusive quando seu app_user está desabilitado. Outra membership do mesmo usuário em outro team não bloqueia por si só.

Cross-team, inexistente, retired, parent mismatch e parent inativo permanecem indistinguíveis externamente.

### Least privilege

F38 criará owner dedicado equivalente a `compras_contracting_item_mutation_owner`.

Authority máxima de UPDATE:

```text
description
quantity
unit
catalog_code
updated_at
```

A capability não poderá:

- criar ou deletar item;
- alterar ordinal, retired state, scope ou created_at;
- tocar o allocator F35;
- atualizar `contractings`;
- atualizar/deletar eventos;
- reutilizar authority de F26/F29/F32/F35.

Runtime normal continuará sem DML direto e receberá somente `EXECUTE` explícito da primitive F38.

### Auditoria

Cada campo realmente alterado gera um evento escalar `item_changed` com:

- `item_id` do item;
- `field_key` em `description`, `quantity`, `unit`, `catalog_code`;
- old/new correspondentes;
- actor/team/contracting derivados;
- mesmo `operation_at` do `updated_at`.

Mudança de N campos gera exatamente N eventos. Quantity é registrada a partir de `numeric::text` no banco. No-op gera zero eventos. Falha de qualquer evento reverte toda a tentativa.

Não foi inventado blob JSON de before/after.

## Próxima frente

A única `NEXT_ACTION` canônica está em `docs/ai/NEXT_ACTION.md`:

`F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item`.

F38 deve:

- preservar migrations `0001..0008` byte-for-byte;
- criar `database/migrations/0009_contracting_item_mutation.sql`;
- criar capability/RLS/primitive dedicadas da ADR-015;
- criar provisioning de EXECUTE isolado;
- criar adapter server-only `persistent-item-mutation.ts`;
- preservar texto/NULL/numeric exatamente;
- implementar snapshot concurrency completo;
- gerar um evento por campo alterado;
- provar rollback e least privilege;
- provar concorrência com oito writers;
- manter F26/F29/F32/F35 sem authority adicional;
- não implementar Server Action/UI;
- não incluir reorder, retire/restore, delete ou pesquisa de preços.

A SPEC está em `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`.

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
- `0007_contracting_item_create.sql`;
- `0008_contracting_create_concurrency_repair.sql`.

Migration aplicada não é reescrita. Correção futura exige migration aditiva. F38 começa em `0009`.

F37 não alterou banco, grants, policies, capabilities, primitives ou aplicação operacional.

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

Arquitetura: `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, ADR-010, ADR-011, ADR-012, ADR-013, ADR-014, ADR-015.

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
