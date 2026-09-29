# F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01 - Resultado

**Estado:** CONCLUÍDA E INTEGRADA  
**PR:** #79  
**Head validado:** `b4c86ec71016a1c33d6825e9420a91a2b7f330db`  
**Merge em main:** `4e7bb411205469977878e01cb04ea35d5ad50401`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Entrega

F47 materializou a ADR-018 como uma boundary persistente específica para alterar ou limpar `contractings.responsible_membership_id`, sem Server Action e sem UI.

Foram integrados:

- migration aditiva `0012_contracting_responsible_mutation.sql`;
- capability selada `compras_contracting_responsible_mutation_owner`;
- primitive `public.mutate_contracting_responsible(uuid, uuid, uuid, uuid)`;
- provisioning separado com EXECUTE-only para o runtime validado;
- adapter server-only `mutatePersistentContractingResponsible`;
- teste unitário do adapter;
- matriz SQL adversarial;
- prova PostgreSQL concorrente real;
- workflow dedicado `F47 Contracting Responsible Mutation`.

Migrations `0001..0011` permaneceram byte-for-byte imutáveis. A migration `0012` é estritamente aditiva.

## Contrato server-only

O adapter aceita somente:

```text
contractingId: string
expectedResponsibleMembershipId: string | null
newResponsibleMembershipId: string | null
```

IDs não nulos precisam ser UUIDs sintaticamente válidos.

Team, actor, issuer, subject e actor membership não são aceitos como input. O UUID do evento é gerado no servidor a cada tentativa.

Resultados externos:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

O resultado interno `denied` é colapsado para `not-available`.

## Autorização e candidate

A primitive mantém o guard target-team pilot-only:

1. current app_user ativo;
2. contratação alvo ativa;
3. actor com membership não revogada no target team;
4. exatamente uma membership não revogada no target team.

Membership adicional do actor em outro team não bloqueia por si só.

Segundo membro não revogado no target team bloqueia, inclusive quando o app_user correspondente está desabilitado.

Para novo responsável não nulo, a candidate membership precisa:

- existir;
- pertencer ao mesmo team da contratação;
- não estar revogada;
- apontar para app_user não desabilitado.

A candidate nunca concede authority.

Q-009 permanece aberta.

## Concorrência e ordem de decisão

A primitive aplica a ordem:

1. identidade, target e guard;
2. lock da contratação com `SELECT ... FOR UPDATE`;
3. `conflict` quando current difere do expected com semântica null-safe;
4. `unchanged` quando current coincide com new;
5. validação da candidate não nula;
6. update e evento atômico;
7. `updated`.

Isso impede stale write e garante que retry com expected antigo continue sendo `conflict`, mesmo quando o valor solicitado já coincide com o estado atual.

A prova PostgreSQL real executou oito writers concorrentes com o mesmo expected:

- 1 `updated`;
- 7 `conflict`;
- exatamente 1 evento persistido.

Retry posterior com o mesmo expected retornou `conflict` sem duplicar evento.

## Estado degradado

Foram preservadas as decisões da ADR-018:

- responsável atual apontando para membership revogada pode permanecer em no-op ou ser limpo quando o actor segue sendo o único membro não revogado da equipe;
- nova atribuição para essa membership revogada é negada;
- responsável atual apontando para app_user desabilitado cuja membership continua não revogada conta para o guard e não cria atalho de correção;
- clear para `NULL` é operação real permitida.

## Evento atômico

Em mudança real, é gravado exatamente um evento:

```text
event_type = 'responsible_changed'
field_key = 'responsible_membership_id'
old_value = UUID textual anterior ou NULL
new_value = UUID textual novo ou NULL
note = NULL
related_identifier_id = NULL
item_id = NULL
actor_membership_id = derivado
team_id = derivado
contracting_id = target autorizado
occurred_at = operation_at
created_at = operation_at
```

`contractings.updated_at`, `occurred_at` e `created_at` compartilham o mesmo `operation_at`.

Falha forçada no INSERT do evento foi provada como rollback do update e do timestamp.

## Least privilege

A capability F47:

- é `NOLOGIN`, `NOINHERIT`, sem `SUPERUSER`, `BYPASSRLS` ou ownership de tabela-base;
- possui somente as leituras necessárias para identidade, guard, target e candidate;
- possui UPDATE apenas de `responsible_membership_id` e `updated_at`;
- possui INSERT coluna-a-coluna apenas para o shape aprovado de `contracting_events`;
- não escreve `memberships` nem `app_users`;
- não possui UPDATE/DELETE de eventos;
- não recebe authority de outras capabilities e não amplia as capabilities F26/F29/F32/F35/F38/F41/F44.

O runtime normal recebe somente EXECUTE da primitive por provisioning separado e continua sem DML direto.

Auth e read-only runtimes não recebem EXECUTE F47.

## Red-team

A implementação e as provas rejeitam:

- team, actor ou identidade controlados pelo caller;
- candidate responsável como authority;
- assignment cross-team;
- candidate inexistente, revogada ou incompatível;
- app_user desabilitado como nova candidate;
- segundo membro não revogado como autorização multiusuário;
- last-write-wins;
- stale expected convertido em `unchanged`;
- UPDATE genérico de `contractings`;
- DML direto do runtime;
- escrita de identidade/membership pela capability;
- evento não atômico ou mutável;
- target cross-team/inexistente como oracle;
- target arquivado/cancelado;
- claims ausentes, malformados ou desconhecidos;
- app_user corrente desabilitado;
- actor sem membership válida;
- alteração de migrations já aplicadas;
- UI ou Server Action antecipados;
- resolução implícita de Q-009;
- provider hosted, secret ou dado real.

A inspeção final do diff da PR #79 encontrou exatamente sete arquivos novos da F47 e nenhuma alteração em arquivo anterior.

Não havia review thread, review pendente ou comentário na PR antes da promoção.

## Verificação

Head final `b4c86ec71016a1c33d6825e9420a91a2b7f330db`:

- CI `36583612708`: PASS;
- F22 Private Preview Preflight `36583612785`: PASS;
- F29 Contracting Create `36583612773`: PASS;
- F32 Contracting Object Mutation `36583612662`: PASS;
- F35 Contracting Item Create `36583612851`: PASS;
- F38 Contracting Item Mutation `36583612588`: PASS;
- F41 Related Identifier Create `36583612637`: PASS;
- F44 Manual Timeline Note Create `36583612716`: PASS;
- F47 Contracting Responsible Mutation `36583612741`: PASS.

O workflow F47 valida também os blobs imutáveis de `0001..0011`.

A nova migration aplicada possui blob:

- `0012_contracting_responsible_mutation.sql`: `1635b6874cc3bd7f044b3c6ecff8423e14442e80`.

A partir desta integração, migrations `0001..0012` formam o baseline aplicado e imutável.

## Invariantes preservados

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público tratado como superfície permanente;
- F21 permanece `ON HOLD`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- falha protegida nunca vira demo fallback;
- F47 não adicionou Server Action nem UI.
