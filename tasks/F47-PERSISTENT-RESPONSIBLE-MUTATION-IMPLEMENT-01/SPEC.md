# F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01 - Implementar edição persistente do responsável interno

**Classe:** T2 - banco/segurança  
**Estado:** READY após integração da F46  
**Dependências:** F46, ADR-003, ADR-004, ADR-005, ADR-011 a ADR-018, F44/F45  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

ADR-018 definiu a menor boundary persistente para editar `contractings.responsible_membership_id`. O read model já mostra responsável, mas ainda não existe primitive de escrita específica, auditável e least-privilege.

## Objetivo

Implementar somente a boundary PostgreSQL/server-only definida na ADR-018, com optimistic concurrency, clear para `NULL`, candidato elegível, evento atômico, resultados opacos e guard target-team pilot-only.

F47 não adiciona Server Action nem UI.

## Contrato público server-only

Criar interface equivalente a:

```text
mutatePersistentContractingResponsible({
  contractingId,
  expectedResponsibleMembershipId,
  newResponsibleMembershipId
})
```

Tipos:

```text
contractingId: string
expectedResponsibleMembershipId: string | null
newResponsibleMembershipId: string | null
```

Regras:

- IDs são candidatos, não authority;
- expected/new não nulos precisam ser UUIDs sintaticamente válidos;
- `NULL` é estado real e não usa string sentinela;
- event UUID é gerado server-side por tentativa;
- team, actor, issuer, subject e actor membership nunca são input.

## Implementação obrigatória

1. recuperar `main` real e confirmar F46 integrada;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente ADR-018 e esta SPEC;
4. reler SECURITY/DATABASE e migrations relevantes porque a tarefa é T2;
5. confirmar migrations `0001..0011` byte-for-byte antes de editar;
6. criar somente migration aditiva `0012_contracting_responsible_mutation.sql` ou nome equivalente ordenável;
7. criar capability dedicada equivalente a `compras_contracting_responsible_mutation_owner`;
8. aplicar lifecycle ADR-005 e postflight fail-closed;
9. conceder somente leituras mínimas de identidade, memberships, app_users e contratação;
10. conceder UPDATE somente de `responsible_membership_id` e `updated_at`;
11. conceder INSERT coluna-a-coluna somente do shape de evento aprovado;
12. criar policies RLS específicas sem ampliar policies/capabilities anteriores;
13. criar primitive `SECURITY DEFINER` com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
14. aplicar guard target-team pilot-only antes de conflict/no-op;
15. bloquear a contratação com `SELECT ... FOR UPDATE`;
16. comparar current/expected null-safe;
17. retornar `conflict` antes de no-op quando expected estiver stale;
18. retornar `unchanged` quando expected atual e new igual ao current, inclusive current degradado;
19. para mudança real não nula, exigir candidate no mesmo team, membership não revogada e app_user não desabilitado;
20. permitir mudança real para `NULL`;
21. atualizar responsável + `updated_at` e inserir exatamente um `responsible_changed` na mesma transação;
22. registrar old/new como UUID textual ou `NULL`;
23. manter note, item e related identifier nulos;
24. criar provisioning separado que conceda somente `EXECUTE` ao runtime validado;
25. criar adapter server-only reutilizando `withTrustedDatabaseMutationContext`;
26. adicionar testes unitários, matriz SQL adversarial e prova PostgreSQL concorrente real;
27. criar workflow/gate F47 compatível com os padrões F32/F38/F41/F44;
28. executar regressões aplicáveis;
29. fazer red-team integral de grants, RLS, candidate authority, concorrência e opacidade;
30. confirmar migrations `0001..0011` imutáveis após a implementação;
31. promover somente estado verde;
32. atualizar checkpoint com exatamente uma nova NEXT_ACTION.

## Primitive esperada

Forma conceitual:

```text
public.mutate_contracting_responsible(
  p_contracting_id uuid,
  p_expected_responsible_membership_id uuid,
  p_new_responsible_membership_id uuid,
  p_event_id uuid
) returns text
```

Expected/new são nullable.

Resultados internos permitidos:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

Resultados externos:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available`;
- `unavailable`.

## Event shape

Em update real:

```text
event_type = 'responsible_changed'
field_key = 'responsible_membership_id'
old_value = previous membership UUID::text ou NULL
new_value = new membership UUID::text ou NULL
note = NULL
related_identifier_id = NULL
item_id = NULL
actor_membership_id = derivado
team_id = derivado
contracting_id = target autorizado
occurred_at = operation_at
created_at = operation_at
```

`contractings.updated_at`, event `occurred_at` e event `created_at` usam o mesmo `operation_at`.

## Ordem de decisão obrigatória

Depois de input estrutural válido:

1. identidade/target/guard pilot-only;
2. lock da contratação;
3. `conflict` se current difere do expected;
4. `unchanged` se current igual ao new;
5. se new não nulo, validar candidate;
6. update + evento;
7. `updated`.

Nenhum estado protegido anterior à autorização pode produzir `conflict` ou `unchanged`.

## Candidate não nulo

Exigir:

- membership existente;
- mesmo team do target;
- `revoked_at IS NULL`;
- app_user correspondente com `disabled_at IS NULL`.

Candidate não define actor nem escopo.

Cross-team, inexistente, revogado e app_user desabilitado colapsam em `denied` e externamente `not-available`.

## Guard pilot-only

Exigir:

- current app_user ativo;
- contratação visível e ativa;
- membership não revogada do actor no target team;
- exatamente uma membership não revogada no target team.

Segundo membro não revogado bloqueia mesmo quando o app_user correspondente está desabilitado.

Membership adicional do actor em outro team não bloqueia por si só.

Q-009 permanece aberta.

## Testes obrigatórios

Além de lint, typecheck, testes e build:

1. `NULL -> actor membership` atualiza e audita;
2. `actor membership -> NULL` atualiza e audita;
3. expected stale retorna `conflict`;
4. stale permanece conflict quando new já coincide com current;
5. no-op retorna `unchanged` sem timestamp/evento;
6. current revogado pode ser limpo quando o actor permanece o único membro não revogado da equipe;
7. no-op de current revogado permanece unchanged;
8. current de app_user desabilitado com membership ainda não revogada bloqueia quando isso produz segundo membro não revogado;
9. novo candidate revogado nega;
10. novo candidate cujo app_user esteja desabilitado nega sem resultado externo específico;
11. candidate cross-team nega;
12. candidate inexistente nega;
13. target cross-team/inexistente indistinguível;
14. target archived/cancelled nega;
15. claims ausentes/malformados/desconhecidos negam;
16. app_user corrente desabilitado nega;
17. actor sem membership ou revogado nega;
18. segundo membro não revogado bloqueia;
19. segundo membro desabilitado mas não revogado também bloqueia;
20. membership do actor em outro team não bloqueia target elegível;
21. oito writers concorrentes com mesmo expected produzem 1 updated, 7 conflict e 1 evento;
22. retry pós-sucesso não duplica evento;
23. falha forçada do evento reverte update e timestamp;
24. old/new do evento preservam `NULL` e UUID textual;
25. event shape fechado e actor/team derivados;
26. runtime normal não possui DML direto;
27. capability não possui LOGIN, SUPERUSER, BYPASSRLS, ownership de tabela-base ou membership utilizável;
28. capability UPDATE limitado às duas colunas aprovadas;
29. capability não escreve membership/app_user nem UPDATE/DELETE eventos;
30. capabilities F26/F29/F32/F35/F38/F41/F44 não ganham authority F47;
31. Auth/read-only runtimes não recebem EXECUTE F47;
32. `PUBLIC EXECUTE` revogado e search_path fixo;
33. migrations `0001..0011` byte-for-byte imutáveis;
34. gates F22/F29/F32/F35/F38/F41/F44 permanecem verdes;
35. somente dados/identidades fictícios;
36. nenhum provider hosted write, secret ou dado real.

## Red-team mínimo

Rejeitar PASS se:

- browser puder escolher team, actor, issuer, subject ou actor membership;
- candidate responsável virar authority;
- assignment cross-team for possível;
- candidate revogado ou app_user desabilitado puder ser atribuído;
- segundo membro for tratado como autorização multiusuário;
- clear para `NULL` for removido sem fonte canônica;
- stale expected virar last-write-wins ou unchanged;
- runtime ganhar DML direto;
- capability conseguir UPDATE genérico de contractings;
- capability antiga ganhar grants novos;
- evento não for atômico;
- evento puder ser alterado/deletado;
- cross-team/inexistente/candidate inválido virarem oracle;
- `contractings.updated_at` mudar em no-op/negação;
- migration aplicada for reescrita;
- F47 adicionar UI/Server Action;
- Q-009 for resolvida implicitamente;
- provider hosted, secret ou dado real for necessário.

## Fora do escopo

- UI/Server Action de responsável;
- apresentação amigável do evento `responsible_changed`;
- política multiusuário definitiva;
- criação/revogação de memberships;
- etapa/status/waiting;
- arquivamento/cancelamento;
- pesquisa de preços;
- auditoria de leitura;
- F21/provider hosted;
- dado real.

## Critério de encerramento

F47 fecha quando ADR-018 estiver materializada em migration aditiva, capability least-privilege, primitive, provisioning, adapter e provas adversariais/concorrentes, com migrations anteriores imutáveis e regressões aplicáveis verdes, sem UI e sem resolver Q-009.
