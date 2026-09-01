# F08-SERVER-TRUST-ADAPTER-01 — Sessão server-side e contexto transacional confiável

**Classe:** T3 — integração externa, com impacto direto de T2 — segurança  
**Estado:** READY após conclusão de F07  
**Dependências:** ADR-003, migrations `0001` e `0002`, policies de leitura validadas em CI  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

F07 implementou e provou a camada PostgreSQL de leitura autorizada, mas o aplicativo ainda não possui a parte anterior da fronteira: uma sessão externa validada no servidor e um adaptador server-only que transforme essa sessão em `issuer + subject`, abra a transação de banco e estabeleça o contexto local consumido pelas policies.

Sem essa camada, `request.jwt.claims` continua somente um mecanismo de teste e não existe caminho de produção autorizado para acessar o PostgreSQL.

## 2. Resultado esperado

Implementar a primeira fronteira server-side executável, sem provisionar infraestrutura, cobrindo:

1. cliente/configuração server-side do Auth usando a API oficial atual;
2. função de produção que obtém uma sessão validada pela API real do SDK;
3. derivação de `auth_issuer` por configuração confiável do servidor e de `auth_subject` pela sessão validada;
4. tipo pequeno de identidade externa, contendo somente os campos necessários;
5. adaptador server-only de PostgreSQL/Neon capaz de abrir transação e definir localmente o contexto `{"iss": ..., "sub": ...}` antes de uma operação protegida;
6. SQL parametrizado para `set_config('request.jwt.claims', ..., true)` ou mecanismo oficial equivalente compatível com PostgreSQL comum;
7. fail-closed em ausência/falha de sessão, configuração ou contexto;
8. testes de unidade e integração local/mocked suficientes para provar a fronteira sem secret, banco hospedado ou usuário real.

A produção deve depender da API real e atual do SDK escolhido. Mocks entram somente nos testes/bordas externas.

## 3. Inspeção e revalidação obrigatórias

Antes de editar:

- reler ADR-003;
- revisar migration `0002_trusted_identity_read_policies.sql` e testes F07;
- revisar arquitetura atual do Next.js e dependências existentes;
- consultar documentação oficial atual do Managed Better Auth/Neon Auth para sessão server-side em Next.js;
- consultar documentação oficial atual do driver PostgreSQL/Neon escolhido para transações no runtime do projeto;
- confirmar versão/pacote recomendado hoje, forma correta de configurar secrets server-side e API atual de `getSession`/equivalente;
- confirmar como executar uma transação com comando parametrizado antes de qualquer query protegida;
- registrar mudança material de produto/API/custo/privacidade se divergir de ADR-003.

Não confiar em memória ou exemplo antigo para comportamento mutável do provedor.

## 4. Fronteira de identidade

O caminho de produção deve preservar:

```text
request
  -> servidor Next.js
  -> SDK oficial valida/resolve sessão
  -> issuer confiável de configuração server-only
  + subject da sessão validada
  -> ExternalIdentity { issuer, subject }
  -> transação de banco
  -> contexto LOCAL iss + sub
  -> RLS
```

Regras:

- nenhuma função de produção aceita `issuer`, `subject`, `app_user_id`, `membership_id` ou `team_id` como input de autorização vindo do cliente;
- header `Host`, query string, body, route param e cookie arbitrário não definem issuer;
- subject vem somente do objeto de usuário/sessão que o SDK declarou validado;
- identidade externa desconhecida não é auto-provisionada;
- email/nome não substituem subject;
- configuração faltante ou ambígua falha fechado.

## 5. Adapter server-only

Código que toca Auth secreto, connection string ou PostgreSQL deve ser impossível de importar acidentalmente no bundle client-side. Usar a convenção server-only vigente do Next.js/ecossistema atual.

O adapter deve separar duas responsabilidades pequenas:

- resolução da identidade externa confiável;
- execução de uma operação protegida em transação com contexto local.

Uma interface conceitual aceitável:

```ts
export type ExternalIdentity = {
  issuer: string;
  subject: string;
};

export async function getVerifiedExternalIdentity(): Promise<ExternalIdentity | null>;

export async function withTrustedDatabaseContext<T>(
  operation: (db: ScopedDatabaseClient) => Promise<T>,
): Promise<T>;
```

Os nomes podem mudar conforme o desenho existente. A regra é que `withTrustedDatabaseContext` obtenha a identidade internamente; o chamador não passa identidade ou escopo.

## 6. Contexto PostgreSQL

Dentro de cada operação protegida:

1. obter sessão/identidade antes da query de domínio;
2. iniciar transação;
3. serializar somente `{ iss, sub }`;
4. definir `request.jwt.claims` com `set_config(..., true)` ou mecanismo oficialmente equivalente e parametrizado;
5. executar a operação usando a mesma transação/conexão;
6. encerrar a transação;
7. garantir por teste que operação posterior sem identidade/contexto não herda claims anteriores.

É proibido interpolar issuer/subject em SQL textual.

O fato de o servidor poder definir o GUC faz dele parte da fronteira de confiança. A credencial usada por esse adapter deve permanecer server-only e, quando houver ambiente real, pertencer a role operacional sem owner/BYPASSRLS.

## 7. Configuração e secrets

Nesta slice:

- não adicionar valor real de variável de ambiente;
- documentação/exemplo deve usar nomes genéricos e placeholders;
- não versionar `.env` com credencial;
- não usar prefixo público para secret ou connection string;
- não logar sessão completa, cookie, token, connection string ou claims brutos;
- mensagens de erro devem ser operacionais sem serializar segredo.

Se o SDK exigir um secret server-side adicional, registrar somente o nome da variável e a finalidade, nunca um valor.

## 8. Signup e admissão

F06 identificou que o produto de Auth pode permitir signup por padrão. F08 não expõe nenhuma UI/rota própria de signup/login e não autoautoriza identidades externas.

Se a integração necessária para obter `getSession()` implicar expor automaticamente endpoint público de signup, parar e registrar bloqueio/decisão antes de publicar essa superfície. Esconder botão não é mitigação suficiente.

Controle de convite/admissão definitivo continua fora desta slice.

## 9. Testes obrigatórios

### Identidade

- sessão ausente -> `null`/negação;
- erro/falha de validação -> fail-closed;
- sessão sem subject -> fail-closed;
- issuer configurado ausente -> fail-closed;
- issuer é lido de configuração server-only, não da request;
- parâmetros falsos de user/team/membership na request não alteram identidade;
- caminho de produção usa a API real do SDK; mock fica isolado em teste.

### Contexto transacional

- claims contêm somente `iss` e `sub`;
- `set_config`/equivalente usa parâmetros, não interpolação;
- operation executa depois do contexto na mesma transação;
- ausência de identidade impede abrir/executar query protegida;
- erro ao definir contexto impede a operation;
- contexto local não vaza para operação seguinte;
- testes continuam sem owner/BYPASSRLS como prova de autorização.

### Regressão

- migrations `0001 + 0002`: PASS;
- suites F05/F07: PASS;
- lint/typecheck/test/build: PASS.

## 10. Red-team obrigatório

Procurar deliberadamente:

- uso de issuer derivado de `Host`, Origin ou input do cliente;
- subject substituível por body/query/header;
- função pública que aceite `team_id`/membership/user e monte claims;
- import de secret/config server-only por Client Component;
- token/cookie/connection string em log ou erro;
- SQL por interpolação;
- `set_config(..., false)` ou contexto de sessão que possa vazar no pool;
- query executada fora da transação que recebeu o contexto;
- fallback permissivo quando sessão/config falhar;
- owner, `neondb_owner`, superuser ou `BYPASSRLS` no caminho normal;
- auto-provisionamento silencioso;
- endpoint/signup público criado por conveniência;
- mudança de API do provedor não refletida na documentação/ADR;
- dependência desnecessária ou acoplamento que impeça trocar provedor.

## 11. Fora do escopo

Não:

- criar/provisionar projeto Auth ou banco Neon;
- usar secret/JWT/cookie/connection string real;
- login/signup UI;
- convite/admissão final;
- conectar Central/detalhe a dados persistentes reais;
- auto-provisionar `app_users`/memberships;
- mutation/write policies/RPC;
- resolver Q-009;
- implementar Q-010;
- deploy;
- dados reais.

## 12. Critério de encerramento

A tarefa termina quando:

- o production path usa a API oficial atual do SDK server-side para obter sessão;
- `issuer + subject` são derivados exclusivamente da fronteira confiável;
- a operação PostgreSQL estabelece contexto local parametrizado na mesma transação;
- falhas de sessão/config/contexto são fail-closed;
- testes adversariais cobrem identidade, inputs, secrets, SQL e vazamento de contexto;
- gates existentes permanecem verdes;
- nenhuma infraestrutura/credencial real foi criada;
- exatamente uma nova `NEXT_ACTION` fica pronta para conectar uma primeira leitura persistente da aplicação ou tratar bloqueio técnico real encontrado.
