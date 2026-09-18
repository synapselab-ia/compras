# Current State - Compras

**PROJECT_STATUS:** F41_INTEGRATED_F42_READY  
**CURRENT_PHASE:** F41 integrada e verificada no head da PR; F42 READY; F21 ON HOLD  
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
**F41_FINAL_HEAD:** `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`  
**F41_MERGE_COMMIT:** `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`  
**F41_FINAL_HEAD_CI_RUN:** `35355476581`  
**F41_FINAL_HEAD_DB_RUN:** `35355476626`  
**LAST_GOOD_MAIN_COMMIT:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**LAST_GOOD_MAIN_CI_RUN:** `35252994972`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou `main` em `ac1d365de27999a5dcfe6d9b9a6e1b85693927a2`, merge do checkpoint F40/F41. Não havia PR operacional aberta da F41 nem branch de implementação ativa.

A única frente canônica era:

`F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01 - Implementar vínculo persistente mínimo de identificador relacionado`.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos e todos os blob SHAs coincidiram. SECURITY e DATABASE foram lidos diretamente por se tratar de tarefa T2.

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

O adapter prepara/aceita UUID opaco da intenção e gera `eventId` server-side em cada tentativa.

Team, actor, membership, issuer, subject, `linked_at`, `unlinked_at` e timestamps continuam derivados de contexto confiável.

Resultados externos:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

Não existe UI nem Server Action F41.

## Autorização target-team pilot-only

A primitive só cria quando:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está visível e ativa;
3. usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive se seu app_user estiver desabilitado.

Membership adicional do mesmo usuário em outra equipe não bloqueia a equipe alvo por si só.

Q-009 permanece aberta.

## Replay e concorrência

`relatedIdentifierId` é somente idempotency key preparada, nunca authority.

`already-linked` exige nova autorização e prova exata da row ativa e do evento canônico:

- mesmo UUID, team e contracting;
- `unlinked_at IS NULL`;
- textos idênticos por comparação null-safe;
- exatamente um evento `related_identifier_linked` com actor derivado;
- `occurred_at = created_at = linked_at`;
- field/old/new/note/item nulos.

Row sem evento, row com dois eventos canônicos, row desvinculada e payload divergente retornam `denied`.

A prova PostgreSQL concorrente confirmou:

- oito writers com mesmo UUID/payload geram uma `created` e sete `already-linked`;
- exatamente uma row e um evento;
- mesmo UUID com payload divergente não faz overwrite;
- UUIDs diferentes com payload idêntico criam rows distintas.

## Semântica textual

F41 não inventou regra ausente:

- sem trim;
- sem case-folding;
- sem máscara;
- sem regex de negócio;
- sem empty-to-NULL implícito;
- sem taxonomia fechada;
- sem deduplicação por valor/tipo/origem.

`identifierValue` preserva inclusive `''` e spaces-only.

`identifierKind`, `sourceSystem` e `note` preservam `NULL`, `''`, spaces-only e leading/trailing spaces como estados distintos.

Q-003 permanece aberta.

## Least privilege e auditoria

A capability `compras_related_identifier_create_owner` é dedicada, `NOLOGIN`, `NOINHERIT`, sem privilégio administrativo, sem `BYPASSRLS` e sem ownership de tabela-base.

Ela possui somente:

- leituras necessárias para identidade, guard e replay;
- INSERT coluna-a-coluna nas colunas aprovadas de `related_identifiers`;
- INSERT coluna-a-coluna nas colunas aprovadas de `contracting_events`;
- helpers indispensáveis.

Ela não possui:

- UPDATE/DELETE de identificador;
- UPDATE de contratação;
- UPDATE/DELETE de evento;
- DML de itens/allocator;
- EXECUTE de F26/F29/F32/F35/F38.

As capabilities anteriores não receberam EXECUTE F41.

Runtime normal recebe somente EXECUTE F41 pelo provisioning dedicado e continua sem DML direto.

Criação e evento `related_identifier_linked` usam o mesmo `operation_at` na mesma transação. Falha de evento reverte a row. `contractings.updated_at` permanece inalterado.

## Red-team F41

A matriz adversarial cobriu:

- capability insegura por LOGIN, SUPERUSER, CREATEROLE, BYPASSRLS e membership utilizável;
- runtime INHERIT e runtime com DML direto;
- auth/context ausente, malformado e identidade desconhecida;
- app_user desabilitado;
- app_user ativo sem membership;
- membership revogada;
- segundo membro não revogado, inclusive app_user desabilitado;
- membership adicional do mesmo usuário em outra equipe;
- cross-team, inexistente, arquivado e cancelado;
- colisão global cross-team do UUID sem oracle;
- replay exato;
- payload divergente sob o mesmo UUID;
- row sem evento, com dois eventos e desvinculada;
- `NULL` versus `''`;
- vazio, spaces-only e leading/trailing spaces;
- ausência de deduplicação textual;
- event UUID collision com rollback integral;
- ausência de authority cruzada;
- parent `updated_at` invariável;
- concorrência real.

O primeiro run dedicado encontrou uma ambiguidade PL/pgSQL entre variável local e coluna `actor_membership_id`. A variável foi renomeada para `current_actor_membership_id`, sem relaxamento de segurança. O red-team foi então ampliado e o head final ficou verde.

## Verificação F41

Head final da PR `#65`: `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`.

Gates observados no head final:

- CI `35355476581`: PASS;
- F22 Private Preview Preflight `35355476503`: PASS;
- F29 Contracting Create `35355476516`: PASS;
- F32 Contracting Object Mutation `35355476614`: PASS;
- F35 Contracting Item Create `35355476513`: PASS;
- F38 Contracting Item Mutation `35355476539`: PASS;
- F41 Related Identifier Create `35355476626`: PASS.

A comparação final da PR mostrou somente os sete artefatos novos da F41. Não havia review thread pendente.

PR `#65` integrada por merge commit `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`.

O conector GitHub disponível expõe runs associados a evento de pull request, mas não fornece readback dos runs de push do merge commit. Nenhum PASS pós-merge é afirmado sem evidência. Por esse motivo `LAST_GOOD_MAIN_COMMIT` permanece no último main executável com readback pós-merge disponível, o pós-F39.

Resultado detalhado: `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/RESULT.md`.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01 - Integrar criação persistente de identificador relacionado no detalhe`.

A SPEC está em `tasks/F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01/SPEC.md`.

F42 deve expor F41 no detalhe persistente com Server Action estreita, UUID preparado no servidor e estável em retry, transporte explícito de `NULL`/texto, feedback sanitizado, readback protegido e demo read-only.

F42 não altera migrations, grants, policies, capability, primitive ou provisioning F41 e não inclui edição, desvínculo/re-link ou delete.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-003, Q-004 e Q-009 permanecem abertas.
