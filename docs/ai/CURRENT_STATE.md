# Current State - Compras

**PROJECT_STATUS:** F36_INTEGRATED_F37_READY  
**CURRENT_PHASE:** F36 concluída, integrada e verificada; F37 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_NEXT_ACTION_WRITE_CREATE_UI_OBJECT_MUTATION_OBJECT_DETAIL_UI_ITEM_CREATE_BOUNDARY_AND_ITEM_CREATE_DETAIL_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_VALIDATED_NO_F36_DATABASE_CHANGE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F36_HOSTED_WRITES  
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
**F30_MERGE_COMMIT:** `c0f6e822253e9e324f00bc674f4805f52cbca16c`  
**F31_MERGE_COMMIT:** `b541592aa4a392dfab439389daaddcd4c811c5e5`  
**F32_MERGE_COMMIT:** `e7f893e8d186853b859dfb281f134d057b0b6e97`  
**F33_MERGE_COMMIT:** `c4c3d5416ecfd7f49c74ffd0a32425db8621958c`  
**F33_CHECKPOINT_MERGE_COMMIT:** `bfa9a65fae06ef8c3cc29586287160be3ab29d31`  
**F34_MERGE_COMMIT:** `51b02799e5994567ca144b38c4117271695ff7e2`  
**F35_MERGE_COMMIT:** `879902c9e55c60ae514e0ce961f9246202c5c9f8`  
**F36_PR:** `#54`  
**F36_FINAL_HEAD:** `7d0e317a25cc2ef9bbc83df3817238f61d5c0404`  
**F36_MERGE_COMMIT:** `c177e7e8c1b3a46a5d5c3276b4945b81019c706a`  
**LAST_GOOD_COMMIT:** `c177e7e8c1b3a46a5d5c3276b4945b81019c706a`  
**LAST_GOOD_CI_RUN:** `34989894313`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e validação

A sessão recuperou `main` em `73604d1d7310353e822ace07fc9202ae160f55d0`, confirmou ausência de PR ativa anterior e identificou F36 como a única `NEXT_ACTION` canônica deixada pelo checkpoint F35.

O `CONTEXT_MANIFEST` foi revalidado contra a árvore canônica. PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, ARCHITECTURE, SECURITY, DATABASE, DEFINITION_OF_DONE, SOURCE_OF_TRUTH e WORK_PROTOCOL permaneceram nos hashes declarados. `CONTEXT_STATUS = VALID`.

F36 foi tratada como T1 com impacto T2 por expor escrita persistente via Server Action, embora sem mudança de autoridade PostgreSQL. `REAL_DATA_ALLOWED = NO` permaneceu obrigatório.

## F36 - criação de item integrada ao detalhe persistente

F36 expôs exclusivamente a boundary F35 já integrada. Nenhuma migration, grant, policy, capability, primitive ou provisioning de banco foi alterado.

### Server Action e payload

A action persistente de criação de item:

- funciona somente quando `persistent-read-mode` está válido;
- aceita exatamente `contractingId`, `description`, `quantity`, `unit` e `catalogCode`, além de transporte interno `$ACTION_*` do framework que não é tratado como authority;
- rejeita scalars duplicados;
- rejeita campos extras controláveis pelo browser antes de alcançar F35;
- não aceita team, actor, membership, issuer, subject, ordinal, item UUID, event UUID, callback ou redirect como authority;
- não executa SQL/DML próprio;
- chama `createPersistentContractingItem` e expõe somente `created`, `not-available` ou `unavailable`;
- revalida apenas a rota local fixa após `created`, de modo que a lista é relida pelo read model protegido existente.

`description`, `unit` e `catalogCode` permanecem textos exatos, inclusive vazio e espaços. Quantidade vazia ou ausente na UI representa `null`; qualquer texto não vazio segue como `string` exata para F35/PostgreSQL. Não há `Number`, `parseFloat`, trim ou normalização de negócio.

### UI persistente

O detalhe persistente passou a oferecer o formulário mínimo "Adicionar item" dentro do painel de itens ativos.

O formulário contém somente:

```text
contractingId
description
quantity
unit
catalogCode
```

Quantidade usa input textual com dica decimal, não `type=number`, para não introduzir coerção de precisão no navegador. Nenhum input de authority, ordinal, UUID interno, reorder, retire, delete ou pesquisa de preços foi incluído.

O botão reutiliza o componente com `useFormStatus`, ficando desabilitado durante pending para reduzir double-submit acidental sem inventar idempotência persistente.

Demo permanece estritamente read-only. Estado de query forjado não faz formulário nem feedback de escrita aparecer em demo.

### Feedback sanitizado

A UI reconhece somente:

- `created` -> `Item adicionado.`;
- `not-available` -> mensagem genérica de indisponibilidade para o registro;
- `unavailable` -> mensagem genérica de falha temporária.

Arrays, valores desconhecidos e detalhes técnicos não são refletidos. Cross-team/inexistente continua sem oracle na camada browser-facing.

## Red-team F36

Os testes e a revisão adversarial cobriram e rejeitaram:

- team, team_id, actor, membership, issuer e subject forjados;
- ordinal, item UUID e event UUID controlados pelo browser;
- callback, callbackURL e redirect controlados pelo browser;
- scalar duplicado/ambíguo;
- quantity convertida por JavaScript ou submetida como `type=number`;
- trim ou empty-to-NULL indevido para campos textuais;
- demo com qualquer write;
- revalidação de rota fornecida pelo cliente;
- feedback contendo conexão, SQL, claim ou detalhe de autorização;
- alteração de migrations `0001..0007`, grants, policies, capabilities ou primitives;
- provider hosted, secret ou dado real;
- expansão para update/reorder/retire/delete de item ou pesquisa de preços.

O primeiro head da F36 encontrou uma falha real na suíte ao importar estaticamente um módulo `server-only` da boundary F35 dentro do módulo compartilhado de actions. A correção manteve F35 isolada por import dinâmico somente no caminho de execução da action F36, evitando carregar a boundary server-only nos testes legados das actions F27/F33. O head corrigido ficou totalmente verde.

## Verificação F36

Head final da PR `7d0e317a25cc2ef9bbc83df3817238f61d5c0404`:

- CI `34989649457`: PASS;
- F22 Private Preview Preflight `34989650055`: PASS;
- F29 Contracting Create `34989649664`: PASS;
- F32 Contracting Object Mutation `34989649765`: PASS;
- F35 Contracting Item Create `34989649584`: PASS.

PR `#54` integrada por merge commit `c177e7e8c1b3a46a5d5c3276b4945b81019c706a`.

Pós-merge em `main`:

- CI `34989894313`: PASS;
- F22 Private Preview Preflight `34989894397`: PASS;
- F29 Contracting Create `34989894362`: PASS;
- F32 Contracting Object Mutation `34989894237`: PASS;
- F35 Contracting Item Create `34989894477`: PASS.

O diff final da F36 alterou somente sete arquivos de application/tests. `database/`, migrations, workflows de authority, providers e arquivos de secret permaneceram fora do diff.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01 - Desenhar edição persistente mínima de item`.

A SPEC está em `tasks/F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01/SPEC.md`.

F37 é exclusivamente de desenho T2. Deve definir payload, optimistic concurrency, autorização, capability, auditoria, semântica exata e resultados sanitizados para editar campos existentes de item, sem implementação operacional, sem reorder/retire e sem pesquisa de preços.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-004 e Q-009 permanecem abertas.