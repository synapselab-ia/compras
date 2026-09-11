# F27-PERSISTENT-NEXT-ACTION-DETAIL-UI-01 — Integrar edição persistente de próxima ação no detalhe

**Classe:** T1 — feature normal, com impacto T2 — autorização/escrita server-side  
**Estado:** COMPLETED / PASS  
**Dependências:** F26, ADR-003, ADR-009 e ADR-011  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F26 entrega a primitive PostgreSQL estreita e o adapter server-side para alterar `contractings.next_action`, mas a jornada do detalhe continua somente leitura. A Definition of Done exige que uma necessidade operacional prevista possa ser executada pela aplicação; portanto a próxima slice deve expor somente essa mutação já aprovada, sem abrir CRUD amplo nem inferir permissões multiusuário.

## Resultado esperado

No modo persistente autorizado, o detalhe de uma contratação deve permitir alterar apenas `Próxima ação` por uma Server Action estreita que reutiliza `mutatePersistentContractingNextAction`.

A jornada deve:

1. mostrar o valor atual carregado pelo read model protegido;
2. permitir enviar apenas `contractingId`, valor esperado observado e novo `next_action`;
3. nunca aceitar actor, `team_id`, membership, issuer, subject ou event UUID como autoridade do form/browser;
4. gerar feedback distinto para `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` sem revelar existência cross-team;
5. atualizar/recarregar o detalhe após sucesso sem fallback para fixtures;
6. permanecer totalmente desabilitada no modo demo;
7. não liberar qualquer outra coluna ou operação persistente.

## Fronteira funcional

### Modo demo

- continua somente leitura;
- não renderiza controle que execute write real;
- não chama adapter de mutação;
- banner continua explícito sobre dados fictícios/persistência desabilitada.

### Modo persistente

- somente o campo `Próxima ação` fica editável nesta slice;
- o ID da rota é seletor candidato, nunca fonte de escopo;
- o valor atual de `next_action` carregado do banco é enviado como `expectedNextAction` para a precondição otimista da ADR-011;
- o novo valor é preservado sem trim, limite de tamanho ou regra non-null que o modelo não sustente;
- `NULL` deve continuar representável de forma deliberada; string vazia não pode ser convertida silenciosamente em `NULL` sem regra aprovada.

## Server Action obrigatória

Criar uma Server Action dedicada à alteração de `next_action`.

Ela pode receber somente dados equivalentes a:

```text
contractingId
expectedNextAction
newNextAction
```

Requisitos:

- validar o shape do payload sem criar regra de negócio nova;
- delegar a autorização/atomicidade para a boundary F26;
- não receber nem encaminhar `team_id`, actor, membership, issuer, subject ou event UUID do browser;
- não aceitar URL/redirect arbitrário fornecido pelo cliente;
- não logar payload, sessão, claims, connection string ou detalhes de erro;
- retornar somente estado sanitizado suficiente para a UI;
- sem demo fallback em falha protegida.

## Semântica de resultado na UI

### `updated`

- informar sucesso;
- invalidar/revalidar o detalhe persistente apropriado;
- o novo valor e o evento devem ser observáveis no readback posterior.

### `unchanged`

- informar que não houve alteração;
- não apresentar movimentação inexistente.

### `conflict`

- informar que o valor mudou desde a leitura e que o usuário deve revisar o estado atual;
- não sobrescrever silenciosamente;
- revalidar/recarregar o detalhe antes de nova tentativa.

### `not-available`

- usar mensagem genérica de recurso/ação indisponível;
- não distinguir UUID inexistente, cross-team, identidade sem autorização, segundo membro ativo, arquivado ou cancelado.

### `unavailable`

- usar erro técnico sanitizado;
- não expor driver, SQL, session, claims ou connection string;
- não trocar silenciosamente para demo.

## UI/UX mínima

A interface deve permanecer coerente com o detalhe existente e incluir:

- label clara `Próxima ação`;
- controle acessível por teclado;
- estado de envio/pending que evite submissão acidental repetida;
- feedback textual associado à ação;
- valor atual visível antes da edição;
- tratamento deliberado de conflito;
- sem controles de stage/status/responsável/aguardando.

Não é necessário criar editor genérico, modal complexo ou design system novo.

## Segurança

A UI não é enforcement. Devem permanecer verdadeiros:

- sessão Better Auth é validada no servidor;
- contexto confiável contém somente `iss/sub` LOCAL;
- RLS continua autoritativa;
- runtime continua sem DML direto em tabelas protegidas;
- runtime usa apenas `EXECUTE` da primitive F26 para esta escrita;
- Q-009 continua aberta e o guard pilot-only permanece no banco;
- cross-team e inexistente continuam indistinguíveis externamente;
- modo demo nunca vira caminho de escrita.

## Testes obrigatórios

### Server Action / aplicação

- payload válido chama a interface F26 com exatamente candidate ID + expected + new;
- campos extras forjados de actor/team/membership/event UUID são ignorados/rejeitados e nunca encaminhados;
- payload malformado falha fechado;
- `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` são mapeados para estados sanitizados;
- `conflict` não é convertido em sucesso;
- erro interno não vaza detalhes;
- revalidação ocorre apenas nos resultados previstos;
- nenhum redirect arbitrário é aceito do cliente.

### Componente/detalhe

- demo renderiza somente leitura e não expõe form de mutação persistente;
- persistente renderiza controle apenas de `next_action`;
- feedback de sucesso, no-op, conflito, indisponibilidade de recurso e erro técnico é compreensível;
- teclado/label/status possuem acessibilidade básica;
- nenhuma edição de stage/status/responsável/waiting aparece nesta slice.

### Regressão

- lint PASS;
- typecheck PASS;
- testes completos PASS;
- build PASS;
- CI database PASS, incluindo concorrência F26;
- Auth/F24 PostgreSQL PASS;
- F22 Private Preview Preflight PASS;
- nenhuma migration aplicada é reescrita.

## Red-team obrigatório

Rejeitar PASS se:

- browser puder fornecer actor/team/membership/issuer/subject/event UUID confiável;
- demo conseguir disparar write;
- Server Action contornar `mutatePersistentContractingNextAction` com SQL/DML próprio;
- conflito sobrescrever estado atual;
- cross-team e inexistente produzirem mensagens distinguíveis;
- falha protegida cair para fixtures/demo;
- payload ou erro sensível chegar a log/UI;
- controle liberar outra coluna além de `next_action`;
- Q-009 for resolvida implicitamente;
- runtime ganhar DML direto;
- provider hosted ou dado real for usado.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios em teste;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-009 permanece aberta;
- autenticação não é autorização;
- RLS continua autoritativa;
- F26 continua sendo a única primitive de escrita disponível;
- sem fallback protegido → demo.

## Fora do escopo

- edição de stage/status/responsável/aguardando;
- criação/arquivamento/cancelamento de contratação;
- mutação de itens/identificadores;
- política multiusuário;
- resolução de Q-001/Q-002/Q-006/Q-009;
- provider hosted;
- retomada F21;
- dado real.

## Execução realizada

F27 foi implementada na PR `#43` sobre F26 integrada.

- `ContractingDetailPresentation` preserva `nextActionValue: string | null` separado da apresentação humana, mantendo `NULL` distinto de string vazia;
- `updatePersistentNextActionAction` exige modo persistente, valida somente o candidate UUID e encaminha exclusivamente `contractingId`, `expectedNextAction` e `newNextAction` para `mutatePersistentContractingNextAction`;
- campos extras forjados e `$ACTION_*` não viram autoridade nem são encaminhados;
- ausência deliberada de `expectedNextAction`/`newNextAction` representa `NULL`; string vazia continua string vazia;
- demo não renderiza form e a própria Server Action bloqueia execução fora do modo persistente;
- sucesso e conflito revalidam somente a rota local fixa do detalhe;
- feedback externo é limitado aos cinco estados sanitizados previstos;
- o editor expõe apenas `Próxima ação`, com label, pending/disabled e opção explícita de limpar para `NULL`;
- nenhum DML, grant, migration ou primitive F26 foi alterado.

### Red-team executado

Os testes provam que browser não injeta team/actor/membership/issuer/subject/event UUID/callback confiáveis; duplicate scalar falha fechado; demo/invalid mode não chega à F26; erro inesperado não vaza connection string; conflito não vira sucesso; controles de stage/status/responsável/waiting não aparecem; feedback forjado no modo demo é ignorado.

Uma primeira tentativa adicional de teste do botão pending falhou por assertar a substring `disabled` contra `aria-disabled="false"`; o teste foi corrigido sem alterar implementação ou enforcement.

### Verificação funcional

Head `96eae1dfa3a6105e87f80b2b103c509b897c4db6`:

- CI `34613166500`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `34613166498`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- F26 PostgreSQL/RLS/concorrência: PASS;
- Better Auth/F24: PASS.

Nenhum provider hosted, secret, environment variable ou dado real foi usado.

## Critério de encerramento

PASS. A aplicação persistente expõe somente a alteração de `Próxima ação` pela boundary F26, com concorrência/feedback fail-closed e demo read-only. A promoção final ainda depende dos mesmos gates verdes no head documental final antes do merge.
