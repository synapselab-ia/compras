# F31-PERSISTENT-CONTRACTING-OBJECT-MUTATION-DESIGN-01 - Desenhar edição persistente do objeto

**Classe:** T2 - fronteira de autorização e mutação persistente  
**Estado:** COMPLETED / DESIGN PASS  
**Dependências:** F25, F26, F27, F29, F30, ADR-011 e ADR-012  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema resolvido

Após F30, a aplicação permite criar uma contratação persistente com `object`, mas esse campo ainda não possui boundary própria de edição. F31 precisava decidir a menor authority segura sem ampliar F26, F29 ou conceder DML direto ao runtime.

## Recuperação e contexto

A work unit recuperou `main` em `ac0162677f39d1f176ad5a9e0c431770c3d3d204`, confirmou ausência de PR/branch F31 ativa e revalidou os 10 blobs do `CONTEXT_MANIFEST` sem divergência.

Foram inspecionados diretamente:

- ADR-011 e ADR-012;
- SECURITY e DATABASE;
- F25/F26/F27/F29/F30;
- migrations `0004_next_action_mutation.sql` e `0005_contracting_create.sql`;
- matrizes PostgreSQL F26/F29;
- adapters e Server Actions F26/F27/F29/F30;
- Q-009 em `OPEN_QUESTIONS.md`.

Migrations `0001..0005` permaneceram intocadas.

## Decisão

A decisão canônica foi registrada em `docs/decisions/ADR-013-persistent-contracting-object-mutation.md`.

Foi adotada capability PostgreSQL própria para editar exclusivamente `contractings.object`, em vez de:

- ampliar F26;
- ampliar F29;
- conceder DML direto ao runtime.

A futura primitive recebe conceitualmente somente:

```text
contractingId
expectedObject
newObject
eventId server-only
```

O browser nunca fornece team, actor, membership, creator, issuer, subject ou event UUID confiável.

## Semântica de `object`

`object` permanece `text NOT NULL` e deve ser preservado exatamente:

- sem trim;
- sem limite de tamanho inventado;
- sem regra non-empty;
- sem empty-to-NULL;
- string vazia e espaços continuam valores válidos.

A mutação só pode atualizar `object` e `updated_at`.

## Autorização pilot-only

A autorização segue F26 porque uma linha existente já possui `team_id` canônico:

1. identidade corrente resolve para `app_user` ativo;
2. contratação existe no escopo autorizado;
3. contratação não está arquivada/cancelada;
4. usuário possui membership não revogada na equipe alvo;
5. a equipe alvo possui exatamente uma membership não revogada.

Segundo membro não revogado bloqueia, inclusive se seu `app_user` estiver desabilitado.

Uma membership adicional do mesmo usuário em outra equipe não bloqueia por si só. Copiar o guard global de F29 seria incorreto porque esse guard existe para derivar o team antes do `INSERT`. Q-009 continua aberta.

## Concorrência e retry

A ADR definiu:

- `SELECT ... FOR UPDATE`;
- precondição exata/null-safe de `expectedObject`;
- `conflict` avaliado antes de `unchanged`;
- no-op sem `updated_at` novo e sem evento;
- sem coluna de versão nesta slice.

Duas chamadas concorrentes com o mesmo expected antigo produzem no máximo um update/evento; as demais retornam `conflict`.

Retry idêntico depois de sucesso não é replay-success como F29: expected fica stale, portanto a repetição retorna `conflict` e não cria segundo evento. Essa semântica preserva o padrão F26 e evita sucesso causalmente ambíguo.

## Histórico e atomicidade

Mudança real deve criar exatamente um evento:

- `event_type = 'object_changed'`;
- `field_key = 'object'`;
- `old_value` e `new_value` exatos;
- actor/team/contracting derivados do banco;
- mesmo instante para `updated_at`, `occurred_at` e `created_at`;
- campos auxiliares nulos.

Falha do evento reverte o update. Eventos permanecem append-only.

## Least privilege

A implementação deve criar owner técnico próprio equivalente a `compras_contracting_object_mutation_owner`, `NOLOGIN`, `NOINHERIT`, não privilegiado, sem ownership de tabelas-base e sem membership utilizável.

A primitive será `SECURITY DEFINER`, `search_path = pg_catalog`, SQL estático, `PUBLIC EXECUTE` revogado. O runtime recebe somente `EXECUTE` por provisionamento separado.

F26 continua sem authority de `object`; F29 continua sem authority de atualização de linhas existentes.

## Resultados externos

A boundary futura expõe somente:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para negação;
- `unavailable` para falha técnica.

Cross-team, inexistente, identidade inválida, falta/revogação de membership, segundo membro e contratação arquivada/cancelada colapsam em `not-available`. `conflict` e `unchanged` só aparecem depois de autorização.

## Red-team documental

A decisão foi rejeitada se permitisse:

- browser controlar identity/scope/actor/event UUID;
- F26/F29 ganhar authority adicional;
- runtime receber DML direto;
- capability alterar colunas além de `object`/`updated_at`;
- update sem evento atômico;
- trim/normalização/empty-to-NULL inventados;
- stale write virar last-write-wins;
- stale expected virar `unchanged` apenas porque `newObject` coincide com estado atual;
- side channel cross-team;
- segundo membro virar política multiusuário;
- guard global de criação F29 ser copiado sem necessidade;
- migration aplicada ser reescrita;
- provider hosted, secret ou dado real.

Nenhum desses caminhos foi aceito no desenho final.

## Verificação desta work unit

F31 é design-only, portanto não houve migration, SQL, adapter, Server Action ou UI nova para executar contra PostgreSQL.

A verificação aplicável consiste em:

- `CONTEXT_MANIFEST`: VALID;
- consistência explícita com ADR-011/ADR-012;
- consistência com SECURITY/DATABASE;
- comparação de alternativas e authority;
- matriz adversarial detalhada para F32;
- diff documental somente PUBLIC/FICTITIOUS;
- migrations `0001..0005` intocadas.

Os gates automatizados da PR devem permanecer verdes antes da promoção.

## Artefatos

Criado:

- `docs/decisions/ADR-013-persistent-contracting-object-mutation.md`;
- `tasks/F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01/SPEC.md`.

Atualizados:

- este SPEC;
- `docs/00-START-HERE.md`;
- `docs/ai/CURRENT_STATE.md`;
- `docs/ai/NEXT_ACTION.md`.

## Fora do escopo preservado

- migration/primitive/adapters de F32;
- UI/Server Action de edição;
- `next_action`, stage, status, responsável ou waiting;
- itens/identificadores;
- arquivamento/cancelamento;
- política multiusuário;
- retomada F21;
- provider hosted;
- dado real.

## Próxima ação

A única próxima ação canônica é:

`F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01 - Implementar boundary persistente de edição do objeto`.

## Critério de encerramento

F31 está encerrada quando ADR-013 e a SPEC F32 estiverem integradas, com a decisão fechada, red-team documental concluído e gates da PR/main verdes.