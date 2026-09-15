# F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** COMPLETED / PASS  
**Dependências:** fundação `contracting_items`, F26, F29, F32, SECURITY, DATABASE e modelo de domínio  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Resultado

F34 foi concluída como slice exclusivamente de desenho.

Artefatos produzidos:

- `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md`;
- `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

Nenhuma migration, primitive, policy, grant, adapter, Server Action ou UI operacional foi criada. Migrations `0001..0006` permaneceram imutáveis. Q-004 e Q-009 permanecem abertas.

## Decisões finais

### Payload e confiança

A futura boundary server-only recebe somente:

```text
contractingId
description
quantity
unit
catalogCode
```

`quantity` é `string | null` no adapter para evitar `Number` JavaScript antes do PostgreSQL `numeric`. Team, actor, membership, issuer, subject, ordinal, item UUID e event UUID ficam fora da authority do browser. Item UUID e event UUID são gerados server-side.

Não foram criadas regras de trim, empty-to-NULL, descrição non-empty, quantidade positiva, unidade obrigatória, catálogo obrigatório, limite de tamanho ou precisão/escala de negócio.

### Autorização pilot-only

A autorização segue F26/F32 por equipe alvo:

- identidade interna ativa;
- contratação alvo visível, não arquivada e não cancelada;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia, inclusive quando seu `app_user` estiver desabilitado. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. Inexistente, cross-team e demais negações permanecem externamente indistinguíveis.

### Capability

F35 usará capability própria equivalente a `compras_contracting_item_create_owner`, separada de F26/F29/F32.

A role será `NOLOGIN`, `NOINHERIT`, não privilegiada, sem `BYPASSRLS`, sem ownership de tabelas-base e sem membership utilizável. A primitive será `SECURITY DEFINER`, com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

Runtime normal continuará sem DML direto e receberá apenas `EXECUTE` explícito por provisionamento separado.

### Allocator de ordinal

O red-team rejeitou o primeiro rascunho que usava `SELECT ... FOR UPDATE` na contratação pai, porque PostgreSQL exige privilégio `UPDATE` para locking clauses. Isso ampliaria authority sobre `contractings` sem necessidade funcional.

A decisão final usa tabela técnica por contratação, equivalente a:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
```

Fluxo final da F35:

1. autorizar a contratação por leitura protegida;
2. criar a row do allocator somente após autorização;
3. bloquear a row do allocator;
4. revalidar autorização após o lock;
5. reconciliar `last_ordinal` com `MAX(ordinal)` real, incluindo itens retirados;
6. usar `1` quando não houver valor ou `maior + 1` caso contrário;
7. atualizar allocator e inserir item + evento na mesma transação.

Gaps não são reutilizados. Writers da mesma contratação serializam na mesma row técnica. Contratações diferentes usam rows distintas e não sofrem lock global. A capability recebe UPDATE somente de `last_ordinal` e zero UPDATE em `contractings`.

### Atomicidade e resultados

Cada criação bem-sucedida gera exatamente um item e um evento `item_created` na mesma transação. Falha do evento reverte item e allocator. `contractings.updated_at` não é alterado.

A futura boundary expõe somente:

- `created`;
- `not-available`;
- `unavailable`.

## Red-team F34

A revisão adversarial rejeitou e o desenho final não contém:

- scope, actor, membership, ordinal ou UUIDs internos controlados pelo browser;
- UPDATE em `contractings` concedido somente para obter row lock;
- allocator criado antes de autorização ou sem revalidação após lock;
- `MAX + 1` sem serialização por contratação;
- retry cego de unique violation;
- lock global;
- reutilização automática de gaps;
- DML direto para runtime;
- ampliação de F26/F29/F32;
- capability utilizável como login ou privilegiada;
- regra de quantidade/unidade/catálogo inventada;
- quantidade convertida por `Number`/`parseFloat`;
- evento não atômico;
- alteração de `contractings.updated_at`;
- deduplicação sem chave de negócio aprovada;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real;
- reescrita das migrations `0001..0006`.

## Verificação

O primeiro head `cfb83dbe9510495016584acda837cbcae30db5e4` passou os gates automatizados, mas o red-team manual posterior encontrou a exigência de `UPDATE` para locking clauses PostgreSQL e bloqueou a promoção desse desenho.

Após a correção para allocator técnico, o head `86d1ca411ee2a74af322aae43693255651d1d0c3` passou:

- CI `34971780173`: PASS;
- F22 Private Preview Preflight `34971780249`: PASS;
- F29 Contracting Create `34971780144`: PASS;
- F32 Contracting Object Mutation `34971780237`: PASS.

O diff corrigido permanece exclusivamente documental. Nenhuma migration `0001..0006`, código operacional, grant, policy, provider hosted, secret ou dado real foi alterado.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0006` permanecem imutáveis.

## Encerramento

O critério de encerramento da F34 foi satisfeito. A implementação correspondente está especificada na F35.