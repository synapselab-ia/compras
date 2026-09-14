# Next Action - Compras

## F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** READY  
**Objetivo:** definir a próxima boundary persistente para adicionar um item a uma contratação existente, sem inventar regras de quantidade/unidade/pesquisa, com least privilege, autorização pilot-only, atribuição concorrente de ordinal e auditoria atômica.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F33 integrou a edição persistente de `contractings.object` no detalhe sem ampliar a camada PostgreSQL. O núcleo inicial já possui criação de contratação, edição de objeto e próxima ação, enquanto `contracting_items` existe desde a fundação e itens fazem parte do núcleo funcional previsto.

Antes de implementar write de item, é necessário fechar decisões que não devem ser improvisadas na implementação, especialmente payload mínimo, UUIDs server-side, autorização por equipe alvo, concorrência de `ordinal`, capability dedicada e evento atômico.

Q-004 sobre pesquisa de preços e Q-009 sobre política multiusuário permanecem abertas e não são dependências a serem resolvidas por F34.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F34.

## Execução obrigatória

1. recuperar o estado canônico após F33 e revalidar `CONTEXT_MANIFEST`;
2. ler `PROJECT_DESIGN`, `DOMAIN_MODEL`, `BUSINESS_WORKFLOW`, `OPEN_QUESTIONS`, SECURITY, DATABASE e `tasks/F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01/SPEC.md`;
3. inspecionar `0001_core_foundation.sql`, especialmente `contracting_items` e `contracting_events`, sem alterar migrations aplicadas;
4. inspecionar F26/F29/F32 e ADR-011/012/013 como precedentes de capability, autorização e auditoria;
5. definir payload mínimo sem criar validações de negócio não suportadas pelas fontes;
6. manter team, actor, membership, issuer, subject, item UUID, event UUID e scope fora da authority do browser;
7. decidir geração server-side dos UUIDs necessários;
8. decidir atribuição de `ordinal` no banco com comportamento concorrente explícito e testável em PostgreSQL 17;
9. manter autorização pilot-only ancorada na contratação/equipe alvo, sem copiar automaticamente o guard global da criação F29;
10. decidir capability própria ou alternativa formalmente justificada, preservando runtime sem DML direto;
11. definir criação do item e evento automático na mesma transação, com rollback se a auditoria falhar;
12. definir resultados externos sanitizados e sem oracle entre cross-team, inexistente e outras negações;
13. desenhar matriz adversarial e de concorrência para a implementação seguinte;
14. produzir ADR-014 e uma SPEC de implementação F35 se a arquitetura ficar fechada;
15. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION` somente após os gates documentais verdes.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F26 continua exclusiva de `next_action`;
- F29 continua exclusiva de criação mínima de contratação;
- F32 continua exclusiva de mutação de `object`;
- migrations aplicadas `0001..0006` permanecem imutáveis;
- nenhuma regra de quantidade, unidade, catálogo ou pesquisa de preços pode ser inventada nesta slice;
- falha protegida nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01/SPEC.md` seguindo as fontes canônicas nela referenciadas.

## Critério de encerramento

F34 fecha quando a criação mínima de item estiver arquiteturalmente definida quanto a payload, autorização, ordinal concorrente, capability, atomicidade/auditoria e resultados sanitizados, com ADR e matriz futura de implementação completas, sem código operacional ou migration nesta slice.