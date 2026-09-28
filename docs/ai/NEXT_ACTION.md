# Next Action - Compras

## F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01 - Integrar criação persistente de nota manual no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY após integração da F44  
**Objetivo:** tornar a boundary F44 utilizável no detalhe persistente por uma Server Action estreita e UI mínima, mantendo UUID preparado por intenção, retry técnico idempotente, semântica exata de `NULL`/texto, feedback sanitizado, readback protegido e demo read-only.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F44 integrou a primeira boundary persistente de nota manual na timeline com primitive, capability, RLS, provisioning, adapter e concorrência já provados.

O detalhe persistente já lê `contracting_events` pelo modelo protegido e apresenta atividade recente. O gap pequeno e independente agora é expor somente essa operação já aprovada no detalhe, sem criar nova authority de banco.

A frente é independente de F21, não exige provider hosted e não resolve Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 ou Q-010.

## Execução obrigatória

1. recuperar `main` real e confirmar F44 integrada pela PR `#71`, merge `55f887252cfd5e5e81596e7434e6d5cec906aced`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente ADR-017, resultado F44 e a SPEC F45;
4. confirmar migrations `0001..0011` byte-for-byte antes de editar;
5. inspecionar F42 como precedente principal de candidate UUID, Server Action, retry e feedback;
6. inspecionar página, action, componente, tipos e read model atuais do detalhe;
7. manter migration, grants, policies, capability, primitive e provisioning F44 imutáveis;
8. preparar `eventId` server-side antes da primeira submissão;
9. reutilizar o mesmo `eventId` somente em retry técnico `unavailable`;
10. criar Server Action dedicada que aceite somente `contractingId`, `eventId`, `noteKind` e `note`, além de campos internos `$ACTION_*`;
11. rejeitar scalars duplicados, campos extras e IDs malformados antes de F44;
12. decodificar `noteKind = null|text` sem normalizar o conteúdo;
13. chamar exclusivamente `createPersistentManualTimelineNote`, sem SQL/DML próprio;
14. não aceitar team, actor, membership, issuer, subject, event type, timestamps, field/old/new, item ou related identifier como authority;
15. manter navegação restrita à rota local fixa do detalhe;
16. mapear somente `created`, `already-added`, `not-available` e `unavailable`;
17. preservar candidate apenas para `unavailable`;
18. revalidar/readback após `created` ou `already-added`;
19. usar somente a timeline do read model protegido para confirmação;
20. renderizar UI somente no modo persistente;
21. manter demo e falha protegida sem caminho de write;
22. não adicionar edição/exclusão de evento, categoria, prioridade ou Pendência;
23. criar testes de action, feedback, candidate/retry, componente/página e demo;
24. executar lint, typecheck, testes, build e regressões F22/F29/F32/F35/F38/F41/F44;
25. fazer red-team integral de payload, authority, retry, opacidade, demo e navegação;
26. confirmar migrations `0001..0011` imutáveis;
27. promover somente depois dos gates aplicáveis verdes;
28. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser puder transformar `eventId` em scope ou authority;
- candidate for gerado no browser;
- retry técnico trocar o candidate e puder duplicar a intenção;
- Server Action executar SQL/DML próprio ou contornar F44;
- browser puder fornecer team, actor, membership, issuer, subject, event type ou timestamps como authority;
- browser puder controlar field/old/new/item/related identifier;
- `NULL`, vazio ou espaços forem normalizados sem regra canônica;
- surgir deduplicação por conteúdo da nota;
- demo ou configuração inválida puder gravar;
- falha protegida cair para fixtures/demo;
- callback ou redirect externo puder ser controlado pelo cliente;
- feedback revelar existência cross-team ou motivo protegido;
- migrations/grants/policies/capability/primitive/provisioning F44 forem alterados;
- UI permitir edição/exclusão de evento;
- categoria, prioridade ou Pendência forem inventadas;
- questão aberta for resolvida implicitamente;
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
- F44 continua sendo a única boundary de criação persistente de nota manual;
- migrations aplicadas `0001..0011` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01/SPEC.md`.

## Critério de encerramento

F45 fecha quando uma pessoa autorizada em modo persistente puder adicionar uma nota manual pelo detalhe usando exclusivamente F44, com `eventId` preparado no servidor e estável em retry técnico, transporte explícito de `NULL`/texto, payload sem authority controlada pelo browser, feedback sanitizado, readback protegido, demo read-only e todos os gates/adversariais verdes.
