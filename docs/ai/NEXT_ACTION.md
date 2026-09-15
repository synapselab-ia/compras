# Next Action - Compras

## F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01 - Integrar criação persistente de item no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY  
**Objetivo:** tornar a boundary F35 utilizável no detalhe persistente por uma Server Action e UI mínimas, mantendo payload estreito, readback protegido, feedback sanitizado e demo estritamente read-only.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F35 está integrada e provou a criação persistente mínima de item com capability dedicada, allocator técnico por contratação, auditoria atômica, concorrência real e adapter server-only. A próxima slice pode expor essa operação sem ampliar a camada PostgreSQL.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário permanecem abertas. F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F36.

## Execução obrigatória

1. recuperar o estado canônico após F35 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-014 e `tasks/F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01/SPEC.md`;
3. inspecionar precedentes F27/F30/F33, detalhe persistente, read model de itens, `persistent-read-mode` e adapter F35;
4. manter migrations `0001..0007`, grants, policies, capabilities e primitives byte-for-byte imutáveis;
5. adicionar Server Action dedicada que só encaminhe `contractingId`, `description`, `quantity`, `unit` e `catalogCode` para `createPersistentContractingItem`;
6. rejeitar scalars duplicados/ambíguos e não aceitar team, actor, membership, issuer, subject, ordinal, item UUID, event UUID, callback ou redirect como authority do browser;
7. não executar SQL/DML próprio na action e não criar fallback demo;
8. preservar description, unit e catalogCode exatamente, inclusive vazio e espaços, sem trim ou empty-to-NULL;
9. transportar quantity como `string | null`, sem `Number`/`parseFloat`; ausência do campo numérico na UI representa `null`, texto presente segue exato para F35/PostgreSQL;
10. não inventar positividade, required, escala, precisão, vínculo com unidade ou regra de Q-004;
11. renderizar criação somente no detalhe em modo persistente válido e manter demo/configuração inválida sem write;
12. manter inputs de authority e operações de update/reorder/retire fora da UI;
13. usar estado pending para reduzir double-submit acidental, sem inventar idempotência persistente;
14. em `created`, revalidar apenas a rota local fixa e fazer readback pelo read model protegido;
15. mapear somente `created`, `not-available` e `unavailable` para feedback sanitizado, sem oracle cross-team/inexistente;
16. provar forged payload, duplicatas, semântica exata de strings, quantity string/null, demo read-only, sanitização, revalidação local, pending e acessibilidade;
17. executar lint, typecheck, testes, build, CI/Auth/RLS, F22, F29, F32 e F35;
18. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION` somente após todos os gates verdes.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F35 continua sendo a única boundary de item create;
- migrations aplicadas não são reescritas;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01/SPEC.md` seguindo ADR-014 e os precedentes F27/F30/F33.

## Critério de encerramento

F36 fecha quando o detalhe persistente permitir adicionar item mínimo exclusivamente pela boundary F35, com payload restrito, sem authority controlada pelo browser, sem normalização textual indevida, quantity string/null, readback protegido, feedback sanitizado, demo read-only e todos os gates/adversariais verdes.