# F41 - Resultado da criação persistente mínima de identificador relacionado

**Estado:** COMPLETED / PASS  
**PR de implementação:** `#65`  
**Head promovido da implementação:** `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`  
**Merge em main:** `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`  
**Correção pós-merge de teste:** checkpoint PR `#66`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Resultado

A ADR-016 foi materializada sem Server Action ou UI.

Foram integrados:

- `database/migrations/0010_related_identifier_create.sql`;
- capability selada `compras_related_identifier_create_owner`;
- primitive `public.create_related_identifier(...)`;
- provisioning `database/provisioning/grant_related_identifier_create_runtime.sql`;
- adapter server-only `src/features/contracting-detail/persistent-related-identifier-create.ts`;
- testes unitários do adapter;
- prova SQL adversarial;
- prova PostgreSQL concorrente real;
- workflow dedicado `F41 Related Identifier Create`.

Migrations `0001..0009` permaneceram byte-for-byte imutáveis. A migration `0010` foi aditiva.

## Contrato da boundary

O adapter server-only aceita somente:

```text
contractingId: string
relatedIdentifierId: string
identifierKind: string | null
identifierValue: string
sourceSystem: string | null
note: string | null
```

O adapter gera `eventId` no servidor em cada tentativa.

Team, actor, membership, issuer, subject, `linked_at`, `unlinked_at` e timestamps não são authority do caller.

Resultados externos:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

## Autorização

A primitive usa o guard target-team pilot-only:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está visível e ativa;
3. usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive quando seu app_user está desabilitado.

Membership adicional do mesmo usuário em outra equipe não bloqueia a equipe alvo.

Q-009 permanece aberta.

## Replay e concorrência

`relatedIdentifierId` é somente identidade estável/idempotency key da intenção, nunca authority.

`already-linked` exige nova autorização e prova exata de:

- mesma row por UUID;
- mesmo team e contracting;
- `unlinked_at IS NULL`;
- textos idênticos por comparação null-safe;
- exatamente um evento canônico `related_identifier_linked`;
- actor igual à membership derivada;
- `occurred_at = linked_at`;
- `created_at = linked_at`;
- field/old/new/note/item nulos no evento.

Row sem evento, row com múltiplos eventos canônicos, row desvinculada ou payload divergente não viram replay-success.

A prova PostgreSQL real validou:

- oito chamadas concorrentes com mesmo UUID/payload;
- exatamente uma `created`;
- sete `already-linked`;
- uma única row;
- um único evento;
- mesmo UUID com payload divergente sem overwrite;
- UUIDs distintos com payload idêntico criando rows distintas.

Não existe retry cego que converta qualquer unique violation em sucesso.

## Atomicidade e auditoria

Criação de row e evento `related_identifier_linked` pertencem à mesma transação e usam o mesmo `operation_at`.

Falha de evento reverte a row.

Colisão de event UUID é falha técnica, não replay-success.

`contractings.updated_at` não é alterado para representar timeline.

## Semântica textual

A implementação não inventa regras ausentes:

- sem trim;
- sem case-folding;
- sem máscara;
- sem regex de negócio;
- sem limite de tamanho inventado;
- sem empty-to-NULL implícito;
- sem taxonomia fechada;
- sem deduplicação por valor, tipo, origem ou combinação.

`identifierValue` preserva inclusive `''` e spaces-only.

`identifierKind`, `sourceSystem` e `note` preservam `NULL`, `''`, spaces-only e leading/trailing spaces como estados distintos.

Q-003 permanece aberta.

## Least privilege

A capability F41:

- é `NOLOGIN`, `NOINHERIT`, não privilegiada e sem `BYPASSRLS`;
- não possui ownership de tabela-base;
- possui apenas leituras necessárias para identidade, guard e replay;
- possui INSERT coluna-a-coluna nas colunas aprovadas de `related_identifiers`;
- não pode inserir `unlinked_at`;
- possui INSERT coluna-a-coluna das colunas aprovadas de `contracting_events`;
- não possui UPDATE/DELETE em identificadores;
- não possui UPDATE em `contractings`;
- não possui UPDATE/DELETE em eventos;
- não possui DML em itens ou allocator;
- não possui EXECUTE das primitives F26/F29/F32/F35/F38.

As capabilities anteriores não receberam EXECUTE F41.

Runtime normal recebe somente EXECUTE explícito da primitive F41 por provisioning separado e continua sem DML direto.

## Red-team

A matriz adversarial cobriu:

- capability insegura por LOGIN, SUPERUSER, CREATEROLE, BYPASSRLS ou membership utilizável;
- runtime `INHERIT` ou com DML direto;
- claims ausentes, malformados e identidade desconhecida;
- app_user desabilitado;
- app_user ativo sem membership;
- membership revogada;
- segundo membro não revogado, inclusive app_user desabilitado;
- membership adicional do mesmo usuário em outra equipe;
- contratação cross-team, inexistente, arquivada e cancelada;
- colisão cross-team do UUID sem oracle;
- replay exato;
- mesmo UUID com payload diferente;
- row sem evento;
- row com dois eventos canônicos;
- row desvinculada;
- `NULL` versus `''`;
- string vazia, spaces-only e leading/trailing spaces;
- UUIDs distintos com payload idêntico;
- `identifierValue = NULL` rejeitado pelo contrato físico;
- colisão de event UUID com rollback integral;
- ausência de authority cruzada entre capabilities;
- ausência de DML direto na runtime;
- `contractings.updated_at` invariável;
- concorrência real.

O primeiro run F41 encontrou ambiguidade PL/pgSQL entre a variável local e a coluna `actor_membership_id`. A variável foi renomeada para `current_actor_membership_id`, sem relaxamento de segurança.

Na verificação do checkpoint pós-merge, o workflow F41 encontrou quoting inválido em três asserções do arquivo `database/tests/related_identifier_create.sql`, onde `$$...$$` havia sido materializado como `$...$`. O defeito estava restrito ao teste adversarial. Migration `0010`, primitive, grants, policies, provisioning e adapter de produção não foram alterados. As três asserções foram corrigidas.

## Verificação

Head promovido da PR `#65`, `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`:

- CI `35355476581`: PASS;
- F22 Private Preview Preflight `35355476503`: PASS;
- F29 Contracting Create `35355476516`: PASS;
- F32 Contracting Object Mutation `35355476614`: PASS;
- F35 Contracting Item Create `35355476513`: PASS;
- F38 Contracting Item Mutation `35355476539`: PASS;
- F41 Related Identifier Create `35355476626`: PASS.

Após a correção do quoting no checkpoint, o head `c61eb4a3c253e96fb347b2787d201bc5e249c36f` ficou verde em:

- CI `35356582294`: PASS;
- F22 Private Preview Preflight `35356582129`: PASS;
- F29 Contracting Create `35356581998`: PASS;
- F32 Contracting Object Mutation `35356582261`: PASS;
- F35 Contracting Item Create `35356582179`: PASS;
- F38 Contracting Item Mutation `35356582177`: PASS;
- F41 Related Identifier Create `35356581973`: PASS.

O head documental posterior `751542948b45fe4a38dfc9e8d7f0f27bc1c2d7c2` também ficou verde em todos os mesmos workflows antes desta consolidação documental.

Os blobs de migrations `0001..0009` foram comparados novamente após a promoção e permaneceram idênticos ao baseline recuperado no início da sessão. A migration `0010` permaneceu com SHA `9a1dd6fec62181c506a5efad8d5518f53cf2e154`.

Não havia review thread pendente nas PRs verificadas.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público tratado como superfície permanente;
- migrations `0001..0010` passam a ser imutáveis;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-003, Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- falha protegida nunca vira demo fallback;
- F41 não adicionou Server Action nem UI.
