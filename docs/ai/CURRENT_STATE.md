# Current State — Compras

**PROJECT_STATUS:** F24_INTEGRATED_F25_READY  
**CURRENT_PHASE:** F24 integrada em `main`; F25 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_DISTRIBUTED_SIGNIN_LIMITER_IMPLEMENTED_PERSISTENT_PREVIEW_BLOCKED_PRE_SECRETS  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_AND_AUTH_GUARD_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_SIGNIN_LIMITER_APPLICATION_SIDE_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F24_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_FINAL_CHECKPOINT_COMMIT:** `a1037b38269c2e67e0ec249ed597eb5171eb31d2`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_PR:** `#40` — MERGED  
**F24_FINAL_PR_HEAD:** `fbd5be5bec0d0b916c4b16a0a9bf8988c18ced02`  
**F24_PR_CI_RUN:** `34479092121` — PASS  
**F24_PR_PREFLIGHT_RUN:** `34479092184` — PASS  
**F24_MERGE_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**F24_MAIN_CI_RUN:** `34479463372` — PASS  
**F24_MAIN_PREFLIGHT_RUN:** `34479463381` — PASS  
**LAST_GOOD_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**LAST_GOOD_CI_RUN:** `34479463372`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou a `main` em `79bd5564d423ff84cf64998a2d61591a3398cf4f` e localizou a frente ativa na PR `#40`, branch `f24-private-signin-abuse-control-implement`, em vez de abrir trabalho paralelo.

O `CONTEXT_MANIFEST` foi revalidado contra `main` antes dos writes. Todos os 10 inputs estáveis coincidiram exatamente com os blobs esperados; `CONTEXT_STATUS = VALID`.

A única `NEXT_ACTION` recuperada era F24. A work unit foi concluída, red-teamed, verificada e promovida.

## F24 — limiter distribuído integrado

A F24 materializou a camada application-side da ADR-010 sem provider hosted write.

### Enforcement PostgreSQL

A migration `database/auth/migrations/0003_signin_abuse_limiter.sql` cria o namespace isolado `auth_guard`, tabela de buckets pseudônimos, índice de expiração e primitive `SECURITY DEFINER` com `search_path` fixo.

A role `compras_auth_runtime` permanece `LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION`, sem ownership ou DML direto na tabela do limiter. Ela recebe somente `USAGE` no schema e `EXECUTE` no primitive.

Policy versionada:

- `source`: 120 tentativas / 15 min;
- `identifier`: 20 / 15 min;
- `pair`: 8 / 5 min.

Os três buckets são consumidos atomicamente com relógio PostgreSQL. O purge oportunístico é limitado a 16 expirados por chamada e usa índice + `SKIP LOCKED`.

### Aplicação

`src/server/auth/signin-limiter.ts`:

- aceita origem hosted somente com runtime Vercel explícito;
- usa apenas `x-forwarded-for` com exatamente um IP válido;
- rejeita chain, hostname, tokens múltiplos e ambiente não hosted;
- canonicaliza IPv6 para evitar evasão por representação textual equivalente;
- deriva buckets opacos via HKDF/HMAC com domain separation a partir de `BETTER_AUTH_SECRET`;
- não persiste/loga email ou IP em claro;
- converte falha de configuração/store em `unavailable`.

`private-admission.ts` chama o limiter antes de `auth.api.signInEmail`:

- limite excedido → `rejected` sem Better Auth;
- limiter/config/store indisponível → `unavailable` sem Better Auth;
- `allowed` → segue o fluxo já validado de sign-in, cookie e readback da sessão.

Signup normal e `/api/auth/[...path]` continuam fechados. Autenticação continua separada de autorização de domínio/RLS.

## Red-team F24

Foram verificados e rejeitados:

- limiter somente process-local/in-memory;
- header alternativo/browser-supplied como origem confiável;
- forwarded chain/hostname/origem não hosted;
- persistência de email/IP em claro;
- buckets distintos para IPv6 equivalente — corrigido com canonicalização;
- limites fornecidos pelo caller/env permissiva;
- runtime com ownership, DML amplo ou `BYPASSRLS`;
- acesso do domínio ao limiter/Auth ou do Auth ao domínio;
- lost update/race acima do limite;
- Better Auth executado após `rejected`/`unavailable`;
- reabertura de signup/catch-all;
- reescrita de migration aplicada;
- provider hosted write;
- dado ou identidade real.

Também foi corrigido um teste que assumia preservar whitespace original já normalizado pelo objeto `Headers`; a prova final testa somente condições semanticamente observáveis.

## Verificação e promoção

Head funcional `3291a62f57b350edf8b882ec08cc2655ed54d99d` passou CI `34476876653` e F22 Private Preview Preflight `34476876664`.

Checkpoint final da PR em `fbd5be5bec0d0b916c4b16a0a9bf8988c18ced02` passou:

- CI `34479092121`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `34479092184`: PASS.

A PR `#40` foi integrada por merge em `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`.

Pós-merge em `main`:

- CI `34479463372`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `34479463381`: PASS.

O teste concorrente F24 executa 32 chamadas sobre o mesmo `pair` e prova exatamente 8 `allowed`, 24 `rejected` e contador persistido 32, sem lost update.

Nenhum recurso Vercel/Neon/Redis/KV, secret ou environment variable hosted foi criado ou alterado. `REAL_DATA_ALLOWED = NO`.

## F21 permanece ON HOLD

Nenhuma condição do `resume_when` foi fabricada ou relaxada. F21 continua fora da frente ativa até existir superfície Vercel autenticada com readback completo de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch sem exposição dos valores.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica: `F25-FIRST-PERSISTENT-MUTATION-DESIGN-01 — Definir a primeira mutação persistente rastreável`.

F25 é design-only. Deve definir por ADR a primeira escrita persistente de `contractings.next_action`, preservando autorização pilot-only sem inferir Q-009, atomicidade estado + `contracting_events`, concorrência e fail-closed.