# F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** DESIGN COMPLETE / VERIFYING  
**Dependências:** fundação `contracting_items`, F26, F29, F32, SECURITY, DATABASE e modelo de domínio  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Resultado do desenho

F34 produziu `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md` e `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

Nenhuma migration, primitive, policy, grant, adapter, Server Action ou UI operacional foi criada nesta slice. Migrations `0001..0006` permanecem imutáveis. Q-004 e Q-009 permanecem abertas.

## Decisões fechadas

### Payload e confiança

A futura boundary server-only recebe somente:

```text
contractingId
description
quantity
unit
catalogCode
```

`description` é string. `quantity` é `string | null` no adapter para não passar por `Number` JavaScript antes do PostgreSQL `numeric`. `unit` e `catalogCode` são `string | null`.

Team, actor, membership, issuer, subject, ordinal, item UUID e event UUID não são authority do browser. Item UUID e event UUID são gerados server-side em cada tentativa.

O desenho não cria trim, empty-to-NULL, descrição non-empty, quantidade positiva, unidade obrigatória, catálogo obrigatório, limite de tamanho ou precisão/escala de negócio.

### Autorização pilot-only

A autorização segue F26/F32 por equipe alvo, porque a contratação existente já define o `team_id` canônico:

- identidade interna ativa;
- contratação alvo visível, não arquivada e não cancelada;
- membership não revogada do usuário na equipe alvo;
- exatamente uma membership não revogada na equipe alvo.

Segundo membro não revogado bloqueia, inclusive quando seu `app_user` estiver desabilitado. Outra membership do mesmo usuário em equipe diferente não bloqueia por si só. Inexistente, cross-team e demais negações permanecem externamente indistinguíveis.

### Capability

A implementação F35 usará capability própria equivalente a `compras_contracting_item_create_owner`, separada de F26/F29/F32.

A role será `NOLOGIN`, `NOINHERIT`, não privilegiada, sem `BYPASSRLS`, sem ownership de tabelas-base e sem membership utilizável. A primitive será `SECURITY DEFINER`, com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado.

Runtime normal continuará sem DML direto e receberá apenas `EXECUTE` explícito da primitive F35 por provisionamento separado.

### Ordinal e concorrência

O red-team identificou uma falha no primeiro rascunho: PostgreSQL exige privilégio `UPDATE` para locking clauses como `SELECT ... FOR UPDATE`. Portanto, bloquear a row de `contractings` contrariaria o objetivo de manter a capability de item create sem UPDATE na contratação pai.

A decisão final usa uma tabela técnica de allocator por contratação, equivalente a:

```text
contracting_item_ordinal_counters
team_id uuid NOT NULL
contracting_id uuid PRIMARY KEY
last_ordinal integer NULL
```

A F35 deverá:

1. autorizar a contratação por leitura protegida;
2. criar a row técnica com `ON CONFLICT DO NOTHING` somente após autorização;
3. bloquear a row do allocator com `SELECT ... FOR UPDATE`;
4. revalidar autorização após o lock;
5. obter `MAX(ordinal)` de todos os itens, inclusive retirados;
6. reconciliar `last_ordinal` com o máximo real;
7. usar `1` quando ambos forem `NULL`, senão `maior + 1`;
8. atualizar o allocator e criar item + evento na mesma transação.

Gaps não são reutilizados. Writers da mesma contratação serializam na mesma row técnica. Contratações diferentes usam rows distintas e não sofrem lock global. Falha de item/evento reverte também o avanço do allocator.

A capability recebe UPDATE somente de `last_ordinal` na tabela técnica, e zero UPDATE em `contractings`.

### Atomicidade e histórico

Cada criação bem-sucedida gera exatamente um item e exatamente um evento `item_created` na mesma transação.

O evento referencia `item_id`, deriva team/actor/contracting do banco e usa o mesmo instante de banco dos timestamps definidos. `field_key`, `old_value`, `new_value`, `note` e `related_identifier_id` ficam nulos.

Falha do evento reverte item e allocator. Negação não cria allocator para target não autorizado, item ou evento. `contractings.updated_at` não é alterado.

### Resultados externos

A futura primitive distingue internamente somente `created` e `denied`. O adapter expõe apenas:

- `created`;
- `not-available`;
- `unavailable`.

Nenhum UUID interno, ordinal, team, actor, SQL, driver, claim ou connection string é retornado. Falha protegida nunca cai para demo.

## Red-team F34

A revisão adversarial rejeita:

- scope, actor, membership, ordinal ou UUIDs internos controlados pelo browser;
- row lock na contratação pai que exija UPDATE desnecessário;
- allocator criado antes de autorização ou sem revalidação após lock;
- `MAX(ordinal) + 1` sem serialização por contratação;
- retry cego de unique violation;
- table lock ou advisory lock global;
- reutilização automática de gaps;
- retirada do item excluindo seu ordinal histórico do máximo;
- DML direto para runtime;
- ampliação das capabilities F26/F29/F32;
- role de capability utilizável como login ou role privilegiada;
- criação em contratação inexistente, cross-team, arquivada ou cancelada;
- guard global da F29 copiado para row com team conhecido;
- regra de quantidade/unidade/catálogo inventada;
- quantidade convertida por `Number`/`parseFloat`;
- evento não atômico;
- alteração de `contractings.updated_at`;
- deduplicação sem chave de negócio aprovada;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real;
- reescrita das migrations `0001..0006`.

## Verificação

O primeiro head de desenho `cfb83dbe9510495016584acda837cbcae30db5e4` passou:

- CI `34970699468`;
- F22 Private Preview Preflight `34970699518`;
- F29 Contracting Create `34970699591`;
- F32 Contracting Object Mutation `34970699549`.

Esses gates automatizados não detectaram a exigência de privilégio PostgreSQL para o row lock da contratação pai. O red-team manual posterior detectou o problema e o desenho foi corrigido para allocator técnico dedicado.

A F34 só pode ser promovida para `PASS` após o head corrigido e o checkpoint final repetirem todos os gates aplicáveis.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0006` permanecem imutáveis.

## Encerramento esperado

F34 fecha quando o desenho corrigido da ADR-014 e o checkpoint passarem os gates finais, deixando F35 como única `NEXT_ACTION` canônica.