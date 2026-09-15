# Next Action - Compras

## F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Finalizar desenho de criação persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** VERIFYING  
**Objetivo:** concluir a validação do desenho corrigido da ADR-014, após o red-team substituir o row lock da contratação pai por allocator técnico least-privilege, e somente então promover F35.

Esta é a única `NEXT_ACTION` canônica enquanto a F34 estiver em verificação.

## Estado da execução

ADR-014 e a SPEC F35 já existem. O primeiro desenho automatizava ordinal por `SELECT ... FOR UPDATE` na contratação pai, mas o red-team manual detectou que PostgreSQL exige privilégio `UPDATE` para locking clauses. Conceder esse privilégio a uma capability de item create ampliaria authority sobre `contractings` sem necessidade funcional.

O desenho foi corrigido para usar uma tabela técnica de allocator por contratação, com `last_ordinal`, RLS própria e lock somente nessa row técnica. A capability F35 terá zero UPDATE em `contractings`.

## Execução restante obrigatória

1. revisar o diff integral corrigido;
2. confirmar que migrations `0001..0006` permanecem byte-for-byte imutáveis;
3. confirmar que F26/F29/F32 não receberam authority adicional;
4. confirmar que o allocator só pode ser criado após autorização e que a primitive revalida autorização após adquirir seu lock;
5. confirmar que retired participa do maior ordinal e gaps não são reutilizados;
6. confirmar que falha de item/evento reverte também o allocator;
7. executar CI, F22 Private Preview Preflight, F29 Contracting Create e F32 Contracting Object Mutation no head corrigido;
8. se todos passarem, marcar F34 como `COMPLETED / PASS`;
9. atualizar checkpoint final e promover exatamente uma nova `NEXT_ACTION`: F35;
10. executar novamente os gates do checkpoint;
11. integrar PR #51 somente com todos os gates verdes e verificar os workflows em `main` após o merge.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente documentação/código fictício ou sanitizado;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- runtime normal continua sem DML direto;
- capability de item create não recebe UPDATE em `contractings`;
- migrations aplicadas não são reescritas;
- nenhuma regra de quantidade, unidade, catálogo ou pesquisa de preços é inventada;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

A decisão corrigida está em `docs/decisions/ADR-014-minimal-persistent-contracting-item-creation.md` e a implementação futura está especificada em `tasks/F35-PERSISTENT-CONTRACTING-ITEM-CREATE-IMPLEMENT-01/SPEC.md`.

## Critério de encerramento

F34 fecha somente após o desenho corrigido e o checkpoint final passarem os gates aplicáveis. Depois disso, F35 deve se tornar a única `NEXT_ACTION` canônica.