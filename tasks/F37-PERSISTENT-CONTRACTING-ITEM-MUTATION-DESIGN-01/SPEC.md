# F37-PERSISTENT-CONTRACTING-ITEM-MUTATION-DESIGN-01 - Desenhar edição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** COMPLETED / DESIGN PASS  
**Dependências:** F31/F32/F33, ADR-014, F35/F36, fundação `contracting_items`, SECURITY, DATABASE e modelo de domínio  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Resultado

F37 foi concluída como slice exclusivamente de desenho.

Artefatos produzidos:

- `docs/decisions/ADR-015-minimal-persistent-contracting-item-mutation.md`;
- `tasks/F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01/SPEC.md`.

Nenhuma primitive, policy, grant, adapter, Server Action ou UI da mutação F38 foi implementada nesta work unit.

Antes do desenho, a frente ativa `repair-f29-concurrency-conflict` foi recuperada. A PR #56 corrigiu de forma aditiva a corrida concorrencial da F29 por `database/migrations/0008_contracting_create_concurrency_repair.sql`, sem reescrever `0001..0007`. O red-team da própria correção encontrou e corrigiu a necessidade de `CREATE` temporário no schema durante `CREATE OR REPLACE FUNCTION`, com revogação e postflight antes do commit. Depois dos gates verdes, a PR foi integrada em `main`.

A partir desse ponto, migrations `0001..0008` passam a ser histórico aplicado imutável para a F38. A implementação da ADR-015 está prevista em `0009`.

Q-004 e Q-009 permanecem abertas. F21 permanece `ON HOLD`.

## Recuperação e contexto

A work unit:

- recuperou `main` e a branch de reparo F29 ativa;
- revalidou os 10 blobs do `CONTEXT_MANIFEST` sem divergência;
- inspecionou ADR-013 e ADR-014;
- inspecionou F31/F32/F33 e F34/F35/F36;
- inspecionou o schema físico de `contracting_items` e `contracting_events`;
- inspecionou o read model persistente, que transporta `quantity::text` e filtra itens `retired_at IS NULL`;
- inspecionou as capabilities F32 e F35 como precedentes de optimistic concurrency, guard target-team, allocator e auditoria.

`CONTEXT_STATUS = VALID` permaneceu verdadeiro.

## Decisão canônica

A decisão foi registrada na ADR-015.

A primeira edição persistente de item será uma mutação atômica do snapshot completo dos quatro campos editáveis:

- `description`;
- `quantity`;
- `unit`;
- `catalog_code`.

A boundary recebe `contractingId + itemId`, os quatro valores esperados e os quatro valores novos. `team_id`, actor, membership, issuer, subject, ordinal, retired state, timestamps e event UUIDs não são authority do browser.

O binding `contractingId + itemId` evita confused deputy entre contratações da mesma equipe sem transformar esses IDs em autorização.

## Semântica dos campos

### Texto

Não há trim, normalização, tamanho máximo inventado ou empty-to-NULL.

- `description` continua `NOT NULL`, mas `''` e spaces-only permanecem válidos;
- `unit` e `catalog_code` preservam distintamente `NULL`, `''`, spaces-only e leading/trailing spaces.

### Numeric

`quantity` permanece:

- `numeric NULL` no PostgreSQL;
- `string | null` na interface TypeScript.

Não há `Number`, `parseFloat` ou coerção floating-point. A comparação concorrente ocorre no PostgreSQL e a auditoria textual usa `numeric::text` do valor de banco.

Nenhuma regra de positividade, required, escala máxima, precisão de negócio ou vínculo com unidade foi criada.

Numeric textual inválido deve falhar fechado como `unavailable`, sem update/evento e sem detalhe do cast.

## Optimistic concurrency

A ADR-015 adota snapshot completo para impedir lost update entre campos diferentes.

A implementação F38 deve:

1. autorizar e bloquear a row do item com `SELECT ... FOR UPDATE`;
2. comparar os quatro valores atuais com os quatro expected usando semântica null-safe;
3. retornar `conflict` se qualquer expected estiver stale;
4. somente depois avaliar `unchanged`;
5. atualizar quando houver mudança real.

`conflict` vence `unchanged`. Retry pós-sucesso fica stale e retorna `conflict`, sem segundo conjunto de eventos.

No-op não altera `updated_at` e não cria evento.

Nenhuma version column foi adicionada ao desenho.

## Autorização pilot-only

A autorização segue F26/F32/F35 por equipe alvo:

1. identidade interna ativa;
2. item `itemId` pertence ao `contractingId` candidato e está no scope RLS;
3. item não está retirado;
4. parent está no mesmo team e não está arquivado/cancelado;
5. usuário possui membership não revogada no team alvo;
6. team possui exatamente uma membership não revogada.

Segundo membro bloqueia inclusive quando o app_user correspondente estiver desabilitado. Outra membership do mesmo usuário em outro team não bloqueia por si só.

A implementação deve revalidar parent/membership após o lock do item e manter RLS como enforcement final no update/evento para fechar mudanças concorrentes de autorização.

Cross-team, inexistente, parent mismatch, retired e demais negações permanecem externamente indistinguíveis.

Q-009 continua aberta.

## Capability e least privilege

F38 terá owner dedicado equivalente a:

`compras_contracting_item_mutation_owner`

A role será selada, `NOLOGIN`, `NOINHERIT`, não privilegiada, sem ownership de tabelas-base e sem membership utilizável.

Authority máxima:

- SELECT mínimo de identidade/membership/parent/item;
- UPDATE somente `description`, `quantity`, `unit`, `catalog_code`, `updated_at` em item;
- INSERT coluna-a-coluna somente dos eventos aprovados;
- EXECUTE de helpers necessários.

Sem:

- INSERT/DELETE de item;
- UPDATE de scope, ordinal, created/retired state;
- UPDATE em `contractings`;
- privilege no allocator F35;
- UPDATE/DELETE de eventos;
- expansão de F26/F29/F32/F35.

Runtime normal recebe somente EXECUTE da primitive F38 por provisioning separado.

## Auditoria

O red-team rejeitou serialização JSON inventada de before/after.

O schema já modela alteração escalar com `field_key`, `old_value` e `new_value`, então a decisão final gera um evento por campo realmente alterado:

- `event_type = 'item_changed'`;
- `item_id = item alvo`;
- `field_key` em `description`, `quantity`, `unit`, `catalog_code`;
- old/new do campo;
- actor/team/contracting derivados;
- mesmo `operation_at` do `updated_at`;
- `note` e `related_identifier_id` nulos.

Uma mudança de N campos gera exatamente N eventos, de 1 a 4. No-op gera zero.

Para permitir IDs independentes sem extensão de UUID no banco, o adapter F38 gera quatro event UUIDs server-side, mapeados fixamente aos quatro campos. Eles nunca chegam do browser.

Falha de qualquer evento reverte update, timestamp e todos os eventos da tentativa.

`contractings.updated_at` permanece inalterado.

## Resultados sanitizados

Primitive:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

Adapter:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para negação;
- `unavailable` para falha técnica/configuração/conexão/numeric inválido/driver/resultado impossível.

`conflict` e `unchanged` só aparecem depois da autorização.

## Red-team documental

A decisão foi rejeitada se permitisse:

- authority de browser para team/actor/membership/issuer/subject/ordinal/retired/timestamp/event UUID;
- `itemId` ignorar o binding com `contractingId`;
- item retired ou parent inativo ser mutável;
- cross-team/inexistente virar oracle;
- segundo membro liberar política multiusuário;
- guard global F29 ser copiado por conveniência;
- runtime receber DML direto;
- F26/F29/F32/F35 serem ampliadas;
- capability tocar allocator ou `contractings`;
- trim, normalização ou empty-to-NULL;
- quantity passar por Number/parseFloat;
- regra de positividade/escala/precisão inventada;
- stale snapshot parcial virar last-write-wins;
- stale expected virar unchanged porque new coincide com current;
- no-op criar timestamp/evento;
- evento falho deixar update parcial;
- audit JSON opaco substituir eventos escalares;
- retry pós-sucesso criar segundo evento;
- `contractings.updated_at` ser alterado;
- migrations `0001..0008` serem reescritas;
- provider hosted, secret ou dado real.

Nenhum desses caminhos foi aceito.

## Matriz adversarial transferida para F38

A SPEC F38 exige provas de:

- alteração isolada e multi-campo;
- N campos alterados = N eventos;
- semântica exata de texto/null;
- numeric válido de alta precisão sem float JS e numeric inválido fail-closed;
- stale snapshot e conflito antes de no-op;
- 8 writers concorrentes com um único vencedor;
- retry pós-sucesso sem duplicação;
- rollback quando primeiro/intermediário/último evento falha;
- identidade/membership/cross-team/retired/inactive parent;
- segundo membro e membership adicional em outro team;
- least privilege e isolamento entre capabilities;
- migrations aplicadas imutáveis;
- regressões F22/F29/F32/F35/Auth/CI.

## Fora do escopo preservado

- implementation SQL/code da F38;
- Server Action/UI de edição;
- ordinal/reorder;
- retire/restore;
- delete;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- regra nova de quantidade/unidade/catálogo;
- provider hosted;
- retomada F21;
- dado real.

## Próxima ação

A única próxima ação prevista após promoção desta F37 é:

`F38-PERSISTENT-CONTRACTING-ITEM-MUTATION-IMPLEMENT-01 - Implementar edição persistente mínima de item`.

## Critério de encerramento

F37 está materialmente encerrada quando ADR-015 e a SPEC F38 estiverem integradas, com red-team documental concluído, migrations aplicadas preservadas e gates da PR/main verdes. O checkpoint canônico só deve ser atualizado depois dos gates verdes da branch de desenho.
