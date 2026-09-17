# F38 - Resultado da implementação da edição persistente mínima de item

**Estado:** COMPLETED / PASS  
**PR:** `#59`  
**Head final verificado:** `3643ce63bdd9e7d0564dba7662987197610fccb5`  
**Merge em main:** `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Resultado

A ADR-015 foi materializada sem Server Action ou UI.

Foram integrados:

- `database/migrations/0009_contracting_item_mutation.sql`;
- capability selada `compras_contracting_item_mutation_owner`;
- primitive `public.mutate_contracting_item_fields(...)`;
- provisioning `database/provisioning/grant_contracting_item_mutation_runtime.sql`;
- adapter server-only `src/features/contracting-detail/persistent-item-mutation.ts`;
- prova SQL adversarial;
- prova PostgreSQL concorrente real;
- gate dedicado `F38 Contracting Item Mutation`.

Migrations `0001..0008` permaneceram imutáveis. Após a promoção, `0001..0009` passam a ser histórico aplicado imutável.

## Boundary final

A operação modifica somente:

```text
description
quantity
unit
catalog_code
updated_at
```

O contrato server-only recebe `contractingId + itemId`, snapshot esperado dos quatro campos e snapshot novo dos quatro campos. Team, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs não são authority do caller público.

Os quatro UUIDs de evento são gerados no servidor em cada tentativa. `quantity` permanece `string | null` até PostgreSQL `numeric`, sem `Number`, `parseFloat`, trim ou normalização.

Resultados externos permanecem limitados a:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

## Concorrência e auditoria

A primitive bloqueia somente a row do item. Depois do lock e da revalidação de parent/membership:

1. qualquer divergência entre current e o snapshot esperado dos quatro campos retorna `conflict`;
2. snapshot esperado atual + novo snapshot idêntico retorna `unchanged` sem write;
3. mudança real retorna `updated`.

`conflict` precede `unchanged`, portanto retry pós-sucesso não produz replay-success.

Cada campo efetivamente alterado gera um evento `item_changed`, em ordem lógica fixa, com old/new escalares e o mesmo `operation_at` de `contracting_items.updated_at`. Falha no primeiro, em evento intermediário ou no último evento reverte item, timestamp e eventos anteriores da tentativa.

## Least privilege

A capability F38:

- é `NOLOGIN`, `NOINHERIT`, não privilegiada e sem `BYPASSRLS`;
- não possui ownership de tabelas-base;
- possui UPDATE somente de `description`, `quantity`, `unit`, `catalog_code`, `updated_at` em `contracting_items`;
- não possui INSERT/DELETE de item;
- não altera ordinal, retired state, scope ou created_at;
- não possui UPDATE em `contractings`;
- não toca `contracting_item_ordinal_counters`;
- não atualiza/deleta eventos;
- não recebe authority F26/F29/F32/F35.

Runtime normal recebe somente `EXECUTE` por provisioning explícito e continua sem DML direto. Auth/read-only runtimes não recebem EXECUTE F38.

## Red-team

A verificação adversarial cobriu:

- capability insegura por LOGIN, SUPERUSER, CREATEROLE, BYPASSRLS ou membership utilizável;
- runtime `INHERIT` ou com DML direto;
- forged scope/actor/membership/issuer/subject/event UUID/ordinal/retired/timestamps;
- claims ausentes, malformados, desconhecidos e usuário desabilitado;
- membership revogada e segundo membro não revogado, inclusive app_user desabilitado;
- membership adicional do mesmo usuário em outro team;
- cross-team, inexistente, parent mismatch, retired, archived e cancelled;
- snapshot stale e stale com new já igual a current;
- oito writers concorrentes com o mesmo expected, com exatamente um `updated` e sete `conflict`;
- retry pós-sucesso sem duplicação de histórico;
- alteração de parent/membership enquanto writer espera o item lock;
- texto vazio/espaços, NULL e high-precision numeric;
- numeric inválido sem residue;
- falha do primeiro, intermediário e último evento com rollback integral.

O primeiro head geral de CI encontrou somente uma asserção flakey do teste novo: o teste rejeitava qualquer UUID aleatório contendo o substring `9999`, embora isso pudesse ocorrer legitimamente. O teste foi corrigido para comparar os UUIDs gerados com os quatro UUIDs forjados exatos. Nenhuma regra de produção foi relaxada.

## Verificação

Head final `3643ce63bdd9e7d0564dba7662987197610fccb5`:

- CI `35225725483`: PASS;
- F22 Private Preview Preflight `35225725558`: PASS;
- F29 Contracting Create `35225725477`: PASS;
- F32 Contracting Object Mutation `35225725555`: PASS;
- F35 Contracting Item Create `35225725650`: PASS;
- F38 Contracting Item Mutation `35225725479`: PASS.

Pós-merge em `main` `38850c8c8e4ceb41c7d1a4d0c83ba158aa20c597`:

- CI `35225868866`: PASS;
- F22 Private Preview Preflight `35225868874`: PASS;
- F29 Contracting Create `35225868945`: PASS;
- F32 Contracting Object Mutation `35225868819`: PASS;
- F35 Contracting Item Create `35225868818`: PASS;
- F38 Contracting Item Mutation `35225868927`: PASS.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- falha protegida nunca vira demo fallback;
- F38 não implementou Server Action nem UI.
