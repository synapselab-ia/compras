# F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** COMPLETED / PASS  
**Dependências:** fundação `contracting_items`, F26, F29, F32, SECURITY, DATABASE e modelo de domínio  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Resultado

F34 foi concluída como slice exclusivamente de desenho. A decisão arquitetural foi registrada em `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md` e a implementação futura foi especificada em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

Nenhuma migration, primitive, policy, grant, adapter, Server Action ou UI operacional foi criada nesta slice. Migrations `0001..0006` permaneceram imutáveis. Q-004 e Q-009 permanecem abertas.

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

`description` é string. `quantity` é transportada como `string | null` no adapter para não passar por `Number` JavaScript antes do PostgreSQL `numeric`. `unit` e `catalogCode` são `string | null`.

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

`ordinal` não é input do caller.

A primitive deve:

1. autorizar e bloquear a contratação alvo com `SELECT ... FOR UPDATE`;
2. após o lock, calcular `MAX(ordinal)` considerando todos os itens da contratação, inclusive retirados;
3. usar `1` se não houver item, senão `MAX + 1`;
4. não reutilizar gaps.

Writers concorrentes na mesma contratação são serializados pela row pai. Contratações diferentes não usam lock global. A constraint `UNIQUE (contracting_id, ordinal)` permanece como backstop, sem retry cego como algoritmo primário.

### Atomicidade e histórico

Cada criação bem-sucedida gera exatamente um item e exatamente um evento `item_created` na mesma transação.

O evento referencia `item_id`, deriva team/actor/contracting do banco e usa o mesmo instante de banco dos timestamps de criação do item. `field_key`, `old_value`, `new_value`, `note` e `related_identifier_id` ficam nulos.

Falha do evento reverte o item. Negação não cria item nem evento. `contractings.updated_at` não é alterado nesta operação.

### Resultados externos

A futura primitive distingue internamente somente `created` e `denied`. O adapter expõe apenas:

- `created`;
- `not-available`;
- `unavailable`.

Nenhum UUID interno, ordinal, team, actor, SQL, driver, claim ou connection string é retornado. Falha protegida nunca cai para demo.

## Red-team F34

O desenho foi rejeitado como PASS se permitisse qualquer uma das seguintes propriedades. Nenhuma permaneceu no desenho final:

- scope, actor, membership, ordinal ou UUIDs internos controlados pelo browser;
- `MAX(ordinal) + 1` sem serialização pela contratação pai;
- retry cego de unique violation como solução de corrida;
- table lock ou advisory lock global;
- reutilização automática de gaps;
- retirada do item excluindo seu ordinal histórico do máximo;
- DML direto para runtime;
- ampliação das capabilities F26/F29/F32;
- role de capability utilizável como login ou role privilegiada;
- criação em contratação inexistente, cross-team, arquivada ou cancelada;
- guard global da F29 copiado para uma row com team já conhecido;
- regra de quantidade/unidade/catálogo inventada;
- quantidade convertida por `Number`/`parseFloat`;
- evento não atômico;
- alteração desnecessária de `contractings.updated_at`;
- deduplicação de item sem chave de negócio aprovada;
- resolução implícita de Q-004 ou Q-009;
- provider hosted, secret ou dado real.

## Verificação documental

Head de desenho validado antes do checkpoint: `cfb83dbe9510495016584acda837cbcae30db5e4`.

Gates executados nesse head:

- CI `34970699468`: PASS;
- F22 Private Preview Preflight `34970699518`: PASS;
- F29 Contracting Create `34970699591`: PASS;
- F32 Contracting Object Mutation `34970699549`: PASS.

O diff validado antes do checkpoint continha somente ADR-014 e a SPEC F35. Não havia alteração de migration, código operacional, grant, policy, provider hosted, secret ou dado real.

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

O critério de encerramento da F34 foi satisfeito. A arquitetura de criação mínima de item está fechada quanto a payload, autorização, UUIDs, ordinal concorrente, capability, atomicidade/auditoria, resultados sanitizados e matriz adversarial.

A implementação correspondente está especificada na F35.