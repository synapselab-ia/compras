# ADR-003 — Fronteira de identidade confiável e autorização de leitura

**Status:** Accepted  
**Data:** 2026-09-01  
**Escopo:** desenho; nenhum recurso Neon/Auth/Data API é provisionado por esta decisão

## Contexto

A migration `0001_core_foundation.sql` já criou o núcleo relacional com RLS habilitada e `FORCE ROW LEVEL SECURITY`, sem policy permissiva. O próximo passo exige uma identidade corrente confiável antes de liberar qualquer leitura.

O modelo já aprovado separa:

1. identidade autenticada externa;
2. `app_users`, identificados por `auth_issuer + auth_subject`;
3. `memberships`, que autorizam acesso a um `team_id` apenas enquanto ativas.

Q-009 continua aberta. Portanto, membership não pode ser reinterpretada como perfil final de edição. Esta decisão trata somente da fronteira de identidade e da futura autorização mínima de `SELECT`.

## Evidência externa revalidada

Documentação oficial Neon consultada em 2026-09-01:

- índice oficial atual de documentação: https://neon.com/docs/llms.txt
- Managed Better Auth: https://neon.com/docs/auth/overview
- fluxo de autenticação: https://neon.com/docs/auth/authentication-flow
- checklist de produção do Auth: https://neon.com/docs/auth/production-checklist
- referência server-side para Next.js: https://neon.com/docs/auth/reference/nextjs-server
- migração/referência do SDK server-side v0.2: https://neon.com/docs/auth/migrate/from-auth-v0.1
- Data API — visão geral e segurança: https://neon.com/docs/data-api/overview e https://neon.com/docs/data-api/access-control
- provedores customizados da Data API: https://neon.com/docs/data-api/custom-authentication-providers
- Serverless Driver: https://neon.com/docs/serverless/serverless-driver
- Row-Level Security com Neon: https://neon.com/docs/guides/row-level-security
- `pg_session_jwt` mantido pela Neon: https://github.com/neondatabase/pg_session_jwt

A documentação atual sustenta os seguintes pontos relevantes:

- Managed Better Auth é a oferta de autenticação gerenciada atual da Neon e armazena usuários/sessões/configuração no Postgres da branch;
- o SDK server-side atual para Next.js expõe `createNeonAuth(...)` e `auth.getSession()` e exige segredo de cookie no servidor;
- a Data API valida JWT com JWKS configurado e disponibiliza o `sub` autenticado para RLS por helpers como `auth.user_id()`;
- a Data API aceita provedores JWT customizados por JWKS;
- o Serverless Driver documenta explicitamente o padrão de backend que verifica identidade antes de definir claims transacionais para RLS e adverte que a conexão usada não pode possuir `BYPASSRLS` nem usar `neondb_owner` como papel operacional;
- `request.jwt.claims`/claims de sessão não constituem prova por si só quando podem ser configurados por um cliente SQL; a confiança depende de quem validou e definiu esse contexto;
- Managed Better Auth está documentado atualmente para regiões AWS; Azure ainda não é suportado;
- o fluxo de Auth permite cadastro por qualquer pessoa por padrão. O checklist de produção pressupõe essa possibilidade e recomenda controles como domínios confiáveis e verificação de email. Isso conflita com a regra do projeto de não possuir signup público como comportamento padrão e deve ser tratado antes de qualquer Auth real ser exposto.

## Decisão

### 1. Caminho inicial de confiança: sessão verificada no servidor

A primeira integração operacional seguirá o caminho:

```text
Browser
  -> sessão/cookie Managed Better Auth
  -> Next.js server
  -> auth.getSession()
  -> identidade externa verificada
  -> contexto transacional mínimo
  -> PostgreSQL com papel sem BYPASSRLS
  -> RLS
```

A aplicação **não** usará, na primeira implementação, a Data API diretamente do browser como fronteira principal de acesso aos dados internos.

Motivos:

- preserva a arquitetura `browser -> server -> PostgreSQL/RLS` já aprovada;
- mantém a credencial de banco exclusivamente no servidor;
- permite testar a política em PostgreSQL descartável sem depender de um recurso hospedado;
- evita acoplar a migration canônica a uma API/provider específico antes de existir necessidade concreta;
- permite que a mesma política sobreviva a troca futura do provedor de Auth.

A Data API continua uma opção válida futura. Sua integração JWT/JWKS atual foi confirmada, mas qualquer adoção direta pelo cliente exigirá nova revisão de grants, issuer/claims e testes adversariais.

### 2. Identidade externa confiável

Para Managed Better Auth no caminho server-side:

- `auth_subject` será o identificador de usuário retornado pela sessão verificada (`session.user.id`);
- `auth_issuer` será o namespace do endpoint de Auth configurado no servidor para aquela sessão, obtido de configuração confiável do ambiente, nunca de input do browser;
- o par será comparado exatamente com `app_users(auth_issuer, auth_subject)`;
- email, nome, `team_id`, `user_id`, `membership_id` ou qualquer ID enviado pelo cliente não substituem esse par.

O valor de issuer não será inferido de hostname enviado na requisição. Se uma futura integração baseada diretamente em JWT usar o claim `iss`, ela deverá provar a equivalência/mapeamento com o namespace persistido antes de reutilizar registros existentes.

Não há auto-provisionamento de `app_users` ou `memberships` no primeiro login. Identidade autenticada desconhecida resulta em nenhum usuário interno e, portanto, nenhum acesso.

### 3. Contexto transacional para PostgreSQL

Depois de uma sessão válida, o servidor pode iniciar uma transação e definir somente o contexto mínimo necessário para RLS, por exemplo claims sanitizados contendo `iss` e `sub`.

Esse contexto:

- é definido exclusivamente por código server-side após `auth.getSession()` bem-sucedido;
- é `LOCAL` à transação e não deve vazar entre requests/conexões reutilizadas;
- não recebe JSON arbitrário vindo do browser;
- é consumido por SQL estático/parametrizado;
- não transforma uma variável de sessão em fonte autônoma de confiança.

A distinção é essencial: uma variável configurável pelo próprio cliente SQL é insegura como identidade; a mesma variável pode ser um transporte aceitável quando um servidor confiável valida a sessão, controla a credencial de banco e a define dentro da transação.

### 4. Interface PostgreSQL futura

A próxima migration deve preferir helpers pequenos e portáveis, `STABLE`, `SECURITY INVOKER`, sem argumentos de identidade e com `search_path` deliberado. A interface esperada é equivalente a:

- `current_auth_issuer()` -> issuer do contexto verificado ou `NULL`;
- `current_auth_subject()` -> subject do contexto verificado ou `NULL`;
- `current_app_user_id()` -> `app_users.id` correspondente ao par, somente se o usuário não estiver desabilitado.

`current_app_user_id()` não deve ser usado para definir a própria policy de `app_users` se isso criar recursão de RLS. A policy de `app_users` deve conseguir reconhecer diretamente o próprio `auth_issuer + auth_subject`; as demais tabelas podem então resolver o usuário corrente sem `SECURITY DEFINER` e sem bypass de RLS.

Falha, ausência ou JSON inválido no contexto devem resultar em `NULL` e nenhuma linha visível.

### 5. Policies mínimas de leitura

A primeira liberação será exclusivamente `SELECT`.

Comportamento esperado:

- `app_users`: o usuário só pode enxergar sua própria linha quando `auth_issuer + auth_subject` correspondem ao contexto verificado e `disabled_at IS NULL`;
- `memberships`: somente memberships do `current_app_user_id()` com `revoked_at IS NULL`;
- `teams`: somente equipes para as quais exista membership ativa do usuário corrente;
- `contractings`, `related_identifiers`, `contracting_items` e `contracting_events`: somente linhas cujo `team_id` possua membership ativa do usuário corrente.

Não haverá policy permissiva de `INSERT`, `UPDATE` ou `DELETE` nessa slice. Q-009 permanece aberta e escrita continuará separada da leitura.

### 6. Grants e papel operacional

O papel usado pelo servidor para consultas normais deve:

- não ser owner das tabelas;
- não ter `BYPASSRLS`;
- não usar `neondb_owner` como identidade operacional;
- receber apenas os grants necessários ao caso de uso.

A migration de policies não deve converter `PUBLIC` ou um papel anônimo em leitor dos dados internos. Testes podem criar papéis artificiais e grants adicionais apenas no banco descartável para provar o enforcement.

### 7. Cadastro público não concede autorização

A documentação atual registra que qualquer pessoa pode se cadastrar por padrão no Managed Better Auth.

Isso não altera a autorização interna:

- cadastro/autenticação não cria `app_user` automaticamente;
- `app_user` sem membership ativa não lê dados de equipe;
- membership revogada deixa de autorizar imediatamente na consulta ao banco;
- usuário interno desabilitado deixa de resolver como usuário corrente.

Mesmo assim, antes de expor Auth real, a integração deve impedir signup público como comportamento da aplicação. O mecanismo concreto deve ser revalidado na documentação vigente na slice de Auth real; ocultar o botão não é suficiente.

### 8. Sessão, revogação e fail-closed

O SDK server-side atual pode cachear dados de sessão em cookie assinado. A autorização de negócio não será derivada de membership embutida nessa sessão.

Membership e `disabled_at` são consultados no PostgreSQL a cada acesso autorizado. Assim, uma membership revogada ou usuário interno desabilitado não permanece autorizado por causa do cache da sessão.

Se a sessão não puder ser validada, o issuer/subject não puderem ser derivados, o contexto não puder ser estabelecido ou o banco não puder verificar membership, a resposta deve falhar fechada.

## Red-team

### Usuário autenticado sem membership

Resultado esperado: pode existir no provedor e até em `app_users`, mas não enxerga equipes nem linhas operacionais sem membership ativa.

### Membership revogada

Resultado esperado: `revoked_at IS NOT NULL` não participa das policies; acesso desaparece sem depender de novo login.

### UUID conhecido de outra equipe

Resultado esperado: conhecer `contracting_id`, item, identificador ou qualquer UUID não altera o resultado; `team_id` continua filtrado por membership ativa obtida no banco.

### Forja de IDs pelo browser

`issuer`, `subject`, `app_user_id`, `membership_id` e `team_id` enviados pelo browser não são usados como identidade. O servidor deriva issuer/subject da sessão e configuração confiáveis e o banco deriva o restante.

### Forja do contexto PostgreSQL

O contexto transacional não é tratado como seguro se o cliente possuir credencial SQL. Por isso a credencial operacional permanece server-only e não existe endpoint de SQL arbitrário. Um vazamento dessa credencial é incidente de segurança, não um cenário autorizado.

### Papel privilegiado

Owner, superuser ou `BYPASSRLS` não prova autorização. O caminho normal usa papel não privilegiado e os testes adversariais também.

### Data API

A Data API atual suporta JWT/JWKS e RLS, mas não é necessária para a primeira fronteira. Se for adotada depois, deve haver prova independente de issuer, grants, papel autenticado, ausência de acesso anônimo e equivalência com o modelo `app_users + memberships`.

### Signup público

Achado material: Managed Better Auth permite signup por padrão, em conflito com a baseline do projeto. A mitigação estrutural desta decisão é não autoautorizar identidades recém-criadas; a integração real de Auth continua proibida até existir controle de admissão testado além da UI.

## Consequências

### Positivas

- mantém `issuer + subject` e `memberships` como fonte de autorização;
- preserva PostgreSQL/RLS portátil e testável localmente;
- não exige Data API para segurança;
- não envia segredo de banco ao browser;
- revogação de membership é efetiva no banco;
- não resolve Q-009 nem Q-010 por inferência.

### Custos

- o servidor passa a ser parte explícita da fronteira de confiança;
- toda consulta interna precisa executar com contexto transacional correto;
- uma conexão operacional comprometida poderia forjar o contexto e deve ser protegida como credencial sensível;
- uma futura adoção direta da Data API exigirá nova integração/teste, apesar das capacidades atuais do provedor.

## Próxima implementação permitida

A evidência é suficiente para uma slice independente que implemente, em PostgreSQL descartável e sem Auth hospedado:

- helpers de contexto/identidade;
- policies `SELECT` para usuário próprio + membership ativa;
- testes de não autenticado, usuário sem membership, membership revogada, usuário desabilitado, UUID conhecido e cross-team;
- teste explícito de que contexto ausente/inválido falha fechado;
- nenhum grant de escrita e nenhuma policy de escrita.

A integração real com Managed Better Auth, secrets, signup/admission e banco hospedado continua fora dessa próxima slice.
