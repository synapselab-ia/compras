# Next Action - Compras

## F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01 - Implementar criação persistente mínima de item

**Classe:** T2 - banco, autorização e escrita server-side  
**Estado:** READY  
**Objetivo:** materializar ADR-014 em uma boundary PostgreSQL/server-only para adicionar um item a uma contratação existente, com capability dedicada, ordinal atribuído sob lock da contratação pai, auditoria atômica e resultados sanitizados.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F34 fechou o desenho arquitetural da criação mínima de item em ADR-014 e produziu uma SPEC executável para F35. A implementação pode avançar sem resolver Q-004 de pesquisa de preços nem Q-009 de política multiusuário.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F35.

## Execução obrigatória

1. recuperar o estado canônico após F34 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-014 e `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`;
3. revalidar SECURITY, DATABASE, ADR-003/005/009/011/012/013 e os precedentes F26/F29/F32 necessários;
4. manter migrations `0001..0006` byte-for-byte imutáveis;
5. criar nova migration `0007_contracting_item_create.sql` com capability própria, RLS específica e primitive estreita;
6. manter F26 exclusiva de `next_action`, F29 exclusiva de criação de contratação e F32 exclusiva de mutação de `object`;
7. manter runtime normal sem DML direto e conceder somente `EXECUTE` da primitive F35 por provisioning separado;
8. criar adapter server-only que aceite somente `contractingId`, `description`, `quantity`, `unit` e `catalogCode`;
9. gerar item UUID e event UUID no servidor e manter team, actor, membership, issuer, subject e ordinal fora da authority do browser;
10. transportar `quantity` como `string | null` até PostgreSQL `numeric`, sem `Number` ou `parseFloat`;
11. preservar `description`, `unit` e `catalogCode` exatamente, inclusive vazio/espaços conforme nullability física;
12. seguir autorização pilot-only por equipe alvo de F26/F32, sem copiar o guard global da F29;
13. bloquear a contratação autorizada com `SELECT ... FOR UPDATE` antes de calcular `MAX(ordinal) + 1`;
14. considerar itens retirados no máximo e não reutilizar gaps;
15. criar item e evento `item_created` na mesma transação, com rollback integral se a auditoria falhar;
16. não alterar `contractings.updated_at` nesta operação;
17. expor somente `created`, `not-available` e `unavailable` na boundary server-only;
18. provar em PostgreSQL 17 concorrência real de no mínimo 8 writers na mesma contratação, sem ordinal duplicado e sem retry cego;
19. provar que contratações diferentes não dependem de lock global;
20. executar preflight adversarial de role/capability, regressões Auth/RLS/F24/F26/F29/F32, lint, typecheck, testes e build;
21. criar workflow F35 dedicado e exigir todos os gates verdes antes da promoção;
22. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION` somente após validação completa.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas não são reescritas;
- nenhuma regra de quantidade positiva, unidade obrigatória, catálogo obrigatório, trim, tamanho ou pesquisa de preços pode ser inventada;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md` seguindo ADR-014 e as fontes canônicas nela referenciadas.

## Critério de encerramento

F35 fecha quando a criação mínima de item estiver implementada e provada com capability dedicada, autorização pilot-only por contratação/equipe alvo, ordinal concorrente serializado pela row pai, evento atômico, adapter server-only sanitizado e todas as regressões verdes, sem UI e sem ampliar as capabilities anteriores.