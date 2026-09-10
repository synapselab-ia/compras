# F25-FIRST-PERSISTENT-MUTATION-DESIGN-01 — Definir a primeira mutação persistente rastreável

**Classe:** T5 — decisão arquitetural pequena, com impacto T2 — banco/segurança  
**Estado:** VERIFIED / READY TO MERGE  
**Dependências:** F12, F20, F22, F24, ADR-003, ADR-005, ADR-009, `DATABASE.md` e `SECURITY.md`  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O produto já possui leituras persistentes protegidas e o schema canônico já separa estado atual (`contractings`) de histórico append-only (`contracting_events`), mas ainda não existe uma fronteira canônica para escrita operacional normal.

`DATABASE.md` exige que uma alteração rastreável atualize estado e evento na mesma transação lógica e rejeita CRUD amplo direto. Ao mesmo tempo, Q-009 continua aberta: a existência de uma membership não autoriza inferir silenciosamente permissões multiusuário.

Antes de implementar a primeira escrita, é necessário fechar uma decisão pequena, explícita e reversível sobre a fronteira de mutação.

## Caso concreto de desenho

Usar `contractings.next_action` como primeiro caso concreto porque:

- `next_action` já pertence ao núcleo funcional aprovado;
- a coluna já existe no schema canônico;
- não depende de fechar as taxonomias de etapa/status;
- a alteração é escalar e pode ser representada por `contracting_events.field_key/old_value/new_value`;
- permite provar autorização, atomicidade, histórico e concorrência antes de ampliar a superfície de escrita.

A F25 é **design-only**. Não implementar migration, Server Action ou write de produção nesta work unit.

## Resultado esperado

Produzir uma ADR aceita que defina, para a primeira mutação persistente:

1. fronteira de confiança entre sessão Better Auth, identidade interna e membership;
2. forma de autorização que não resolva Q-009 por inferência;
3. escolha entre transação server-side e primitive PostgreSQL estreita/`SECURITY DEFINER`;
4. como impedir que browser escolha `team_id`, `actor_membership_id` ou escopo confiável;
5. atomicidade entre atualização de `contractings.next_action`, `updated_at` e inserção de `contracting_events`;
6. semântica de concorrência/lost update adequada ao primeiro piloto;
7. representação do evento sem criar enum/taxonomia prematura;
8. comportamento fail-closed para identidade sem autorização, UUID de outra equipe, membership revogada e configuração inválida;
9. grants/roles mínimos necessários;
10. caminho de rollback e testes obrigatórios da implementação seguinte.

## Restrição de Q-009

A decisão não pode declarar que “qualquer membro da equipe pode editar tudo”.

A opção preferencial a ser avaliada é um **guard de piloto individual** que somente permita a mutação quando a identidade atual possuir a única membership ativa do escopo alvo, falhando fechada se houver segundo membro ativo. Isso preserva o piloto individual sem congelar a política multiusuário futura.

Se essa opção não puder ser sustentada pelo modelo atual sem ambiguidade, registrar `DECISÃO NECESSÁRIA`/open question em vez de ampliar permissão.

## Alternativas mínimas a comparar

### A. Transação server-side com role operacional limitada

Avaliar:

- derivação de identidade no servidor;
- `BEGIN` + contexto LOCAL confiável;
- seleção/lock da contratação autorizada;
- atualização + evento no mesmo commit;
- grants DML mínimos sem CRUD genérico.

### B. Primitive PostgreSQL estreita

Avaliar:

- função específica para `next_action`;
- `SECURITY DEFINER` apenas se necessário;
- `search_path` fixo;
- actor derivado do contexto confiável, nunca de parâmetro do browser;
- `EXECUTE` como capability em vez de DML amplo;
- ownership separado do runtime.

A ADR deve escolher uma alternativa e justificar por segurança, simplicidade, testabilidade e evolução futura.

## Concorrência

A ADR deve definir explicitamente como evitar lost update. Comparar ao menos:

- lock pessimista da linha durante transação;
- precondição otimista baseada em versão/estado atual existente;
- combinação mínima adequada ao piloto.

Não criar coluna/versionamento novo sem necessidade demonstrada. Se uma migration adicional for necessária, ela pertence à implementação seguinte, não à F25.

## Evento/histórico

A decisão deve preservar:

- `contracting_events` append-only;
- `actor_membership_id` derivado da identidade autorizada;
- `field_key = 'next_action'` ou convenção equivalente explícita;
- `old_value` e `new_value` auditáveis;
- mesmo `team_id`/`contracting_id` da linha alterada;
- nenhuma alteração de estado sem evento correspondente.

Não inventar uma taxonomia de eventos ampla nesta work unit.

## Red-team obrigatório

Rejeitar a decisão se ela permitir:

- browser fornecer actor/membership/team confiável;
- UUID conhecido de outra equipe produzir update ou side channel desnecessário;
- membership revogada editar;
- segundo membro ativo herdar permissão por inferência de Q-009;
- update de `contractings` sem evento atômico;
- evento sem update correspondente após falha parcial;
- role runtime com `BYPASSRLS`, superuser, ownership ou `CREATEROLE` para CRUD normal;
- função `SECURITY DEFINER` com `search_path` controlável;
- CRUD amplo como atalho;
- alteração de migrations já aplicadas;
- dado real/interno no repo/testes;
- dependência de F21/Vercel hosted para provar a decisão.

## Verificação obrigatória

- recuperar e validar contexto;
- ler `SECURITY.md`, `DATABASE.md`, ADR-003/005/009 e código/migrations/testes de identidade/RLS;
- confirmar que `next_action` e `contracting_events` já existem no schema;
- revisar Q-009 e não resolvê-la silenciosamente;
- produzir ADR versionada;
- definir matriz de autorização e concorrência para a implementação seguinte;
- definir testes PostgreSQL adversariais da próxima work unit;
- revisar diff integral;
- CI GitHub em PASS;
- nenhum hosted write;
- `REAL_DATA_ALLOWED = NO`;
- exatamente uma nova `NEXT_ACTION` ao encerrar F25.

## Fora do escopo

- implementar a escrita;
- editar etapa/status/responsável/aguardando;
- criar papéis multiusuário;
- resolver Q-009 globalmente;
- adicionar Data API pública;
- alterar Auth/sign-in;
- retomar F21;
- provider hosted;
- dado real.

## Critério de encerramento

F25 fecha quando existir uma ADR aceita, pequena e executável para a primeira mutação persistente de `next_action`, com autorização pilot-only sem inferir Q-009, atomicidade estado+evento, estratégia de concorrência e plano de testes adversariais suficientes para uma implementação subsequente.

## Resultado executado

A decisão foi fechada em `docs/decisions/ADR-011-first-persistent-next-action-mutation.md`.

A ADR escolhe uma primitive PostgreSQL estreita `SECURITY DEFINER`, com owner técnico `NOLOGIN` não privilegiado, em vez de conceder DML direto à role runtime. O runtime continuará apenas com `EXECUTE` sobre a capability específica.

A autorização permanece **pilot-only**: o usuário corrente precisa ser a única membership não revogada da equipe da contratação. Se houver segunda membership ativa, a escrita falha fechada; Q-009 permanece explicitamente aberta.

A concorrência foi definida como `SELECT ... FOR UPDATE` combinado com precondição otimista null-safe sobre o valor anterior de `next_action`. Chamadas concorrentes com o mesmo expected não podem produzir last-write-wins silencioso: somente uma vence; as demais retornam conflito sem evento.

A alteração real deve atualizar `next_action` + `updated_at` e inserir exatamente um `contracting_events` na mesma transação, com actor/team/contracting derivados do banco. No-op não altera timestamp e não gera evento.

A matriz adversarial da implementação foi versionada em `tasks/F26-FIRST-PERSISTENT-NEXT-ACTION-MUTATION-IMPLEMENT-01/SPEC.md`.

Red-team da decisão rejeitou:

- actor/team/membership fornecidos pelo browser;
- membership como permissão multiusuário implícita;
- DML amplo para runtime;
- owner/superuser/`BYPASSRLS` como runtime normal;
- `SECURITY DEFINER` com search path inseguro;
- estado sem evento ou evento sem estado;
- lost update silencioso;
- side channel cross-team por UUID conhecido;
- alteração de migrations aplicadas;
- dependência de provider hosted;
- dado real.

Nenhuma migration, Server Action, UI de escrita ou recurso hosted foi criado nesta F25. `REAL_DATA_ALLOWED = NO`.
