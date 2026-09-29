# F49-PERSISTENT-WAITING-STATE-MUTATION-DESIGN-01 - Desenhar edição persistente do estado de espera

**Classe:** T2 - design de boundary de escrita e auditoria  
**Estado:** READY / NEXT após integração da F48  
**Dependências:** modelo atual de `contractings`, F26/F32/F47 como precedentes de mutation, ADR-003, ADR-005, ADR-009, BUSINESS_WORKFLOW e OPEN_QUESTIONS  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O produto já permite editar objeto, próxima ação e responsável, porém o detalhe persistente ainda apresenta `waiting_type`, `waiting_reference`, `waiting_since` e `waiting_reason` somente como leitura.

A regra operacional central exige responder com quem ou onde a ação está pendente, desde quando e por qual motivo. Ao mesmo tempo, Q-002 mantém aberta a taxonomia final de status e tipos de espera.

A próxima slice deve desenhar uma boundary mínima e auditável para o estado de espera sem definir silenciosamente taxonomias finais e sem implementar produção.

## Objetivo

Produzir uma decisão arquitetural executável para futura mutation persistente do conjunto de espera atual:

```text
waiting_type
waiting_reference
waiting_since
waiting_reason
```

A decisão deve determinar:

- qual snapshot completo funciona como expected para optimistic concurrency;
- quais valores podem ser solicitados pelo caller e quais devem ser derivados;
- como representar ausência versus texto, sem colapsar `NULL`, vazio e espaços se o schema permitir distinção;
- como tratar `waiting_since` sem permitir timestamp de auditoria controlado pelo browser;
- quando uma alteração é `unchanged`, `conflict`, `updated` ou indisponível;
- como gravar evento atômico sem abrir CRUD genérico de `contractings`;
- qual capability mínima e qual primitive futura seriam necessárias;
- como preservar o guard pilot-only enquanto Q-009 estiver aberta;
- como manter Q-001/Q-002 abertas sem inventar catálogo de etapa, status ou waiting type.

F49 é design-only.

## 1. Recuperação obrigatória

Antes de decidir:

1. recuperar `main` real após F48;
2. revalidar `CONTEXT_MANIFEST`;
3. ler o resultado F48;
4. ler `PROJECT_DESIGN`, `BUSINESS_WORKFLOW` e as questões Q-001, Q-002, Q-006 e Q-009;
5. inspecionar schema/migrations aplicadas `0001..0012`;
6. inspecionar read model atual do detalhe e Central;
7. usar F26, F32 e F47 como precedentes de optimistic concurrency, atomicidade e least privilege;
8. confirmar que não há regra posterior já documentada para o estado de espera.

## 2. Limite de produto

F49 não pode resolver por inferência:

- taxonomia final de etapas;
- taxonomia final de status;
- catálogo definitivo de tipos de espera;
- regras de alerta por tempo;
- transformação de próxima ação em Pendência;
- política multiusuário definitiva.

Se algum desses pontos for indispensável para definir a boundary, registrar dependência explícita ou abrir decisão necessária. Não inventar enum, prazo ou transição.

## 3. Snapshot e concorrência

Avaliar e documentar se a unidade de concorrência deve ser o snapshot completo:

```text
expectedWaitingType: string | null
expectedWaitingReference: string | null
expectedWaitingSince: timestamp | null
expectedWaitingReason: string | null
```

A decisão deve impedir lost update e mixed-state entre campos relacionados.

Definir precedência entre:

```text
denied
conflict
unchanged
updated
```

Não permitir last-write-wins silencioso.

## 4. Semântica de waiting_since

Este é o ponto principal do desenho.

F49 deve decidir, com base nas fontes canônicas e sem inventar regra de negócio, se `waiting_since`:

- é sempre derivado no servidor/banco quando o estado de espera muda;
- pode ser preservado em alterações que não representam novo início de espera;
- pode ser limpo junto com o estado de espera;
- ou exige decisão de produto antes da implementação.

O browser não deve controlar timestamp de auditoria ou `updated_at`.

Se for necessário aceitar uma data operacional informada por usuário, a decisão deve distinguir claramente esse dado de timestamp técnico/auditável e justificar por fonte canônica. Não criar esse campo por conveniência.

## 5. Nullabilidade e texto

Preservar a semântica real do schema.

Não converter automaticamente:

- `NULL` em string vazia;
- string vazia em `NULL`;
- spaces-only em ausência;
- texto em catálogo não aprovado.

Se o design futuro expuser texto nullable no browser, especificar transporte explícito `null|text`.

## 6. Autorização

A futura boundary deve:

- derivar identidade, team e actor de contexto confiável;
- tratar `contractingId` somente como target candidate;
- manter target-team pilot-only enquanto Q-009 estiver aberta;
- não aceitar team, actor, user, issuer ou subject como input;
- não usar valores de waiting como prova de autorização;
- não conceder DML amplo ao runtime;
- manter feedback externo opaco para target não autorizado.

## 7. Auditoria

Definir evento atômico suficiente para reconstruir a alteração do estado de espera.

Avaliar se a mudança deve usar:

- um único evento fechado contendo snapshot old/new serializado em colunas existentes apenas se isso já for suportado sem `jsonb` inventado;
- múltiplos eventos de campo na mesma transação;
- ou outra forma compatível com o modelo canônico.

Não alterar o modelo nesta slice. A escolha deve ser justificada pelo schema e pelos precedentes existentes.

A futura implementação deve atualizar estado e evento(s) atomicamente e não criar evento em `unchanged`, `conflict` ou negação.

## 8. Least privilege

Especificar capability futura dedicada.

Ela não deve possuir:

- ownership de tabela-base;
- UPDATE genérico de `contractings`;
- DML em memberships/app_users;
- UPDATE/DELETE de eventos;
- authority de F26/F29/F32/F35/F38/F41/F44/F47.

Runtime normal deve continuar sem DML direto e receber, no máximo, EXECUTE da primitive aprovada em provisioning separado.

## 9. Artefatos esperados

F49 deve produzir exatamente o necessário para tornar a implementação seguinte executável:

1. `docs/decisions/ADR-019-persistent-waiting-state-mutation.md`;
2. `tasks/F50-PERSISTENT-WAITING-STATE-MUTATION-IMPLEMENT-01/SPEC.md`.

Não criar migration, SQL de produção, adapter, Server Action ou UI.

## 10. Red-team obrigatório

Rejeitar a decisão se ela:

- inventar taxonomia de etapa/status/waiting;
- resolver Q-002 ou Q-009 implicitamente;
- aceitar timestamp técnico controlado pelo browser;
- permitir update parcial que produza snapshot misto sem regra explícita;
- criar last-write-wins;
- transformar next_action em pendência sem resolver Q-006;
- usar waiting value como authority;
- conceder DML direto ao runtime;
- abrir UPDATE genérico de contractings;
- criar evento mutável ou não atômico;
- exigir provider hosted, secret ou dado real;
- alterar migration aplicada.

## 11. Verificação

Executar:

- revisão integral da ADR e SPEC produzidas;
- diff/red-team documental;
- confirmação de que nenhum arquivo de produção, migration, grant, policy ou provisioning mudou;
- CI e gates aplicáveis ao head documental;
- confirmação de migrations `0001..0012` imutáveis;
- confirmação de `REAL_DATA_ALLOWED = NO`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas, salvo decisão explícita futura;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0012` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Critério de encerramento

F49 fecha quando existir uma ADR defensável para mutation do estado de espera atual e uma SPEC F50 executável, com concorrência, nullabilidade, timestamp, autorização, auditoria e least privilege definidos sem inventar taxonomias, sem implementar produção e sem resolver silenciosamente questões abertas.
