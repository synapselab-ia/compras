# Next Action - Compras

## F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01 - Implementar criação persistente de nota manual na timeline

**Classe:** T2 - banco/segurança  
**Estado:** READY após integração da F43  
**Objetivo:** implementar ADR-017 com capability persistente dedicada para criar o evento `manual_note_added`, com UUID preparado por intenção, replay exato, guard pilot-only, least privilege, concorrência e resultados sanitizados, sem UI ou Server Action nesta slice.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F43 integrou ADR-017 e fechou o desenho da primeira operação manual da timeline sem abrir uma primitive genérica de eventos.

O schema físico, a leitura protegida e a timeline já existem. O próximo gap pequeno e independente é materializar a boundary server/database antes de expor qualquer jornada de UI.

A frente é independente de F21, não exige provider hosted e não resolve Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 ou Q-010.

## Execução obrigatória

1. recuperar `main` real e confirmar F43 integrada pela PR `#69`, merge `adab76f1a02ca4602c917d812ceb1d5721ddbfd4`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente `docs/decisions/ADR-017-minimal-persistent-manual-timeline-note.md`;
4. executar `tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/SPEC.md`;
5. confirmar migrations `0001..0010` byte-for-byte antes de editar;
6. criar somente migration aditiva `0011` ou equivalente ordenável;
7. criar capability dedicada de manual timeline note create;
8. criar apenas policies/grants estreitos necessários à nova capability;
9. materializar primitive `SECURITY DEFINER` com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
10. manter runtime normal sem DML direto;
11. criar provisioning separado que conceda somente `EXECUTE` da primitive;
12. criar adapter server-only e helper server-only que prepare `eventId` estável por intenção;
13. preservar `note` exatamente, inclusive `NULL`, vazio e espaços;
14. fixar `event_type = 'manual_note_added'` fora da authority do caller;
15. manter field/old/new/item/related identifier nulos nesta operação;
16. implementar replay `already-added` somente após autorização atual e prova exata do evento canônico;
17. não deduplicar por conteúdo da nota;
18. garantir que a operação não atualize `contractings.updated_at`;
19. tratar concorrência de mesmo UUID sem retry cego ou overwrite;
20. manter cross-team, inexistente, inativo, membership inválida e colisão não equivalente sem oracle;
21. criar testes SQL adversariais e prova PostgreSQL concorrente real;
22. criar testes unitários do adapter e workflow F44;
23. executar gates e regressões F22/F29/F32/F35/F38/F41;
24. fazer red-team integral de grants, RLS, authority, replay e opacidade;
25. confirmar migrations `0001..0010` imutáveis;
26. promover somente depois dos gates aplicáveis verdes;
27. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser/caller puder definir team, actor, membership, issuer, subject ou timestamps como authority;
- caller puder definir `event_type`, field/old/new/item/related identifier arbitrários;
- `eventId` preparado conceder scope ou autorização;
- nota manual virar primitive genérica de evento;
- runtime normal ganhar INSERT/UPDATE/DELETE direto em `contracting_events`;
- capability puder UPDATE/DELETE eventos ou mutar contratação/item/identificador;
- F26/F29/F32/F35/F38/F41 ganharem authority adicional;
- target cross-team, arquivado ou cancelado aceitar nota;
- segundo membro não revogado for tratado como política multiusuário resolvida;
- `NULL`, vazio ou espaços forem normalizados sem fonte;
- existir deduplicação por texto da nota;
- replay aceitar payload divergente ou outro event type pela mesma PK;
- colisão cross-team virar oracle;
- `contractings.updated_at` for alterado apenas para representar timeline;
- migrations `0001..0010` forem reescritas;
- questão aberta for resolvida implicitamente;
- falha protegida cair para demo;
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
- falha protegida nunca vira demo fallback;
- F44 não inclui UI nem Server Action.

## Fonte da tarefa

Executar `tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/SPEC.md`.

## Critério de encerramento

F44 fecha quando a criação persistente mínima de nota manual estiver implementada e provada contra ADR-017, com um único evento canônico por intenção, idempotência segura por UUID preparado, replay exato, capability least-privilege, resultados sanitizados, concorrência real e regressões aplicáveis verdes, sem UI nesta slice.
