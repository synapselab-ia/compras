# Current State - Compras

**PROJECT_STATUS:** F42_INTEGRATED_F43_READY  
**CURRENT_PHASE:** F42 integrada; F43 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_CONTRACTING_CREATE_NEXT_ACTION_OBJECT_ITEM_CREATE_ITEM_EDIT_AND_RELATED_IDENTIFIER_CREATE_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_F38_F41_VALIDATED_MIGRATIONS_0001_0010_IMMUTABLE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F42_HOSTED_WRITE_VALIDATION  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F41_PR:** `#65`  
**F41_MERGE_COMMIT:** `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`  
**F42_PR:** `#67`  
**F42_IMPLEMENTATION_HEAD:** `296b00a98402fa7a8dd534ea4cea9eda9b0e90cc`  
**F42_MERGE_COMMIT:** `53db535df7981f957674ca708bea7b30308992b3`  
**F42_CI_RUN:** `35382784877`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto desta frente

A sessão recuperou o estado real do GitHub em `main` no merge do checkpoint F41/F42:

`5953f5dbfc4cab82b61311f293d6b2dd62972b64`.

Não havia PR operacional aberta nem branch F42 ativa.

A única frente canônica era:

`F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01 - Integrar criação persistente de identificador relacionado no detalhe`.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos e todos os blob SHAs coincidiram.

SECURITY e DATABASE foram lidos diretamente porque F42 possui efeito T2 de autorização/escrita server-side.

O baseline de migrations `0001..0010` foi capturado antes da implementação.

A correção pós-merge da F41 em `c61eb4a3c253e96fb347b2787d201bc5e249c36f` foi verificada independentemente e estava verde em CI, F22, F29, F32, F35, F38 e F41.

## F42 integrada

A implementação foi realizada na branch:

`f42-related-identifier-create-detail-ui`

e promovida pela PR `#67`.

Merge em `main`:

`53db535df7981f957674ca708bea7b30308992b3`.

Artefatos de produção alterados/adicionados:

- `src/app/contratacoes/[id]/page.tsx`;
- `src/features/contracting-detail/actions.ts`;
- `src/features/contracting-detail/components/contracting-detail.tsx`;
- `src/features/contracting-detail/related-identifier-create-feedback.ts`.

Testes novos/ajustados:

- `src/app/contratacoes/[id]/page.test.tsx`;
- `src/features/contracting-detail/related-identifier-create-action.test.ts`;
- `src/features/contracting-detail/related-identifier-create-feedback.test.ts`;
- `src/features/contracting-detail/components/contracting-detail.test.tsx`.

Nenhum arquivo de banco, migration, grant, policy, capability, primitive ou provisioning foi alterado.

## Jornada F42

No detalhe persistente autorizado, o painel de identificadores relacionados agora permite criar um novo vínculo usando exclusivamente a boundary F41.

A Server Action aceita somente:

```text
contractingId
relatedIdentifierId
identifierKindKind
identifierKind
identifierValue
sourceSystemKind
sourceSystem
noteKind
note
```

Team, actor, membership, issuer, subject, event UUID, timestamps, lifecycle e navegação arbitrária não são aceitos como authority.

A action não possui SQL/DML próprio.

Ela chama exclusivamente:

`createPersistentRelatedIdentifier(...)`.

## Candidate e retry

O `relatedIdentifierId` inicial é preparado no servidor por:

`preparePersistentRelatedIdentifierCandidateId()`.

Semântica integrada:

- `created`: intenção concluída, readback protegido e novo candidate na próxima intenção;
- `already-linked`: replay exato concluído, readback protegido e novo candidate na próxima intenção;
- `not-available`: feedback genérico, candidate anterior descartado;
- `unavailable`: feedback técnico sanitizado e o mesmo candidate validado é preservado para retry.

O candidate continua sendo somente identidade técnica/idempotency key. Não concede scope nem autorização.

Demo, falha protegida e detalhe indisponível não preparam nem expõem candidate de escrita.

## NULL versus texto

`identifierKind`, `sourceSystem` e `note` usam transporte explícito `null|text`.

A UI e a action preservam:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

`identifierValue` permanece string exata, inclusive vazia ou somente espaços, conforme F41.

Não existe:

- trim;
- case-folding;
- máscara;
- regex de negócio;
- taxonomia fechada;
- deduplicação por valor/tipo/origem;
- conversão implícita empty-to-NULL.

Q-003 permanece aberta.

## Demo e falha protegida

Demo continua estritamente read-only.

Mesmo query state F42 forjado em demo:

- não renderiza formulário;
- não mostra candidate;
- não mostra feedback de escrita como se uma operação tivesse ocorrido.

Falha protegida continua sem fallback para fixture/demo.

## Red-team F42

A matriz cobriu:

- duplicate scalars;
- campos extras;
- authority forjada;
- event UUID/timestamps/lifecycle forjados;
- callback/redirect externo;
- candidate malformado;
- candidate válido forjado sem authority;
- NULL versus vazio/espaços;
- texto sem normalização;
- resultado impossível;
- exceção com detalhe técnico;
- demo com query state forjado;
- retry `unavailable` com candidate estável;
- sucesso/replay com nova intenção posterior;
- ausência de UI F42 em demo;
- readback pela lista protegida existente.

O primeiro CI da PR encontrou duas falhas apenas em testes novos: uma asserção dependente da ordem de atributos React e isolamento incompleto de aliases no teste de página. Os testes foram corrigidos sem alterar o contrato de produção.

## Verificação F42

Head promovido:

`296b00a98402fa7a8dd534ea4cea9eda9b0e90cc`.

Gates finais:

- CI `35382784877`: PASS;
- F22 Private Preview Preflight `35382784984`: PASS;
- F29 Contracting Create `35382784990`: PASS;
- F32 Contracting Object Mutation `35382784911`: PASS;
- F35 Contracting Item Create `35382784957`: PASS;
- F38 Contracting Item Mutation `35382784934`: PASS;
- F41 Related Identifier Create `35382784907`: PASS.

O job `verify` de CI confirmou:

- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS.

Os jobs de banco e auth também ficaram verdes.

Não havia review thread pendente na PR `#67` antes do merge.

Os workflows são acionados na PR e não produziram run adicional para o merge commit de `main`; o tree promovido é exatamente o head verde da PR mais o merge GitHub.

Resultado detalhado:

`tasks/F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01/RESULT.md`.

## Imutabilidade

Migrations `0001..0010` permaneceram byte-for-byte idênticas ao baseline capturado antes da implementação.

SHAs finais:

- `0001_core_foundation.sql`: `a10e9733b71abae272fb58b763cae4c1439dd70c`;
- `0002_trusted_identity_read_policies.sql`: `ba6dd439f86e893faf1e4cb5ef59a3730876a757`;
- `0003_team_member_directory.sql`: `33b98ad1b6134a02b0662e9f2f03dfbd07df92a8`;
- `0004_next_action_mutation.sql`: `7773f1c0c19efb055a42d953d08bca1dab082b85`;
- `0005_contracting_create.sql`: `fdf8bfd1176c9c1e047b1d5fcb3512c9fab71d74`;
- `0006_contracting_object_mutation.sql`: `f3318318720b9df270430088001ad1f6002a4728`;
- `0007_contracting_item_create.sql`: `ddb098fe03c123b7b6cb8665890b1a2c8c12093b`;
- `0008_contracting_create_concurrency_repair.sql`: `c91f379aef0d0922c7de3be78d798e537fef9099`;
- `0009_contracting_item_mutation.sql`: `11f0639ae623eefb5794e69a1c7419cfd6a66fc2`;
- `0010_related_identifier_create.sql`: `9a1dd6fec62181c506a5efad8d5518f53cf2e154`.

Provisioning F41 permaneceu:

`grant_related_identifier_create_runtime.sql` = `0f6ac20ddff00f9c547f6c99919acdef81c73e86`.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01 - Desenhar criação persistente de nota manual na timeline`.

A SPEC está em:

`tasks/F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01/SPEC.md`.

A escolha dessa frente não resolve questões abertas. Ela usa uma capacidade já prevista pelo DOMAIN_MODEL e pelo DATABASE: nota manual como evento da timeline.

Edição/desvínculo de identificadores relacionados permanece fora da próxima frente para não antecipar semântica que pode depender de Q-003.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.

Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas.
