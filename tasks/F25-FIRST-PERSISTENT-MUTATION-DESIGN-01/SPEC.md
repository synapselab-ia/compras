# F25-FIRST-PERSISTENT-MUTATION-DESIGN-01 — Definir a primeira mutação persistente rastreável

**Classe:** T5 — decisão arquitetural pequena, com impacto T2 — banco/segurança  
**Estado:** COMPLETE / INTEGRATED  
**Dependências:** F12, F20, F22, F24, ADR-003, ADR-005, ADR-009, `DATABASE.md` e `SECURITY.md`  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O produto já possui leituras persistentes protegidas e o schema canônico já separa estado atual (`contractings`) de histórico append-only (`contracting_events`), mas ainda não existia uma fronteira canônica para escrita operacional normal.

`DATABASE.md` exige que uma alteração rastreável atualize estado e evento na mesma transação lógica e rejeita CRUD amplo direto. Ao mesmo tempo, Q-009 continua aberta: a existência de uma membership não autoriza inferir silenciosamente permissões multiusuário.

F25 fechou uma decisão pequena, explícita e reversível antes de qualquer implementação de escrita.

## Caso concreto de desenho

O primeiro caso é `contractings.next_action` porque:

- já pertence ao núcleo funcional aprovado;
- a coluna já existe no schema canônico;
- não depende de fechar taxonomias de etapa/status;
- a alteração é escalar e pode ser representada por `contracting_events.field_key/old_value/new_value`;
- permite provar autorização, atomicidade, histórico e concorrência antes de ampliar a superfície de escrita.

F25 permaneceu **design-only**. Nenhuma migration, Server Action ou write de produção foi implementada nesta work unit.

## Decisão integrada

A decisão está em `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`.

Foi escolhida uma primitive PostgreSQL estreita `SECURITY DEFINER`, com owner técnico `NOLOGIN` não privilegiado, em vez de conceder DML direto à role runtime. O runtime continuará apenas com `EXECUTE` sobre a capability específica.

A fronteira de confiança continua sessão Better Auth validada no servidor → contexto LOCAL `iss/sub` → `app_user` → membership → capability. Browser não fornece actor, `team_id`, membership, issuer ou subject confiáveis.

## Restrição de Q-009

Q-009 permanece aberta.

A autorização é **pilot-only**: o usuário corrente precisa possuir membership não revogada na equipe da contratação e essa precisa ser a única membership `revoked_at IS NULL` da equipe.

Se houver segunda membership ativa, a escrita falha fechada para esta primitive. Isso não concede nem nega uma política multiusuário futura; apenas impede inferi-la silenciosamente.

Uma membership não revogada conta para o guard mesmo se seu usuário estiver desabilitado, preservando comportamento conservador diante de estado de membership incompleto.

## Concorrência

A ADR definiu `SELECT ... FOR UPDATE` combinado com precondição otimista null-safe sobre o valor anterior de `next_action`.

Chamadas concorrentes com o mesmo expected não podem produzir last-write-wins silencioso: somente uma vence; as demais retornam conflito sem update/evento.

Nenhuma coluna de versão foi criada nesta decisão.

## Evento/histórico

A implementação F26 deverá preservar:

- `contracting_events` append-only;
- actor derivado da identidade autorizada;
- `event_type = 'next_action_changed'`;
- `field_key = 'next_action'`;
- `old_value` e `new_value` auditáveis;
- mesmo team/contracting da linha bloqueada;
- update de `next_action`/`updated_at` e evento na mesma transação;
- mesmo instante de banco para estado e evento;
- no-op sem novo timestamp/evento.

Falha do evento deve reverter o update.

## Red-team executado

A decisão foi rejeitada como aceitável se permitisse:

- browser fornecer actor/membership/team confiável;
- UUID conhecido de outra equipe produzir update ou side channel de existência;
- membership revogada editar;
- segundo membro ativo herdar permissão por inferência de Q-009;
- update sem evento atômico ou evento sem update correspondente;
- DML direto amplo para runtime;
- runtime/capability privilegiado de forma incompatível;
- `SECURITY DEFINER` com `search_path` controlável;
- lost update silencioso;
- no-op com evento falso;
- alteração de migrations aplicadas;
- dado real/interno;
- dependência de F21/Vercel hosted.

A revisão integral da PR confirmou que F25 alterou apenas documentação/SPEC e não introduziu código executável de escrita ou migration.

## Verificação e promoção

PR `#41`:

- head final: `eb9d816af9217f1342a05f0d391792c5fd6abaed`;
- CI `34501334860`: PASS — `verify`, `database`, `auth-database`;
- F22 Private Preview Preflight `34501334789`: PASS;
- lint, typecheck, testes e build: PASS;
- suites PostgreSQL/RLS/Auth existentes: PASS.

Promoção:

- merge commit: `a74ddc381915eaa3ca3e6a38da7c62e0636eb953`;
- main CI `34501521020`: PASS;
- main F22 Private Preview Preflight `34501521011`: PASS.

Nenhum provider hosted foi alterado. Nenhuma secret/environment variable foi criada. Nenhum dado/identidade real foi usado. `REAL_DATA_ALLOWED = NO`.

## Artefatos

Criados/integrados:

- `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`;
- `tasks/F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01/SPEC.md`.

Atualizados/integrados:

- `docs/00-START-HERE.md`;
- `docs/ai/CURRENT_STATE.md`;
- `docs/ai/NEXT_ACTION.md`;
- este arquivo.

## Fora do escopo preservado

- implementação da escrita;
- edição de etapa/status/responsável/aguardando;
- papéis multiusuário ou resolução de Q-009;
- Data API pública;
- alteração de Auth/sign-in;
- retomada de F21;
- provider hosted;
- dado real.

## Critério de encerramento

F25 está encerrada: ADR-011 aceita e integrada, autorização pilot-only definida sem resolver Q-009, atomicidade estado+evento e estratégia de concorrência explícitas, matriz adversarial da implementação versionada, PR e gates pós-merge em PASS.

A única próxima ação canônica é `F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01`.
