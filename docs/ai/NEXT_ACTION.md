# Next Action - Compras

## F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01 - Implementar boundary persistente de edição do objeto

**Classe:** T1 - feature normal, com impacto T2 - banco/autorização  
**Estado:** READY AFTER F31 PROMOTION  
**Objetivo:** materializar ADR-013 em uma capability PostgreSQL/server-only exclusiva para editar `contractings.object`, com optimistic concurrency, evento atômico, autorização pilot-only, least privilege e resultados sanitizados.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F31 fecha o desenho de edição de `object` sem ampliar F26 ou F29. A decisão estabelece capability própria, payload mínimo, concorrência por expected value, histórico atômico e isolamento de authority.

A próxima slice deve implementar somente a boundary PostgreSQL/server-only. UI/Server Action fica para work unit posterior.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F32.

## Execução obrigatória

1. recuperar o estado canônico após F31 e revalidar `CONTEXT_MANIFEST`;
2. ler ADR-013 e a SPEC `tasks/F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01/SPEC.md`;
3. inspecionar migrations/provisionamentos/testes F26/F29 e `withTrustedDatabaseMutationContext`;
4. manter migrations `0001..0005` imutáveis;
5. criar nova migration `0006_...sql` com capability owner dedicado e não privilegiado;
6. criar primitive estreita `SECURITY DEFINER` equivalente a `mutate_contracting_object(uuid,text,text,uuid)` com `search_path = pg_catalog` e `PUBLIC EXECUTE` revogado;
7. derivar identity/team/actor somente do contexto LOCAL `iss/sub` + banco;
8. manter autorização pilot-only por equipe alvo, sem copiar o guard global de criação F29;
9. usar `SELECT ... FOR UPDATE` + expected object exato;
10. avaliar `conflict` antes de `unchanged`;
11. preservar `object` exatamente, inclusive string vazia e espaços;
12. atualizar somente `object`/`updated_at` e inserir um único `object_changed` atômico;
13. garantir rollback se o evento falhar e no-op sem timestamp/evento;
14. manter runtime sem DML direto e conceder somente `EXECUTE` por provisionamento separado;
15. criar adapter server-only `mutatePersistentContractingObject` ou equivalente, gerando event UUID no servidor;
16. provar isolamento de authority contra F26/F29/Auth/read-only runtimes;
17. executar matriz PostgreSQL 17, concorrência real, lint, typecheck, testes, build e regressões;
18. revisar diff integral, red-team e deixar exatamente uma nova `NEXT_ACTION` somente após todos os gates verdes.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F26 continua exclusiva de `next_action`;
- F29 continua exclusiva de criação mínima;
- migrations aplicadas permanecem imutáveis;
- browser não define identity/scope/actor/membership/event UUID;
- falha protegida nunca vira demo fallback nem expõe detalhe interno;
- UI/Server Action de edição ficam fora da F32.

## Fonte da tarefa

Executar `tasks/F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01/SPEC.md` seguindo ADR-013 e as fontes canônicas ali referenciadas.

## Critério de encerramento

F32 fecha quando a nova boundary de edição de `object` estiver implementada e provada em PostgreSQL 17 contra least privilege, autorização pilot-only, RLS, atomicidade, rollback, no-op, conflito e concorrência, com adapter server-only sanitizado e regressões verdes, sem UI nesta slice.