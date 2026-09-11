# Next Action — Compras

## F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01 — Implementar boundary de criação persistente mínima

**Classe:** `T1 — feature normal` com impacto `T2 — autorização/banco`  
**Estado:** READY  
**Objetivo:** materializar a ADR-012 em PostgreSQL 17 descartável e código server-only, implementando criação mínima, pilot-only, auditável e idempotente de `contractings` sem abrir CRUD amplo e sem Server Action/UI de cadastro nesta slice.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F28 fechou por ADR a fronteira da primeira criação persistente: payload mínimo, derivação de team/actor/created_by, capability própria, evento inicial atômico e idempotência por UUID preparado server-side.

A decisão preserva Q-001/Q-002/Q-006/Q-009 abertas e mantém F26/F27 como únicas escritas executáveis integradas até a implementação da nova boundary.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F29.

## Execução obrigatória

1. recuperar `main`, confirmar F28 integrada/verde e revalidar `CONTEXT_MANIFEST`;
2. inspecionar ADR-012, ADR-003/005/009/011, SECURITY, DATABASE, migrations `0001..0004`, F26 e testes adversariais;
3. criar `database/migrations/0005_contracting_create.sql` sem reescrever migrations aplicadas;
4. criar capability técnica própria e selada para criação, mantendo runtime normal sem DML direto;
5. implementar primitive específica com `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
6. aceitar na boundary apenas candidate UUID + `object`; team/actor/membership/issuer/subject/created_by não são argumentos confiáveis;
7. aplicar guard pilot-only: exatamente uma membership não revogada do usuário, team derivado não arquivado e exatamente uma membership não revogada no team;
8. criar row mínima com campos não aprovados `NULL` e sem tornar o criador responsável automaticamente;
9. criar exatamente um evento `contracting_created` na mesma transação e com o mesmo instante de banco;
10. implementar replay idempotente e double-submit concorrente pelo candidate UUID, sem deduplicação por conteúdo;
11. criar provisionamento separado que conceda somente `EXECUTE` à role runtime segura;
12. criar interface server-only que gera event UUID, preserva `object` exatamente, sanitiza estados e não possui demo fallback;
13. provar matriz adversarial em PostgreSQL 17, incluindo corrida de pelo menos 8 writers, rollback de evento, isolation de F26/Auth/read-only e absence de DML direto;
14. executar lint, typecheck, testes, build, CI database/Auth e F22 Private Preview Preflight;
15. revisar diff integral, fazer red-team e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS permanece autoritativa;
- runtime normal continua sem CRUD amplo;
- F26 não recebe novos grants de criação;
- capability de criação não recebe authority de update de `next_action` por conveniência;
- migrations `0001..0004` permanecem imutáveis;
- Server Action/UI de cadastro ficam fora da F29;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F29-PERSISTENT-CONTRACTING-CREATE-IMPLEMENT-01/SPEC.md` seguindo `docs/decisions/ADR-012-minimal-persistent-contracting-creation.md` e as fontes de segurança/banco ali referenciadas.

## Critério de encerramento

F29 fecha quando a boundary ADR-012 estiver implementada e provada em PostgreSQL 17 real contra autorização, least privilege, atomicidade, rollback e idempotência concorrente, com regressões F22/F26/Auth verdes e exatamente uma nova `NEXT_ACTION` para tornar o cadastro utilizável pela aplicação.
