# Next Action - Compras

## F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01 - Desenhar criação persistente de nota manual na timeline

**Classe:** T2 - desenho arquitetural de escrita/auditoria  
**Estado:** READY após integração da F42  
**Objetivo:** desenhar a primeira boundary persistente de criação de nota manual em `contracting_events`, com payload mínimo, authorization guard pilot-only, least privilege, semântica textual, idempotência/concorrência e resultados sanitizados definidos para implementação posterior.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F42 integrou a criação persistente de identificador relacionado ao detalhe e fechou o ciclo F40/F41/F42.

O núcleo funcional inicial ainda exige timeline útil e rastreável. O DOMAIN_MODEL prevê explicitamente `nota manual` como tipo de evento esperado e o DATABASE já registra que eventos de nota manual podem usar `note` sem `field_key`.

Essa frente é pequena, independente e não exige resolver as taxonomias de etapa/status, Q-003, pesquisa de preços ou política multiusuário. Edição/desvínculo de identificador relacionado continua fora do próximo passo porque sua semântica pode depender de Q-003.

## Execução obrigatória

1. recuperar o `main` real e confirmar F42 integrada pela PR `#67`, merge `53db535df7981f957674ca708bea7b30308992b3`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler `tasks/F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01/RESULT.md` e `tasks/F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01/SPEC.md`;
4. ler diretamente SECURITY e DATABASE porque F43 é T2;
5. inspecionar PROJECT_DESIGN, DOMAIN_MODEL e BUSINESS_WORKFLOW nos pontos de timeline/auditoria;
6. inspecionar schema físico, RLS e grants atuais de `contracting_events`;
7. inspecionar os shapes de eventos e guards de F26/F29/F32/F35/F38/F41;
8. confirmar migrations `0001..0010` byte-for-byte antes de qualquer alteração documental;
9. desenhar somente a criação de nota manual, sem mutar estado de contratação, item ou identificador;
10. definir payload server-only mínimo e todos os valores derivados por contexto confiável;
11. impedir que browser escolha team, actor, membership, issuer, subject, timestamps ou `event_type` arbitrário;
12. definir shape fechado do evento manual, incluindo nullability de `field_key`, old/new, item e related identifier;
13. definir semântica exata de `note` para `NULL`, vazio e espaços sem inventar non-empty, trim ou limite de negócio;
14. decidir e justificar estratégia de UUID/idempotência/replay;
15. definir autorização pilot-only sem resolver Q-009;
16. definir capability dedicada e grants máximos sem ampliar capabilities anteriores;
17. definir opacidade para inexistente, cross-team, inativo e falhas de membership;
18. definir concorrência, colisões e resultados externos sanitizados;
19. produzir ADR canônica e exatamente uma SPEC executável para a implementação seguinte;
20. executar red-team documental, CI/gates aplicáveis e confirmar migrations imutáveis;
21. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser puder escolher team, actor, membership, issuer, subject ou timestamps;
- browser puder definir `event_type`, `field_key`, old/new, item ou related identifier arbitrários;
- nota manual virar primitive genérica de evento;
- runtime normal receber INSERT direto em `contracting_events`;
- capability receber UPDATE/DELETE de eventos ou DML de contratação/item/identificador;
- F26/F29/F32/F35/F38/F41 ganharem authority adicional;
- cross-team, contratação inativa ou falha de membership produzir oracle protegido;
- semântica textual for normalizada por conveniência;
- taxonomia, categoria, prioridade ou entidade Pendência forem inventadas;
- falha protegida cair para demo;
- migrations `0001..0010` forem alteradas;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 ou Q-010 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público continua tratado como superfície permanente;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- questões abertas não são resolvidas silenciosamente;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0010` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01/SPEC.md`.

## Critério de encerramento

F43 fecha quando existir decisão canônica e red-teamed para criação persistente mínima de nota manual na timeline, com payload, authority, authorization guard, capability, semântica textual, idempotência/concorrência, resultados sanitizados e matriz adversarial definidos, além de exatamente uma SPEC de implementação seguinte pronta para execução, sem código operacional nesta slice.
