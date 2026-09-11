# F30-PERSISTENT-CONTRACTING-CREATE-UI-01 — Tornar cadastro persistente mínimo utilizável

**Classe:** T1 — feature normal, com impacto T2 — fronteira de autorização  
**Estado:** PLANNED / NEXT  
**Dependências:** F27, F29, ADR-003, ADR-009 e ADR-012  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F29 materializou a boundary PostgreSQL/server-only da ADR-012, mas a aplicação ainda não oferece uma jornada para uma pessoa autorizada cadastrar uma contratação persistente.

A Central atual continua declarando que nenhuma ação da tela grava registros. A próxima slice deve tornar somente a criação mínima utilizável, sem ampliar o payload, sem criar CRUD genérico e sem resolver Q-001/Q-002/Q-006/Q-009 por conveniência.

## Objetivo

Adicionar uma jornada persistente mínima de cadastro que reutilize exclusivamente `preparePersistentContractingCandidateId()` e `createPersistentContracting({ contractingId, object })`, com enforcement server-side, feedback sanitizado e modo demo estritamente read-only.

## Execução obrigatória

### 1. Recuperação e inspeção

- confirmar F29 integrada e todos os gates pós-merge verdes;
- revalidar `CONTEXT_MANIFEST`;
- inspecionar `src/app/page.tsx`, Central do Setor, boundary F27, `persistent-read-mode`, F29 adapter/testes, ADR-012, SECURITY e DATABASE;
- não alterar migrations `0001..0005`.

### 2. Entrada da jornada

A jornada pode usar rota dedicada, componente server-rendered na Central ou combinação pequena equivalente, desde que:

- só seja apresentada como write persistente quando `readPersistentReadMode() === "persistent"`;
- modo demo continue sem formulário capaz de acionar criação persistente;
- modo `invalid`/falha protegida não renderize caminho de write e não caia para demo;
- o candidate UUID seja gerado no servidor por `preparePersistentContractingCandidateId()` antes da submissão;
- o formulário exponha semanticamente somente candidate UUID e `object`.

### 3. Server Action estreita

Criar uma Server Action específica para cadastro.

Ela deve:

- falhar/redirect fechado se o modo persistente não estiver exatamente habilitado;
- ler cada campo confiável no máximo uma vez e rejeitar duplicata do mesmo scalar;
- aceitar somente `contractingId` e `object` como payload encaminhado;
- ignorar/rejeitar sem confiar campos extras de team, actor, membership, created_by, issuer, subject, eventId, callback/redirect ou `$ACTION_*`;
- não executar SQL/DML diretamente;
- chamar exclusivamente `createPersistentContracting`;
- nunca receber `eventId` do browser;
- nunca aceitar destino de redirect arbitrário;
- sanitizar erro inesperado como `unavailable`;
- não possuir demo fallback.

### 4. Semântica do objeto

Preservar ADR-012/F29:

- `object` deve ser string e obrigatório estruturalmente no formulário;
- não aplicar trim silencioso;
- não inventar limite de tamanho;
- não inventar regra server-side que transforme string vazia em `NULL`;
- não adicionar `next_action`, stage, status, responsável ou waiting ao cadastro.

A interface HTML pode usar semântica de formulário adequada, mas qualquer restrição de negócio nova exige fonte canônica; não inferir uma regra apenas por conveniência de UX.

### 5. Resultado e navegação

Resultados externos permitidos:

- `created`;
- `already-created`;
- `not-available`;
- `unavailable`.

Regras:

- `created` deve levar ao detalhe persistente do candidate UUID criado;
- `already-created` pode levar ao mesmo detalhe como retry idempotente, sem criar novo fato;
- `not-available` e `unavailable` devem usar mensagem/estado sanitizado sem revelar existência cross-team, actor, membership, claims, SQL ou conexão;
- nenhuma string de erro interna entra em query string, HTML ou log;
- redirects são construídos somente de rotas locais fixas + candidate UUID validado.

### 6. UI mínima

A UI deve conter somente o necessário para cadastrar `object` e submeter.

Deve provar:

- pending desabilita repetição acidental de submit;
- não existem inputs/controles de team/actor/membership/created_by;
- não existem inputs de `next_action`, stage, status, responsável ou waiting;
- feedback de falha é sanitizado;
- após criação/replay, a pessoa chega a uma rota coerente com o registro autorizado;
- Central/demo não apresenta write persistente enganoso.

### 7. Testes adversariais

Provar no mínimo:

1. persistent mode renderiza a entrada mínima de cadastro;
2. demo mode não renderiza formulário/action de criação persistente;
3. invalid/unavailable não chama F29;
4. candidate UUID vem do helper server-side;
5. action encaminha exatamente `{ contractingId, object }`;
6. team/actor/membership/created_by/issuer/subject/eventId forjados não atravessam a boundary;
7. callback/redirect forjado não controla navegação;
8. duplicate `contractingId` ou `object` falha fechado antes de F29;
9. candidate UUID malformado não chega a F29;
10. `object` preserva espaços e string vazia conforme a semântica já aprovada;
11. `created` e `already-created` usam apenas rota local do candidate;
12. `not-available` não distingue cross-team/inexistente;
13. erro contendo connection string/claims não aparece na UI/redirect;
14. pending desabilita submissão repetida;
15. nenhum controle de campos fora do payload mínimo é adicionado;
16. F29/F26/F22/Auth continuam verdes.

## Red-team obrigatório

Rejeitar PASS se:

- browser puder escolher team/actor/membership/created_by confiável;
- event UUID atravessar o formulário;
- Server Action executar SQL/DML direto;
- demo ou configuração inválida puder gravar;
- erro protegido cair para dados demo;
- redirect externo puder ser forjado;
- `object` for trimado/normalizado por regra não aprovada;
- UI criar stage/status/responsável/waiting/next_action automaticamente;
- double-submit da mesma solicitação gerar duas contratações;
- retorno cross-team revelar existência;
- migration `0001..0005` for modificada;
- provider hosted, secret ou dado real for necessário para provar a slice.

## Verificação

- lint;
- typecheck;
- unit/component tests;
- build;
- CI database/Auth;
- F22 Private Preview Preflight;
- F29 Contracting Create;
- diff/red-team integral.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities continuam autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0005` permanecem imutáveis;
- F29 é a única boundary de criação usada pela aplicação.

## Fora do escopo

- edição de `object` após criação;
- `next_action` no cadastro;
- stage/status/responsável/waiting;
- itens/identificadores;
- upload/anexo;
- arquivamento/cancelamento;
- política multiusuário;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F30 fecha quando uma pessoa no modo persistente puder iniciar e concluir o cadastro mínimo de uma contratação pela boundary F29, com candidate UUID server-side, payload restrito a `contractingId + object`, navegação/feedback sanitizados, demo read-only e todos os gates/adversariais verdes.
