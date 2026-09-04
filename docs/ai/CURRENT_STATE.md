# Current State — Compras

**PROJECT_STATUS:** F23_INTEGRATED_F24_READY  
**CURRENT_PHASE:** F23 integrada em `main`; F24 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_PERSISTENT_PREVIEW_BLOCKED_PRE_SECRETS  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_AND_FICTITIOUS_PREFLIGHT_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_ABUSE_CONTROL_DESIGN_ACCEPTED_IMPLEMENTATION_PENDING_F24  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_VERCEL_AUTH_OBSERVED_NO_F23_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_FINAL_CHECKPOINT_COMMIT:** `a1037b38269c2e67e0ec249ed597eb5171eb31d2`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_PR:** `#39` — MERGED  
**F23_FINAL_PR_HEAD:** `b151c7bc0fb9d5c251df9c76c229f47855c81043`  
**F23_PR_CI_RUN:** `33907918844` — PASS  
**F23_PR_PREFLIGHT_RUN:** `33907918969` — PASS  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F23_MAIN_CI_RUN:** `33908077415` — PASS  
**F23_MAIN_PREFLIGHT_RUN:** `33908077522` — PASS  
**LAST_GOOD_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**LAST_GOOD_CI_RUN:** `33908077415`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Estado real recuperado e promovido

A sessão partiu da `main` `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`, já com F22 integrada.

Os runs pós-merge de F22 que estavam pendentes no checkpoint anterior foram recuperados e confirmados em PASS:

- CI `33880974626`;
- F22 Private Preview Preflight `33880974672`.

Não havia PR aberta. A única `NEXT_ACTION` canônica recuperada era `F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01`.

A branch `f23-private-signin-abuse-control-design` foi criada, a PR `#39` foi aberta, passou os gates, recebeu revisão integral do diff e foi integrada por merge em `52f398901de0360d7e6b31b880f08d02e999c97b`.

A CI de `main` após o merge também passou integralmente.

## Contexto

O `CONTEXT_MANIFEST` foi revalidado contra `main` antes da decisão F23.

Todos os 10 inputs estáveis permaneceram nos blobs canônicos esperados:

- produto: `PROJECT_DESIGN`, `DOMAIN_MODEL`, `BUSINESS_WORKFLOW`, `OPEN_QUESTIONS`;
- arquitetura: `ARCHITECTURE`, `SECURITY`, `DATABASE`;
- qualidade: `DEFINITION_OF_DONE`;
- operação: `SOURCE_OF_TRUTH`, `WORK_PROTOCOL`.

`CONTEXT_STATUS = VALID`.

## F21 permanece ON HOLD

A superfície Vercel autenticada disponível nesta sessão foi inspecionada novamente.

Ela continua oferecendo leitura/deploy/logs/acesso a deployment protegido e pesquisa de documentação, mas não expõe as operações necessárias para satisfazer o `resume_when` da F21:

1. readback completo de Deployment Protection/Vercel Authentication e bypasses relevantes;
2. CRUD/readback de sensitive Preview environment variables escopadas à branch;
3. prova operacional da cadeia protegida sem ampliar exposição.

Nenhum secret, banco, branch, environment variable, Firewall rule ou outro recurso hosted foi criado/alterado em F23.

## F23 — decisão integrada

A ADR-010 (`docs/decisions/ADR-010-private-signin-abuse-control.md`) foi aceita e integrada.

Decisão:

1. **PostgreSQL compartilhado** será o limiter application-side autoritativo antes de `auth.api.signInEmail`;
2. **Vercel Firewall/WAF** será defesa edge complementar antes de uma exposição hosted mais ampla;
3. limiter somente process-local/in-memory não é enforcement aceitável;
4. hosted source só poderá usar `x-forwarded-for` sob a fronteira Vercel validada, com exatamente um IP válido e sem forwarded chain;
5. email/IP não serão persistidos em claro;
6. buckets serão pseudonimizados com HKDF/HMAC e domain separation a partir de secret já server-only;
7. policy inicial versionada:
   - `source`: 120 / 15 min;
   - `identifier`: 20 / 15 min;
   - `pair`: 8 / 5 min;
8. os três buckets serão consumidos atomicamente antes do Better Auth;
9. limite excedido retorna o mesmo estado externo `rejected` de credencial inválida;
10. limiter/store/config indisponível retorna `unavailable` e não chama Better Auth;
11. não existe bucket global bloqueante;
12. observabilidade não registra email, IP, digest individual, senha, cookie, token, connection string ou payload de sessão.

Redis/KV dedicado foi comparado e rejeitado nesta fase por adicionar provider, credencial e dependência operacional sem necessidade. A implementação application-side pode ser integralmente provada com PostgreSQL 17 descartável.

## Revalidação externa F23

Documentação oficial vigente foi revalidada antes da decisão.

### Better Auth v1.6

Confirmado que chamadas server-side por `auth.api` não são afetadas pelo rate limiter HTTP embutido. O storage padrão em memória também não é enforcement distribuído adequado a múltiplas instâncias serverless.

As fontes oficiais estão registradas na ADR-010.

### Vercel

Confirmado pelas fontes oficiais:

- Firewall/WAF pode aplicar rate limit antes da aplicação;
- regras podem usar path/método/IP e possuem control plane/rollback;
- `x-forwarded-for` é normalmente sobrescrito pela Vercel com o IP público do cliente para prevenir spoofing, salvo configuração explícita de trusted proxy;
- Vercel Authentication permanece parte obrigatória da fronteira de Preview.

A prova hosted continua dependente de readback do provider; documentação não foi tratada como substituto desse gate.

## Red-team F23

Rejeitados:

- limiter autoritativo somente em memória;
- header arbitrário/browser-supplied como origem confiável;
- IP-only como defesa completa;
- email/global-only como chave bloqueante;
- fail-open quando limiter/store falha;
- reabertura de `/api/auth/[...path]`, signup, OAuth, OTP ou Admin;
- logging de email/IP/digest individual/credenciais;
- Redis/KV/provider novo sem necessidade;
- redução de Vercel Authentication;
- alteração de autorização/RLS de domínio;
- dado/identidade real;
- secret ou connection string persistida no repositório.

A revisão final da PR `#39` confirmou apenas seis arquivos de documentação/SPEC alterados, sem código executável ou migration.

O scan do diff final não encontrou `postgresql://`, URL hosted Vercel/Neon, control-plane ID ou credencial persistida.

## Verificação F23

PR `#39`:

- head final: `b151c7bc0fb9d5c251df9c76c229f47855c81043`;
- CI `33907918844`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `33907918969`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes completos: PASS;
- PostgreSQL/RLS/Auth: PASS;
- build Next.js: PASS.

Após promoção:

- merge commit: `52f398901de0360d7e6b31b880f08d02e999c97b`;
- main CI `33908077415`: PASS — `verify`, `database`, `auth-database`;
- main F22 Private Preview Preflight `33908077522`: PASS.

Nenhum provider hosted foi alterado e `REAL_DATA_ALLOWED` continua `NO`.

## Artefatos F23

Criados/integrados:

- `docs/decisions/ADR-010-private-signin-abuse-control.md`;
- `tasks/F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01/SPEC.md`.

Atualizados/integrados:

- `docs/00-START-HERE.md`;
- `docs/ai/NEXT_ACTION.md`;
- `tasks/F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01/SPEC.md`;
- este checkpoint.

## Próxima ação

Executar somente `F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01` conforme `docs/ai/NEXT_ACTION.md`, `tasks/F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01/SPEC.md` e ADR-010.

F21 permanece `ON HOLD` até seu `resume_when` externo ser objetivamente satisfeito.
