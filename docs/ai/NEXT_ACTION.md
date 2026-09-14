# Next Action - Compras

## F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01 - Integrar edição persistente do objeto no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY  
**Objetivo:** expor no detalhe persistente somente a edição de `contractings.object` pela boundary F32 já provada, com Server Action estreita, optimistic concurrency, preservação exata do texto, feedback sanitizado e demo read-only.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F32 materializou ADR-013 em PostgreSQL/server-only e passou a matriz adversarial, teste real de concorrência e regressões em `main`. A capability, primitive e adapter já existem; a próxima slice deve somente conectar essa authority aprovada ao detalhe da aplicação, sem criar nova primitive, novo DML ou CRUD amplo.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F33.

## Execução obrigatória

1. recuperar o estado canônico após F32 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-013 e `tasks/F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01/SPEC.md`;
3. inspecionar F27/F30 como precedentes de Server Action/UI estreitas e a implementação F32;
4. manter migrations `0001..0006` imutáveis e não ampliar grants/capabilities;
5. criar Server Action dedicada que aceite somente `contractingId`, `expectedObject` e `newObject`;
6. rejeitar payload ambíguo/duplicado e impedir authority forjada do browser;
7. preservar `expectedObject`/`newObject` exatamente, inclusive string vazia e espaços, sem trim/normalização;
8. delegar autorização, concorrência, lock, atomicidade e auditoria a `mutatePersistentContractingObject`;
9. mapear somente `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` para UX sanitizada;
10. em conflito, não sobrescrever e exigir revisão/readback do estado atual;
11. revalidar somente rota local fixa nos resultados deliberados, sem callback/redirect arbitrário;
12. manter modo demo estritamente read-only e sem chamada à boundary F32;
13. renderizar editor somente de `Objeto`, sem liberar outras colunas/operações;
14. testar payload forjado, duplicatas, exact-string, demo, conflito, sanitização, revalidação, acessibilidade e ausência de authority extra;
15. executar lint, typecheck, testes, build, CI database/Auth e workflows F22/F29/F32;
16. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION` somente após todos os gates verdes.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F26 continua exclusiva de `next_action`;
- F29 continua exclusiva de criação mínima;
- F32 continua exclusiva de mutação de `object`;
- migrations aplicadas `0001..0006` permanecem imutáveis;
- browser não define identity/scope/actor/membership/event UUID;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F33-PERSISTENT-CONTRACTING-OBJECT-DETAIL-UI-01/SPEC.md` seguindo ADR-013 e as fontes canônicas ali referenciadas.

## Critério de encerramento

F33 fecha quando o detalhe persistente permitir editar somente `object` pela boundary F32, com expected-value exato, conflito fail-closed, demo read-only, payload sem authority controlada pelo cliente e regressões verdes, sem qualquer ampliação da camada PostgreSQL nesta slice.
