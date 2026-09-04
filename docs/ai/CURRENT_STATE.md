# Current State — Compras

**PROJECT_STATUS:** F23_IMPLEMENTED_VERIFYING_F24_READY  
**CURRENT_PHASE:** F22 integrada/verde; F23 design implementado na branch e em verificação; F24 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_PERSISTENT_PREVIEW_BLOCKED_PRE_SECRETS  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_AND_FICTITIOUS_PREFLIGHT_EPHEMERAL_PASS  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_ABUSE_CONTROL_DESIGN_DECIDED_NOT_YET_IMPLEMENTED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_VERCEL_AUTH_OBSERVED_NO_F23_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_FINAL_CHECKPOINT_COMMIT:** `a1037b38269c2e67e0ec249ed597eb5171eb31d2`  
**F21_CHECKPOINT_MERGE_COMMIT:** `b38ad708a6f668b4886930a96eaff95a1251590a`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_PR:** `#38` — MERGED  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F22_MAIN_CI_RUN:** `33880974626` — PASS  
**F22_MAIN_PREFLIGHT_RUN:** `33880974672` — PASS  
**F23_BRANCH:** `f23-private-signin-abuse-control-design`  
**F23_STATE:** `IMPLEMENTED / VERIFYING`  
**LAST_GOOD_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**LAST_GOOD_CI_RUN:** `33880974626`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação da sessão F23

A sessão recuperou `main` em `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`, merge da PR F22 `#38`.

Os runs pós-merge que estavam pendentes no checkpoint anterior já terminaram:

- CI canônica `33880974626`: `completed / success`;
- F22 Private Preview Preflight `33880974672`: `completed / success`.

Portanto F22 está integrada e verde. O `LAST_GOOD_COMMIT` passa a ser `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`.

Não existia PR aberta nem branch F23 ativa. Foi criada `f23-private-signin-abuse-control-design` a partir do last-good.

## Contexto

O `CONTEXT_MANIFEST` foi revalidado diretamente contra `main`.

Todos os 10 inputs estáveis continuam exatamente nos blobs esperados:

- produto: `PROJECT_DESIGN`, `DOMAIN_MODEL`, `BUSINESS_WORKFLOW`, `OPEN_QUESTIONS` — MATCH;
- arquitetura: `ARCHITECTURE`, `SECURITY`, `DATABASE` — MATCH;
- qualidade: `DEFINITION_OF_DONE` — MATCH;
- operação: `SOURCE_OF_TRUTH`, `WORK_PROTOCOL` — MATCH.

`CONTEXT_STATUS = VALID`.

A única `NEXT_ACTION` recuperada foi `F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01`.

## F21 continua ON HOLD

A disponibilidade de ferramentas Vercel foi novamente inspecionada antes da decisão F23.

A superfície autenticada da sessão continua oferecendo leitura/deploy/logs/acesso a deployment protegido e pesquisa de documentação, mas não expõe CRUD/readback de sensitive Preview environment variables por branch nem a leitura completa de Deployment Protection/bypasses exigida pela F21.

Portanto o `resume_when` da F21 não foi presumido satisfeito e nenhum write hosted foi realizado.

## Inspeção F23

Foram lidos diretamente:

- `src/server/auth/private-admission.ts`;
- `src/server/auth/runtime.ts`;
- `src/server/auth/configuration.ts`;
- ADR-007;
- ADR-009;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- SPEC F23 e checkpoint vigente.

A implementação atual confirma:

- `signInExistingIdentity()` chama `configured.auth.api.signInEmail()` server-side;
- não existe limiter antes dessa chamada;
- a jornada normal mantém `disableSignUp=true`;
- `/api/auth/[...path]` continua fora do fluxo de admissão;
- sucesso só é persistido depois de readback da sessão/cookie;
- erro Auth indisponível e credencial rejeitada já possuem estados genéricos separados.

## Revalidação externa F23

Documentação oficial atual revalidada em 2026-09-04:

### Better Auth v1.6

`https://better-auth.com/docs/1.6/concepts/rate-limit`

Confirmado:

- requests server-side por `auth.api` **não** são afetadas pelo rate limiter embutido;
- storage padrão do limiter é em memória e não é apropriado como enforcement distribuído em muitos cenários serverless;
- Better Auth suporta database/secondary/custom storage para seu limiter HTTP, mas isso não muda o bypass das chamadas `auth.api` usadas pela aplicação.

Também foi revalidada a referência de segurança Better Auth v1.6.

### Vercel

Foram revalidadas as páginas oficiais de:

- request headers;
- Firewall/WAF rate limiting;
- CLI/API de Firewall;
- Vercel Authentication/Deployment Protection.

Confirmado:

- Vercel Firewall/WAF executa antes da aplicação e suporta rate limit por path/método/IP;
- `x-forwarded-for` é sobrescrito pela Vercel com o IP público do cliente para impedir spoofing, salvo quando uma configuração explícita de trusted proxy altera essa fronteira;
- regras WAF podem ser lidas/alteradas por control plane oficial e possuem rollback operacional;
- Vercel Authentication continua sendo a barreira externa do Preview existente.

## F23 — decisão arquitetural

A ADR-010 foi criada e aceita.

### Camadas

1. **Limiter application-side autoritativo:** PostgreSQL compartilhado, executado antes de `auth.api.signInEmail`.
2. **Vercel Firewall/WAF:** defesa edge obrigatória para exposição hosted mais ampla, reduzindo volume antes da Function, mas não substituindo o limiter application-side.

Limiter somente process-local/in-memory foi rejeitado.

Redis/KV dedicado foi comparado e rejeitado nesta etapa porque adicionaria provider/secret/dependência operacional sem necessidade; PostgreSQL já existe no desenho Auth, oferece atomicidade e é reproduzível integralmente em CI.

### Trusted source

Em hosted Vercel, `x-forwarded-for` só poderá ser usado quando:

- o runtime comprovar ambiente Vercel;
- existir exatamente um IP válido;
- não houver cadeia com vírgulas;
- o preflight hosted confirmar que a configuração de proxy preserva a fronteira esperada.

Ausência/ambiguidade -> limiter `unavailable` -> sign-in fail-closed.

Headers alternativos/browser-supplied não podem virar fallback confiável.

### Pseudonimização

Nenhum email/IP será armazenado em claro.

A implementação deve derivar chave do limiter a partir de `BETTER_AUTH_SECRET` com HKDF/HMAC e domain separation `compras/signin-limiter/v1`, evitando uma nova secret.

Buckets:

- `source` = HMAC(origem confiável);
- `identifier` = HMAC(email normalizado para bucket defensivo);
- `pair` = HMAC(origem + email normalizado).

Email continua input de credencial, não identidade/autorização confiável.

### Policy inicial versionada

| Bucket | Janela | Máximo |
|---|---:|---:|
| `source` | 15 min | 120 |
| `identifier` | 15 min | 20 |
| `pair` | 5 min | 8 |

As três reservas são atômicas e ocorrem antes do Better Auth, independentemente de conta existir ou senha estar correta.

Não existe bucket global bloqueante.

### Estados externos

- allow -> segue para Better Auth;
- limit exceeded -> `rejected`, igual a credencial inválida;
- limiter/store/config unavailable -> `unavailable`, sem chamar Better Auth;
- nenhum caminho cai para sign-in sem limiter ou para demo.

### Privacidade/observabilidade

Persistência do limiter fica restrita a digest pseudônimo, bucket/policy, contador e timestamps mínimos.

Proibido logar email, IP, digest individual, senha, cookie, token, connection string ou session payload.

Janela máxima de enforcement: 15 minutos. Retenção física alvo: <=24h após expiração, com purge oportunístico na F24 e requisito de cleanup periódico/readback antes de garantia formal de produção.

## Red-team F23

Resultado:

- limiter autoritativo somente em memória: REJEITADO;
- Better Auth catch-all reaberto para herdar limiter: REJEITADO;
- signup/OAuth/OTP/Admin reaberto: REJEITADO;
- IP arbitrário/browser header como única confiança: REJEITADO;
- somente IP como defesa completa: REJEITADO;
- somente email/global key como defesa: REJEITADO;
- falha do limiter permitindo auth: REJEITADO;
- raw email/IP/credential em logs/store: REJEITADO;
- Redis/KV/provider novo sem necessidade: REJEITADO;
- Vercel Authentication reduzida: REJEITADO;
- alteração de domínio/RLS: REJEITADO;
- hosted write em F23: NÃO.

Trade-off explícito mantido: um atacante distribuído pode causar throttling temporário de uma identidade específica ao consumir seu bucket. O desenho evita lockout global e usa janela curta + edge defense; métricas futuras podem justificar ajuste versionado dos limites.

## Artefatos F23

Criados:

- `docs/decisions/ADR-010-private-signin-abuse-control.md`;
- `tasks/F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01/SPEC.md`.

Atualizados:

- `docs/00-START-HERE.md`;
- `docs/ai/NEXT_ACTION.md`;
- este checkpoint.

Nenhum arquivo executável, migration aplicada ou configuração hosted foi alterado nesta work unit de design.

## Verificação aplicável

Como F23 é T0/design e não altera código executável, lint/typecheck/test/build não são exigidos antes do primeiro commit documental por mudança local. A PR ainda deve passar a CI normal do repositório antes de promoção/merge.

Verificações já concluídas:

- estado GitHub/main: RECUPERADO;
- F22 post-merge CI: PASS;
- F22 post-merge preflight: PASS;
- `CONTEXT_MANIFEST`: VALID;
- código/ADRs/SECURITY/DATABASE exigidos: INSPECIONADOS;
- documentação Better Auth/Vercel: REVALIDADA;
- F21 blocker: CONTINUA PRESENTE;
- threat model: COMPLETO;
- alternativas edge/PostgreSQL/Redis-KV: COMPARADAS;
- confiança de origem: DEFINIDA;
- policy/atomicidade/fail-closed: DEFINIDOS;
- privacidade/retenção/observabilidade: DEFINIDAS;
- red-team de design: PASS;
- hosted writes: NENHUM;
- dados/identidades reais: NENHUM.

## Próxima ação

Executar somente `F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01` conforme `docs/ai/NEXT_ACTION.md`, `tasks/F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01/SPEC.md` e ADR-010.

F21 permanece `ON HOLD` até seu `resume_when` externo ser objetivamente satisfeito.
