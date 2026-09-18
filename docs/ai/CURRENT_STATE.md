# Current State - Compras

**PROJECT_STATUS:** F40_INTEGRATED_F41_READY  
**CURRENT_PHASE:** F40 integrada e verificada; F41 READY; F21 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_SELF_HOSTED_AUTH_SIGNIN_LIMITER_CONTRACTING_CREATE_NEXT_ACTION_OBJECT_ITEM_CREATE_AND_ITEM_EDIT_UI_INTEGRATED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_F26_F29_F32_F35_F38_VALIDATED_MIGRATIONS_0001_0009_IMMUTABLE  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_AND_SIGNIN_LIMITER_INTEGRATED  
**DEPLOYMENT_STATUS:** EXISTING_F18_PREVIEW_READY_NO_F39_HOSTED_WRITE_VALIDATION  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**F21_FINAL_CHECKPOINT_COMMIT:** `73cd3ec1ef524c526c91124d40efae1eff2061ce`  
**F29_CONCURRENCY_REPAIR_MERGE_COMMIT:** `738666901fae43ce25dd11398904735e15c85da1`  
**F37_MERGE_COMMIT:** `88d7d43f06afe8a9eef4d446331c173a8d238856`  
**F38_PR:** `#59`  
**F38_MERGE_COMMIT:** `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`  
**F39_PR:** `#61`  
**F39_FINAL_HEAD:** `3f4d5d0c7d63d4b5f221481bec42e7e0464faee0`  
**F39_MERGE_COMMIT:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**F40_PR:** `#63`  
**F40_FINAL_HEAD:** `4211d92b100be1064bfd14b60d1b8ab132e51abe`  
**F40_MERGE_COMMIT:** `9463aab5dbfbda5b1c037b622ddb83859600253e`  
**F40_FINAL_HEAD_CI_RUN:** `35350201262`  
**LAST_GOOD_MAIN_COMMIT:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**LAST_GOOD_MAIN_CI_RUN:** `35252994972`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou `main` em `bfe60c895b94ff5373360d830f1f5e4d95bc51d2`, confirmou ausência de PR aberta e ausência de branch F40 operacional ainda ativa. A única frente canônica era F40.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos. Todos os blobs declarados permaneceram idênticos, portanto `CONTEXT_STATUS = VALID`.

Foram inspecionados produto, domínio, workflow, questões abertas, SECURITY, DATABASE, DoD, migrations relevantes, ADR-012 a ADR-015 e o read model persistente de `related_identifiers`.

O repositório continua público e `REAL_DATA_ALLOWED = NO` permanece obrigatório.

## F40 integrada

A PR `#63` executou a slice design-only da primeira criação persistente de identificador relacionado.

Artefatos integrados:

- `docs/decisions/ADR-016-minimal-persistent-related-identifier-creation.md`;
- `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/SPEC.md`.

Nenhuma migration, policy, grant, capability, primitive, provisioning, adapter, Server Action, UI ou código operacional foi criado na F40.

Migrations `0001..0009` permaneceram byte-for-byte imutáveis.

## Decisão ADR-016

O contrato server-only futuro parte de:

```text
contractingId
relatedIdentifierId
identifierKind
identifierValue
sourceSystem
note
```

`contractingId` e `relatedIdentifierId` são apenas candidatos opacos. O segundo funciona como identidade estável/idempotency key preparada pelo servidor, nunca como authority.

Team, actor, membership, issuer, subject, timestamps e event UUIDs permanecem derivados de contexto confiável.

A autorização usa o guard target-team pilot-only já adotado pelas mutations em entidade existente:

1. identidade corrente resolve app_user ativo;
2. contratação candidata está visível e ativa;
3. usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive se seu app_user estiver desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia por si só.

Q-009 permanece aberta.

## Semântica de texto e cardinalidade

A decisão não inventa regras ausentes das fontes:

- não há trim;
- não há case-folding;
- não há máscara ou regex;
- não há catálogo fechado de tipo/origem;
- não há limite de tamanho de negócio inventado;
- não há empty-to-NULL implícito;
- não há deduplicação por número, tipo, origem ou combinação.

`identifierValue` é `text NOT NULL`, portanto a boundary futura preserva inclusive `''` e espaços enquanto não houver regra canônica non-empty.

`identifierKind`, `sourceSystem` e `note` preservam `NULL`, vazio e espaços como estados distintos.

UUIDs diferentes com payload textual igual podem representar duas criações distintas. Q-003 permanece aberta.

## Idempotência e concorrência

`relatedIdentifierId` é preparado no servidor antes da primeira submissão e reutilizado nos retries da mesma intenção.

Um replay só pode retornar `already-linked` depois de nova autorização da contratação candidata e prova exata de:

- mesma row ativa;
- mesmo team e contracting;
- textos idênticos por comparação null-safe;
- exatamente um evento canônico `related_identifier_linked`;
- actor derivado igual;
- `occurred_at` e `created_at` iguais a `linked_at`;
- shape do evento sem field/old/new/note/item.

Row desvinculada ou row sem exatamente um evento canônico não é replay-success.

Chamadas concorrentes com o mesmo UUID/payload devem produzir uma única row e um único evento. Colisão com payload diferente não faz overwrite. UUIDs diferentes com payload igual podem criar rows distintas.

Colisão de event UUID é falha técnica e nunca vira replay-success.

## Least privilege e auditoria

A futura capability é dedicada, conceitualmente `compras_related_identifier_create_owner`, sem LOGIN, SUPERUSER, BYPASSRLS ou ownership de tabela-base.

Runtime normal recebe somente `EXECUTE` da primitive futura por provisioning separado.

A capability poderá apenas:

- resolver identidade;
- ler memberships do guard;
- ler contratação alvo;
- ler o mínimo de row/evento para prova de replay;
- inserir colunas aprovadas de `related_identifiers`;
- inserir colunas aprovadas de `contracting_events`.

Ela não recebe UPDATE/DELETE de identificador/evento, UPDATE de contratação nem authority das capabilities anteriores.

Criação e evento `related_identifier_linked` pertencem à mesma transação e usam o mesmo `operation_at`. Falha do evento reverte a row. `contractings.updated_at` não é usado como substituto da timeline.

## Red-team F40

A revisão adversarial rejeitou explicitamente:

- scope, actor, membership ou timestamps vindos do browser;
- autorização derivada do UUID do identificador;
- vínculo cross-team, arquivado ou cancelado;
- resolução implícita da política multiusuário;
- DML direto pela runtime;
- ampliação de F26/F29/F32/F35/F38;
- normalização ou validação textual inventada;
- colapso de `NULL`, vazio e espaços;
- deduplicação por valor/tipo/origem;
- replay por mera colisão de UUID;
- replay de row desvinculada;
- replay de row sem exatamente um evento canônico;
- evento fora da transação;
- update artificial de `contractings.updated_at`;
- reescrita de migrations aplicadas;
- resolução implícita de Q-003, Q-004 ou Q-009;
- fallback para demo;
- dependência de provider hosted, secret ou dado real.

O red-team reforçou o desenho inicial para exigir exatamente um evento canônico no replay e igualdade de `created_at` e `occurred_at` com `linked_at`.

## Verificação F40

Head final da PR `#63`: `4211d92b100be1064bfd14b60d1b8ab132e51abe`.

Gates observados no head final:

- CI `35350201262`: PASS;
- F22 Private Preview Preflight `35350201005`: PASS;
- F29 Contracting Create `35350201149`: PASS;
- F32 Contracting Object Mutation `35350201190`: PASS;
- F35 Contracting Item Create `35350201079`: PASS;
- F38 Contracting Item Mutation `35350201025`: PASS.

A comparação `main...head` mostrou somente os dois documentos da F40.

Os blobs de migrations `0001..0009` foram comparados entre `main` e a branch F40 e permaneceram idênticos.

PR `#63` integrada por merge commit `9463aab5dbfbda5b1c037b622ddb83859600253e`. O merge commit foi inspecionado e contém somente ADR-016 e a SPEC F41.

O conector GitHub disponível expõe runs associados a evento de pull request, mas não fornece readback dos runs de push do merge commit. Portanto nenhum PASS pós-merge é afirmado sem evidência. O `LAST_GOOD_MAIN_COMMIT` executável com readback de CI permanece o pós-F39 já validado; F40 não alterou código executável.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01 - Implementar vínculo persistente mínimo de identificador relacionado`.

A SPEC está em `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/SPEC.md`.

F41 deve implementar ADR-016 com migration aditiva `0010`, capability dedicada, policies RLS, primitive, provisioning, adapter server-only, testes SQL adversariais, prova PostgreSQL concorrente e workflow/regressões.

F41 não inclui UI nem Server Action.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-003, Q-004 e Q-009 permanecem abertas.
