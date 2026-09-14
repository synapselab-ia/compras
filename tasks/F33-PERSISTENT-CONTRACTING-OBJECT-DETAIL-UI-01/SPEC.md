# F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01 - Integrar edição persistente do objeto no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** COMPLETED / PASS  
**Dependências:** F32, ADR-003, ADR-009 e ADR-013  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F32 entrega a primitive PostgreSQL estreita e o adapter server-only para alterar `contractings.object`, mas o detalhe persistente continuava sem uma jornada de edição desse campo. A slice deveria expor somente a mutação já aprovada, sem abrir CRUD amplo, sem ampliar authority e sem resolver implicitamente política multiusuário.

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
8. não liberar qualquer outra coluna ou operação persistente além das já integradas anteriormente.

## Fronteira funcional

### Modo demo

- continua somente leitura;
- não renderiza controle que execute write real;
- não chama adapter de mutação;
- banner continua explícito sobre dados fictícios/persistência desabilitada.

### Modo persistente

- `Objeto` fica editável por esta slice, ao lado da edição de `Próxima ação` já existente da F27;
- o ID da rota é seletor candidato, nunca fonte de escopo;
- o valor atual de `object` carregado do banco é enviado como `expectedObject` para a precondição otimista da ADR-013;
- `newObject` é preservado como string sem trim, limite de tamanho, regra non-empty ou conversão empty-to-NULL inventados;
- a UI não infere disponibilidade cross-team nem política de membership.

## Server Action obrigatória

A Server Action dedicada à alteração de `object` recebe somente dados equivalentes a:

```text
contractingId
expectedObject
newObject
```

Requisitos preservados:

- validar o shape do payload sem criar regra de negócio nova;
- delegar autorização, lock, concorrência, atomicidade e auditoria à boundary F32;
- rejeitar scalars duplicados/ambíguos de FormData;
- não receber nem encaminhar `team_id`, actor, membership, issuer, subject ou event UUID do browser;
- não aceitar callback/URL/redirect arbitrário fornecido pelo cliente;
- não logar payload, sessão, claims, connection string ou detalhe de erro;
- retornar somente estado sanitizado suficiente para a UI;
- sem demo fallback em falha protegida.

## Semântica de resultado na UI

- `updated`: sucesso e revalidação da rota local fixa;
- `unchanged`: informa no-op sem movimentação inexistente;
- `conflict`: informa stale state, revalida/readback e exige revisão antes de nova tentativa;
- `not-available`: mensagem genérica sem oracle de existência/autorização;
- `unavailable`: erro técnico sanitizado, sem fallback para demo.

## Segurança

A UI não é enforcement. Permanecem verdadeiros:

- sessão Better Auth validada no servidor;
- contexto confiável usa somente `iss/sub` LOCAL;
- RLS/capability F32 continuam autoritativas;
- runtime normal continua sem DML direto em tabelas protegidas;
- browser não define identity/scope/actor/membership/event UUID;
- Q-009 continua aberta e o guard pilot-only permanece no banco;
- cross-team e inexistente continuam indistinguíveis externamente;
- modo demo nunca vira caminho de escrita;
- F26 continua exclusiva de `next_action` e F29 continua exclusiva de criação mínima.

## Execução realizada

F33 foi implementada na branch `f33-persistent-contracting-object-detail-ui`, PR `#49`, sobre `main` em `d4afcca06b968bfac8467a1f492d99cdcc8d5c57`.

A implementação adicionou:

- `updatePersistentObjectAction` em `src/features/contracting-detail/actions.ts`;
- feedback sanitizado dedicado em `object-feedback.ts`;
- editor persistente de `Objeto` no detalhe;
- parsing do estado sanitizado `objectMutation` na página de detalhe;
- testes de Server Action, feedback e componente.

A Server Action lê exatamente uma vez `contractingId`, `expectedObject` e `newObject`. `expectedObject` e `newObject` são obrigatoriamente strings presentes, mas `""` permanece válido e distinto de ausência. Espaços e leading/trailing spaces são encaminhados sem trim/normalização.

Campos forjados de team, actor, membership, issuer, subject, event UUID, callback e campos framework-like não se tornam authority e não são encaminhados a F32. Redirect e revalidação usam exclusivamente a rota local fixa do detalhe.

A UI usa o valor protegido carregado pelo read model como `expectedObject`; conflito não sobrescreve o estado atual e provoca readback/revisão. Demo não renderiza editor nem feedback forjado e a própria Server Action bloqueia modo não persistente.

Nenhuma migration, grant, policy, RLS, capability ou primitive PostgreSQL foi alterada. `0001..0006` permaneceram imutáveis. Não houve provider hosted write, secret ou dado real.

## Red-team executado

O diff e a suíte rejeitam:

- authority de browser para team/actor/membership/issuer/subject/event UUID;
- callback/redirect arbitrário;
- scalars duplicados ou ausentes chegando à F32;
- demo ou configuração inválida alcançando a mutação;
- trim, normalização ou rejeição de string vazia;
- stale conflict convertido em sucesso;
- erro de banco vazando connection string/detalhe interno;
- feedback cross-team/inexistente distinguível;
- formulário expondo stage/status/responsável/waiting ou outras authorities;
- SQL/DML próprio na Server Action;
- expansão de F26/F29/F32;
- alteração das migrations aplicadas;
- provider hosted ou dado real.

Não havia review threads pendentes na PR.

## Verificação

Head final da PR `81f926b91657fe6de458d4ad01aee15f62672592`:

- CI `34850892351`: PASS, incluindo lint, typecheck, testes, build, database e auth-database;
- F22 Private Preview Preflight `34850892414`: PASS;
- F29 Contracting Create `34850892361`: PASS;
- F32 Contracting Object Mutation `34850892323`: PASS.

A PR `#49` foi integrada por merge commit `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`.

Pós-merge em `main`:

- CI `34851216964`: PASS;
- F22 Private Preview Preflight `34851216895`: PASS;
- F29 Contracting Create `34851216887`: PASS;
- F32 Contracting Object Mutation `34851217022`: PASS.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios em teste;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- migrations aplicadas permanecem imutáveis;
- sem fallback protegido para demo.

## Critério de encerramento

PASS. O detalhe persistente expõe a edição de `object` exclusivamente pela boundary F32, com expected-value exato, conflito fail-closed, demo read-only, payload sem authority controlada pelo cliente e regressões verdes, sem ampliação da camada PostgreSQL.