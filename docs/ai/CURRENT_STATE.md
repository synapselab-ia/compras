# Current State — Compras

**PROJECT_STATUS:** F21_ON_HOLD_VERCEL_CONTROL_PLANE_F22_READY  
**CURRENT_PHASE:** F21 checkpoint integrado; F21 ON HOLD antes de secrets; F22 READY; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_IMPLEMENTED_PERSISTENT_PREVIEW_BLOCKED_PRE_SECRETS  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_VERSIONED_EPHEMERAL_PASS_NO_F21_HOSTED_DB  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_IMPLEMENTED_CI_PROVEN_HOSTED_PREVIEW_PENDING  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_VERCEL_AUTH_OBSERVED_NO_NEW_F21_DEPLOYMENT  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F20_MERGE_COMMIT:** `a5313463b3ccf7f7d3b229ca0ab8798f586cafcc`  
**F20_PR:** `#36` — MERGED  
**F20_FINAL_CHECKPOINT_COMMIT:** `a1037b38269c2e67e0ec249ed597eb5171eb31d2`  
**F20_FINAL_CHECKPOINT_CI_RUN:** `33871918152` — PASS  
**F21_CHECKPOINT_PR:** `#37` — MERGED  
**F21_CHECKPOINT_MERGE_COMMIT:** `b38ad708a6f668b4886930a96eaff95a1251590a`  
**F21_PR_CI_RUN:** `33873199115` — PASS  
**F21_MAIN_CI_RUN:** `33873312591` — PASS  
**LAST_GOOD_COMMIT:** `b38ad708a6f668b4886930a96eaff95a1251590a`  
**LAST_GOOD_CI_RUN:** `33873312591`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Estado real recuperado

A F21 partiu da `main` `a1037b38269c2e67e0ec249ed597eb5171eb31d2`, cuja CI `33871918152` estava integralmente em PASS.

Não existia branch F21 ativa. A frente foi criada em `f21-private-preview-self-hosted-provision`, executada e integrada em `main` pela PR `#37`.

O merge/checkpoint F21 é `b38ad708a6f668b4886930a96eaff95a1251590a`. A CI da PR `33873199115` e a CI de `main` `33873312591` passaram integralmente em `verify`, `database` e `auth-database`.

O `CONTEXT_MANIFEST` foi revalidado. Todos os 10 inputs estáveis continuaram exatamente nos blobs esperados; portanto `CONTEXT_STATUS = VALID`.

A tarefa executada foi a única `NEXT_ACTION` então canônica: `F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01`.

## F21 — recuperação de providers

### Vercel

O projeto vinculado ao repositório e já usado na faixa F18 continua existindo.

Estado observado:

- deployment mais recente da aplicação: `READY`;
- target: Preview, não Production;
- nenhuma implantação nova apareceu após a criação da branch F21, confirmando que Git auto-deploy não voltou a ampliar a superfície;
- o acesso ao Preview pela superfície autenticada do conector retornou redirecionamento para a barreira de autenticação Vercel;
- não foi observado deployment Production `READY` correspondente à aplicação privada.

Isso preserva a barreira externa F18/F21 antes de qualquer secret novo.

### Neon

A organização Neon foi recuperada. Não existe projeto dedicado a Compras.

Os projetos existentes pertencem a outras frentes e não foram reutilizados. Nenhum projeto, branch, database, role, identidade ou secret Neon foi criado ou alterado durante F21.

## Revalidação externa F21

### Vercel

A documentação oficial atual confirmou que o provider suporta:

- Deployment Protection/Vercel Authentication;
- environment variables sensíveis;
- variáveis Preview escopadas por branch Git;
- inspeção/alteração de Deployment Protection pelo control plane/CLI/API.

Entretanto, a superfície Vercel autenticada disponível nesta sessão não expõe operações para:

- ler/read-back o estado completo de Deployment Protection e bypasses;
- criar/atualizar/listar metadados/remover environment variables sensíveis de Preview por branch.

A capability existe no provider, mas não está disponível no conector/control plane acessível pela sessão.

### Neon / PostgreSQL

A documentação Neon atual confirmou novamente:

- branches são isoladas e apropriadas para ambientes temporários;
- roles criadas por Console/CLI/API recebem membership em `neon_superuser`, incompatível com runtime normal deste projeto;
- roles limitadas podem/devem ser criadas por SQL e receber grants explícitos.

Isso continua compatível com F20/ADR-005/ADR-009 e não reabre Managed Neon Auth.

## Decisão F21 — ON HOLD fail-closed

F21 não pode prosseguir para a etapa de secrets sem conseguir aplicar e ler de volta os controles Vercel obrigatórios.

Os gates que faltam são precisamente os que impedem:

- secret em escopo maior que a branch dedicada;
- bypass/exception não verificado;
- ativação persistente sem proteção demonstrada.

Provisionar PostgreSQL hospedado antes de saber que a cadeia Vercel pode ser finalizada produziria recurso e credenciais sem caminho seguro de integração. Portanto a execução parou **antes** de criar banco/roles/secrets hosted.

Isso é um blocker de superfície de controle da sessão, não uma decisão para relaxar a arquitetura.

### resume_when

Retomar F21 somente quando a sessão possuir superfície Vercel autenticada capaz de:

1. ler/read-back Deployment Protection/Vercel Authentication e bypasses relevantes;
2. criar, atualizar, listar metadados e remover sensitive environment variables de Preview escopadas à branch F21;
3. inspecionar/disparar o Preview sem criar Production pública por conveniência.

Secrets nunca devem ser transferidos por chat para contornar esse blocker.

## Red-team F21

Resultado deliberado:

- Preview anônimo sem barreira externa: NÃO observado; proteção Vercel continua presente;
- Production `READY` pública criada por F21: NÃO;
- novo deployment automático após branch F21: NÃO;
- secret/connection string persistido em GitHub: NÃO;
- secret anexado à Vercel sem readback de escopo: NÃO;
- projeto/branch Neon criado prematuramente: NÃO;
- projeto Neon de outra frente reutilizado: NÃO;
- role control-plane privilegiada adotada como runtime: NÃO;
- Managed Neon Auth reintroduzido: NÃO;
- proteção externa removida para contornar blocker: NÃO;
- dado/identidade real: NÃO.

A revisão integral do diff público da PR `#37` também procurou connection strings, URLs hosted, IDs de control plane e secrets; nenhum desses valores foi persistido.

O red-team rejeitou um falso PASS e preservou a fronteira aprovada.

## Rollback / residual F21

Não houve write de infraestrutura hosted em F21.

Consequentemente:

- nenhum secret F21 precisa ser revogado;
- nenhum recurso PostgreSQL F21 precisa ser removido;
- nenhuma identidade/sessão F21 existe para invalidar;
- o Preview F18 preexistente continua privado/fictício e inalterado.

## F20 preservada

A implementação integrada continua válida:

- Better Auth self-hosted `1.6.23` pinado;
- `disableSignUp=true`;
- `/api/auth/[...path]` deny-all;
- sign-in/sign-out por Server Actions estreitas;
- sessão e subject validados server-side;
- issuer `urn:compras:better-auth:self-hosted:v1`;
- schema Auth separado;
- Auth runtime e domínio runtime separados;
- migrations Auth versionadas;
- bootstrap one-shot restrito a `example.invalid`;
- RLS e isolamento Auth/domínio provados em CI.

## Verificação F21

- GitHub/main inicial: RECUPERADO;
- `CONTEXT_MANIFEST`: VALID;
- documentação oficial Vercel/Neon: REVALIDADA;
- estado real Vercel/Neon: RECUPERADO antes de writes;
- barreira Vercel do Preview existente: OBSERVADA;
- novo deployment F21 automático: AUSENTE;
- hosted secrets F21: NENHUM;
- recurso PostgreSQL F21: NENHUM;
- dados/identidades reais: NENHUM;
- revisão do diff público: PASS;
- CI PR `33873199115`: PASS;
- CI `main` `33873312591`: PASS.

## Last good

O last-good canônico passa a ser o checkpoint F21 integrado `b38ad708a6f668b4886930a96eaff95a1251590a`, validado pela CI de `main` `33873312591`.

Esse checkpoint registra corretamente um blocker externo; ele não representa preview persistente operacional. `REAL_DATA_ALLOWED` continua `NO`.

## Próxima ação

Executar somente `F22-PRIVATE-PREVIEW-SEED-SMOKE-ASSETS-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F22-PRIVATE-PREVIEW-SEED-SMOKE-ASSETS-01/SPEC.md`.

F21 permanece `ON HOLD` e só volta a ser frente ativa quando seu `resume_when` for objetivamente satisfeito.
