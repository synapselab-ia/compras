# F41 - Resultado da criação persistente mínima de identificador relacionado

**Estado:** COMPLETED / PASS  
**PR:** `#65`  
**Head da implementação promovida:** `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`  
**Merge em main:** `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`  
**Head de correção/verificação pós-merge:** `c61eb4a3c253e96fb347b2787d201bc5e249c36f`  
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

Migrations `0001..0009` permaneceram byte-for-byte imutáveis. Após a promoção, `0001..0010` passam a compor o histórico aplicado que não deve ser reescrito.

## Boundary final

O contrato server-only aceita somente:

```text
contractingId: string
relatedIdentifierId: string
identifierKind: string | null
identifierValue: string
sourceSystem: string | null
note: string | null
```

O adapter gera `eventId` server-side em cada tentativa. Team, actor, membership, issuer, subject, `linked_at`, `unlinked_at` e timestamps não são authority do caller.

`relatedIdentifierId` é UUID preparado/idempotency key da intenção, não segredo e não autorização.

Resultados externos permanecem limitados a:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

## Autorização e replay

A primitive usa o guard target-team pilot-only:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está visível e ativa;
3. usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive quando seu app_user está desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia a equipe alvo.

Replay `already-linked` só ocorre depois da autorização atual e da prova conjunta de:

- mesma row por UUID;
- mesmo team e contracting;
- `unlinked_at IS NULL`;
- textos exatos por comparação null-safe;
- exatamente um evento canônico `related_identifier_linked`;
- actor igual à membership derivada;
- `occurred_at = linked_at`;
- `created_at = linked_at`;
- field/old/new/note/item nulos no evento.

Row sem evento, row com múltiplos eventos canônicos, row desvinculada ou payload divergente retornam `denied`, que o adapter converte para `not-available`.

## Concorrência e atomicidade

A criação usa o UUID preparado sem deduplicação textual.

A prova PostgreSQL real validou:

- oito chamadas concorrentes com o mesmo UUID e payload;
- exatamente uma `created`;
- sete `already-linked`;
- uma única row;
- um único evento;
- mesmo UUID com payload divergente sem overwrite, produzindo uma criação e uma negação;
- UUIDs distintos com o mesmo payload criando rows distintas.

Row e evento usam o mesmo `operation_at` e pertencem à mesma transação. Colisão de event UUID falha tecnicamente e reverte a row. `contractings.updated_at` não é alterado para representar timeline.

## Semântica textual

A implementação preserva integralmente o contrato físico/canônico atual:

- sem trim;
- sem upper/lowercase;
- sem máscara;
- sem regex de negócio;
- sem limite de tamanho inventado;
- sem empty-to-NULL implícito;
- sem taxonomia fechada;
- sem deduplicação por valor, tipo, origem ou combinação.

`identifierValue` preserva inclusive `''` e spaces-only.

`identifierKind`, `sourceSystem` e `note` preservam `NULL`, `''`, spaces-only e leading/trailing spaces como estados distintos.

## Least privilege

A capability F41:

- é `NOLOGIN`, `NOINHERIT`, não privilegiada e sem `BYPASSRLS`;
- não possui ownership de tabelas-base;
- possui apenas leituras necessárias para identidade, guard e prova de replay;
- possui INSERT coluna-a-coluna nas colunas aprovadas de `related_identifiers`;
- não pode inserir `unlinked_at`;
- possui INSERT coluna-a-coluna do evento canônico;
- não possui UPDATE/DELETE em identificadores;
- não possui UPDATE em `contractings`;
- não possui UPDATE/DELETE em eventos;
- não possui DML em itens ou allocator;
- não possui EXECUTE das primitives F26/F29/F32/F35/F38.

As capabilities anteriores não receberam EXECUTE F41.

Runtime normal recebe apenas EXECUTE explícito da primitive F41 pelo provisioning separado e continua sem DML direto de domínio.

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
- colisão global de UUID existente em outra equipe sem oracle;
- replay exato;
- mesmo UUID com payload diferente;
- row sem evento canônico;
- row com dois eventos canônicos;
- row desvinculada;
- `NULL` versus `''`;
- string vazia, spaces-only e leading/trailing spaces;
- UUIDs distintos com payload textual idêntico;
- `identifierValue = NULL` rejeitado pelo contrato físico;
- colisão de event UUID com rollback integral;
- ausência de authority cruzada entre capabilities;
- ausência de DML direto na runtime;
- `contractings.updated_at` invariável;
- concorrência real de mesmo UUID e de payload divergente.

O primeiro run F41 encontrou ambiguidade PL/pgSQL entre a variável local e a coluna `actor_membership_id` durante a prova de replay. A variável foi renomeada para `current_actor_membership_id`, sem relaxar regra de segurança. Depois disso, o red-team foi ampliado com caso explícito de app_user ativo sem membership e diferenciação `NULL` versus `''`.

Na verificação do checkpoint pós-merge, o workflow F41 detectou erro de quoting em três asserções recém-adicionadas do arquivo de teste SQL: `$...$` havia sido materializado como `$...# F41 - Resultado da criação persistente mínima de identificador relacionado

**Estado:** COMPLETED / PASS  
**PR:** `#65`  
**Head da implementação promovida:** `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`  
**Merge em main:** `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`  
**Head de correção/verificação pós-merge:** `c61eb4a3c253e96fb347b2787d201bc5e249c36f`  
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

Migrations `0001..0009` permaneceram byte-for-byte imutáveis. Após a promoção, `0001..0010` passam a compor o histórico aplicado que não deve ser reescrito.

## Boundary final

O contrato server-only aceita somente:

```text
contractingId: string
relatedIdentifierId: string
identifierKind: string | null
identifierValue: string
sourceSystem: string | null
note: string | null
```

O adapter gera `eventId` server-side em cada tentativa. Team, actor, membership, issuer, subject, `linked_at`, `unlinked_at` e timestamps não são authority do caller.

`relatedIdentifierId` é UUID preparado/idempotency key da intenção, não segredo e não autorização.

Resultados externos permanecem limitados a:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

## Autorização e replay

A primitive usa o guard target-team pilot-only:

1. identidade confiável resolve app_user ativo;
2. contratação candidata está visível e ativa;
3. usuário possui membership não revogada na equipe alvo;
4. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive quando seu app_user está desabilitado. Membership adicional do mesmo usuário em outra equipe não bloqueia a equipe alvo.

Replay `already-linked` só ocorre depois da autorização atual e da prova conjunta de:

- mesma row por UUID;
- mesmo team e contracting;
- `unlinked_at IS NULL`;
- textos exatos por comparação null-safe;
- exatamente um evento canônico `related_identifier_linked`;
- actor igual à membership derivada;
- `occurred_at = linked_at`;
- `created_at = linked_at`;
- field/old/new/note/item nulos no evento.

Row sem evento, row com múltiplos eventos canônicos, row desvinculada ou payload divergente retornam `denied`, que o adapter converte para `not-available`.

## Concorrência e atomicidade

A criação usa o UUID preparado sem deduplicação textual.

A prova PostgreSQL real validou:

- oito chamadas concorrentes com o mesmo UUID e payload;
- exatamente uma `created`;
- sete `already-linked`;
- uma única row;
- um único evento;
- mesmo UUID com payload divergente sem overwrite, produzindo uma criação e uma negação;
- UUIDs distintos com o mesmo payload criando rows distintas.

Row e evento usam o mesmo `operation_at` e pertencem à mesma transação. Colisão de event UUID falha tecnicamente e reverte a row. `contractings.updated_at` não é alterado para representar timeline.

## Semântica textual

A implementação preserva integralmente o contrato físico/canônico atual:

- sem trim;
- sem upper/lowercase;
- sem máscara;
- sem regex de negócio;
- sem limite de tamanho inventado;
- sem empty-to-NULL implícito;
- sem taxonomia fechada;
- sem deduplicação por valor, tipo, origem ou combinação.

`identifierValue` preserva inclusive `''` e spaces-only.

`identifierKind`, `sourceSystem` e `note` preservam `NULL`, `''`, spaces-only e leading/trailing spaces como estados distintos.

## Least privilege

A capability F41:

- é `NOLOGIN`, `NOINHERIT`, não privilegiada e sem `BYPASSRLS`;
- não possui ownership de tabelas-base;
- possui apenas leituras necessárias para identidade, guard e prova de replay;
- possui INSERT coluna-a-coluna nas colunas aprovadas de `related_identifiers`;
- não pode inserir `unlinked_at`;
- possui INSERT coluna-a-coluna do evento canônico;
- não possui UPDATE/DELETE em identificadores;
- não possui UPDATE em `contractings`;
- não possui UPDATE/DELETE em eventos;
- não possui DML em itens ou allocator;
- não possui EXECUTE das primitives F26/F29/F32/F35/F38.

As capabilities anteriores não receberam EXECUTE F41.

Runtime normal recebe apenas EXECUTE explícito da primitive F41 pelo provisioning separado e continua sem DML direto de domínio.

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
- colisão global de UUID existente em outra equipe sem oracle;
- replay exato;
- mesmo UUID com payload diferente;
- row sem evento canônico;
- row com dois eventos canônicos;
- row desvinculada;
- `NULL` versus `''`;
- string vazia, spaces-only e leading/trailing spaces;
- UUIDs distintos com payload textual idêntico;
- `identifierValue = NULL` rejeitado pelo contrato físico;
- colisão de event UUID com rollback integral;
- ausência de authority cruzada entre capabilities;
- ausência de DML direto na runtime;
- `contractings.updated_at` invariável;
- concorrência real de mesmo UUID e de payload divergente.

. O defeito estava somente no teste adversarial, não em migration, primitive, grants, policies, provisioning ou adapter de produção. As três asserções foram corrigidas em `database/tests/related_identifier_create.sql` e a suíte completa voltou a ficar verde.

## Verificação

Head promovido da PR `#65`, `24fccfbd9a58a7ddfd265b7f6b3ec05646e583e0`:

- CI `35355476581`: PASS;
- F22 Private Preview Preflight `35355476503`: PASS;
- F29 Contracting Create `35355476516`: PASS;
- F32 Contracting Object Mutation `35355476614`: PASS;
- F35 Contracting Item Create `35355476513`: PASS;
- F38 Contracting Item Mutation `35355476539`: PASS;
- F41 Related Identifier Create `35355476626`: PASS.

A comparação `main...head` antes da promoção mostrou somente os sete artefatos novos da F41. Os blobs de migrations `0001..0009` foram comparados novamente em `main` após o merge e permaneceram idênticos aos hashes baseline recuperados no início da sessão.

PR `#65` integrada por merge commit `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`.

A verificação de checkpoint posterior encontrou somente o quoting incorreto das três asserções SQL descritas acima. No head corrigido `c61eb4a3c253e96fb347b2787d201bc5e249c36f`, os gates observados foram:

- CI `35356582294`: PASS;
- F22 Private Preview Preflight `35356582129`: PASS;
- F29 Contracting Create `35356581998`: PASS;
- F32 Contracting Object Mutation `35356582261`: PASS;
- F35 Contracting Item Create `35356582179`: PASS;
- F38 Contracting Item Mutation `35356582177`: PASS;
- F41 Related Identifier Create `35356581973`: PASS.

O conector GitHub disponível expõe runs associados ao evento de pull request, mas não fornece readback dos runs de push do merge commit. O checkpoint usa o head corrigido acima como evidência executável pós-merge da suíte F41, sem afirmar um run de push que o conector não consegue ler.

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
