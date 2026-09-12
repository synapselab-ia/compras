# Next Action — Compras

## F31-PERSISTENT-CONTRACTING-OBJECT-MUTATION-DESIGN-01 — Desenhar edição persistente do objeto

**Classe:** `T2 — fronteira de autorização e mutação persistente`  
**Estado:** READY  
**Objetivo:** decidir a menor boundary segura para editar exclusivamente `contractings.object`, mantendo autorização pilot-only, concorrência explícita, evento atômico, least privilege, RLS autoritativa e a semântica atual de `object` sem transformações inventadas.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F30 torna a criação mínima utilizável pela aplicação. O núcleo funcional inicial prevê cadastro e edição de contratação, mas `object` ainda não possui uma mutação própria. F26 é exclusiva de `next_action` e F29 é exclusiva de criação; ampliar qualquer uma por conveniência enfraqueceria o isolamento de authority já provado.

A próxima slice deve ser somente de desenho. Antes de qualquer nova migration ou UI, é necessário decidir payload, concorrência, evento, capability, resultados externos e autorização da edição de `object` sem resolver Q-009 silenciosamente.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F31.

## Execução obrigatória

1. recuperar o estado canônico após F30 e revalidar `CONTEXT_MANIFEST`;
2. inspecionar ADR-011, ADR-012, F25/F26/F27, F29/F30, SECURITY, DATABASE, migrations e testes de mutação existentes;
3. manter migrations aplicadas imutáveis;
4. definir a fronteira de confiança e o payload mínimo da edição de `object`;
5. definir concorrência otimista compatível com os padrões já aprovados;
6. preservar `object` exatamente, inclusive string vazia, sem trim, limite, regra non-empty ou coerção para `NULL` inventados;
7. manter autorização pilot-only sem transformar Q-009 em política multiusuário;
8. definir atualização de estado + evento histórico na mesma transação lógica;
9. definir capability própria/least privilege sem ampliar F26 ou F29;
10. definir resultados sanitizados para sucesso, conflito, negação e falha, sem oracle cross-team;
11. produzir nova ADR e matriz adversarial suficiente para a implementação posterior;
12. não implementar migration, SQL, adapter, Server Action ou UI nesta work unit;
13. revisar o diff documental, fazer red-team e deixar exatamente uma nova `NEXT_ACTION` somente se a decisão ficar fechada.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas salvo decisão explícita e necessária;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas permanecem imutáveis;
- F26 continua exclusiva de `next_action`;
- F29 continua exclusiva de criação mínima;
- browser não define identidade, escopo, actor ou membership confiável;
- erro protegido nunca vira demo fallback nem expõe detalhe interno.

## Fonte da tarefa

Executar `tasks/F31-PERSISTENT-CONTRACTING-OBJECT-MUTATION-DESIGN-01/SPEC.md` seguindo as fontes canônicas ali referenciadas.

## Critério de encerramento

F31 fecha quando existir uma ADR implementável para edição exclusiva de `object`, com payload mínimo, concorrência, autorização pilot-only, evento atômico, least privilege e semântica sanitizada definidos, sem alteração de código operacional nesta slice.
