# F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01 - Integrar edição persistente do objeto no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY  
**Dependências:** F32, ADR-003, ADR-009 e ADR-013  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F32 entrega a primitive PostgreSQL estreita e o adapter server-only para alterar `contractings.object`, mas o detalhe persistente continua sem uma jornada de edição desse campo. A próxima slice deve expor somente a mutação já aprovada, sem abrir CRUD amplo, sem ampliar authority e sem resolver implicitamente política multiusuário.

## Resultado esperado

No modo persistente autorizado, o detalhe de uma contratação deve permitir alterar apenas o campo `Objeto` por uma Server Action estreita que reutiliza `mutatePersistentContractingObject`.

A jornada deve:

1. mostrar o valor atual carregado pelo read model protegido;
2. enviar apenas `contractingId`, `expectedObject` e `newObject`;
3. preservar o texto exatamente como enviado, inclusive string vazia e espaços;
4. nunca aceitar team, actor, membership, issuer, subject ou event UUID como autoridade do form/browser;
5. mapear `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` para feedback sanitizado;
6. atualizar/recarregar o detalhe após os resultados previstos, sem fallback para fixtures;
7. permanecer read-only no modo demo;
8. não liberar qualquer outra coluna ou operação persistente.

## Fronteira funcional

### Modo demo

- continua somente leitura;
- não renderiza controle que execute write real;
- não chama adapter de mutação;
- banner continua explícito sobre dados fictícios/persistência desabilitada.

### Modo persistente

- somente `Objeto` fica editável nesta slice;
- o ID da rota é seletor candidato, nunca fonte de escopo;
- o valor atual de `object` carregado do banco é enviado como `expectedObject` para a precondição otimista da ADR-013;
- `newObject` é preservado byte-for-byte como string JS/SQL text, sem trim, limite de tamanho, regra non-empty ou conversão empty-to-NULL inventados;
- a UI não deve inferir disponibilidade cross-team nem política de membership.

## Server Action obrigatória

Criar uma Server Action dedicada à alteração de `object`.

Ela pode receber somente dados equivalentes a:

```text
contractingId
expectedObject
newObject
```

Requisitos:

- validar o shape do payload sem criar regra de negócio nova;
- delegar autorização, lock, concorrência, atomicidade e auditoria à boundary F32;
- rejeitar scalars duplicados/ambíguos de FormData;
- não receber nem encaminhar `team_id`, actor, membership, issuer, subject ou event UUID do browser;
- não aceitar callback/URL/redirect arbitrário fornecido pelo cliente;
- não logar payload, sessão, claims, connection string ou detalhe de erro;
- retornar somente estado sanitizado suficiente para a UI;
- sem demo fallback em falha protegida.

## Semântica de resultado na UI

### `updated`

- informar sucesso;
- revalidar o detalhe persistente por rota local fixa;
- o novo valor e o evento devem ser observáveis no readback posterior.

### `unchanged`

- informar que não houve alteração;
- não apresentar movimentação inexistente.

### `conflict`

- informar que o objeto mudou desde a leitura e que o usuário deve revisar o estado atual;
- não sobrescrever silenciosamente;
- revalidar/recarregar o detalhe antes de nova tentativa.

### `not-available`

- usar mensagem genérica de recurso/ação indisponível;
- não distinguir UUID inexistente, cross-team, identidade sem autorização, membership ausente/revogada, segundo membro, arquivado ou cancelado.

### `unavailable`

- usar erro técnico sanitizado;
- não expor driver, SQL, session, claims ou connection string;
- não trocar silenciosamente para demo.

## UI/UX mínima

A interface deve permanecer coerente com o detalhe existente e incluir:

- label clara `Objeto`;
- controle acessível por teclado;
- valor atual visível antes da edição;
- estado pending/disabled contra submissão acidental repetida;
- feedback textual associado à ação;
- tratamento deliberado de conflito;
- nenhum controle novo para `next_action`, stage, status, responsável, waiting, archive/cancel ou itens.

Não criar editor genérico, CRUD genérico, modal complexo ou design system novo.

## Segurança

A UI não é enforcement. Devem permanecer verdadeiros:

- sessão Better Auth é validada no servidor;
- contexto confiável usa somente `iss/sub` LOCAL;
- RLS/capability F32 permanecem autoritativas;
- runtime normal continua sem DML direto em tabelas protegidas;
- runtime usa somente `EXECUTE` explícito da primitive F32 para esta escrita;
- browser não define identity/scope/actor/membership/event UUID;
- Q-009 continua aberta e o guard pilot-only permanece no banco;
- cross-team e inexistente continuam indistinguíveis externamente;
- modo demo nunca vira caminho de escrita;
- F26 continua exclusiva de `next_action` e F29 continua exclusiva de criação mínima.

## Testes obrigatórios

### Server Action / aplicação

- payload válido chama F32 com exatamente candidate ID + expected + new;
- string vazia e espaços são preservados sem normalização;
- campos extras forjados de actor/team/membership/issuer/subject/event UUID/callback são rejeitados ou ignorados e nunca encaminhados;
- scalar duplicado/ambíguo falha fechado;
- payload malformado falha fechado;
- demo/configuração inválida não chega à F32;
- `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` são mapeados para estados sanitizados;
- `conflict` não é convertido em sucesso;
- erro interno não vaza detalhes;
- revalidação usa somente rota local fixa e ocorre nos resultados deliberados;
- nenhum redirect arbitrário é aceito do cliente.

### Componente/detalhe

- demo renderiza somente leitura e não expõe form de mutação persistente;
- persistente renderiza controle apenas de `object` nesta slice;
- expected value corresponde ao estado persistido apresentado;
- feedback de sucesso, no-op, conflito, indisponibilidade de recurso e erro técnico é compreensível;
- teclado/label/status possuem acessibilidade básica;
- nenhuma authority ou outra coluna editável aparece no formulário.

### Regressão

- lint PASS;
- typecheck PASS;
- testes completos PASS;
- build PASS;
- CI database PASS, incluindo F26/F29/F32;
- Better Auth/F24 PostgreSQL PASS;
- F22 Private Preview Preflight PASS;
- F29 Contracting Create PASS;
- F32 Contracting Object Mutation PASS;
- nenhuma migration aplicada `0001..0006` é reescrita.

## Red-team obrigatório

Rejeitar PASS se:

- browser puder fornecer actor/team/membership/issuer/subject/event UUID confiável;
- demo conseguir disparar write;
- Server Action contornar `mutatePersistentContractingObject` com SQL/DML próprio;
- texto for trimado, normalizado ou vazio for rejeitado sem regra canônica;
- conflito sobrescrever estado atual ou virar sucesso;
- cross-team e inexistente produzirem mensagens distinguíveis;
- falha protegida cair para fixtures/demo;
- payload ou erro sensível chegar a log/UI;
- controle liberar outra coluna além de `object`;
- Q-009 for resolvida implicitamente;
- runtime ganhar DML direto;
- migrations `0001..0006` forem alteradas;
- provider hosted ou dado real for usado.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios em teste;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- migrations aplicadas permanecem imutáveis;
- sem fallback protegido para demo.

## Fora do escopo

- mutação de `next_action`, stage, status, responsável ou waiting;
- criação, arquivamento ou cancelamento de contratação;
- mutação de itens ou identificadores;
- política multiusuário;
- resolução de Q-001/Q-002/Q-006/Q-009;
- mudança de migration/capability F32;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F33 fecha quando o detalhe persistente expuser exclusivamente a edição de `object` por Server Action estreita sobre F32, preservando exact-value/optimistic concurrency, mantendo demo read-only, authority fora do browser, feedback fail-closed e todos os gates/regressões verdes.