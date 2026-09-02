# F09-FIRST-PERSISTENT-READ-01 — Primeira leitura persistente da Central

**Classe:** T1 — feature de leitura, com impacto de T2 — segurança  
**Estado:** READY após conclusão de F08  
**Dependências:** ADR-003, migrations `0001` e `0002`, `withTrustedDatabaseContext()` da F08  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

A F08 concluiu a fronteira server-only `sessão validada -> issuer + subject -> transação LOCAL -> RLS`, mas nenhuma consulta de domínio da aplicação usa essa fronteira. A Central continua alimentada exclusivamente por fixtures demonstrativas.

A primeira leitura persistente deve provar a ligação entre a camada de aplicação e o banco sem provisionar infraestrutura, sem usar credenciais reais e sem ampliar as policies atuais por conveniência.

## 2. Resultado esperado

Implementar uma primeira leitura server-side da Central que:

- execute exclusivamente dentro de `withTrustedDatabaseContext()`;
- leia somente contratações ativas visíveis pelas policies existentes;
- não aceite `team_id`, `membership_id`, `app_user_id`, issuer ou subject como input;
- preserve o modo demonstrativo como padrão quando a leitura persistente não estiver explicitamente habilitada;
- nunca use dados demo como fallback silencioso quando o modo persistente estiver habilitado e a autenticação/configuração falhar;
- exponha estado indisponível genérico, sem serializar erro, sessão, claim ou connection string;
- mantenha filtros client-side sobre os registros já autorizados pelo servidor;
- não conecte ainda o detalhe da contratação a dados persistentes.

## 3. Limite importante de identidade de responsável

As policies atuais permitem ao usuário ler sua própria linha de `app_users` e sua própria membership, mas não constituem um diretório de membros da equipe. Portanto, esta slice **não deve ampliar RLS nem expor identidades de colegas por atalho**.

Para a primeira leitura:

- responsável nulo -> `Sem responsável`;
- quando o responsável é a própria membership visível, pode usar o próprio `display_name` já autorizado;
- quando existe `responsible_membership_id` mas a identidade não é visível pelas policies atuais, mostrar rótulo genérico `Responsável não disponível`;
- a necessidade de um diretório de equipe seguro deve ser tratada em work unit T2 separada antes de prometer nomes de todos os responsáveis.

## 4. Ativação segura

Adicionar flag server-only não secreta `COMPRAS_PERSISTENT_READ_ENABLED`.

- ausente ou `false`: modo demonstrativo;
- exatamente `true`: modo persistente;
- qualquer outro valor: configuração inválida e estado indisponível;
- nunca criar `NEXT_PUBLIC_*` para essa flag ou para secrets;
- em modo persistente, falha de sessão/banco/contexto não cai para dados demo.

A página deve ser dinâmica para que sessão/configuração sejam avaliadas em runtime.

## 5. Consulta mínima

Ler de `contractings` somente campos já necessários à Central:

- `id`;
- `object`;
- `responsible_membership_id`;
- `stage_key`;
- `status_key`;
- `waiting_type` / `waiting_reference`;
- `next_action`;
- última ocorrência em `contracting_events`.

Não usar `updated_at` como sinônimo de última movimentação relevante. Se não existir evento visível, mostrar `Sem movimentação registrada`.

A consulta pode fazer `LEFT JOIN` da própria membership/app_user para reconhecer o responsável corrente, respeitando as policies existentes. Não criar consulta privilegiada para descobrir colegas.

## 6. UI

- componente de filtros recebe registros do servidor por props;
- modo demo continua explicitamente identificado como fictício;
- modo persistente é identificado como leitura autorizada e somente leitura;
- erro de leitura persistente mostra estado indisponível sem dados substitutos;
- resultado persistente vazio é um estado vazio legítimo;
- links para detalhe permanecem somente no modo demo, pois o detalhe persistente está fora desta slice.

## 7. Testes obrigatórios

### Repositório de leitura

- chama `withTrustedDatabaseContext()`;
- query não recebe parâmetro de identidade ou escopo;
- tentativa de passar objeto com `team_id`/membership/user por cast não altera a query;
- mapeia valores nulos sem inventar regra de negócio;
- não usa `updated_at` como última movimentação;
- distingue responsável próprio de responsável não visível.

### Seleção de fonte

- flag ausente/`false` -> demo;
- `true` -> persistente;
- flag inválida -> indisponível;
- erro do caminho persistente -> indisponível, sem fallback demo;
- detalhes do erro não aparecem no valor retornado.

### Regressão

- suites F05/F07/F08 continuam PASS;
- PostgreSQL `0001` e `0001 + 0002` continuam PASS;
- lint/typecheck/test/build: PASS;
- CI: PASS.

## 8. Red-team obrigatório

Procurar deliberadamente:

- query que aceite `team_id` ou identidade do browser;
- fallback para demo escondendo falha do modo persistente;
- import de código server-only por Client Component;
- segredo/connection string em prop, erro ou log;
- acesso a `app_users`/memberships além do permitido pelas policies atuais;
- uso de owner/BYPASSRLS para obter nome de colega;
- `updated_at` tratado como evento;
- link persistente para detalhe ainda demonstrativo;
- configuração pública ou permissiva;
- qualquer dado real ou pré-publicação em fixture, PR ou CI.

## 9. Fora do escopo

Não:

- provisionar Neon/Auth/Vercel;
- usar secret ou dado real;
- login/signup UI;
- ampliar policies de diretório de equipe;
- conectar detalhe persistente;
- mutations ou policy de escrita;
- resolver Q-009 ou Q-010;
- criar pesquisa de preços.

## 10. Critério de encerramento

A tarefa termina quando a Central possui um caminho persistente server-side opt-in que usa a fronteira F08 e falha fechado, o modo demo continua explicitamente separado, os gates passam e existe exatamente uma nova `NEXT_ACTION` para resolver o diretório de membros/responsáveis ou outro bloqueio objetivo revelado pela leitura real.
