# Next Action — Compras

## F27-PERSISTENT-NEXT-ACTION-DETAIL-UI-01 — Integrar edição persistente de próxima ação no detalhe

**Classe:** `T1 — feature normal` com impacto `T2 — autorização/escrita server-side`  
**Estado:** READY  
**Objetivo:** tornar utilizável pela aplicação a única escrita aprovada em F26, permitindo editar somente `contractings.next_action` no detalhe persistente por Server Action estreita, sem abrir CRUD adicional nem alterar a autorização pilot-only.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F26 implementou e provou a fronteira de banco/aplicação da ADR-011, mas o detalhe persistente ainda é somente leitura. A Definition of Done exige uma jornada utilizável para a necessidade operacional prevista.

F27 deve ligar a interface já existente de detalhe à boundary F26 sem criar nova autoridade:

- modo demo continua sem write;
- modo persistente edita apenas `Próxima ação`;
- browser fornece somente ID candidato + expected observado + novo valor;
- actor, team, membership, issuer, subject e event UUID continuam derivados/gerados no servidor/banco;
- conflito não pode virar overwrite silencioso;
- cross-team/inexistente permanecem indistinguíveis externamente;
- falha protegida nunca cai para fixtures/demo.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F27.

## Execução obrigatória

1. recuperar o estado real de `main` e confirmar F26 integrada/verde;
2. validar o `CONTEXT_MANIFEST` e inspecionar o detalhe, view-data, Server Actions existentes e boundary F26;
3. criar Server Action dedicada somente a `next_action`;
4. aceitar apenas `contractingId`, `expectedNextAction` e `newNextAction` do form;
5. reutilizar `mutatePersistentContractingNextAction`; não emitir SQL/DML próprio na action;
6. manter demo estritamente read-only;
7. mapear `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` para feedback sanitizado;
8. revalidar/read-back o detalhe nos resultados apropriados;
9. implementar pending/feedback/acessibilidade básica sem editor genérico;
10. provar que campos forjados de actor/team/membership/event UUID não atravessam a boundary;
11. provar que conflito não sobrescreve e que cross-team/inexistente não criam side channel;
12. executar lint, typecheck, testes, build, CI PostgreSQL/Auth e F22 preflight;
13. fazer red-team integral e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-009 permanece aberta;
- autenticação não é autorização;
- RLS permanece autoritativa;
- F26 continua sendo a única primitive de escrita;
- runtime continua sem DML direto nas tabelas protegidas;
- nenhuma escrita de stage/status/responsável/aguardando;
- modo demo nunca executa write;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F27-PERSISTENT-NEXT-ACTION-DETAIL-UI-01/SPEC.md` seguindo ADR-003, ADR-009, ADR-011, `docs/architecture/SECURITY.md`, `docs/architecture/DATABASE.md` e a boundary F26 integrada.

## Critério de encerramento

F27 fecha quando uma pessoa autorizada consegue alterar somente `Próxima ação` pelo detalhe persistente, com semântica correta de sucesso/no-op/conflito/indisponibilidade, sem nova superfície de autoridade e com todos os gates de F26/RLS/Auth/F22 novamente em PASS.
