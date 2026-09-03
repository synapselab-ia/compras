# ADR-009 — Adotar Better Auth self-hosted para a admissão privada

**Status:** Accepted / ADOPT  
**Data:** 2026-09-03  
**Escopo:** autenticação do primeiro preview privado e evolução posterior; não autoriza dados reais  
**Classificação permitida nesta etapa:** PUBLIC / FICTITIOUS ONLY

## Contexto

A F17 comprovou em sessão autenticada real que o Managed Better Auth disponível na conta/região Neon não permite aplicar e ler de volta o controle obrigatório de signup restrito. O provider abriu email signup por padrão e o controle correspondente estava indisponível para escrita. A tentativa foi encerrada fail-closed e o recurso Neon descartável foi removido.

A F18 provou que a aplicação Next.js pode ser hospedada em Preview atrás da Vercel Authentication sem Auth interno, banco, secrets ou dados reais. Isso removeu o bloqueio visual, mas não resolveu a admissão privada persistente.

A F19 avaliou a alternativa de executar Better Auth diretamente na aplicação e usar PostgreSQL controlado como storage de Auth.

## Evidência oficial revalidada

Documentação oficial Better Auth v1.6 revalidada em 2026-09-03:

- PostgreSQL é suportado diretamente por `betterAuth({ database: Pool })`;
- PostgreSQL pode usar schema não-default via `search_path`;
- o CLI/programmatic migration system consegue gerar/aplicar o schema Auth;
- `emailAndPassword.enabled=true` habilita email/senha;
- `emailAndPassword.disableSignUp=true` bloqueia signup;
- `trustedOrigins` é configurável explicitamente;
- `advanced.disableCSRFCheck` e `advanced.disableOriginCheck` existem e não devem ser habilitados;
- endpoints do Better Auth podem ser chamados diretamente por `auth.api.*` no servidor;
- `auth.api.signInEmail`, `auth.api.getSession` e `auth.api.signOut` suportam o fluxo necessário à F14;
- Server Actions que precisam escrever cookies devem encaminhar `Set-Cookie` corretamente ou usar o integration plugin oficial `nextCookies`;
- plugins e social providers só entram quando explicitamente configurados;
- cookie cache de sessão é desabilitado por padrão e não precisa ser ligado no primeiro preview;
- chamadas server-side por `auth.api` não recebem o rate limit client-side do Better Auth, portanto a proteção de login precisa ser tratada conscientemente antes de exposição mais ampla.

Fontes oficiais:

- `https://better-auth.com/docs/1.6/adapters/postgresql`
- `https://better-auth.com/docs/1.6/concepts/database`
- `https://better-auth.com/docs/1.6/reference/options`
- `https://better-auth.com/docs/1.6/concepts/api`
- `https://better-auth.com/docs/1.6/authentication/email-password`
- `https://better-auth.com/docs/1.6/integrations/next`
- `https://better-auth.com/docs/1.6/concepts/session-management`
- `https://better-auth.com/docs/1.6/concepts/rate-limit`

## Prova executável F19

A branch F19 adicionou `src/server/auth/self-hosted-proof.test.ts` usando somente SQLite em memória e valores fictícios.

A prova executada na CI demonstrou com o Better Auth realmente instalado no lockfile:

1. `disableSignUp=true` rejeita `auth.api.signUpEmail` antes de qualquer tabela Auth existir;
2. `socialProviders={}` e `plugins=[]` mantêm métodos laterais ausentes da instância de prova;
3. migrations Better Auth podem ser aplicadas programaticamente em storage descartável;
4. um bootstrap one-shot não exposto por HTTP pode criar um usuário fictício em uma instância separada;
5. ao voltar para a configuração guardada com `disableSignUp=true`, novo signup continua rejeitado;
6. o usuário já existente consegue autenticar por `auth.api.signInEmail`;
7. o cookie de sessão emitido permite `auth.api.getSession` retornar identidade server-side;
8. `auth.api.signOut` emite a invalidação do cookie.

A CI da prova passou em lint, typecheck, testes, build e suíte PostgreSQL/RLS existente. Nenhum usuário real, secret operacional ou banco hospedado foi usado.

## Decisão

**ADOPT:** substituir a dependência arquitetural do Managed Neon Auth por Better Auth self-hosted no caminho privado.

Neon pode continuar sendo o PostgreSQL hospedado, mas deixa de ser o controlador de admissão. A aplicação passa a controlar a configuração Auth versionada e verificável.

F17 permanece registrada como evidência histórica e `ON HOLD`; ela não volta a bloquear o projeto. Se o Managed Neon Auth ganhar no futuro controles equivalentes e houver motivo para reconsiderá-lo, isso exige nova decisão arquitetural.

## Fronteira escolhida

### Superfície HTTP

A política da F14 é preservada:

- `/api/auth/[...path]` continua deny-all e não monta `auth.handler()`/`toNextJsHandler`;
- sign-in continua somente por Server Action estreita;
- sign-out continua somente por Server Action estreita;
- sessão é lida server-side;
- signup, OAuth, OTP, magic link, reset de senha, Admin API e demais endpoints não ganham rota HTTP pública por conveniência.

Better Auth possuir métodos programáticos não significa que a aplicação os exponha por HTTP.

### Configuração mínima

O primeiro preview privado deve usar configuração equivalente a:

- `emailAndPassword.enabled = true`;
- `emailAndPassword.disableSignUp = true`;
- `socialProviders = {}`;
- nenhum plugin de método de autenticação;
- `trustedOrigins` contendo somente a origem Preview aprovada;
- `advanced.disableCSRFCheck` não habilitado;
- `advanced.disableOriginCheck` não habilitado;
- cookie cache não habilitado;
- cookies secure/httpOnly em hospedagem;
- integration plugin `nextCookies()` permitido somente como transporte de `Set-Cookie` em Server Actions, por não adicionar método de admissão.

### Identidade

A identidade entregue à fronteira F08 continua sendo derivada exclusivamente de sessão validada no servidor:

```text
issuer = urn:compras:better-auth:self-hosted:v1
subject = Better Auth user.id validado por getSession
```

Nenhum `user_id`, `issuer`, `subject`, `team_id` ou membership fornecido pelo browser é aceito como identidade confiável.

O issuer é estável e versionado para não depender de hostname transitório de deployment.

### Separação de Auth e domínio

O Auth pode usar o mesmo cluster/branch PostgreSQL do preview, mas deve possuir fronteira própria:

- schema dedicado: `auth`;
- role de migration/owner separada da role runtime;
- role runtime Auth dedicada, sem `SUPERUSER`, `BYPASSRLS`, `CREATEDB`, `CREATEROLE` ou ownership;
- `search_path` da conexão Auth fixado no schema `auth`;
- grants runtime limitados às tabelas/sequências Auth necessárias;
- role Auth sem grants operacionais nas tabelas de domínio `public`;
- role do domínio continua separada e sujeita à RLS existente;
- Auth não recebe credencial de bootstrap/migration no runtime normal.

A existência do usuário em Better Auth não cria `app_users` nem `memberships` automaticamente.

### Connection strings e secrets

Separar no runtime:

- `AUTH_DATABASE_URL` — conexão somente da role Auth runtime;
- `DATABASE_URL` — conexão existente da role de domínio/RLS;
- `BETTER_AUTH_SECRET` — secret server-only do Better Auth;
- `COMPRAS_AUTH_BASE_URL` — origem exata do ambiente privado.

Todos são server-only e, no primeiro preview, devem ser Vercel Preview + branch-specific. Nenhum valor entra no Git, PR, log ou browser bundle.

### Migrations Auth

Não usar painel do provider como fonte canônica.

A implementação deve:

1. promover `better-auth` a dependência direta e com versão exata antes de gerar schema;
2. gerar SQL para a versão pinada;
3. revisar e versionar o SQL em diretório Auth separado das migrations do domínio;
4. aplicar com role migrator, não com runtime;
5. verificar schema/objetos/grants após aplicação;
6. tratar upgrade de Better Auth como migration nova, sem reescrever migration aplicada.

O proof F19 usou o `better-auth@1.6.23` transitivo já fixado pelo lockfile. Isso é suficiente para a prova, mas **não** é aceitável como dependência de produção; F20 deve tornar a dependência direta antes da implementação.

### Bootstrap do primeiro usuário fictício

No preview não haverá signup público temporário.

O bootstrap será um caminho administrativo one-shot e não roteável:

1. banco/schema Auth vazio e protegido;
2. script/config de bootstrap executado apenas pelo operador, não implantado como endpoint;
3. instância bootstrap pode permitir `signUpEmail` somente dentro desse processo fechado para criar exatamente a identidade fictícia de teste;
4. runtime normal permanece configurado com `disableSignUp=true`;
5. após bootstrap, prova obrigatória de que novo signup é rejeitado e o usuário existente consegue sign-in;
6. criação do `app_user`/membership fictícios é ação administrativa separada e explícita; não nasce de hook Auth automático.

Antes de uso institucional, onboarding administrativo definitivo deve receber work unit própria; o bootstrap do preview não vira processo permanente por inércia.

## Threat model comparativo

| Vetor | Managed Neon Auth observado | Better Auth self-hosted adotado |
|---|---|---|
| Signup de email | Ativo por padrão e sem WRITE disponível | `disableSignUp=true` versionado e testável |
| Readback/enforcement | Provider não expôs controle exigido | Configuração + teste executável sob controle do repo |
| OAuth lateral | Provider observado apresentou Google/shared keys | `socialProviders={}`; nenhum provider configurado |
| Plugins laterais | Não foi possível provar estado seguro | Lista explícita; somente integração de cookie permitida |
| Trusted origins | Provider não permitiu fechar toda a prova | Lista estrita na configuração da aplicação |
| Superfície HTTP | Provider possui endpoints próprios | Catch-all da aplicação permanece deny-all |
| Banco Auth | Gerenciado pelo provider | Schema/roles/grants versionados e separados |
| Identidade para RLS | SDK Neon | Sessão Better Auth server-side -> issuer + subject |
| Portabilidade | Dependência de capability Neon | PostgreSQL + Better Auth controlados pela aplicação |
| Responsabilidade operacional | Menor, mas capability insuficiente | Maior; exige migration, secret rotation, atualização e monitoramento próprios |

## Red-team e respostas

- **endpoint signup direto:** deny-all HTTP + `disableSignUp=true` no motor;
- **OAuth/plugin lateral:** nenhum provider/método plugin configurado;
- **wildcard/localhost em hospedagem:** proibidos em `trustedOrigins` do preview;
- **Auth -> autorização automática:** proibido; `app_users`/membership continuam separados;
- **role privilegiada:** proibida no runtime Auth;
- **Auth contornar RLS do domínio:** role Auth não recebe grants no domínio;
- **reset/password flow:** não exposto por rota/Server Action nesta etapa;
- **secret no client:** configuração inteira permanece em módulo `server-only`;
- **sessão forjada:** `getSession` server-side é fonte da identidade;
- **cookie em Server Action:** F20 deve usar `nextCookies()` oficial ou forwarding explícito testado; nunca presumir cookie setado;
- **migration não reproduzível:** SQL gerado da versão exata é versionado antes de hospedagem;
- **dependência transitiva:** F20 deve adicionar pin direto antes de código runtime;
- **brute force/rate limit:** `auth.api` server-side não usa o rate limiter client-side; o primeiro preview continua atrás da Vercel Authentication e F20 deve deixar explícita a proteção de tentativas antes de qualquer exposição sem essa barreira;
- **cookie cache/revogação atrasada:** não habilitar cookie cache no primeiro preview.

## Consequências

### Positivas

- remove o blocker estrutural do signup Managed Neon Auth;
- mantém o modelo de segurança F14/F08/RLS;
- torna a política de admissão versionada, testável e revisável;
- reduz lock-in do Auth sem trocar o PostgreSQL;
- permite evolução sem esperar capability futura do provider.

### Custos

- a equipe assume migrations e upgrades Better Auth;
- passa a existir uma conexão/role Auth runtime adicional;
- rotação de `BETTER_AUTH_SECRET` e observabilidade passam a ser responsabilidade do produto;
- Server Actions exigem tratamento correto de cookies;
- proteção contra tentativas abusivas precisa ser explicitamente desenhada, pois chamadas `auth.api` server-side não herdam rate limit client-side.

## Próxima work unit

A decisão deve ser implementada em `F20-SELF-HOSTED-AUTH-IMPLEMENT-01`, ainda somente com dados fictícios e sem provisionamento persistente hospedado. A F20 deve trocar o adaptador Auth da aplicação, adicionar dependências diretas, schema/migrations Auth reproduzíveis, testes de admissão/cookie/sessão e preservar o deny-all HTTP e a fronteira RLS.
