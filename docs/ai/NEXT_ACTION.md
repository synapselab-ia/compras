# Next Action - Compras

## F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01 - Integrar edição persistente de item no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY após integração da F38  
**Objetivo:** integrar a boundary F38 ao detalhe persistente com snapshot bruto protegido, Server Action estreita, semântica exata de `NULL`/texto/numeric, feedback sanitizado e demo read-only.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F38 integrou migration `0009`, capability, RLS, primitive, provisioning, adapter server-only e gate dedicado para editar somente `description`, `quantity`, `unit` e `catalog_code` de item ativo. A boundary está verde no head final e no pós-merge, mas ainda não existe jornada UI/Server Action correspondente.

O padrão canônico já usado em F31/F32/F33 e F34/F35/F36 separa desenho, implementação da boundary e integração UI. F39 é a terceira slice desse ciclo para ADR-015.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário permanecem abertas. F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F39.

## Execução obrigatória

1. recuperar `main` real após F38 e confirmar PR #59 integrada;
2. revalidar `CONTEXT_MANIFEST`;
3. ler ADR-015, `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/RESULT.md` e a SPEC F39;
4. inspecionar F33/F36, `persistent-read.ts`, `types.ts`, actions, feedbacks e detalhe atuais;
5. manter migrations `0001..0009` byte-for-byte imutáveis;
6. não alterar grants, policies, capability, primitive ou provisioning F38;
7. estender o read model protegido para fornecer o snapshot bruto de item necessário à optimistic concurrency, sem parse de `label`/`note`;
8. preservar `description`, `quantity`, `unit` e `catalogCode` exatamente, incluindo distinção de `NULL`, vazio e espaços;
9. manter `quantity` como `string | null`, lida por `numeric::text`, sem `Number`, `parseFloat` ou `type=number`;
10. criar Server Action dedicada que aceite somente os campos de transporte definidos na SPEC e rejeite duplicados/campos extras;
11. nunca aceitar team, actor, membership, issuer, subject, ordinal, retired state, timestamps ou event UUIDs como authority do browser;
12. nunca aceitar callback/redirect arbitrário;
13. chamar exclusivamente `mutatePersistentContractingItem`, sem SQL/DML próprio;
14. transportar sempre os quatro expected values do snapshot protegido, não expected parcial;
15. codificar `unit` e `catalogCode` com escolha explícita `text` versus `null`, para não colapsar `NULL` em `''`;
16. interpretar somente quantity literalmente vazia como `null`; qualquer texto não vazio segue exato para F38/PostgreSQL;
17. renderizar editor somente em persistent mode válido e para item com snapshot protegido;
18. manter demo estritamente read-only e sem hidden snapshot operacional;
19. mapear somente `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` para feedback fixo sanitizado;
20. `updated` revalida somente a rota local fixa e relê pelo read model protegido;
21. `conflict` não faz retry automático nem expõe current protegido na URL;
22. `not-available` não distingue cross-team, inexistente, retired, parent inativo ou membership;
23. desabilitar nova submissão enquanto pending;
24. não criar reorder, retire/restore, delete ou pesquisa de preços;
25. executar lint, typecheck, unit/component tests, build, CI database/Auth, F22, F29, F32, F35 e F38;
26. fazer red-team integral de forged payload, null/empty, concurrency snapshot, demo e navegação;
27. atualizar checkpoint somente depois de todos os gates ficarem verdes;
28. deixar exatamente uma nova NEXT_ACTION somente após F39 ser integralmente verificada.

## Red-team mínimo

Rejeitar PASS se:

- expected snapshot for reconstruído de `label`, `note`, DOM, ordinal ou timestamp;
- expected for parcial;
- unit/catalog `NULL` virar vazio implicitamente;
- quantity sofrer coerção floating-point no navegador/JavaScript;
- action executar SQL/DML ou contornar F38;
- browser puder fornecer scope/actor/event IDs como authority;
- callback/redirect externo controlar navegação;
- conflito for convertido em retry automático;
- feedback criar oracle de existência/scope/retired state;
- demo/configuração inválida puder gravar;
- falha protegida cair para fixture/demo;
- migrations `0001..0009`, grants, policies, capability ou primitive F38 forem alterados;
- escopo expandir para reorder/retire/delete/preço;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-004 e Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F35 continua exclusiva da criação de item;
- F38 continua exclusiva da edição dos quatro campos de item;
- migrations aplicadas `0001..0009` permanecem imutáveis;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01/SPEC.md` seguindo ADR-015 e os precedentes F33/F36.

## Critério de encerramento

F39 fecha quando o detalhe persistente editar item exclusivamente por F38, com snapshot bruto protegido dos quatro campos, optimistic concurrency completo, semântica exata de `NULL`/texto/numeric, feedback e navegação sanitizados, demo read-only e todos os gates/adversariais verdes.
