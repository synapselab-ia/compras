# F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01 — Desenhar criação persistente mínima de contratação

**Classe:** T5 — decisão/arquitetura, com impacto T2 — autorização/banco  
**Estado:** PLANNED / NEXT  
**Dependências:** F27, ADR-003, ADR-005, ADR-009 e ADR-011  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

Após F27, o piloto consegue consultar contratações persistentes e alterar somente `Próxima ação`, mas ainda não consegue cadastrar uma nova contratação. `PROJECT_DESIGN.md` inclui cadastro no núcleo funcional inicial; ao mesmo tempo, Q-001/Q-002/Q-006/Q-009 continuam abertas e não podem ser resolvidas silenciosamente para viabilizar criação.

Antes de implementar outra capability de escrita, é necessário fechar uma decisão arquitetural mínima sobre criação: payload permitido, derivação de equipe/ator, evento inicial, idempotência, grants e comportamento fail-closed.

## Objetivo

Produzir uma ADR executável para a primeira criação persistente de `contractings`, sem implementar migration, Server Action ou UI nesta work unit.

A decisão deve permitir uma implementação posterior pequena e verificável, sem transformar criação em CRUD genérico e sem exigir taxonomias ainda abertas.

## Perguntas que F28 deve decidir

### 1. Payload mínimo de criação

Partir do schema e das fontes canônicas e decidir quais valores o browser pode solicitar na primeira criação.

Regras de desenho:

- `object` é estruturalmente obrigatório no schema e deve ser tratado conforme a semântica já existente, sem inventar trim/tamanho além do que as fontes sustentam;
- decidir explicitamente se `next_action` entra na criação inicial ou permanece para alteração posterior por F26/F27;
- não tornar `stage_key`, `status_key`, responsável, waiting ou pendência obrigatórios enquanto as respectivas regras/taxonomias estiverem abertas;
- não fechar Q-001, Q-002 ou Q-006 por conveniência.

### 2. Derivação de equipe e ator

Criação não possui uma contratação pré-existente da qual derivar `team_id`. A ADR deve definir um mecanismo pilot-only e fail-closed que derive o escopo exclusivamente da identidade Better Auth validada + banco.

A decisão deve analisar e escolher uma regra que:

- nunca aceite `team_id`, `app_user_id`, membership ou `created_by_membership_id` do browser como autoridade;
- falhe fechada quando a identidade não possuir exatamente um escopo inequivocamente elegível para criação;
- preserve Q-009 aberta e não transforme membership em permissão multiusuário geral;
- considere explicitamente o caso de múltiplas memberships não revogadas e o caso de segundo membro ativo na equipe.

### 3. Capability/grants

Decidir se criação deve possuir capability técnica própria ou reutilizar algum owner já existente.

A escolha deve justificar least privilege e manter o runtime normal sem `INSERT` direto em `contractings`/`contracting_events`.

Se houver capability:

- `NOLOGIN`;
- `NOINHERIT`;
- sem superuser/`BYPASSRLS`/`CREATEDB`/`CREATEROLE`/replication;
- sem ownership de tabelas-base;
- lifecycle compatível com ADR-005;
- `SECURITY DEFINER` com `search_path` fixo se função privilegiada for escolhida.

### 4. Histórico inicial

Definir o evento mínimo e atômico da criação.

A ADR deve decidir:

- chave do evento inicial sem criar taxonomia geral prematura;
- actor/team/contracting derivados no banco;
- timestamp(s) coerentes entre linha e evento;
- quais campos old/new/note devem ou não ser usados;
- rollback integral se o evento não puder ser persistido.

Nenhuma criação rastreável pode existir sem o evento correspondente.

### 5. ID e idempotência

Definir quem gera o UUID da nova contratação e do evento e como submissão repetida/retry evita duplicação silenciosa.

A decisão deve distinguir:

- identificador opaco não é autorização;
- idempotency/retry não pode exigir um segredo no browser;
- double-submit acidental não deve criar duas contratações indistinguíveis sem tratamento deliberado;
- conflito/duplicata deve ter resultado sanitizado e verificável.

Não adicionar infraestrutura externa somente para esta propriedade se PostgreSQL/aplicação já puderem garanti-la de forma simples.

### 6. Semântica externa

Definir estados mínimos equivalentes a sucesso, rejeição de autorização/escopo, duplicata/idempotência e indisponibilidade técnica.

Erros não podem expor SQL, claims, connection string, actor interno ou detalhes de membership. Falha protegida não vira demo fallback.

## Inspeção obrigatória

- `docs/product/PROJECT_DESIGN.md`;
- `docs/product/DOMAIN_MODEL.md`;
- `docs/product/BUSINESS_WORKFLOW.md`;
- `docs/product/OPEN_QUESTIONS.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- ADR-003, ADR-005, ADR-009 e ADR-011;
- migrations `0001..0004`;
- `contractings`/`contracting_events` e constraints/FKs atuais;
- boundary F26/F27 e testes adversariais;
- Definition of Done.

## Entregáveis

1. nova ADR para criação persistente mínima;
2. matriz de confiança/autorização/idempotência;
3. decisão explícita sobre capability e payload;
4. critérios PostgreSQL adversariais para a implementação seguinte;
5. SPEC da implementação seguinte, somente após a decisão ficar fechada;
6. checkpoint com exatamente uma nova `NEXT_ACTION`.

## Red-team obrigatório

Rejeitar a decisão se:

- browser puder escolher team/actor/membership confiável;
- criação funcionar com múltiplos escopos ambíguos sem regra explícita;
- Q-009 for implicitamente resolvida;
- runtime receber `INSERT` direto amplo;
- capability puder ampliar F26 ou editar colunas fora da criação aprovada;
- criação persistir sem evento atômico;
- retry/double-submit puder duplicar silenciosamente sem decisão;
- stage/status/responsável/waiting forem tornados obrigatórios por inferência;
- dados reais, provider hosted ou secrets forem necessários para provar o desenho.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente exemplos fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 permanecem abertas salvo decisão explicitamente sustentada por fonte — F28 não deve fechá-las;
- autenticação não é autorização;
- RLS continua autoritativa;
- runtime normal continua sem CRUD amplo;
- migrations aplicadas `0001..0004` permanecem imutáveis;
- F26/F27 continuam sendo a única escrita executável integrada até futura implementação de criação.

## Fora do escopo

- implementar migration/function de criação;
- Server Action/UI de criação;
- editar stage/status/responsável/aguardando;
- criar itens/identificadores junto com contratação;
- arquivamento/cancelamento;
- política multiusuário;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F28 fecha quando uma ADR aprovada definir uma fronteira mínima, pilot-only, auditável e idempotente para criar `contractings`, sem inventar taxonomias/permissões abertas, acompanhada da SPEC executável da implementação posterior e de todos os gates documentais aplicáveis.
