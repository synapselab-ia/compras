# Next Action - Compras

## F49-PERSISTENT-WAITING-STATE-MUTATION-DESIGN-01 - Desenhar edição persistente do estado de espera

**Classe:** T2 - design de boundary de escrita e auditoria  
**Estado:** READY após integração da F48  
**Objetivo:** desenhar a futura mutation persistente do conjunto `waiting_type`, `waiting_reference`, `waiting_since` e `waiting_reason`, preservando optimistic concurrency, nullabilidade, timestamp confiável, auditoria atômica e least privilege, sem definir taxonomias finais e sem resolver silenciosamente Q-002 ou Q-009.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F48 tornou o responsável interno editável com a authority F47 preservada.

A regra operacional central ainda exige responder com quem ou onde a ação está pendente, desde quando e por qual motivo. Esses campos já existem no schema e no read model, mas permanecem somente leitura.

Etapa e status definitivos continuam bloqueados pelas taxonomias abertas Q-001/Q-002. O estado de espera pode ser estudado como conjunto técnico atual sem inventar catálogo, desde que o desenho não transforme seus textos abertos em taxonomia definitiva.

## Execução obrigatória

1. recuperar `main` real e confirmar F48 integrada pela PR `#81`, merge `bc0704297c2326e6eea6dca91c16b0c5b1ec3ce7`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler `tasks/F48-PERSISTENT-RESPONSIBLE-MUTATION-DETAIL-UI-01/RESULT.md`;
4. ler PROJECT_DESIGN, BUSINESS_WORKFLOW e Q-001/Q-002/Q-006/Q-009;
5. inspecionar schema/migrations `0001..0012` e read model atual;
6. usar F26, F32 e F47 como precedentes de optimistic concurrency, atomicidade e least privilege;
7. definir a unidade de snapshot expected para os quatro campos de espera;
8. definir semântica segura de `waiting_since`, sem timestamp técnico controlado pelo browser;
9. definir transporte nullable e preservação de texto sem normalização inventada;
10. definir ordem de `denied/conflict/unchanged/updated`;
11. definir evento(s) atômico(s) compatível(is) com o modelo atual;
12. definir capability e primitive futuras com authority mínima;
13. manter target-team pilot-only enquanto Q-009 estiver aberta;
14. não definir enum, catálogo ou transição de etapa/status/waiting;
15. produzir ADR-019 e SPEC F50, sem código de produção;
16. fazer red-team documental;
17. executar CI e gates aplicáveis;
18. confirmar migrations `0001..0012` imutáveis;
19. atualizar checkpoint e deixar exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- taxonomia final de etapa, status ou waiting for inventada;
- Q-002, Q-006 ou Q-009 for resolvida implicitamente;
- browser puder controlar timestamp técnico, team, actor, user, issuer ou subject;
- update parcial puder gerar estado misto sem regra explícita;
- stale write puder virar last-write-wins;
- waiting value virar authority;
- runtime receber DML direto;
- capability futura ganhar UPDATE genérico de `contractings`;
- evento não for atômico ou puder ser alterado;
- migration aplicada for reescrita;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0012` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar:

`tasks/F49-PERSISTENT-WAITING-STATE-MUTATION-DESIGN-01/SPEC.md`.

## Critério de encerramento

F49 fecha quando existir uma ADR defensável e uma SPEC F50 executável para mutation do estado de espera atual, com concorrência, nullabilidade, timestamp, autorização, auditoria e least privilege definidos, sem implementar produção e sem resolver silenciosamente taxonomias ou permissões abertas.
