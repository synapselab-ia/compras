# Next Action - Compras

## F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01 - Desenhar edição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** READY  
**Objetivo:** definir, sem implementar, a boundary persistente mínima para editar campos existentes de um item ativo, com optimistic concurrency, autorização derivada, auditoria atômica, semântica exata de texto/numeric e least privilege.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F36 integrou a criação mínima de item ao detalhe persistente usando exclusivamente a boundary F35, sem ampliar PostgreSQL authority. O fluxo já permite criar e reler itens protegidos. A próxima slice coerente é desenhar a primeira mutação de item existente antes de qualquer implementação operacional.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário permanecem abertas. F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F37.

## Execução obrigatória

1. recuperar o estado canônico após F36 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-013, ADR-014 e `tasks/F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01/SPEC.md`;
3. inspecionar F31/F32/F33 e F34/F35/F36 como precedentes de design, capability, concorrência, adapter e UI;
4. inspecionar o schema físico de `contracting_items`, read model protegido e eventos existentes;
5. definir payload mínimo para selecionar item e editar apenas `description`, `quantity`, `unit` e `catalog_code`, sem team/actor/membership/issuer/subject como authority do browser;
6. preservar `NULL`, string vazia, espaços e `numeric` sem trim, normalização ou conversão JavaScript indevida;
7. definir optimistic concurrency que impeça lost update e não conceda authority sobre `ordinal`, `retired_at` ou timestamps;
8. definir auditoria atômica e resultados externos sanitizados, sem oracle cross-team/inexistente;
9. desenhar capability/primitive próprias com least privilege, sem ampliar F26/F29/F32/F35 e sem DML direto no runtime normal;
10. manter guard pilot-only enquanto Q-009 permanecer aberta;
11. fazer red-team de forged payload, cross-team, item retirado, contratação arquivada/cancelada, concorrência, segundo membro, evento falho, replay acidental e numeric inválido;
12. não implementar migration, primitive, adapter, Server Action ou UI na F37;
13. não incluir reorder, retire/restore, delete de item nem pesquisa de preços;
14. produzir uma ADR nova e exatamente uma SPEC de implementação subsequente;
15. revisar o diff documental, executar os gates aplicáveis e atualizar o checkpoint somente após verde.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F35 continua sendo a única boundary de criação de item;
- migrations aplicadas `0001..0007` permanecem imutáveis durante a F37;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01/SPEC.md` seguindo ADR-013, ADR-014 e os precedentes F31 a F36.

## Critério de encerramento

F37 fecha quando existir desenho arquitetural explícito e red-teamed para edição mínima de item, com payload, concorrência, autorização, capability, auditoria, semântica exata e resultados sanitizados definidos, sem implementação operacional e com uma única SPEC de implementação subsequente.