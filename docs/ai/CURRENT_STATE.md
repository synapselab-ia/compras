# Current State — Compras

**PROJECT_STATUS:** F26_INTEGRATED_F27_IMPLEMENTED_PR_F28_READY  
**CURRENT_PHASE:** F27 implementada e verificada na PR #43; F28 READY; F21 ON HOLD; F17 ON HOLD histórico  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_AND_FIRST_PERSISTENT_NEXT_ACTION_UI_IMPLEMENTED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_NARROW_NEXT_ACTION_MUTATION_VALIDATED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F27_HOSTED_WRITES  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F22_MERGE_COMMIT:** `1ea7b1abb47e81af318872ee5e4c683607b3e2a3`  
**F23_MERGE_COMMIT:** `52f398901de0360d7e6b31b880f08d02e999c97b`  
**F24_MERGE_COMMIT:** `8c4afd1b242781f7e0ef499ab7d879ce1adf635d`  
**F25_MERGE_COMMIT:** `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`  
**F26_PR:** `#42` — MERGED  
**F26_FINAL_PR_HEAD:** `c33e7f3b5d33369c64e158903a85c6eb235de957`  
**F26_PR_CI_RUN:** `34611506543` — PASS  
**F26_PR_PREFLIGHT_RUN:** `34611506565` — PASS  
**F26_MERGE_COMMIT:** `1e9e03eddeac9584ee6044a2393fe6b1e9a31726`  
**F26_MAIN_CI_RUN:** `34611660963` — PASS  
**F26_MAIN_PREFLIGHT_RUN:** `34611660927` — PASS  
**F27_PR:** `#43` — OPEN  
**F27_FUNCTIONAL_VERIFIED_HEAD:** `96eae1dfa3a6105e87f80b2b103c509b897c4db6`  
**F27_FUNCTIONAL_CI_RUN:** `34613166500` — PASS  
**F27_FUNCTIONAL_PREFLIGHT_RUN:** `34613166498` — PASS  
**LAST_GOOD_COMMIT:** `96eae1dfa3a6105e87f80b2b103c509b897c4db6`  
**LAST_GOOD_CI_RUN:** `34613166500`  
**F21_STATE:** `ON HOLD / BLOCKED` — Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação desta sessão

A sessão recuperou `main` em `65cfece6d558d9810e853914dbbb1c32837df23c` e localizou a frente F26 ainda ativa na PR `#42`.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 blobs canônicos e permaneceu `VALID`.

A PR #42 foi fechada pelo protocolo antes de iniciar nova work unit:

- checkpoint F26 corrigido/atualizado;
- CI final de PR `34611506543`: PASS;
- F22 preflight final de PR `34611506565`: PASS;
- merge `1e9e03eddeac9584ee6044a2393fe6b1e9a31726`;
- CI pós-merge `34611660963`: PASS;
- F22 preflight pós-merge `34611660927`: PASS.

Só então a única `NEXT_ACTION` canônica F27 foi iniciada na branch `f27-persistent-next-action-detail-ui`, PR `#43`.

Nenhum provider hosted foi escrito e nenhum dado/identidade real foi usado.

## F27 — edição persistente de Próxima ação no detalhe

### Read model e semântica NULL

`ContractingDetailPresentation` agora preserva `nextActionValue: string | null` separadamente do texto humano `nextAction`.

Isso impede que o fallback visual `Não informada` destrua a precondição otimista da ADR-011 e mantém `NULL` distinto da string vazia.

### Server Action estreita

`updatePersistentNextActionAction`:

- executa somente com `COMPRAS_PERSISTENT_READ_ENABLED=true` válido;
- valida candidate UUID;
- lê somente `contractingId`, `expectedNextAction`, `newNextAction`;
- ignora campos extras do form/framework sem encaminhá-los como autoridade;
- representa `NULL` deliberadamente pela ausência do campo e preserva string vazia literal;
- chama exclusivamente `mutatePersistentContractingNextAction` da F26;
- não emite SQL/DML;
- nunca aceita redirect arbitrário;
- revalida a rota local somente em `updated`/`conflict`;
- sanitiza falha inesperada como `unavailable`;
- não possui fallback para demo.

A própria action bloqueia modo demo/invalid, portanto a ausência do form na UI não é o enforcement único.

### UI mínima

No detalhe persistente:

- somente `Próxima ação` recebe textarea;
- valor atual permanece visível;
- `Salvar próxima ação` preserva o texto exatamente informado;
- `Limpar próxima ação` representa `NULL` explicitamente;
- `useFormStatus` desabilita submissão repetida enquanto pending;
- feedback cobre `updated`, `unchanged`, `conflict`, `not-available` e `unavailable` com mensagens sanitizadas;
- conflito informa que o readback foi recarregado e exige revisão antes de nova tentativa.

No modo demo:

- nenhum form/textarea de escrita é renderizado;
- query state forjado de mutação não produz feedback de sucesso;
- Server Action direta também bloqueia a escrita pelo modo.

Nenhum controle de stage/status/responsável/waiting foi adicionado.

## Red-team F27

Foram provados por testes:

- team/actor/membership/issuer/subject/event UUID/callback forjados não atravessam a boundary;
- duplicate scalar falha fechado;
- candidate ID malformado não chega à F26;
- demo/invalid mode não chama a mutação;
- `NULL` e string vazia permanecem distintos;
- conflito não é mapeado para sucesso e força revalidação;
- cross-team/inexistente continuam sob o mesmo `not-available` da F26;
- erro interno com connection string não chega ao redirect/UI;
- demo não contém form de write;
- persistente não contém inputs de stage/status/responsável/waiting;
- pending desabilita o submit.

Uma primeira versão do teste do botão pending falhou por procurar a substring `disabled` dentro de `aria-disabled="false"`; o teste foi corrigido sem alterar o comportamento da feature. A execução funcional posterior ficou integralmente verde.

## Verificação funcional F27

Head `96eae1dfa3a6105e87f80b2b103c509b897c4db6`:

- CI `34613166500`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `34613166498`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- F26 PostgreSQL/RLS/concorrência: PASS;
- Better Auth/F24: PASS.

Os commits documentais de encerramento ainda precisam receber os mesmos gates verdes no head final da PR antes do merge.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01 — Desenhar criação persistente mínima de contratação`.

F28 é design-only: deve definir por ADR payload, derivação pilot-only de team/actor, capability/grants, evento inicial e idempotência antes de qualquer implementação de criação. Q-001/Q-002/Q-006/Q-009 permanecem abertas.

F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.
