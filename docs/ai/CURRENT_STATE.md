# Current State - Compras

**PROJECT_STATUS:** F41_INTEGRATED_F42_READY  
**CURRENT_PHASE:** F41 integrada; correção pós-merge restrita a teste verificada; F42 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_CONTRACTING_CREATE_NEXT_ACTION_OBJECT_ITEM_CREATE_AND_ITEM_EDIT_UI_INTEGRATED_RELATED_IDENTIFIER_CREATE_BOUNDARY_NO_UI  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_F38_F41_VALIDATED_MIGRATIONS_0001_0010_IMMUTABLE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F41_HOSTED_WRITE_VALIDATION  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F29_CONCURRENCY_REPAIR_MERGE_COMMIT:** `738666901fae43ce25dd11398904735e15c85da1`  
**F38_PR:** `#59`  
**F38_MERGE_COMMIT:** `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`  
**F39_PR:** `#61`  
**F39_MERGE_COMMIT:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**F40_PR:** `#63`  
**F40_MERGE_COMMIT:** `9463aab5dbfbda5b1c037b622ddb83859600253e`  
**F41_PR:** `#65`  
**F41_IMPLEMENTATION_HEAD:** `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`  
**F41_MERGE_COMMIT:** `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`  
**F41_POSTMERGE_TEST_REPAIR_HEAD:** `c61eb4a3c253e96fb347b2787d201bc5e249c36f`  
**F41_POSTMERGE_REPAIR_CI_RUN:** `35356582294`  
**F41_POSTMERGE_REPAIR_DB_RUN:** `35356581973`  
**LAST_GOOD_MAIN_COMMIT:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**LAST_GOOD_MAIN_CI_RUN:** `35252994972`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou `main` em `ac1d365de27999a5dcfe6d9b9a6e1b85693927a2`, merge do checkpoint F40/F41.

Não havia PR operacional aberta da F41 nem branch de implementação ativa.

A única frente canônica era:

`F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01 - Implementar vínculo persistente mínimo de identificador relacionado`.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos e todos os blob SHAs coincidiram.

SECURITY e DATABASE foram lidos diretamente porque F41 é tarefa T2.

Os blobs de migrations `0001..0009` foram capturados antes da implementação e comparados novamente após a promoção. Todos permaneceram byte-for-byte idênticos.

O repositório continua público e `REAL_DATA_ALLOWED = NO` permanece obrigatório.

## F41 integrada

A implementação foi realizada na branch `f41-persistent-related-identifier-create-implement` e promovida pela PR `#65`.

Artefatos integrados:

- `database/migrations/0010_related_identifier_create.sql`;
- `database/provisioning/grant_related_identifier_create_runtime.sql`;
- `database/tests/related_identifier_create.sql`;
- `src/features/contracting-detail/persistent-related-identifier-create.ts`;
- `src/features/contracting-detail/persistent-related-identifier-create.test.ts`;
- `src/features/contracting-detail/persistent-related-identifier-create.postgres.test.ts`;
- `.github/workflows/f41-related-identifier-create.yml`.

A migration `0010` é exclusivamente aditiva. Migrations `0001..0009` não foram alteradas.

## Boundary F41

O contrato server-only aceita somente:

```text
contractingId
relatedIdentifierId
identifierKind
identifierValue
sourceSystem
note
```

O adapter aceita o UUID opaco preparado da intenção e gera `eventId` no servidor em cada tentativa.

Team, actor, membership, issuer, subject, `linked_at`, `unlinked_at` e timestamps continuam derivados de contexto confiável.

Resultados externos:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

Não existe UI nem Server Action F41.

## Autorização e replay

A primitive usa o guard target-team pilot-only.

A operação só é autorizada quando:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está visível e ativa;
3. usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive se seu app_user estiver desabilitado.

Membership adicional do mesmo usuário em outra equipe não bloqueia a equipe alvo.

`relatedIdentifierId` é idempotency key preparada, nunca authority.

Replay `already-linked` exige autorização atual e prova exata de row ativa, payload idêntico e exatamente um evento canônico.

Row sem evento, row com múltiplos eventos canônicos, row desvinculada ou payload divergente não viram replay-success.

## Concorrência, atomicidade e texto

A prova PostgreSQL concorrente confirmou:

- oito writers com mesmo UUID/payload geram uma `created` e sete `already-linked`;
- existe exatamente uma row e um evento;
- mesmo UUID com payload divergente não faz overwrite;
- UUIDs diferentes com payload idêntico criam rows distintas.

Criação e evento `related_identifier_linked` usam o mesmo `operation_at` na mesma transação.

Falha de evento reverte a row.

`contractings.updated_at` permanece inalterado.

Semântica textual:

- sem trim;
- sem case-folding;
- sem máscara;
- sem regex de negócio;
- sem empty-to-NULL implícito;
- sem taxonomia fechada;
- sem deduplicação por valor/tipo/origem.

`identifierValue` preserva inclusive `''` e spaces-only.

`identifierKind`, `sourceSystem` e `note` preservam `NULL`, `''`, spaces-only e leading/trailing spaces.

Q-003 e Q-009 permanecem abertas.

## Least privilege

A capability `compras_related_identifier_create_owner` é dedicada, `NOLOGIN`, `NOINHERIT`, não privilegiada, sem `BYPASSRLS` e sem ownership de tabela-base.

Ela possui somente leituras necessárias, INSERT coluna-a-coluna nas colunas aprovadas de `related_identifiers` e `contracting_events`, e helpers indispensáveis.

Ela não possui UPDATE/DELETE de identificador, UPDATE de contratação, UPDATE/DELETE de evento, DML de itens/allocator ou EXECUTE das primitives F26/F29/F32/F35/F38.

As capabilities anteriores não receberam EXECUTE F41.

Runtime normal recebe somente EXECUTE da primitive F41 por provisioning separado e continua sem DML direto.

## Red-team e correção pós-merge

A matriz adversarial cobriu contexto ausente/malformado, identidade desconhecida/desabilitada, membership ausente/revogada, segundo membro, cross-team, recurso inativo, colisões, replay, NULL versus vazio, espaços, rollback de evento, authority cruzada e concorrência real.

O primeiro run dedicado encontrou ambiguidade PL/pgSQL entre a variável local e a coluna `actor_membership_id`. A variável foi renomeada para `current_actor_membership_id`, sem relaxamento de segurança.

Na verificação do checkpoint pós-merge, o workflow F41 encontrou quoting inválido em três asserções recém-adicionadas do teste SQL, onde `$$...$$` havia sido materializado como `$...$`.

O defeito estava restrito ao arquivo de teste `database/tests/related_identifier_create.sql`.

A correção não alterou migration `0010`, primitive, grants, policies, provisioning ou adapter.

Após a correção, o head `c61eb4a3c253e96fb347b2787d201bc5e249c36f` ficou verde em:

- CI `35356582294`;
- F22 `35356582129`;
- F29 `35356581998`;
- F32 `35356582261`;
- F35 `35356582179`;
- F38 `35356582177`;
- F41 `35356581973`.

O head documental posterior `751542948b45fe4a38dfc9e8d7f0f27bc1c2d7c2` também ficou verde em todos os workflows.

## Verificação estrutural

Migrations `0001..0009` continuam byte-for-byte idênticas ao baseline recuperado no início da sessão.

A migration `0010` permanece com SHA `9a1dd6fec62181c506a5efad8d5518f53cf2e154`.

Não havia review thread pendente na PR de implementação nem no checkpoint.

Resultado detalhado: `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/RESULT.md`.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01 - Integrar criação persistente de identificador relacionado no detalhe`.

A SPEC está em:

`tasks/F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01/SPEC.md`.

F42 deve expor F41 no detalhe persistente com Server Action estreita, UUID preparado no servidor e estável em retry, transporte explícito de `NULL`/texto, feedback sanitizado, readback protegido e demo read-only.

F42 não altera migrations, grants, policies, capability, primitive ou provisioning F41 e não inclui edição, desvínculo/re-link ou delete.

F21 permanece `ON HOLD` até seu `resume_when` objetivo.

Q-003, Q-004 e Q-009 permanecem abertas.
