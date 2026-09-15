# Next Action - Compras

## F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01 - Implementar criação persistente mínima de item

**Classe:** T2 - banco, autorização e escrita server-side  
**Estado:** READY  
**Objetivo:** materializar ADR-014 em uma boundary PostgreSQL/server-only para adicionar item a contratação existente, com capability dedicada, allocator técnico de ordinal por contratação, auditoria atômica e resultados sanitizados.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F34 fechou e verificou o desenho da criação mínima de item. O red-team removeu a necessidade de UPDATE na contratação pai: F35 deve serializar ordinais por uma tabela técnica de allocator, mantendo zero UPDATE de `contractings` para a nova capability.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário permanecem abertas. F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F35.

## Execução obrigatória

1. recuperar o estado canônico após F34 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-014 e `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`;
3. revalidar SECURITY, DATABASE, ADR-003/005/009/011/012/013 e precedentes F26/F29/F32;
4. manter migrations `0001..0006` byte-for-byte imutáveis;
5. criar `0007_contracting_item_create.sql` com tabela técnica de allocator, capability própria, RLS específica e primitive estreita;
6. manter F26 exclusiva de `next_action`, F29 exclusiva de criação de contratação e F32 exclusiva de mutação de `object`;
7. manter runtime normal sem DML direto e conceder somente `EXECUTE` da primitive F35 por provisioning separado;
8. garantir zero UPDATE em `contractings` para a capability F35;
9. criar adapter server-only que aceite somente `contractingId`, `description`, `quantity`, `unit` e `catalogCode`;
10. gerar item UUID e event UUID server-side e manter team, actor, membership, issuer, subject e ordinal fora da authority do browser;
11. transportar `quantity` como `string | null` até PostgreSQL `numeric`, sem `Number` ou `parseFloat`;
12. preservar `description`, `unit` e `catalogCode` exatamente, inclusive vazio/espaços conforme nullability física;
13. seguir autorização pilot-only por equipe alvo de F26/F32, sem copiar o guard global da F29;
14. somente após autorização, criar/bloquear a row do allocator da contratação;
15. revalidar autorização depois de adquirir o lock do allocator;
16. reconciliar `last_ordinal` com `MAX(ordinal)` real, incluindo itens retirados, e não reutilizar gaps;
17. criar item, avanço do allocator e evento `item_created` na mesma transação, com rollback integral se a auditoria falhar;
18. não alterar `contractings.updated_at`;
19. expor somente `created`, `not-available` e `unavailable` na boundary server-only;
20. provar em PostgreSQL 17 concorrência real de no mínimo 8 writers na mesma contratação, sem ordinal duplicado e sem retry cego;
21. provar que contratações diferentes usam rows de allocator distintas e não dependem de lock global;
22. executar preflight adversarial de role/capability, regressões Auth/RLS/F24/F26/F29/F32, lint, typecheck, testes e build;
23. criar workflow F35 dedicado e exigir todos os gates verdes antes da promoção;
24. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION` somente após validação completa.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- capability F35 não recebe UPDATE em `contractings`;
- migrations aplicadas não são reescritas;
- nenhuma regra de quantidade positiva, unidade obrigatória, catálogo obrigatório, trim, tamanho ou pesquisa de preços pode ser inventada;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md` seguindo ADR-014 e as fontes canônicas nela referenciadas.

## Critério de encerramento

F35 fecha quando a criação mínima de item estiver implementada e provada com capability dedicada, allocator técnico por contratação, autorização pilot-only, auditoria atômica, adapter server-only sanitizado e todas as regressões verdes, sem UI e sem ampliar as capabilities anteriores.