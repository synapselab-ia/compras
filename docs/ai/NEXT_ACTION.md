# Next Action - Compras

## F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item

**Classe:** T2 - banco, autorização e escrita server-side  
**Estado:** READY após promoção da F37  
**Objetivo:** implementar a boundary definida pela ADR-015 para editar somente `description`, `quantity`, `unit` e `catalog_code` de item ativo, com snapshot optimistic concurrency, auditoria escalar atômica, autorização target-team, semântica exata de texto/numeric e least privilege.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F37 fechou o desenho da primeira edição persistente de `contracting_items` sem implementar código operacional. ADR-015 definiu contrato, concorrência, autorização, capability, auditoria e resultados sanitizados. A próxima slice deve materializar exatamente essa decisão antes de qualquer integração de UI.

A correção concorrencial F29 foi integrada pela migration `0008_contracting_create_concurrency_repair.sql`. Portanto migrations `0001..0008` são histórico aplicado imutável e a implementação F38 começa em `0009`.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário permanecem abertas. F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F38.

## Execução obrigatória

1. recuperar `main` real após a promoção da F37 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-015 e `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`;
3. inspecionar ADR-013/014, migrations/provisioning/tests F32 e F35, `withTrustedDatabaseMutationContext` e read model protegido de itens;
4. manter migrations `0001..0008` byte-for-byte imutáveis;
5. criar `database/migrations/0009_contracting_item_mutation.sql` com capability dedicada equivalente a `compras_contracting_item_mutation_owner`;
6. manter owner `NOLOGIN`, `NOINHERIT`, não privilegiado, sem ownership de tabelas-base e sem membership utilizável;
7. criar primitive `SECURITY DEFINER` equivalente a `mutate_contracting_item_fields(...)`, com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
8. receber internamente `contractingId`, `itemId`, snapshot esperado dos quatro campos, snapshot novo dos quatro campos e quatro event UUIDs gerados server-side;
9. nunca aceitar team, actor, membership, issuer, subject, ordinal, retired state, timestamps ou event UUIDs como authority do browser/caller público;
10. usar `SELECT ... FOR UPDATE` somente na row do item e vincular `itemId` ao `contractingId` candidato;
11. exigir item não retired, parent ativo, membership corrente no team e exatamente uma membership não revogada no team;
12. revalidar parent/membership depois do lock e manter RLS como enforcement final;
13. comparar todos os quatro expected com o estado atual usando semântica null-safe;
14. avaliar `conflict` antes de `unchanged`;
15. atualizar somente `description`, `quantity`, `unit`, `catalog_code` e `updated_at`;
16. preservar `description`, `unit` e `catalog_code` exatamente, sem trim, normalização ou empty-to-NULL;
17. transportar `quantity` como `string | null` até PostgreSQL `numeric`, sem `Number` ou `parseFloat`;
18. inserir um evento `item_changed` por campo realmente alterado, com old/new escalares, `item_id` e mesmo `operation_at`;
19. gerar quatro event UUIDs no adapter server-only, mapeados fixamente aos quatro campos e nunca expostos como input público;
20. fazer falha de qualquer evento reverter update, timestamp e eventos anteriores da tentativa;
21. não alterar `contractings.updated_at`;
22. criar provisioning separado que conceda somente EXECUTE da primitive ao runtime explícito e seguro;
23. criar adapter `src/features/contracting-detail/persistent-item-mutation.ts` usando `withTrustedDatabaseMutationContext` e resultados sanitizados;
24. mapear somente `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` externamente;
25. garantir que `conflict`/`unchanged` só sejam observáveis após autorização;
26. provar por grants/postflight que a capability não pode criar/deletar/reorder/retire item, tocar allocator ou atualizar `contractings`;
27. provar que runtime normal continua sem DML direto e que Auth/read-only não recebem EXECUTE;
28. provar que F26/F29/F32/F35 não ganham authority F38 e que F38 não ganha authority dessas boundaries;
29. executar matriz PostgreSQL 17 da SPEC, incluindo 8 writers concorrentes com mesmo expected;
30. provar rollback quando o primeiro, um intermediário e o último evento falham;
31. executar lint, typecheck, testes, build, CI database/Auth, F22, F29, F32 e F35;
32. revisar integralmente diff, grants, policies e resultados antes de promover;
33. não implementar Server Action/UI na F38;
34. não incluir reorder, retire/restore, delete ou pesquisa de preços;
35. atualizar checkpoint somente depois de todos os gates e red-team ficarem verdes;
36. deixar exatamente uma nova NEXT_ACTION somente após a F38 estar integralmente verificada.

## Matriz adversarial mínima

A F38 deve provar pelo menos:

- cada campo isolado e os quatro campos juntos podem ser alterados por caller autorizado;
- N campos alterados geram exatamente N eventos;
- no-op não altera timestamp nem cria evento;
- stale expected em qualquer campo retorna `conflict` sem write;
- stale expected continua `conflict` mesmo quando new coincide com current;
- 8 writers concorrentes com mesmo expected resultam em exatamente um `updated` e os demais `conflict`;
- retry pós-sucesso não duplica evento;
- falha do primeiro, intermediário ou último evento reverte tudo;
- description vazio/espaços e unit/catalog `NULL`/vazio/espaços permanecem exatos;
- quantity `NULL`, zero, negativo, fração e alta precisão válida não passam por float JavaScript;
- numeric inválido produz somente `unavailable` e zero write;
- claims inválidos, identidade desconhecida/desabilitada, membership ausente/revogada e segundo membro negam;
- outra membership do mesmo usuário em outro team não bloqueia a equipe alvo por si só;
- cross-team, inexistente, parent mismatch, retired e parent inativo são externamente indistinguíveis;
- capability não possui authority além da ADR-015;
- runtime normal não possui DML direto;
- migrations `0001..0008` permanecem imutáveis.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F35 continua exclusiva da criação de item;
- migrations aplicadas `0001..0008` permanecem imutáveis;
- falha protegida nunca vira demo fallback nem expõe detalhe interno;
- F38 não implementa UI.

## Fonte da tarefa

Executar `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md` seguindo ADR-015 e os precedentes ADR-013/014, F32 e F35.

## Critério de encerramento

F38 fecha quando migration 0009, capability, RLS, primitive, provisioning, adapter server-only e matriz adversarial estiverem implementados e verificados em PostgreSQL 17, com snapshot concurrency, auditoria atômica, rollback, exact text/numeric semantics e least privilege provados, sem UI e com todos os gates verdes.
