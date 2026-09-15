# F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01 - Desenhar edição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** READY  
**Dependências:** F31/F32/F33, ADR-014, F35/F36, fundação `contracting_items`, SECURITY, DATABASE e modelo de domínio  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Objetivo

Desenhar, sem implementar, a próxima boundary persistente mínima para editar campos já existentes de um item ativo de contratação, preservando o modelo default-deny, a autoridade derivada no servidor/banco, a auditoria e a semântica exata dos dados.

A F37 deve produzir uma decisão arquitetural explícita e a SPEC da implementação seguinte. Não deve criar migration, primitive, grant, policy, adapter, Server Action ou UI operacional.

## Escopo obrigatório

1. recuperar o estado canônico após F36 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-013, ADR-014 e os precedentes F31/F32/F33/F34/F35/F36;
3. inspecionar o schema físico de `contracting_items`, o read model protegido e os eventos existentes;
4. definir o payload mínimo para selecionar o item e representar alteração de `description`, `quantity`, `unit` e `catalog_code` sem permitir authority de team/actor/membership/issuer/subject pelo browser;
5. definir como preservar `NULL`, string vazia, espaços e `numeric` sem `Number`, `parseFloat`, trim ou normalização silenciosa;
6. definir optimistic concurrency suficiente para impedir lost update sem transformar ordinal, `retired_at` ou timestamps em authority do cliente;
7. decidir o contrato de auditoria atômica para alteração de item, incluindo evento, valores esperados/anteriores/novos e timestamp, sem vazar detalhe protegido;
8. definir capability/primitive próprias e least privilege, sem ampliar F26, F29, F32 ou F35;
9. manter runtime normal sem DML direto e derivar team/actor/autorização no banco a partir do contexto confiável;
10. manter o guard pilot-only enquanto Q-009 estiver aberta, salvo decisão canônica posterior explícita;
11. definir resultados externos sanitizados e indistinguíveis para inexistente/cross-team/negado;
12. fazer red-team de concorrência, forged payload, cross-team, retired item, contratação arquivada/cancelada, segundo membro, replay acidental, evento falho e numeric inválido;
13. registrar a decisão em ADR nova e produzir exatamente uma SPEC de implementação subsequente;
14. revisar o diff documental, executar os gates aplicáveis e atualizar o checkpoint somente após verde.

## Fora de escopo

- implementar migration ou código operacional;
- criar Server Action ou UI;
- editar ou alocar `ordinal`;
- reorder de itens;
- retirar/restaurar item por `retired_at`;
- excluir item;
- criar regra de preço, pesquisa de preços ou faixa de +/-25%;
- inventar required, positividade, unidade obrigatória, catálogo obrigatório, precisão/escala de negócio ou tamanho máximo;
- resolver Q-004 ou Q-009 por inferência;
- alterar migrations já aplicadas `0001..0007`;
- provider hosted, secrets ou dados reais.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F35 continua sendo a única boundary de criação de item;
- F36 continua sendo somente a UI/Server Action da criação;
- migrations aplicadas não são reescritas;
- falha protegida nunca vira demo fallback nem expõe detalhe interno;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas salvo decisão canônica explícita.

## Artefatos esperados

- ADR nova para edição persistente mínima de item;
- SPEC única da implementação correspondente, prevista como F38;
- atualização de `CURRENT_STATE` e `NEXT_ACTION` ao encerrar a F37.

## Critério de encerramento

F37 fecha somente quando existir um desenho defensável para edição mínima de item que estabeleça payload, concorrência, autorização, capability, auditoria, semântica de `NULL`/texto/numeric, resultados sanitizados e red-team, sem implementação operacional e sem ampliar escopo para reorder, retire ou pesquisa de preços.