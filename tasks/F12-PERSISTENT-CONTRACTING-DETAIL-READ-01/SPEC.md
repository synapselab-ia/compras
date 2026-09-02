# F12-PERSISTENT-CONTRACTING-DETAIL-READ-01 — Conectar detalhe à leitura persistente protegida

**Classe:** T1 — feature de leitura, com impacto de T2 — segurança  
**Estado:** READY após conclusão de F11  
**Dependências:** F08, F09, F11, ADR-003, ADR-004, ADR-005 e migrations `0001`–`0003`  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

Após F11, a Central possui um caminho persistente opt-in capaz de listar contratações autorizadas e resolver responsáveis da mesma equipe pela capability view mínima. O detalhe em `/contratacoes/[id]`, entretanto, continua exclusivamente demonstrativo.

Essa assimetria impede uma jornada persistente coerente: a Central não deve apontar um registro persistente para uma tela alimentada por fixture que apenas compartilha a aparência do produto.

F12 deve conectar o detalhe às mesmas fronteiras de identidade/RLS já validadas, sem provisionar infraestrutura e sem introduzir escrita.

## 2. Resultado esperado

Implementar uma leitura persistente de uma contratação por ID opaco que:

- execute somente dentro de `withTrustedDatabaseContext()`;
- aceite como seletor somente o `id` da contratação vindo da rota;
- não aceite `team_id`, `membership_id`, `app_user_id`, issuer ou subject como entrada;
- trate o ID como localizador, nunca como autorização;
- permita que RLS determine se a contratação existe para o chamador;
- leia o estado atual, identificadores relacionados, itens e eventos já modelados;
- resolva responsável pelo `public.team_member_directory` de F11;
- preserve o modo demo quando `COMPRAS_PERSISTENT_READ_ENABLED` estiver ausente/`false`;
- use o modo persistente quando a flag for exatamente `true`;
- trate configuração inválida/falha protegida como indisponibilidade, nunca como fallback demo;
- permita à Central persistente navegar para o detalhe persistente após a leitura estar implementada.

## 3. Contrato de identidade e escopo

O único valor vindo da rota necessário à consulta é o identificador opaco da contratação.

Ele não pode:

- definir `team_id`;
- definir membership/usuário;
- virar claim;
- escolher issuer/subject;
- contornar RLS;
- ser interpolado em SQL.

O caminho esperado é:

```text
route id -> validação sintática -> query parametrizada
sessão validada -> issuer + subject -> contexto LOCAL -> RLS
```

Esses dois fluxos se encontram no banco: o ID seleciona uma linha candidata e RLS decide se ela é visível.

Um UUID existente em outra equipe e um UUID inexistente devem produzir externamente o mesmo estado de `not found`. A aplicação não deve criar um oracle de existência cross-team.

## 4. Fonte demo vs. persistente

Reutilizar `COMPRAS_PERSISTENT_READ_ENABLED`.

Semântica obrigatória:

- ausente ou `false`: detalhe demo atual;
- exatamente `true`: detalhe persistente;
- qualquer outro valor: indisponível;
- erro de sessão/banco/contexto em modo persistente: indisponível;
- resultado autorizado sem linha: não encontrado;
- nunca retornar fixture demonstrativa como fallback em modo persistente.

Evitar duplicar a semântica da flag em dois módulos divergentes. Se necessário, extrair um helper `server-only` mínimo e testado, sem refatoração ampla.

## 5. Modelo de leitura do detalhe

Usar apenas campos já existentes em `0001`; não criar taxonomia nova.

### Contratação

Ler no mínimo:

- `id`;
- `object`;
- `responsible_membership_id`;
- `stage_key`;
- `status_key`;
- `waiting_type`;
- `waiting_reference`;
- `waiting_since` quando útil à apresentação sem inventar semântica;
- `waiting_reason` quando útil à apresentação sem inventar semântica;
- `next_action`;
- `created_at`;
- `archived_at` / `cancelled_at` somente para decidir se o detalhe deve ser considerado ativo/visível na jornada atual.

Não tratar `updated_at` como evento de histórico.

### Responsável

Resolver exclusivamente por `public.team_member_directory`, correlacionando `team_id + responsible_membership_id`.

- nulo -> `Sem responsável`;
- membro ativo/não desabilitado da mesma equipe -> `display_name`;
- referência que a view não exponha -> fallback genérico, sem segunda consulta privilegiada.

### Identificadores relacionados

Ler de `related_identifiers` somente linhas visíveis e atualmente vinculadas quando a UI atual representar vínculos ativos. Não fechar Q-003 nem inventar catálogo de `identifier_kind`; exibir chaves/valores de forma provisória e segura.

### Itens

Ler de `contracting_items` somente linhas visíveis e não retiradas quando a UI atual representar itens ativos. Não inventar regra de quantidade/unidade/catálogo além do que a linha contém.

### Eventos

Ler de `contracting_events` visíveis, ordenados por `occurred_at` de forma determinística. Não criar semântica final para `event_type`/`field_key` que não esteja aprovada.

A atividade exibida deve vir de eventos; `updated_at` não substitui timeline.

## 6. Tipos e apresentação

O componente de detalhe não deve continuar tipado exclusivamente como `DemoContractingDetail` se passar a receber dados persistentes.

Criar um tipo de apresentação neutro, suficiente para os dois modos, mantendo fixtures demo como uma fonte possível em vez de torná-las o modelo de domínio.

A UI deve distinguir explicitamente:

- `demo`: aviso de dados fictícios;
- `persistent`: aviso de leitura autorizada/somente leitura, sem alegar que é produção;
- `unavailable`: estado genérico sem dados substitutos;
- `not found`: registro não disponível para o seletor atual.

Não exibir mensagens que confirmem que um UUID existe mas pertence a outra equipe.

## 7. Navegação da Central

Após o detalhe persistente existir:

- registros demo continuam navegando para IDs demo;
- registros persistentes podem navegar para `/contratacoes/<uuid>`;
- estado indisponível não cria links fictícios;
- a navegação não transporta `team_id`, membership, user ou qualquer claim em query string/local storage/prop para autorizar o detalhe.

## 8. Validação do ID

O ID persistente esperado é UUID.

A validação deve:

- rejeitar valor malformado antes de construir a consulta de domínio;
- não normalizar silenciosamente para outro ID;
- não consultar por fragmento/text search;
- usar bind parameter (`$1`) com cast explícito/seguro quando necessário;
- não ecoar erro SQL/driver em UI.

Em modo demo, preservar a normalização já existente apenas para os IDs `DEMO-*`, sem misturar essa regra com IDs persistentes.

## 9. Testes obrigatórios

### Repositório persistente

Provar:

- operação passa por `withTrustedDatabaseContext()`;
- somente o ID validado é parâmetro da query;
- SQL não recebe `team_id`, membership/user, issuer ou subject;
- nenhuma interpolação do ID;
- contratação é lida com RLS normal;
- responsável usa `team_member_directory`;
- identificadores/itens/eventos são limitados à contratação visível;
- eventos ordenados por `occurred_at`;
- `updated_at` não é usado como evento.

### Autorização / banco

Usando PostgreSQL descartável com `0001 + 0002 + 0003`, provar com fixtures artificiais:

- A1 lê detalhe da contratação da equipe A;
- A1 não lê contratação da equipe B mesmo conhecendo UUID;
- B1 não lê contratação da equipe A;
- caller sem contexto, sem membership, revogado, desabilitado ou desconhecido lê zero;
- related identifier/item/event de outra contratação/equipe não entra no detalhe;
- responsável colega ativo é resolvido;
- responsável revogado/desabilitado não é revelado;
- nenhuma role privilegiada é usada como caminho normal.

A prova pode reutilizar as policies existentes; não criar policy especial só para o teste.

### Seleção de fonte

Provar:

- flag ausente/false + ID demo -> demo;
- flag true + UUID autorizado -> persistent;
- flag true + UUID inexistente -> not found;
- flag true + UUID cross-team -> mesmo not found externo;
- flag inválida -> unavailable;
- falha protegida -> unavailable, sem fixture;
- ID persistente malformado -> not found/estado seguro definido sem executar SQL de domínio.

### UI/navegação

Provar:

- aviso demo continua explícito;
- modo persistente não usa texto que diga “dados fictícios” para o conteúdo autorizado;
- indisponibilidade não serializa detalhes de erro;
- Central só reativa links persistentes após esta leitura existir;
- URL do detalhe contém somente o ID opaco necessário.

## 10. Red-team obrigatório

Tentar deliberadamente:

- acessar UUID de outra equipe;
- forjar `team_id`, membership e user em argumento, query string/header ou cast de função;
- usar ID como SQL interpolado;
- transformar cross-team em mensagem diferente de inexistente;
- consultar `app_users`/`memberships` diretamente para descobrir colega em vez da capability view;
- usar owner, superuser, `BYPASSRLS`, `neondb_owner` ou `compras_team_directory_view_owner` como credencial operacional;
- retornar demo após erro persistente;
- misturar ID `DEMO-*` com caminho persistente;
- usar `updated_at` como atividade;
- expor erro, cookie, claim, token ou connection string;
- adicionar escrita, resolver Q-009/Q-010 ou fechar taxonomias por acidente.

## 11. CI e gates

Obrigatórios:

- migrations `0001 + 0002 + 0003`: PASS;
- suites de banco F05/F07/F08/F10/F11: PASS;
- testes persistentes do detalhe: PASS;
- testes de modo/estado/navegação: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI: PASS;
- diff integral revisado;
- nenhum secret, dado real ou recurso externo provisionado.

## 12. Fora do escopo

Não:

- editar contratação, itens, identificadores ou eventos;
- criar policy/RPC de escrita;
- criar histórico novo;
- provisionar Neon/Auth/Vercel;
- configurar credencial real;
- login/signup/admissão;
- deploy;
- dados reais;
- resolver Q-001/Q-002/Q-003/Q-004/Q-005/Q-006/Q-009/Q-010;
- implementar pesquisa de preços.

## 13. Critério de encerramento

A tarefa termina quando a jornada `Central persistente -> detalhe persistente -> Central` usa a mesma fronteira F08/F11, um ID conhecido fora do escopo continua indistinguível de inexistente, erros protegidos não viram demo nem vazam detalhes, todos os gates passam e o checkpoint deixa exatamente uma nova `NEXT_ACTION` executável.
