# Current State - Compras

**PROJECT_STATUS:** F39_INTEGRATED_F40_READY  
**CURRENT_PHASE:** F39 integrada e verificada; F40 READY; F21 ON HOLD  
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
**LAST_GOOD_MAIN_COMMIT:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**LAST_GOOD_MAIN_CI_RUN:** `35252994972`  
**F21_STATE:** `ON HOLD / BLOCKED` - Vercel control-plane surface unavailable for required protection/env readback+CRUD  
**F21_RESUME_WHEN:** sessão Vercel autenticada permitir readback de Deployment Protection/bypasses e CRUD de sensitive Preview env vars escopadas à branch, sem exposição de valores  
**ON_HOLD:** `F17-B2` histórico + `F21` conforme resume_when acima

## Recuperação e contexto

A sessão recuperou o checkpoint pós-F38 em `aba830312a217382c141a706e27574cfd73ed01e`, localizou a PR #61 e a branch `f39-persistent-contracting-item-mutation-detail-ui`, retomou a work unit em vez de duplicá-la e promoveu somente depois dos gates finais verdes.

O `CONTEXT_MANIFEST` foi revalidado contra os 10 inputs canônicos e todos os blobs declarados permaneceram idênticos. `CONTEXT_STATUS = VALID`.

O repositório continua público e `REAL_DATA_ALLOWED = NO` permanece obrigatório.

## F39 integrada

A PR `#61` integrou a boundary F38 ao detalhe persistente sem alterar authority PostgreSQL.

Artefatos principais:

- snapshot bruto `mutationSnapshot` para cada item persistente ativo;
- Server Action `updatePersistentContractingItemAction`;
- feedback sanitizado `item-mutation-feedback`;
- editor mínimo dos quatro campos F38 no detalhe persistente;
- testes de action, feedback, read model e renderização.

Resultado detalhado: `tasks/F39-PERSISTENT-CONTRACTING-ITEM-MUTATION-DETAIL-UI-01/RESULT.md`.

Nenhuma migration, grant, policy, capability, primitive ou provisioning foi alterado. Migrations `0001..0009` permanecem byte-for-byte e são histórico aplicado imutável.

## Read model e snapshot F39

Itens persistentes ativos carregam, além da apresentação humana, o snapshot bruto protegido:

```text
mutationSnapshot
  description: string
  quantity: string | null
  unit: string | null
  catalogCode: string | null
```

O snapshot vem diretamente de `contracting_items` sob o read model autorizado. `quantity` permanece `numeric::text`. Label, note, ordinal, timestamp e DOM não são usados para reconstruir optimistic concurrency.

Demo usa `mutationSnapshot = null` e não renderiza editor nem hidden snapshot operacional.

## Server Action F39

A action aceita somente o transporte definido pela SPEC, além de `$ACTION_*` internos do framework.

Ela:

- exige modo persistente;
- valida `contractingId` e `itemId` candidatos;
- rejeita duplicados e campos extras;
- envia sempre os quatro expected e quatro new values para F38;
- preserva description e textos exatamente, sem trim;
- preserva `NULL`, vazio e espaços para unit/catalog por codificação explícita `text|null`;
- mantém quantity como `string | null`, sem `Number`, `parseFloat` ou input numérico;
- chama somente `mutatePersistentContractingItem`;
- não executa SQL/DML;
- não aceita team, actor, membership, issuer, subject, ordinal, retired state, timestamps, event UUIDs ou redirect arbitrário;
- revalida somente a rota local fixa quando o resultado é `updated`;
- não faz retry automático em `conflict`;
- sanitiza falha técnica como `unavailable`.

## Authority F38 preservada

A única authority de edição de item continua na capability F38 `compras_contracting_item_mutation_owner` e na primitive de `0009`.

Ela continua limitada a:

```text
description
quantity
unit
catalog_code
updated_at
```

Runtime normal continua sem DML direto. F26/F29/F32/F35/F38 não receberam authority nova na F39.

## Red-team F39

A revisão adversarial cobriu:

- demo e configuração inválida sem write path;
- snapshot ausente sem editor;
- expected bruto, completo e independente de label/note;
- `NULL`, vazio, spaces-only e leading/trailing spaces;
- quantity nula, zero, negativa, fracionária, alta precisão e texto com espaços;
- campos duplicados e extras;
- authority, lifecycle e navigation fields forjados;
- UUID candidato malformado;
- cinco resultados F38 com mensagens fixas;
- resultado impossível e exceção técnica sem vazamento;
- conflito sem retry automático;
- pending contra double-submit acidental;
- ausência de reorder, retire/restore, delete e preço;
- migrations e authority PostgreSQL intactas.

O primeiro head de CI falhou apenas por uma asserção de teste que dependia da ordem de atributos do HTML estático. O teste foi corrigido para validar os atributos separadamente. Nenhum código de produção, regra de negócio ou segurança foi relaxado.

## Verificação F39

Head final `3f4d5d0c7d63d4b5f221481bec42e7e0464faee0`:

- CI `35252702447`: PASS;
- F22 Private Preview Preflight `35252702624`: PASS;
- F29 Contracting Create `35252702678`: PASS;
- F32 Contracting Object Mutation `35252702666`: PASS;
- F35 Contracting Item Create `35252702213`: PASS;
- F38 Contracting Item Mutation `35252702746`: PASS.

PR #61 integrada por merge commit `09737ac6d11046af5d149b7926997e7e630557cc`.

Pós-merge em `main`:

- CI `35252994972`: PASS;
- F22 Private Preview Preflight `35252994912`: PASS;
- F29 Contracting Create `35252994948`: PASS;
- F32 Contracting Object Mutation `35252994959`: PASS;
- F35 Contracting Item Create `35252994922`: PASS;
- F38 Contracting Item Mutation `35252994933`: PASS.

## Próxima ação

Existe exatamente uma `NEXT_ACTION` canônica:

`F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01 - Desenhar vínculo persistente mínimo de identificador relacionado`.

A SPEC está em `tasks/F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01/SPEC.md`.

A escolha decorre do núcleo inicial já documentado: uma contratação pode agregar múltiplos processos/identificadores administrativos, o schema e o read model já existem, mas ainda falta a primeira boundary de escrita desse relacionamento.

F40 é design-only. Não deve criar código operacional. Deve produzir a decisão canônica e uma única SPEC de implementação seguinte, mantendo `0001..0009` imutáveis.

F21 permanece `ON HOLD` até seu `resume_when` objetivo. Q-004 e Q-009 permanecem abertas.
