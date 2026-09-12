# F32-PERSISTENT-CONTRACTING-OBJECT-MUTATION-IMPLEMENT-01 - Implementar boundary persistente de edição do objeto

**Classe:** T1 - feature normal, com impacto T2 - banco/autorização  
**Estado:** PLANNED / NEXT  
**Dependências:** F31, ADR-003, ADR-005, ADR-009, ADR-011, ADR-012 e ADR-013  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

ADR-013 definiu a menor authority segura para editar exclusivamente `contractings.object`, mas ainda não existe migration, primitive PostgreSQL nem adapter server-only correspondente.

A implementação deve materializar somente essa boundary, preservando F26 e F29 sem authority adicional e mantendo UI/Server Action fora desta work unit.

## Objetivo

Implementar uma capability PostgreSQL própria para alteração rastreável de `contractings.object`, com autorização pilot-only, concorrência por expected value, evento atômico, rollback, least privilege e adapter server-only sanitizado.

## Execução obrigatória

1. recuperar `main`, confirmar F31 integrada e revalidar `CONTEXT_MANIFEST`;
2. inspecionar ADR-013, migrations/provisionamentos/testes F26/F29, `withTrustedDatabaseMutationContext`, SECURITY e DATABASE;
3. não modificar migrations `0001..0005`;
4. criar nova migration `0006_...sql` com owner técnico dedicado equivalente a `compras_contracting_object_mutation_owner`;
5. manter owner `NOLOGIN`, `NOINHERIT`, não privilegiado, sem ownership de tabelas-base e sem membership utilizável;
6. criar primitive `SECURITY DEFINER` equivalente a `mutate_contracting_object(uuid,text,text,uuid)` com `search_path = pg_catalog`, SQL estático e `PUBLIC EXECUTE` revogado;
7. derivar identidade, team e actor exclusivamente de contexto LOCAL `iss/sub` + banco;
8. autorizar somente contratação ativa da equipe alvo com membership corrente não revogada e exatamente uma membership não revogada na equipe;
9. não copiar o guard global de exatamente uma membership do usuário usado por F29 para criação;
10. usar `SELECT ... FOR UPDATE` + precondição exata de `expectedObject`;
11. avaliar `conflict` antes de `unchanged`;
12. preservar `newObject` exatamente, inclusive string vazia e espaços, sem trim, limite ou coerção para `NULL`;
13. atualizar somente `object` e `updated_at`;
14. inserir exatamente um evento `object_changed` com `field_key = 'object'`, old/new exatos, actor/team derivados e mesmo instante do update;
15. garantir no-op sem alteração de timestamp/evento;
16. garantir falha do evento com rollback integral do update;
17. manter eventos append-only;
18. criar provisionamento separado que conceda somente `EXECUTE` ao runtime explícito e seguro;
19. criar adapter server-only equivalente a `mutatePersistentContractingObject({ contractingId, expectedObject, newObject })`, gerando event UUID no servidor e chamando somente a primitive parametrizada;
20. mapear `updated`, `unchanged`, `conflict`, `denied` e falha técnica para estados externos sanitizados conforme ADR-013;
21. não implementar Server Action/UI nesta work unit;
22. executar red-team, PostgreSQL 17 descartável, concorrência real, regressões e checkpoint;
23. deixar exatamente uma nova `NEXT_ACTION` para tornar a edição de `object` utilizável na UI somente se a boundary estiver integralmente verde.

## Matriz adversarial obrigatória

A implementação deve provar no mínimo:

1. único membro não revogado na equipe alvo altera `object` e cria exatamente um evento;
2. empty string e espaços são preservados exatamente;
3. actor/team/contracting são derivados do banco;
4. valor idêntico com expected atual retorna `unchanged` sem timestamp/evento;
5. expected stale retorna `conflict` sem update/evento;
6. stale expected continua `conflict` mesmo quando estado corrente já coincide com `newObject`;
7. concorrência com mesmo expected produz exatamente um `updated`, um evento e demais `conflict`;
8. retry da mesma chamada depois de sucesso não cria segundo evento;
9. falha forçada do evento reverte update e timestamp;
10. claims ausentes/malformados, identidade desconhecida ou usuário desabilitado negam;
11. sem membership ou membership revogada nega;
12. cross-team e inexistente são indistinguíveis externamente;
13. segundo membro não revogado na equipe alvo bloqueia, inclusive app_user desabilitado;
14. arquivado/cancelado bloqueia;
15. usuário com membership em outra equipe não é bloqueado por esse fato quando a equipe alvo satisfaz o guard F26-style;
16. runtime normal não recebe DML direto;
17. capability owner permanece selada, não privilegiada e sem ownership de tabelas-base;
18. capability atualiza somente `object`/`updated_at` e não consegue criar contratação nem alterar `next_action`, stage, status, responsável, waiting, creator, archived/cancelled;
19. eventos não podem ser atualizados/deletados;
20. F26 continua sem `UPDATE object`;
21. F29 continua sem `UPDATE` de linhas existentes;
22. Auth/read-only runtimes não recebem `EXECUTE` da nova primitive;
23. migrations `0001..0005` permanecem imutáveis;
24. F22/F26/F29/Auth continuam verdes;
25. somente dados/identidades fictícios e nenhum provider hosted write.

## Semântica de resultado

Interna da primitive:

- `updated`;
- `unchanged`;
- `conflict`;
- `denied`.

Interface server-only:

- `updated`;
- `unchanged`;
- `conflict`;
- `not-available` para negação;
- `unavailable` para falha técnica/configuração/conexão/contexto/resultado inesperado.

`conflict` e `unchanged` só podem ser observados depois da autorização da contratação.

## Segurança

Rejeitar PASS se:

- browser/caller conseguir fornecer team, actor, membership, creator, issuer, subject ou event UUID confiável;
- runtime ganhar DML direto;
- F26/F29 forem ampliadas;
- capability conseguir editar colunas fora de `object`/`updated_at`;
- `SECURITY DEFINER` tiver search path inseguro ou SQL dinâmico controlável;
- cross-team/inexistente produzirem side channel;
- segundo membro virar permissão multiusuário;
- string vazia for proibida ou transformada;
- update puder sobreviver à falha do evento;
- provider hosted, secret ou dado real for necessário para provar a slice.

## Verificação

- lint;
- typecheck;
- testes unitários;
- build;
- PostgreSQL 17 migration/provisionamento/matriz adversarial;
- teste de concorrência real;
- CI database/Auth;
- F22 Private Preview Preflight;
- regressões F26 e F29;
- revisão integral do diff.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities continuam autoritativas;
- runtime normal continua sem DML direto;
- F26 permanece exclusiva de `next_action`;
- F29 permanece exclusiva de criação mínima;
- migrations aplicadas permanecem imutáveis;
- UI/Server Action ficam fora desta work unit.

## Fora do escopo

- UI/Server Action de edição de `object`;
- edição de `next_action`;
- stage/status/responsável/waiting;
- itens/identificadores;
- arquivamento/cancelamento;
- política multiusuário;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F32 fecha quando a boundary ADR-013 estiver implementada e provada em PostgreSQL 17 contra least privilege, autorização pilot-only, RLS, atomicidade, rollback, no-op, conflito e concorrência, com adapter server-only sanitizado e regressões verdes, sem UI nesta slice.