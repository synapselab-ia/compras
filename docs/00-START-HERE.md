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
- capability persistente separada para edição de `contractings.object`;
- UI/Server Action persistente de edição de `Objeto` integrada sobre F32.

F34 está em verificação final na PR `#51`. ADR-014 e a SPEC F35 foram produzidas, e o red-team corrigiu o mecanismo de serialização de ordinal para evitar conceder UPDATE desnecessário em `contractings`.

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

F33 foi integrada pela PR `#49`, merge `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`. O checkpoint seguinte foi integrado pela PR `#50`, merge `bfa9a65fae06ef8c3cc29586287160be3ab29d31`.

## F34 - desenho de criação persistente de item

A tabela física `contracting_items` já existe desde `0001`, com `ordinal`, descrição, quantidade, unidade, catálogo e timestamps. F34 não implementa escrita; define a próxima boundary.

### Payload futuro

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` será `string | null` no adapter até o PostgreSQL `numeric`. Item UUID e event UUID nascem server-side. Team, actor, membership, issuer, subject e ordinal não são confiados ao browser.

Nenhuma regra de quantidade positiva, unidade obrigatória, catálogo obrigatório, trim, empty-to-NULL, limite de tamanho ou precisão de negócio foi inventada. Q-004 continua aberta.

### Autorização

A futura escrita seguirá o guard por equipe alvo de F26/F32:

- identidade interna ativa;
- contratação visível e ativa;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. Q-009 continua aberta.

### Capability

F35 deverá criar capability própria equivalente a `compras_contracting_item_create_owner`, sem ampliar F26/F29/F32. Runtime normal continuará sem DML direto e receberá somente `EXECUTE` da primitive F35.

### Allocator de ordinal corrigido pelo red-team

O primeiro rascunho considerou `SELECT ... FOR UPDATE` em `contractings`. A revisão adversarial rejeitou essa alternativa porque locking clauses PostgreSQL exigem privilégio UPDATE, o que ampliaria a capability sobre a contratação pai.

ADR-014 agora exige uma tabela técnica por contratação, equivalente a:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
```

A primitive deve autorizar primeiro, criar/bloquear somente essa row técnica, revalidar autorização após o lock, reconciliar `last_ordinal` com `MAX(ordinal)` real, inclusive retired, e então alocar o próximo ordinal.

Gaps não são reutilizados. Contratações distintas usam rows distintas e não sofrem lock global. A capability terá UPDATE apenas de `last_ordinal` no allocator e zero UPDATE em `contractings`.

### Atomicidade

Uma criação bem-sucedida deverá inserir item, avanço do allocator e evento `item_created` na mesma transação. Falha do evento reverte tudo. `contractings.updated_at` não é alterado.

A futura boundary server-only expõe apenas `created`, `not-available` e `unavailable`.

## Frente ativa

A única `NEXT_ACTION` canônica continua F34 enquanto o desenho corrigido estiver em verificação.

F34 fecha somente após:

- revisão integral do diff corrigido;
- CI, F22, F29 e F32 verdes no head corrigido;
- checkpoint final promovendo F35;
- nova rodada de gates verde;
- merge da PR `#51` e verificação pós-merge.

Depois disso, a implementação será `F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01` conforme `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

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
- `0006_contracting_object_mutation.sql`.

Migration aplicada não é reescrita. F35, após promoção da F34, deverá acrescentar `0007`.

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