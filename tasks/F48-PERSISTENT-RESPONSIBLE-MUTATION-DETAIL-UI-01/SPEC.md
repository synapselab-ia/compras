# F48-PERSISTENT-RESPONSIBLE-MUTATION-DETAIL-UI-01 - Integrar edição persistente do responsável no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY / NEXT após integração da F47  
**Dependências:** F47, ADR-018, F33, F45, F11, ADR-003, ADR-004, ADR-005 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F47 materializou a boundary PostgreSQL/server-only da ADR-018 para alterar ou limpar `contractings.responsible_membership_id`, com optimistic concurrency, clear para `NULL`, candidate elegível, guard target-team pilot-only, evento atômico e least privilege.

O detalhe persistente já apresenta o responsável atual em forma humana, usando `team_member_directory`, mas ainda não preserva o UUID bruto do responsável na apresentação nem oferece uma jornada de edição.

A próxima slice deve tornar somente a operação F47 utilizável no detalhe, sem ampliar authority PostgreSQL, sem criar gestão de memberships e sem resolver Q-009.

## Objetivo

No modo persistente autorizado, permitir alterar ou limpar o responsável interno da contratação usando exclusivamente:

```text
mutatePersistentContractingResponsible({
  contractingId,
  expectedResponsibleMembershipId,
  newResponsibleMembershipId
})
```

A interface deve:

- usar o valor bruto protegido atual como precondição otimista;
- listar candidates de apresentação somente pelo diretório protegido existente;
- permitir `Sem responsável` como `NULL`;
- nunca tratar a lista renderizada ou um membership UUID do browser como authority;
- apresentar feedback sanitizado;
- revalidar e confirmar o estado somente pelo read model protegido;
- manter demo estritamente read-only.

F48 não altera a migration `0012`, grants, policies, capability, primitive ou provisioning F47.

## 1. Recuperação e limites

Antes de implementar:

1. recuperar `main` real após F47;
2. revalidar `CONTEXT_MANIFEST`;
3. confirmar PR F47 integrada e gates do head final verdes;
4. ler ADR-018, resultado F47 e esta SPEC;
5. inspecionar F33 como precedente principal de edição de campo com optimistic concurrency;
6. inspecionar F45 como precedente recente de Server Action estreita, demo read-only e feedback sanitizado;
7. inspecionar F11/ADR-004/ADR-005 para o contrato do `team_member_directory`;
8. inspecionar `persistent-read.ts`, `types.ts`, `view-data.ts`, `actions.ts`, página e componente do detalhe;
9. confirmar que `team_member_directory` continua sendo a única superfície humana aprovada para nomes de membros;
10. manter migrations `0001..0012` byte-for-byte imutáveis;
11. não alterar grants, policies, capability, primitive ou provisioning F47.

F48 não implementa nova authority de banco.

## 2. Extensão mínima do read model

O read model protegido precisa fornecer à UI a precondição e as opções de apresentação necessárias, sem expor autoridade adicional.

Adicionar ao modelo de detalhe valores equivalentes a:

```text
responsibleMembershipId: string | null

responsibleOptions: Array<{
  membershipId: string
  displayName: string
}>
```

### Responsible atual

`responsibleMembershipId` deve vir diretamente de `contractings.responsible_membership_id` já lido pela consulta protegida.

Esse valor:

- é precondição de optimistic concurrency;
- não define team;
- não define actor;
- não prova autorização;
- pode apontar para membership que deixou de aparecer no diretório por revogação ou app_user desabilitado;
- deve permanecer disponível como expected raw mesmo quando a apresentação humana seja `Responsável não disponível`.

### Opções humanas

As opções devem vir somente de `public.team_member_directory` e ser restringidas à equipe da contratação alvo através do próprio target protegido.

A consulta pode usar composição equivalente a:

```text
contracting protegido -> team_id
team_member_directory -> membership_id + display_name
```

Requisitos:

- não retornar `team_id` ao browser;
- não retornar `user_id`, issuer, subject ou qualquer identificador de autenticação;
- não consultar `memberships` ou `app_users` diretamente para montar lista humana;
- não criar view nova;
- não criar grant novo;
- não criar endpoint paralelo;
- ordenar de forma estável e determinística;
- não inferir que uma opção renderizada autoriza a mutation.

O enforcement de same-team, membership não revogada e app_user ativo continua integralmente em F47.

## 3. Estado degradado

F48 precisa preservar a semântica de F47 sem esconder estados legítimos.

### Current revogado

Se o current responsável apontar para membership revogada:

- `responsibleMembershipId` ainda deve preservar o UUID bruto atual;
- o nome pode continuar como `Responsável não disponível`;
- a membership revogada não deve ser reintroduzida artificialmente em `responsibleOptions`;
- a UI deve permitir limpar para `NULL`;
- a boundary F47 decide se a operação é autorizada.

### Current com app_user desabilitado

Se o current apontar para membership não revogada cujo app_user esteja desabilitado:

- a opção pode não aparecer no diretório humano;
- o UUID bruto atual continua sendo a precondição;
- a UI não deve tentar contornar o guard;
- F47 pode retornar `not-available` porque essa membership ainda conta como segundo membro não revogado.

Não criar lógica client-side ou server-side de "reparo automático".

## 4. Transporte nullable explícito

O browser precisa transportar `NULL` versus membership UUID sem sentinela ambígua.

A Server Action deve aceitar somente campos equivalentes a:

```text
contractingId
expectedResponsibleKind
expectedResponsibleMembershipId
newResponsibleKind
newResponsibleMembershipId
```

Kinds permitidos:

```text
null
membership
```

Semântica:

- `expectedResponsibleKind = null` produz expected `NULL` e não exige UUID;
- `expectedResponsibleKind = membership` exige exatamente um UUID sintaticamente válido;
- `newResponsibleKind = null` produz new `NULL`;
- `newResponsibleKind = membership` exige exatamente um UUID sintaticamente válido.

A ausência/presença dos scalars deve ser validada de forma estrita.

Não usar string vazia, `"null"`, UUID zero ou outro valor sentinela como estado persistente.

## 5. Server Action estreita

Criar uma Server Action dedicada à edição do responsável.

Ela deve:

- exigir modo persistente;
- ler cada scalar esperado no máximo uma vez;
- rejeitar scalars duplicados ou ambíguos;
- aceitar somente os campos definidos nesta SPEC, além de `$ACTION_*` internos do framework;
- validar `contractingId` como UUID candidato;
- decodificar expected/new apenas para `string | null`;
- validar UUID sintático para valores não nulos;
- não executar SQL ou DML próprio;
- chamar exclusivamente `mutatePersistentContractingResponsible`;
- não aceitar team, actor, user, issuer, subject, event UUID, timestamp, stage, status, waiting ou callback;
- não aceitar URL ou redirect arbitrário;
- nunca cair para demo write;
- sanitizar erro técnico ou resultado impossível como `unavailable`;
- construir navegação somente com a rota local fixa derivada do `contractingId` validado.

A action não deve validar autorização pela lista `responsibleOptions`.

Um UUID válido forjado pelo browser continua sendo apenas candidate e deve alcançar, no máximo, a validação de authority da boundary F47.

## 6. Resultado, navegação e readback

Resultados externos F47:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

Semântica na UI:

- `updated`: revalidar somente a rota local fixa do detalhe, informar sucesso e confirmar o responsável pelo read model protegido;
- `unchanged`: informar no-op sem criar movimentação fictícia;
- `conflict`: revalidar/readback, informar que o estado mudou e exigir nova revisão antes de nova tentativa;
- `not-available`: feedback genérico sem distinguir target inexistente, cross-team, membership, guard, candidate inválida, revogada ou app_user desabilitado;
- `unavailable`: feedback técnico fixo e sanitizado, sem fallback para demo;
- resultado impossível: tratar como `unavailable`.

Nenhuma resposta pode revelar:

- team_id;
- actor membership;
- issuer/subject;
- status de membership protegida;
- existência cross-team;
- SQL;
- connection string;
- erro bruto;
- timestamp interno.

O readback deve usar exclusivamente o modelo protegido de detalhe.

## 7. UI mínima

No detalhe persistente, expor somente o necessário para editar o responsável:

- apresentação do responsável atual;
- seletor com opção explícita `Sem responsável`;
- opções humanas provenientes de `responsibleOptions`;
- submit;
- feedback fixo da operação.

A UI deve:

- carregar o expected raw atual do read model protegido;
- manter labels acessíveis e navegação por teclado;
- desabilitar repetição enquanto a tentativa estiver pending;
- não expor inputs editáveis de team, actor, user, issuer, subject, event UUID ou timestamp;
- não apresentar membership UUID como informação humana principal;
- não sugerir que demo grava dados;
- não oferecer criação, edição ou revogação de memberships;
- não editar stage, status, waiting ou qualquer outro campo por esta jornada.

Se o current não estiver presente nas opções humanas por estado degradado, a UI deve continuar apresentando o estado atual e permitir escolha de `Sem responsável` ou outra opção disponível, sem inventar nome para a membership degradada.

## 8. Demo e falhas protegidas

Demo permanece estritamente read-only:

- não renderiza formulário F48;
- não executa Server Action F48;
- não consulta candidate operacional adicional para habilitar write;
- query string forjada não produz feedback que sugira alteração real.

Persistence inválida, sessão indisponível ou falha de leitura protegida:

- não habilita formulário;
- não chama F47;
- não cai para fixtures;
- não converte falha em demo.

## 9. Candidate e authority

A lista de opções é UX, não boundary de segurança.

Provar explicitamente:

- candidate válida forjada mas cross-team não ganha authority;
- candidate UUID inexistente não ganha feedback específico;
- membership revogada não pode ser reatribuída;
- app_user desabilitado não pode ser reatribuído;
- segundo membro não revogado continua bloqueando pelo guard F47;
- browser não controla actor membership por escolher a própria membership;
- current expected forjado não altera scope, apenas pode resultar em conflict ou negação conforme F47.

Q-009 continua aberta.

F48 não deve liberar transferência multiusuário por inferência da existência do diretório.

## 10. Timeline

F47 já grava `responsible_changed`.

F48 não precisa alterar o contrato de eventos.

Se houver ajuste de apresentação do evento, ele deve ser estritamente visual e baseado em dados já autorizados pelo read model.

Não:

- criar consulta paralela de auditoria;
- resolver UUID histórico por acesso direto a membership revogada;
- alterar event shape;
- editar/excluir evento;
- criar evento adicional na camada de UI.

## 11. Matriz adversarial obrigatória

Provar no mínimo:

1. persistent mode autorizado renderiza editor mínimo de responsável;
2. demo não renderiza editor nem chama F47;
3. persistence inválida/falha protegida não chama F47 e não cai para demo;
4. read model preserva `responsibleMembershipId = NULL` quando não há responsável;
5. read model preserva UUID bruto quando há responsável;
6. current revogado preserva expected UUID mesmo sem opção humana correspondente;
7. opções humanas vêm de `team_member_directory` e são restritas ao target protegido;
8. opções não expõem team_id, user_id, issuer ou subject;
9. `Sem responsável` decodifica exatamente para `newResponsibleMembershipId = null`;
10. expected `NULL` é transportado explicitamente, sem string sentinela;
11. expected UUID é encaminhado exatamente;
12. new UUID é encaminhado exatamente;
13. action encaminha somente `contractingId`, expected e new para F47;
14. scalars duplicados falham fechado antes de F47;
15. campos extras browser-controlled falham fechado;
16. team/actor/user/issuer/subject/event/timestamp forjados não atravessam a action;
17. callback/redirect forjado não controla navegação;
18. `contractingId` malformado não chega a F47;
19. expected membership malformada não chega a F47;
20. new membership malformada não chega a F47;
21. kind inválido ou combinação kind/scalar ambígua falha fechado;
22. candidate válida forjada não vira authority;
23. cross-team/inexistente/revogada/disabled permanecem feedback genérico;
24. segundo membro não revogado não é contornado pela UI;
25. current revogado pode ser submetido como expected para clear sem reintroduzir opção revogada;
26. `updated` revalida somente a rota local fixa;
27. `unchanged` não inventa evento ou mudança;
28. `conflict` força readback e não é apresentado como sucesso;
29. `not-available` não distingue motivo protegido;
30. `unavailable` não expõe erro interno;
31. resultado impossível é sanitizado;
32. erro contendo SQL, claims ou conexão não aparece no HTML ou navegação;
33. pending desabilita repetição acidental;
34. readback do responsável após sucesso vem somente do modelo protegido;
35. não existe gestão de membership, stage/status/waiting ou CRUD genérico;
36. migrations `0001..0012` permanecem byte-for-byte;
37. grants, policies, capability, primitive e provisioning F47 permanecem imutáveis;
38. F26/F29/F32/F35/F38/F41/F44/F47 não recebem authority cruzada nova;
39. CI, F22, F29, F32, F35, F38, F41, F44 e F47 continuam verdes;
40. somente dados/identidades fictícios são usados.

## 12. Red-team obrigatório

Rejeitar PASS se:

- UI ou action tratar membership UUID como autorização;
- browser puder definir team, actor, user, issuer ou subject;
- seleção do próprio membership puder redefinir actor;
- lista do diretório virar enforcement em substituição a F47;
- action consultar membership/app_user diretamente para decidir autorização;
- candidate cross-team, revogada ou disabled puder ser atribuída;
- current degradado for autoajustado sem submissão explícita;
- clear para `NULL` for removido;
- expected value for ignorado;
- conflict for convertido em sucesso;
- stale write virar last-write-wins;
- Server Action executar SQL/DML próprio;
- browser controlar event UUID ou timestamp;
- feedback virar oracle de target/candidate;
- demo/configuração inválida puder gravar;
- protected failure cair para fixture/demo;
- callback/redirect externo for controlável pelo cliente;
- migration `0001..0012` for alterada;
- grant, policy, capability, primitive ou provisioning F47 for ampliado;
- gestão de memberships entrar no escopo;
- Q-009 for resolvida implicitamente;
- provider hosted, secret ou dado real for necessário.

## 13. Verificação

Executar:

- lint;
- typecheck;
- unit/component tests;
- build;
- CI database/Auth;
- F22 Private Preview Preflight;
- F29 Contracting Create;
- F32 Contracting Object Mutation;
- F35 Contracting Item Create;
- F38 Contracting Item Mutation;
- F41 Related Identifier Create;
- F44 Manual Timeline Note Create;
- F47 Contracting Responsible Mutation;
- diff/red-team integral;
- confirmação byte-for-byte de migrations `0001..0012`;
- confirmação de que grants/policies/capability/primitive/provisioning F47 ficaram fora do diff.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios em teste;
- F21 permanece `ON HOLD` até seu `resume_when`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F47 continua sendo a única boundary persistente de alteração do responsável;
- `team_member_directory` continua sendo a superfície humana aprovada para membros;
- migrations aplicadas `0001..0012` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fora do escopo

- criação, edição, convite ou revogação de memberships;
- política multiusuário definitiva;
- resolução de Q-009;
- edição de etapa, status ou waiting;
- arquivamento/cancelamento;
- CRUD genérico de contratação;
- edição/exclusão de eventos;
- mutation de identificador existente;
- pesquisa de preços;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F48 fecha quando uma pessoa autorizada em modo persistente puder alterar ou limpar o responsável pelo detalhe usando exclusivamente F47, com expected membership bruto do read model protegido, options humanas do diretório protegido, transporte nullable explícito, payload sem authority controlada pelo browser, feedback sanitizado, optimistic concurrency preservada, readback protegido, demo read-only e todos os gates/adversariais verdes, sem ampliar a camada PostgreSQL e sem resolver Q-009.
