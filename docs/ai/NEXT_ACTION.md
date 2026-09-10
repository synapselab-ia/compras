# Next Action — Compras

## F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01 — Implementar primeira mutação persistente de próxima ação

**Classe:** `T1 — feature normal` com impacto `T2 — banco/segurança`  
**Estado:** READY  
**Objetivo:** implementar a ADR-011 como capability PostgreSQL estreita para alterar somente `contractings.next_action`, com autorização pilot-only, estado+evento atômicos, proteção contra lost update e runtime sem DML direto.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F25 fechou o desenho da primeira escrita persistente em ADR-011:

- `next_action` é o único campo de escrita desta primeira slice;
- a role runtime de domínio continuará sem `UPDATE`/`INSERT` direto;
- a escrita passa por primitive PostgreSQL específica `SECURITY DEFINER`, com owner técnico `NOLOGIN` não privilegiado e `search_path` fixo;
- identidade, actor, membership e team são derivados da sessão confiável + banco, nunca do browser;
- autorização é estritamente pilot-only: a identidade corrente precisa possuir a única membership não revogada da equipe alvo;
- uma segunda membership ativa bloqueia a escrita, preservando Q-009 aberta;
- update de `next_action`/`updated_at` e inserção de `contracting_events` são uma única unidade transacional;
- concorrência usa lock de linha + precondição otimista do valor anterior, evitando lost update;
- no-op não cria evento nem altera timestamp;
- UUID cross-team/inexistente não deve revelar existência de modo distinto.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F26.

## Execução obrigatória

1. recuperar estado/contexto e confirmar ADR-011/F25 integradas;
2. ler diretamente SECURITY, DATABASE, ADR-003/005/009/011, migrations, trusted-context e testes RLS;
3. criar migration nova do domínio, sem reescrever `0001..0003`;
4. criar/seal owner técnico da capability conforme ADR-005;
5. criar primitive específica de `next_action` com grants/policies mínimos sob RLS;
6. manter runtime sem DML direto e conceder somente `EXECUTE` na primitive;
7. implementar guard pilot-only de única membership ativa;
8. implementar lock + expected antigo null-safe e estado `conflict`;
9. atualizar `next_action` + `updated_at` e inserir evento atômico com actor/team derivados;
10. tratar no-op sem evento/timestamp novo;
11. criar adapter server-side de mutação que reutilize a fronteira segura de `trusted-context` e use `BEGIN` normal + contexto LOCAL `iss/sub`;
12. gerar `event_id` somente no servidor confiável;
13. não aceitar team/actor/membership do browser;
14. executar matriz PostgreSQL adversarial, incluindo concorrência real e rollback forçado do evento;
15. executar lint, typecheck, testes completos, build e preflight F22/F24;
16. revisar diff integral, promover somente após CI verde e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-009 permanece aberta;
- autenticação não é autorização;
- browser não fornece identidade, actor ou escopo confiáveis;
- RLS permanece autoritativa;
- runtime normal sem ownership/superuser/`BYPASSRLS`/`CREATEROLE`;
- runtime sem DML direto para a mutação;
- estado rastreável + evento são atômicos;
- `contracting_events` continua append-only;
- sem escrita de stage/status/responsável/aguardando nesta slice;
- migrations aplicadas permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01/SPEC.md` seguindo ADR-011, ADR-003, ADR-005, ADR-009, `docs/architecture/SECURITY.md` e `docs/architecture/DATABASE.md`.

## Critério de encerramento

F26 fecha quando a primeira mutação persistente de `next_action` estiver implementada e provada em PostgreSQL 17 descartável contra autorização, atomicidade, rollback e concorrência, mantendo runtime sem DML amplo, todas as regressões em PASS, nenhum hosted write e exatamente uma nova `NEXT_ACTION` canônica.
