# Next Action — Compras

## F30-PERSISTENT-CONTRACTING-CREATE-UI-01 — Tornar cadastro persistente mínimo utilizável

**Classe:** `T1 — feature normal` com impacto `T2 — fronteira de autorização`  
**Estado:** READY  
**Objetivo:** tornar a boundary F29 utilizável pela aplicação por uma jornada mínima de cadastro persistente, mantendo candidate UUID preparado server-side, payload restrito a `contractingId + object`, demo estritamente read-only e autorização/RLS autoritativas.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F29 materializou a ADR-012 em PostgreSQL 17 e código server-only: criação mínima, pilot-only, auditável, idempotente e sem DML direto no runtime. A aplicação ainda não expõe uma jornada de cadastro; a Central continua sem UI de criação persistente.

A próxima slice deve apenas conectar uma Server Action/UI estreita à boundary já implementada, sem ampliar payload, sem criar CRUD genérico e sem resolver Q-001/Q-002/Q-006/Q-009 por conveniência.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F30.

## Execução obrigatória

1. recuperar `main`, confirmar F29 integrada/verde e revalidar `CONTEXT_MANIFEST`;
2. inspecionar Central, `src/app/page.tsx`, boundary F27, `persistent-read-mode`, F29 adapter/testes, ADR-012, SECURITY e DATABASE;
3. não modificar migrations `0001..0005`;
4. apresentar entrada de cadastro somente quando `readPersistentReadMode() === "persistent"`;
5. manter demo e configuração inválida sem caminho de write persistente;
6. preparar candidate UUID no servidor com `preparePersistentContractingCandidateId()` antes da submissão;
7. criar Server Action específica que leia scalars uma única vez, rejeite duplicatas e encaminhe somente `{ contractingId, object }`;
8. ignorar/rejeitar campos forjados sem confiar team, actor, membership, created_by, issuer, subject, eventId, callback ou redirect;
9. chamar exclusivamente `createPersistentContracting`, sem SQL/DML direto e sem demo fallback;
10. preservar `object` exatamente, sem trim, limite, non-empty ou coerção para `NULL` inventados;
11. construir redirects somente com rotas locais fixas + candidate UUID validado;
12. mapear `created`, `already-created`, `not-available` e `unavailable` para navegação/feedback sanitizados;
13. manter UI mínima, sem controles de team/actor/membership/created_by/next_action/stage/status/responsável/waiting;
14. provar pending contra repetição acidental e matriz adversarial de payload/redirect/duplicate scalar/erro sensível;
15. executar lint, typecheck, testes, build, CI database/Auth, F22 Private Preview Preflight e F29 Contracting Create;
16. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0005` permanecem imutáveis;
- F29 é a única boundary de criação usada pela aplicação;
- browser não define identidade, escopo, actor, membership, creator ou event UUID;
- falha protegida nunca vira demo fallback;
- nenhuma mensagem interna, claim, connection string ou secret chega a UI/query string/log.

## Fonte da tarefa

Executar `tasks/F30-PERSISTENT-CONTRACTING-CREATE-UI-01/SPEC.md` seguindo ADR-012 e as fontes de segurança/banco ali referenciadas.

## Critério de encerramento

F30 fecha quando uma pessoa no modo persistente puder iniciar e concluir o cadastro mínimo pela boundary F29, com candidate UUID server-side, payload estrito `contractingId + object`, navegação/feedback sanitizados, demo read-only e todos os gates/adversariais verdes.
