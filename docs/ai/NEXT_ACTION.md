# Next Action - Compras

## F48-PERSISTENT-RESPONSIBLE-MUTATION-DETAIL-UI-01 - Integrar edição persistente do responsável no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY após integração da F47  
**Objetivo:** integrar exclusivamente a boundary F47 ao detalhe persistente para alterar ou limpar o responsável interno, preservando optimistic concurrency, options humanas pelo diretório protegido, transporte nullable explícito, feedback sanitizado e demo read-only, sem ampliar authority PostgreSQL e sem resolver Q-009.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F47 integrou e validou a authority server/database para `contractings.responsible_membership_id`.

O detalhe persistente já apresenta o nome do responsável via `team_member_directory`, mas ainda não preserva o UUID bruto do current responsável na apresentação nem oferece a jornada de edição.

A próxima slice independente é conectar a boundary F47 à UI sem alterar sua autoridade.

## Execução obrigatória

1. recuperar `main` real e confirmar F47 integrada pela PR `#79`, merge `4e7bb411205469977878e01cb04ea35d5ad50401`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler ADR-018, resultado F47 e `tasks/F48-PERSISTENT-RESPONSIBLE-MUTATION-DETAIL-UI-01/SPEC.md`;
4. inspecionar F33, F45, F11, `persistent-read.ts`, `types.ts`, `view-data.ts`, `actions.ts`, página e componente do detalhe;
5. confirmar migrations `0001..0012` byte-for-byte antes de editar;
6. manter migration, grants, policies, capability, primitive e provisioning F47 imutáveis;
7. estender o read model com `responsibleMembershipId: string | null`;
8. carregar options humanas somente de `team_member_directory`, restritas ao target protegido;
9. não expor team_id, user_id, issuer ou subject como dados da jornada;
10. preservar current responsável degradado como expected raw mesmo quando seu nome não estiver disponível;
11. implementar transporte explícito `null|membership` para expected e new;
12. criar Server Action estreita que aceita somente `contractingId`, expected e new;
13. rejeitar scalars duplicados, shapes ambíguos, UUIDs malformados e campos extras controlados pelo browser;
14. não executar SQL/DML na Server Action;
15. chamar exclusivamente `mutatePersistentContractingResponsible`;
16. não tratar options renderizadas nem membership UUID como authority;
17. permitir `Sem responsável` como new `NULL`;
18. mapear `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` para feedback fixo e sanitizado;
19. revalidar/readback somente pela rota local e modelo protegido;
20. manter demo, config inválida e protected failure sem write e sem fallback;
21. manter Q-009 aberta e não introduzir gestão de memberships;
22. adicionar testes adversariais de read model, action, feedback, component/page, current degradado e candidate forjada;
23. executar CI, F22, F29, F32, F35, F38, F41, F44 e F47;
24. fazer red-team integral do diff;
25. confirmar migrations `0001..0012` e authority F47 imutáveis;
26. promover somente estado verde;
27. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser puder definir team, actor, user, issuer ou subject;
- membership UUID ou lista do diretório virar authority;
- Server Action consultar banco para criar autorização paralela;
- candidate cross-team, revogada ou disabled puder ser atribuída;
- current degradado for autoajustado;
- clear para `NULL` for removido;
- expected value for ignorado;
- stale conflict virar sucesso ou last-write-wins;
- Server Action executar SQL/DML próprio;
- feedback revelar target/candidate protegido;
- demo ou configuração inválida puder gravar;
- falha protegida cair para fixture/demo;
- migrations `0001..0012` forem alteradas;
- grants, policies, capability, primitive ou provisioning F47 forem ampliados;
- Q-009 for resolvida implicitamente;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F47 continua sendo a única boundary persistente de alteração do responsável;
- `team_member_directory` continua sendo a superfície humana aprovada para membros;
- migrations `0001..0012` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar:

`tasks/F48-PERSISTENT-RESPONSIBLE-MUTATION-DETAIL-UI-01/SPEC.md`.

Boundary canônica:

`tasks/F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01/RESULT.md`.

Decisão canônica:

`docs/decisions/ADR-018-persistent-responsible-mutation.md`.

## Critério de encerramento

F48 fecha quando uma pessoa autorizada em modo persistente puder alterar ou limpar o responsável pelo detalhe usando exclusivamente F47, com expected membership bruto do read model protegido, options humanas do diretório protegido, transporte nullable explícito, payload sem authority controlada pelo browser, feedback sanitizado, optimistic concurrency preservada, readback protegido, demo read-only e todos os gates/adversariais verdes, sem ampliar a camada PostgreSQL e sem resolver Q-009.
