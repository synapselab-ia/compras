# Current State — Compras

**PROJECT_STATUS:** F24_VERIFIED_PR40_CHECKPOINTING_F25_READY  
**CURRENT_PHASE:** F24 implementada e verificada na PR `#40`; checkpoint/merge em andamento; F25 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_DISTRIBUTED_SIGNIN_LIMITER_IMPLEMENTED_PERSISTENT_PREVIEW_BLOCKED_PRE_SECRETS  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_AND_AUTH_GUARD_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_SIGNIN_LIMITER_APPLICATION_SIDE_VERIFIED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F24_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_FINAL_CHECKPOINT_COMMIT:** `a1037b38269c2e67e0ec249ed597eb5171eb31d2`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_PR:** `#40` — OPEN / VERIFIED, checkpointing  
**F24_FUNCTIONAL_HEAD:** `3291a62f57b350edf8b882ec08cc2655ed54d99d`  
**F24_FUNCTIONAL_CI_RUN:** `34476876653` — PASS  
**F24_FUNCTIONAL_PREFLIGHT_RUN:** `34476876664` — PASS  
**LAST_GOOD_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**LAST_GOOD_CI_RUN:** `33908077415`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A `main` foi recuperada em `79bd5564d423ff84cf64998a2d61591a3398cf4f`. A PR `#40` permaneceu aberta e mergeable, com branch ativa `f24-private-signin-abuse-control-implement` e head funcional `3291a62f57b350edf8b882ec08cc2655ed54d99d`.

A única `NEXT_ACTION` canônica recuperada ainda era F24, portanto a sessão retomou a frente em construção em vez de abrir nova implementação paralela.

## Contexto

`CONTEXT_MANIFEST` foi revalidado contra a mesma `main` antes de novos writes.

Todos os 10 inputs estáveis coincidiram exatamente com os blobs esperados:

- `PROJECT_DESIGN.md` → `9f28a371e04ecdce8f2689a6c06b00beeaa25859`;
- `DOMAIN_MODEL.md` → `13d7352cffb68273a26d142bee1165557d7eb864`;
- `BUSINESS_WORKFLOW.md` → `f8fc35aaf8cdd5334591c2402921e6776afd2f4b`;
- `OPEN_QUESTIONS.md` → `145ef9fe301d5c35ad9455d04be5740dbba36a13`;
- `ARCHITECTURE.md` → `a7544848c1eefcc54ec4537d3951e6b3559619d7`;
- `SECURITY.md` → `4c601c35585db74d62d1a8ae83cd3c996ae71630`;
- `DATABASE.md` → `8ab1478030152d58932577e1566fd34ff3a33b6a`;
- `DEFINITION_OF_DONE.md` → `cd0e3d1f01333c418d4fb622940f908df2b87a57`;
- `SOURCE_OF_TRUTH.md` → `61aac1f38a93e2bd50ba60adc699e78826b9f8fa`;
- `WORK_PROTOCOL.md` → `d76159c1687110607338d49767594d4fdfcc1aba`.

`CONTEXT_STATUS = VALID`.

## F24 — implementação verificada

A ADR-010 foi materializada na camada application-side, sem provider hosted write.

### Banco / enforcement

Nova migration versionada:

- `database/auth/migrations/0003_signin_abuse_limiter.sql`.

Ela cria namespace isolado `auth_guard`, tabela de buckets pseudônimos, índice de expiração e primitive `SECURITY DEFINER` com `search_path` fixo.

A role `compras_auth_runtime` recebe somente `USAGE` no schema e `EXECUTE` no primitive. O runtime continua sem ownership, superuser, `BYPASSRLS`, `CREATEDB`, `CREATEROLE`, replication ou DML direto na tabela do limiter.

Policy fixa/versionada:

- `source`: 120 tentativas / 15 min;
- `identifier`: 20 / 15 min;
- `pair`: 8 / 5 min.

Os três buckets são consumidos na mesma chamada transacional com relógio PostgreSQL. O purge oportunístico remove no máximo 16 expirados por chamada usando índice e `SKIP LOCKED`.

### Aplicação

`src/server/auth/signin-limiter.ts`:

- valida runtime Vercel hosted;
- aceita somente `x-forwarded-for` com um único IP válido;
- canonicaliza IPv6 para impedir buckets diferentes para endereços equivalentes;
- normaliza email apenas para bucket defensivo;
- deriva HMACs com HKDF/domain separation a partir de `BETTER_AUTH_SECRET`;
- nunca retorna/loga email/IP em claro;
- converte falhas de configuração/store em `unavailable`.

`private-admission.ts` agora chama o limiter antes de `auth.api.signInEmail`:

- limite excedido → `rejected`;
- limiter/config/store indisponível → `unavailable`;
- Better Auth não é chamado nesses dois caminhos;
- cookie/session readback existente permanece inalterado após `allowed`.

Signup normal e `/api/auth/[...path]` continuam fechados.

## Red-team F24

A revisão integral da PR rejeitou/validou deliberadamente:

- limiter process-local/in-memory;
- header alternativo como origem confiável;
- forwarded chain/hostname/origem não hosted;
- persistência de email/IP em claro;
- mesma representação IPv6 produzindo buckets distintos — corrigido por canonicalização;
- limite controlável por caller/env permissiva;
- runtime com `BYPASSRLS` — migration falha fechada e CI prova;
- DML direto do runtime na tabela do limiter;
- acesso do runtime de domínio ao limiter;
- acesso Auth ao domínio;
- race/lost update em burst concorrente;
- Better Auth chamado após limiter `rejected`/`unavailable`;
- signup/catch-all reabertos;
- alteração de migration aplicada;
- provider hosted write;
- dado/identidade real.

Um teste inicial que esperava detectar whitespace já normalizado pelo objeto `Headers` foi corrigido para testar entradas semanticamente observáveis sem fingir uma garantia inexistente.

## Verificação F24

Head funcional `3291a62f57b350edf8b882ec08cc2655ed54d99d`:

- CI `34476876653`: PASS;
  - `verify`: lint, typecheck, testes completos e build — PASS;
  - `database`: fundação/RLS/diretório/detalhe persistente — PASS;
  - `auth-database`: red-team de roles, Better Auth e limiter PostgreSQL — PASS;
- F22 Private Preview Preflight `34476876664`: PASS.

A suíte PostgreSQL F24 prova:

- thresholds exatos 120/20/8;
- janela nova volta a permitir;
- buckets independentes não se contaminam;
- burst concorrente de 32 tentativas no mesmo `pair` produz exatamente 8 `allowed` e 24 `rejected`, com contador 32;
- purge de expirados preserva bucket ativo;
- falta de `EXECUTE`/input inválido vira `unavailable`;
- runtime Auth e domínio continuam isolados.

A integração Better Auth prova limiter `allowed` antes de sign-in real fictício, sessão e sign-out.

## F21 permanece ON HOLD

Nenhuma condição de `resume_when` foi fabricada ou relaxada. F24 não criou nem alterou recurso Vercel, Neon, Redis/KV, secret ou environment variable hosted.

## Próxima ação

Executar somente `F25-FIRST-PERSISTENT-MUTATION-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F25-FIRST-PERSISTENT-MUTATION-DESIGN-01/SPEC.md` depois da promoção final da F24.

F25 é design-only e deve fechar a fronteira da primeira escrita persistente de `next_action` sem resolver Q-009 por inferência.