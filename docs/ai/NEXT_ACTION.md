# Next Action - Compras

## F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01 - Implementar edição persistente do responsável interno

**Classe:** T2 - banco/segurança  
**Estado:** READY após integração da F46  
**Objetivo:** materializar ADR-018 em uma boundary persistente least-privilege para alterar ou limpar `contractings.responsible_membership_id`, com optimistic concurrency, candidate elegível, evento atômico e resultados opacos, sem UI ou Server Action nesta slice.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F46 integrou a decisão arquitetural e a SPEC executável. O read model já apresenta o responsável, a FK composta já impede vínculo cross-team e o diretório mínimo já define membership ativa + app_user ativo para apresentação.

O próximo passo independente é implementar somente a authority server/database. A jornada de UI fica para uma slice posterior, depois de a capability ser provada contra concorrência, RLS, least privilege e estados degradados.

## Execução obrigatória

1. recuperar `main` real e confirmar F46 integrada pela PR `#77`, merge `12ff777e94ffcd14879eea6b09fb4905e3347642`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente ADR-018 e `tasks/F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01/SPEC.md`;
4. reler SECURITY, DATABASE, ADR-003, ADR-004, ADR-005 e os precedentes F26/F32/F38 porque a tarefa é T2;
5. confirmar migrations `0001..0011` byte-for-byte antes de editar;
6. criar somente migration aditiva `0012_contracting_responsible_mutation.sql` ou nome equivalente ordenável;
7. criar capability dedicada equivalente a `compras_contracting_responsible_mutation_owner`, seguindo ADR-005;
8. conceder somente leituras mínimas de identidade, memberships, app_users e contratação;
9. conceder UPDATE somente de `responsible_membership_id` e `updated_at`;
10. conceder INSERT coluna-a-coluna somente do event shape aprovado;
11. criar policies RLS específicas sem ampliar capabilities anteriores;
12. materializar primitive `SECURITY DEFINER` com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
13. derivar current app user, actor membership e team exclusivamente do contexto confiável + banco;
14. aplicar guard target-team pilot-only antes de expor conflict/no-op;
15. bloquear a contratação e comparar current/expected com semântica null-safe;
16. manter precedência `denied -> conflict -> unchanged -> candidate validation -> updated`;
17. permitir new responsável `NULL`;
18. para new não nulo, exigir membership no mesmo team, não revogada e app_user não desabilitado;
19. tratar candidate somente como valor, nunca authority;
20. atualizar responsável + `updated_at` e inserir exatamente um `responsible_changed` na mesma transação;
21. registrar old/new como membership UUID textual ou `NULL`;
22. criar provisioning separado EXECUTE-only para runtime explicitamente validado;
23. criar adapter server-only reutilizando `withTrustedDatabaseMutationContext` e gerar event UUID no servidor;
24. manter F47 sem Server Action e sem UI;
25. implementar matriz SQL adversarial e teste PostgreSQL concorrente real;
26. provar rollback em falha do evento e ausência de evento/timestamp em conflict/unchanged/denied;
27. provar current responsável revogado corrigível somente quando o guard continua satisfeito;
28. provar que app_user desabilitado com membership ainda não revogada continua contando para o guard e não abre atalho;
29. provar candidate revogado, disabled, cross-team e inexistente negados de forma opaca;
30. provar runtime sem DML direto e capability sem grants além dos necessários;
31. executar CI, F22, F29, F32, F35, F38, F41, F44 e gate F47;
32. fazer red-team integral do diff e de grants/policies/function ownership;
33. confirmar migrations `0001..0011` imutáveis;
34. promover somente depois dos gates aplicáveis verdes;
35. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser/caller puder escolher team, actor, issuer, subject ou actor membership como authority;
- candidate responsável conceder autorização;
- assignment cross-team for possível;
- nova atribuição para membership revogada for possível;
- nova atribuição para app_user desabilitado for possível;
- segundo membro não revogado deixar de bloquear sem decisão explícita de Q-009;
- responsável for tornado obrigatório ou autoatribuído sem fonte canônica;
- clear para `NULL` for removido;
- stale expected virar `unchanged` ou last-write-wins;
- runtime normal ganhar UPDATE/INSERT direto;
- capability conseguir UPDATE genérico de `contractings`;
- capability conseguir escrever memberships/app_users;
- capabilities anteriores ganharem authority F47;
- evento deixar de ser atômico;
- evento puder sofrer UPDATE/DELETE;
- target/candidate cross-team ou inexistente virar oracle;
- no-op/denied alterar `updated_at`;
- migration `0001..0011` for reescrita;
- F47 adicionar UI/Server Action;
- Q-009 for resolvida implicitamente;
- falha protegida cair para demo;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0011` permanecem imutáveis;
- F47 não inclui UI nem Server Action.

## Fonte da tarefa

Executar:

`tasks/F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01/SPEC.md`.

Decisão canônica:

`docs/decisions/ADR-018-persistent-responsible-mutation.md`.

## Critério de encerramento

F47 fecha quando ADR-018 estiver implementada por migration aditiva, capability selada, primitive estreita, provisioning EXECUTE-only, adapter server-only e provas adversariais/concorrentes, com estado+evento atômicos, expected-value concurrency, candidate elegível, resultados opacos, migrations anteriores imutáveis e regressões verdes, sem UI e sem resolver Q-009.
