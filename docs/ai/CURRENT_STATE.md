# Current State - Compras

**PROJECT_STATUS:** F30_INTEGRATED_F31_READY  
**CURRENT_PHASE:** F30 integrada em `main`; F31 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_BOUNDARY_AND_F30_CREATE_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_NARROW_NEXT_ACTION_MUTATION_AND_MINIMAL_CONTRACTING_CREATE_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F30_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_MERGE_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**F25_MERGE_COMMIT:** `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`  
**F26_MERGE_COMMIT:** `1e9e03eddeac9584ee6044a2393fe6b1e9a31726`  
**F27_MERGE_COMMIT:** `54b8fa88f06cdc0020333e16e4aa3ab31e8a6fcf`  
**F28_MERGE_COMMIT:** `04b3e063314180e683e76adbe7c9c5affd53e14f`  
**F29_MERGE_COMMIT:** `3781ec4eebc0b7618f865a83fcf1214ea13c4a71`  
**F30_PR:** `#46` - MERGED  
**F30_FUNCTIONAL_HEAD:** `38f7683bc5c3f7ab539a5764d3f1088dfd499f60`  
**F30_FINAL_PR_HEAD:** `fdad5471e535a4d2833ca42efd9091308114591d`  
**F30_PR_FINAL_CI_RUN:** `34700169464` - PASS  
**F30_PR_FINAL_F22_PREFLIGHT_RUN:** `34700169506` - PASS  
**F30_PR_FINAL_F29_CREATE_RUN:** `34700169547` - PASS  
**F30_MERGE_COMMIT:** `c0f6e822253e9e324f00bc674f4805f52cbca16c`  
**F30_MAIN_CI_RUN:** `34700243224` - PASS  
**F30_MAIN_F22_PREFLIGHT_RUN:** `34700243225` - PASS  
**F30_MAIN_F29_CREATE_RUN:** `34700243158` - PASS  
**LAST_GOOD_COMMIT:** `c0f6e822253e9e324f00bc674f4805f52cbca16c`  
**LAST_GOOD_CI_RUN:** `34700243224`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e promoção desta sessão

A sessão recuperou `main` em `baee340772c00283b19114411b7ecd13c770396b`, confirmou F29 integrada e verde, revalidou os 10 blobs do `CONTEXT_MANIFEST` e confirmou que não havia branch ou PR F30 ativa. A única `NEXT_ACTION` canônica era F30.

A implementação foi realizada na branch `f30-persistent-contracting-create-ui`, PR `#46`, sem provider hosted write, sem dado real e sem alteração das migrations aplicadas `0001..0005`.

O head final da PR `fdad5471e535a4d2833ca42efd9091308114591d` passou todos os gates obrigatórios antes do merge. A PR `#46` foi promovida por merge commit `c0f6e822253e9e324f00bc674f4805f52cbca16c`. Os três workflows pós-merge também passaram em `main`.

## F30 - jornada mínima de criação persistente integrada

F30 conecta a aplicação à boundary F29 sem criar nova autoridade de persistência.

### Entrada e modo

- a Central mostra `Cadastrar nova contratação` somente quando o view data está em modo `persistent`;
- acesso direto a `/contratacoes/nova` em `demo` ou configuração inválida falha fechado e não prepara candidate nem executa write;
- o formulário recebe candidate UUID opaco preparado server-side por `preparePersistentContractingCandidateId()`;
- somente `contractingId` e `object` são controles semânticos da submissão.

### Server Action e confiança

`src/features/contracting-create/actions.ts`:

- exige `readPersistentReadMode() === "persistent"`;
- lê cada scalar confiável uma única vez e rejeita duplicatas;
- valida o candidate UUID antes de qualquer chamada à F29;
- encaminha exclusivamente `{ contractingId, object }` a `createPersistentContracting`;
- ignora campos extras forjados e nunca confia team, actor, membership, creator, issuer, subject, eventId, callback ou redirect;
- não executa SQL/DML direto e não possui demo fallback;
- preserva `object` exatamente, inclusive string vazia;
- usa somente redirects locais fixos e estados públicos whitelisted.

### Idempotência e feedback

O red-team identificou antes da promoção que regenerar candidate após resultado técnico incerto enfraqueceria a proteção de retry da ADR-012. A implementação foi corrigida:

- `created` e `already-created` seguem para o detalhe do UUID validado;
- `not-available` e `unavailable` retornam ao formulário somente com estado sanitizado e o mesmo candidate UUID validado;
- a rota reutiliza o candidate apenas se ele for UUID válido; valor malformado é descartado e um novo candidate server-side é preparado;
- candidate continua sendo apenas idempotency key opaca e não authority;
- `useFormStatus` bloqueia repetição acidental enquanto a action está pendente.

Feedback de criação aceita apenas `created`, `already-created`, `not-available` e `unavailable`; texto arbitrário de query não é refletido na UI.

## Red-team e verificação F30

A revisão integral confirmou:

- migrations `0001..0005` intactas;
- nenhum novo DML, SQL direto ou grant;
- demo/invalid sem caminho de write;
- payload browser-to-boundary limitado a `contractingId + object`;
- campos de authority e redirects externos forjados não são encaminhados;
- duplicate scalar falha antes de F29;
- string vazia e espaços de `object` são preservados;
- mensagens internas não chegam a redirects/feedback;
- retry após falha sanitizada preserva o candidate validado;
- UI não introduz controles de team/actor/membership/created_by/next_action/stage/status/responsável/waiting;
- não há review thread aberta na PR de promoção.

Gates finais da PR no head `fdad5471e535a4d2833ca42efd9091308114591d`:

- CI `34700169464`: PASS;
- F22 Private Preview Preflight `34700169506`: PASS;
- F29 Contracting Create `34700169547`: PASS.

Pós-merge `c0f6e822253e9e324f00bc674f4805f52cbca16c`:

- CI `34700243224`: PASS, incluindo verify, database e auth-database;
- F22 Private Preview Preflight `34700243225`: PASS;
- F29 Contracting Create `34700243158`: PASS.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F31-PERSISTENT-CONTRACTING-OBJECT-MUTATION-DESIGN-01 - Desenhar edição persistente do objeto`.

F31 é exclusivamente de desenho. Deve produzir a decisão arquitetural da próxima mutação de `contractings.object`, com payload mínimo, concorrência explícita, evento atômico, least privilege, autorização pilot-only e resultados sanitizados, sem implementar migration, SQL, Server Action ou UI nessa work unit.

F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.
