# F39 - Resultado da integração da edição persistente de item no detalhe

**Estado:** COMPLETED / PASS  
**PR:** `#61`  
**Head final verificado:** `3f4d5d0c7d63d4b5f221481bec42e7e0464faee0`  
**Merge em main:** `09737ac6d11046af5d149b7926997e7e630557cc`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Resultado

F39 integrou a boundary F38 ao detalhe persistente sem alterar authority PostgreSQL.

Foram integrados:

- snapshot bruto protegido de item no read model;
- Server Action estreita para edição dos quatro campos F38;
- codificação explícita `text` versus `null` para unidade e código de catálogo;
- quantity como `string | null`, sem conversão floating-point em JavaScript;
- feedback fixo e sanitizado para os cinco resultados F38;
- editor por item somente em modo persistente e somente quando existe snapshot protegido;
- pending contra double-submit acidental usando o componente já baseado em `useFormStatus`;
- testes unitários e de renderização para payload, snapshot, NULL/texto, demo e navegação.

Nenhuma migration, grant, policy, capability, primitive ou provisioning foi alterado. Migrations `0001..0009` permaneceram imutáveis.

## Read model e optimistic concurrency

Cada item persistente ativo pode transportar:

```text
mutationSnapshot:
  description: string
  quantity: string | null
  unit: string | null
  catalogCode: string | null
```

O snapshot vem diretamente das colunas protegidas já lidas por RLS. `quantity` continua sendo obtida por `numeric::text`. A UI não reconstrói expected values de `label`, `note`, ordinal, timestamp ou DOM.

Cada submissão F39 envia para F38 o snapshot esperado completo e o snapshot novo completo. `conflict` não gera retry automático.

Fixtures demo possuem `mutationSnapshot = null` e não renderizam editor, hidden snapshot ou write path F39.

## Server Action

A action browser-facing aceita somente os campos de transporte previstos na SPEC, além de campos internos `$ACTION_*` do framework.

Ela:

- exige modo persistente;
- valida `contractingId` e `itemId` como UUIDs candidatos;
- rejeita scalars duplicados;
- rejeita campos extras controláveis pelo browser;
- preserva description e textos sem trim ou normalização;
- interpreta apenas `newQuantity = ''` como `null`;
- mantém qualquer quantity não vazia como string exata;
- usa `kind = text|null` para preservar distinção entre `NULL`, `''` e espaços em unit/catalog;
- chama exclusivamente `mutatePersistentContractingItem`;
- não executa SQL ou DML próprio;
- não aceita callback/redirect arbitrário;
- não aceita team, actor, membership, issuer, subject, ordinal, retired state, timestamps ou event UUIDs como authority;
- sanitiza falha técnica ou resultado impossível como `unavailable`;
- revalida apenas a rota local fixa quando F38 retorna `updated`.

## Red-team

A matriz adversarial cobriu:

- demo estritamente read-only, inclusive com query string de feedback forjada;
- ausência de editor quando o snapshot protegido não existe;
- expected snapshot bruto independente de label/note formatados;
- expected completo dos quatro campos;
- duplicação de cada scalar de transporte;
- campos extras e authority forjada;
- callback/redirect forjado;
- UUIDs candidatos malformados;
- `NULL`, string vazia e spaces-only distintos em unit/catalog;
- description vazia, spaces-only e leading/trailing spaces sem normalização;
- quantity `null`, zero, negativa, fracionária, alta precisão e espaços como texto exato;
- ausência de `Number`, `parseFloat` e `type=number` na jornada F39;
- resultados `updated`, `unchanged`, `conflict`, `not-available`, `unavailable` com mensagens fixas;
- resultado impossível e erro técnico sem detalhe em navegação/HTML;
- nenhum retry automático de conflito;
- nenhum controle de reorder, retire/restore, delete ou pesquisa de preços;
- nenhuma expansão de authority F26/F29/F32/F35/F38.

O primeiro head de CI encontrou apenas uma fragilidade no teste novo de markup: a asserção dependia da ordem de atributos emitida por `renderToStaticMarkup`. O comportamento de produção estava correto. A correção separou as asserções de `name` e `type/inputMode`, sem alterar código de produção ou regra de segurança.

## Verificação

Head final `3f4d5d0c7d63d4b5f221481bec42e7e0464faee0`:

- CI `35252702447`: PASS;
- F22 Private Preview Preflight `35252702624`: PASS;
- F29 Contracting Create `35252702678`: PASS;
- F32 Contracting Object Mutation `35252702666`: PASS;
- F35 Contracting Item Create `35252702213`: PASS;
- F38 Contracting Item Mutation `35252702746`: PASS.

Pós-merge em `main` `09737ac6d11046af5d149b7926997e7e630557cc`:

- CI `35252994972`: PASS;
- F22 Private Preview Preflight `35252994912`: PASS;
- F29 Contracting Create `35252994948`: PASS;
- F32 Contracting Object Mutation `35252994959`: PASS;
- F35 Contracting Item Create `35252994922`: PASS;
- F38 Contracting Item Mutation `35252994933`: PASS.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- migrations `0001..0009` permanecem imutáveis;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- falha protegida nunca vira demo fallback.
