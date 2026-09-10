# Current State — Compras

**PROJECT_STATUS:** F25_VERIFIED_CHECKPOINTING_F26_READY  
**CURRENT_PHASE:** F25 design concluído na branch; PR/CI de promoção pendentes; F26 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_DISTRIBUTED_SIGNIN_LIMITER_INTEGRATED_DOMAIN_WRITE_DESIGN_ACCEPTED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_VALIDATED_FIRST_MUTATION_DESIGNED_NOT_IMPLEMENTED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F25_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_MERGE_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**F24_MAIN_CI_RUN:** `34479463372` — PASS  
**F24_MAIN_PREFLIGHT_RUN:** `34479463381` — PASS  
**LAST_GOOD_COMMIT:** `c60d6d50f3494e1b2ac557992f6f4057f5e8bcf3`  
**LAST_GOOD_CI_RUN:** `34479895944`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A `main` foi recuperada em `c60d6d50f3494e1b2ac557992f6f4057f5e8bcf3`.

Não havia PR F25 aberta nem branch F25 existente. A única `NEXT_ACTION` canônica era `F25-FIRST-PERSISTENT-MUTATION-DESIGN-01`; por isso foi criada a branch `f25-first-persistent-mutation-design` a partir do head real de `main`.

F24 já estava integrada. Os gates finais do checkpoint anterior em `main` estavam verdes:

- CI `34479895944`: PASS;
- F22 Private Preview Preflight `34479895945`: PASS.

## Contexto

O `CONTEXT_MANIFEST` foi revalidado antes de qualquer write.

Todos os 10 inputs estáveis coincidiram exatamente com os blobs esperados de produto, arquitetura, qualidade e protocolo. `CONTEXT_STATUS = VALID`.

A inspeção T5/T2 incluiu diretamente:

- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- `docs/product/OPEN_QUESTIONS.md`, especialmente Q-009;
- ADR-003, ADR-005 e ADR-009;
- migrations do domínio `0001..0003`;
- `src/server/database/trusted-context.ts` e testes;
- leitura persistente de detalhe e provas PostgreSQL/RLS existentes.

Foi confirmado no schema executável que `contractings.next_action`, `contractings.updated_at` e `contracting_events` já existem e que não há policy/grant normal de escrita.

## F25 — ADR-011 aceita

Criada `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`.

### Decisão principal

A primeira escrita persistente será exclusivamente `contractings.next_action` e usará uma **primitive PostgreSQL estreita `SECURITY DEFINER`**, em vez de DML direto pela role runtime.

A implementação F26 deverá manter a role runtime sem `UPDATE`/`INSERT` direto e conceder apenas `EXECUTE` na capability específica.

A função terá owner técnico `NOLOGIN`, não privilegiado, com lifecycle/selagem equivalente à propriedade de segurança da ADR-005, `search_path` fixo e grants mínimos.

### Identidade e autorização

A cadeia continua:

```text
sessão Better Auth validada no servidor
-> issuer + subject
-> contexto LOCAL da transação
-> app_user
-> membership ativa
-> capability de next_action
```

Browser não escolhe actor, `team_id`, membership, issuer ou subject confiáveis.

Q-009 continua aberta. A autorização da primeira escrita é deliberadamente **pilot-only**:

- o usuário corrente precisa possuir membership não revogada na equipe alvo;
- essa deve ser a única membership `revoked_at IS NULL` da equipe;
- se houver segunda membership ativa, a mutação falha fechada.

Uma membership não revogada conta para esse guard mesmo se seu usuário estiver desabilitado; isso evita liberar escrita com base em estado de membership inconsistente.

### Atomicidade e histórico

Mudança real deve, em uma única transação:

- atualizar `next_action`;
- atualizar `updated_at`;
- inserir exatamente um `contracting_events` com `event_type = 'next_action_changed'`, `field_key = 'next_action'`, valores old/new e actor/team/contracting derivados do banco;
- usar o mesmo instante de banco para `updated_at`, `occurred_at` e `created_at`.

Falha do evento reverte o update. Eventos continuam sem UPDATE/DELETE para runtime/capability.

No-op com valor idêntico não altera timestamp e não cria evento.

### Concorrência

A ADR escolheu:

- lock pessimista da contratação (`FOR UPDATE`);
- precondição otimista null-safe sobre o valor anterior de `next_action`.

Duas chamadas com o mesmo valor esperado não podem executar last-write-wins silencioso: a primeira vence e cria evento; a segunda observa precondição stale e retorna conflito sem update/evento.

Nenhuma coluna de versão é criada apenas para esta slice.

### Fail-closed / side channels

Inexistente, cross-team, identidade desconhecida/desabilitada, membership ausente/revogada, segundo membro ativo e contratação arquivada/cancelada não podem revelar existência por resultados distintos antes da autorização.

Falha de configuração/banco/contexto vira indisponibilidade; não existe fallback de escrita nem fallback para demo.

## Red-team F25

A decisão rejeitou explicitamente:

- actor/team/membership fornecidos pelo browser;
- membership como permissão multiusuário implícita;
- segundo membro ativo recebendo escrita por inferência;
- DML direto amplo para runtime;
- owner/superuser/`BYPASSRLS` como runtime normal;
- capability com ownership de tabelas-base ou membership utilizável privilegiada;
- `SECURITY DEFINER` com `search_path` controlável;
- estado sem evento ou evento sem estado;
- last-write-wins silencioso;
- no-op com evento falso;
- side channel de UUID cross-team;
- reescrita de migration aplicada;
- alteração de stage/status/responsável/aguardando;
- resolução global de Q-009;
- dependência de provider hosted;
- dado real.

## Artefatos F25

Criados:

- `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`;
- `tasks/F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01/SPEC.md`.

Atualizados:

- `tasks/F25-FIRST-PERSISTENT-MUTATION-DESIGN-01/SPEC.md`;
- `docs/ai/NEXT_ACTION.md`;
- este checkpoint;
- `docs/00-START-HERE.md` no fechamento da branch.

Nenhuma migration, Server Action, UI de escrita, secret, environment variable ou recurso hosted foi criado/alterado em F25. `REAL_DATA_ALLOWED = NO`.

## Próxima ação

Existe exatamente uma nova `NEXT_ACTION`: `F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01 — Implementar primeira mutação persistente de próxima ação`.

F26 deve implementar ADR-011 em PostgreSQL 17 descartável/CI, incluindo capability owner segura, grants mínimos, adapter de escrita, atomicidade estado+evento, conflito concorrente e red-team completo, sem provider hosted write.
