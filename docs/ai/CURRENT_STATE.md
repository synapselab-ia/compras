# Current State — Compras

**PROJECT_STATUS:** F25_INTEGRATED_F26_READY  
**CURRENT_PHASE:** F25 integrada em `main`; F26 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_DISTRIBUTED_SIGNIN_LIMITER_INTEGRATED_FIRST_DOMAIN_WRITE_DESIGNED  
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
**F25_PR:** `#41` — MERGED  
**F25_FINAL_PR_HEAD:** `eb9d816af9217f1342a05f0d391792c5fd6abaed`  
**F25_PR_CI_RUN:** `34501334860` — PASS  
**F25_PR_PREFLIGHT_RUN:** `34501334789` — PASS  
**F25_MERGE_COMMIT:** `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`  
**F25_MAIN_CI_RUN:** `34501521020` — PASS  
**F25_MAIN_PREFLIGHT_RUN:** `34501521011` — PASS  
**LAST_GOOD_COMMIT:** `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`  
**LAST_GOOD_CI_RUN:** `34501521020`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A sessão recuperou `main` em `c60d6d50f3494e1b2ac557992f6f4057f5e8bcf3`.

Não havia PR/branch F25 ativa. A única `NEXT_ACTION` canônica era `F25-FIRST-PERSISTENT-MUTATION-DESIGN-01`, então foi criada `f25-first-persistent-mutation-design` sobre o head real de `main`.

F24 já estava integrada e os gates finais anteriores estavam verdes:

- CI `34479895944`: PASS;
- F22 Private Preview Preflight `34479895945`: PASS.

## Contexto

O `CONTEXT_MANIFEST` foi revalidado antes de qualquer write. Todos os 10 inputs estáveis coincidiram exatamente com os blobs esperados; `CONTEXT_STATUS = VALID`.

A inspeção T5/T2 incluiu diretamente:

- `SECURITY.md` e `DATABASE.md`;
- `OPEN_QUESTIONS.md`, em especial Q-009;
- ADR-003, ADR-005 e ADR-009;
- migrations do domínio `0001..0003`;
- `src/server/database/trusted-context.ts` e testes;
- leitura persistente de detalhe e provas PostgreSQL/RLS.

Foi confirmado no schema executável que `contractings.next_action`, `contractings.updated_at` e `contracting_events` já existem e que não há fronteira normal de escrita implementada.

## F25 — ADR-011 integrada

Criada e aceita `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`.

### Primitive estreita

A primeira escrita persistente será somente `contractings.next_action`.

Foi escolhida uma primitive PostgreSQL específica `SECURITY DEFINER` em vez de DML direto pela role runtime. A implementação F26 deverá manter o runtime sem `UPDATE`/`INSERT` direto e conceder somente `EXECUTE` na capability.

O owner da função será técnico `NOLOGIN`, não privilegiado, com lifecycle/selagem seguindo ADR-005, sem ownership de tabelas-base e com `search_path` fixo.

### Identidade e autorização pilot-only

A cadeia continua:

```text
sessão Better Auth validada no servidor
-> issuer + subject
-> contexto LOCAL da transação
-> app_user
-> membership
-> capability next_action
```

Browser não escolhe actor, `team_id`, membership, issuer ou subject confiáveis.

Q-009 permanece aberta. A escrita só é autorizada quando a identidade atual possui membership não revogada na equipe alvo e ela é a única membership `revoked_at IS NULL` do escopo.

Se houver segunda membership ativa, a capability falha fechada. Uma membership não revogada conta para o guard mesmo se o usuário correspondente estiver desabilitado, evitando liberação por estado operacional inconsistente.

### Atomicidade e histórico

Mudança real deve, na mesma transação:

- atualizar `next_action`;
- atualizar `updated_at`;
- inserir exatamente um `contracting_events` com `event_type = 'next_action_changed'`, `field_key = 'next_action'`, old/new e actor/team/contracting derivados do banco;
- usar o mesmo instante de banco para estado e evento.

Falha do evento reverte o update. Eventos continuam append-only. No-op não altera timestamp e não cria evento.

### Concorrência

A ADR combina lock pessimista `FOR UPDATE` com precondição otimista null-safe do valor anterior de `next_action`.

Duas chamadas concorrentes com o mesmo expected não podem produzir last-write-wins silencioso: uma vence; a outra retorna `conflict` sem update/evento. Nenhuma coluna de versão foi adicionada apenas para esta slice.

### Fail-closed e side channels

Inexistente, cross-team, identidade desconhecida/desabilitada, membership ausente/revogada, segundo membro ativo e contratação arquivada/cancelada não recebem escrita nem devem revelar existência por resultado distinto antes da autorização.

Falha de configuração/banco/contexto vira `unavailable`; não existe fallback de escrita nem fallback para demo.

## Red-team F25

A revisão integral rejeitou:

- actor/team/membership enviados pelo browser como confiáveis;
- membership como permissão multiusuário implícita;
- segundo membro ativo herdando escrita;
- DML direto amplo para runtime;
- owner/superuser/`BYPASSRLS` como runtime normal;
- capability com ownership de tabelas-base ou membership privilegiada utilizável;
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

O diff final da PR continha somente seis arquivos de documentação/SPEC. Nenhuma migration, Server Action, UI ou código executável de escrita foi adicionado em F25.

## Verificação e promoção

PR `#41`, head `eb9d816af9217f1342a05f0d391792c5fd6abaed`:

- CI `34501334860`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `34501334789`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- PostgreSQL/RLS/Auth existentes: PASS.

Promoção:

- merge commit: `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`;
- main CI `34501521020`: PASS;
- main F22 Private Preview Preflight `34501521011`: PASS.

Nenhum provider hosted, secret ou environment variable foi alterado. Nenhum dado/identidade real foi usado. `REAL_DATA_ALLOWED = NO`.

## Artefatos F25

Criados/integrados:

- `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`;
- `tasks/F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01/SPEC.md`.

Atualizados/integrados:

- `docs/00-START-HERE.md`;
- `docs/ai/NEXT_ACTION.md`;
- `tasks/F25-FIRST-PERSISTENT-MUTATION-DESIGN-01/SPEC.md`;
- este checkpoint.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01 — Implementar primeira mutação persistente de próxima ação`.

F26 deverá materializar ADR-011 em PostgreSQL 17 descartável/CI, com capability owner segura, grants mínimos, adapter server-side de escrita, guard pilot-only, estado+evento atômicos, concorrência adversarial e regressão integral, sem provider hosted write.

F21 permanece `ON HOLD` até seu `resume_when` externo ser objetivamente satisfeito.
