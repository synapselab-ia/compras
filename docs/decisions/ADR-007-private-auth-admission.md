# ADR-007 — Admissão privada por server actions sem proxy Auth genérico

**Status:** Accepted  
**Data:** 2026-09-02  
**Escopo:** implementação F14; nenhum recurso Neon/Vercel é provisionado  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

A ADR-006 exige que o primeiro preview hospedado use Managed Better Auth sem signup público. O runtime F08 já sabe consumir uma sessão validada por `createNeonAuth(...).getSession()`, mas a aplicação ainda não possuía sign-in/sign-out nem uma superfície HTTP que impedisse operações laterais do Better Auth.

O requisito de F14 é mais estreito que a superfície padrão do SDK: somente sign-in por email/senha de identidade já criada, leitura de sessão e sign-out. Signup, OAuth, magic link, OTP, reset de senha, Admin API e organizações não fazem parte da primeira jornada.

## Evidência externa revalidada

Fontes oficiais/repositório oficial consultados em 2026-09-02:

- Neon — Next.js Server SDK Reference: https://neon.com/docs/auth/reference/nextjs-server
- Neon — Managed Better Auth overview: https://neon.com/docs/auth/overview
- Neon — Update email/password configuration: https://neon.com/docs/reference/api/auth/update-neon-auth-email-and-password-config
- `neondatabase/neon-js` — `packages/auth/NEXT-JS.md`
- `neondatabase/neon-js` — `packages/auth/src/next/server/index.ts`
- `neondatabase/neon-js` — `packages/auth/src/server/types.ts`
- `neondatabase/neon-js` — `packages/auth/src/server/network-error.ts`

A versão atualmente fixada pelo projeto, `@neondatabase/auth@0.5.0-beta`, coincide com a versão declarada no pacote oficial consultado.

Pontos relevantes confirmados:

1. `createNeonAuth()` suporta uso direto em Server Components, Route Handlers e Server Actions.
2. O exemplo oficial de Server Action usa `auth.signIn.email({ email, password })` e `auth.signOut()` sem exigir que a aplicação exponha o catch-all `auth.handler()`.
3. `auth.handler()` é um proxy genérico para a API Auth e o próprio SDK oferece métodos adicionais como `signUp`, social/OAuth, OTP, Admin e organizações.
4. A configuração hospedada de email/senha possui `disable_sign_up`, que deve permanecer obrigatória no futuro preview.
5. Erros server-side expõem status/código estruturados, incluindo códigos estáveis de falha de transporte; detalhes brutos não precisam ser enviados à UI.

## Decisão

### 1. Não montar `auth.handler()` na primeira jornada

A aplicação **não** delegará `/api/auth/[...path]` ao handler genérico do SDK em F14.

Em vez disso:

- sign-in será uma Server Action que chama somente `auth.signIn.email()`;
- sign-out será uma Server Action que chama somente `auth.signOut()`;
- sessão será lida somente no servidor;
- `/api/auth/[...path]` será uma fronteira deny-all, respondendo `404` sem delegar ao provider.

Isso remove da superfície HTTP da aplicação signup e endpoints laterais que seriam desnecessários para o preview inicial.

### 2. Provider-side signup continua obrigatório como defesa independente

Bloquear o proxy da aplicação não impede alguém de alcançar diretamente o endpoint hospedado do provider caso sua URL seja conhecida. Portanto a próxima work unit de provisionamento só pode considerar Auth pronto quando a configuração real confirmar:

- email/senha habilitado como método inicial;
- `disable_sign_up=true`;
- métodos adicionais de signup/autocriação desabilitados;
- trusted origins limitadas à superfície necessária;
- usuário fictício criado por caminho administrativo controlado.

O bloqueio da aplicação e o bloqueio do provider são defesa em profundidade; nenhum substitui o outro.

### 3. Estados de sessão

O servidor passa a distinguir três resultados genéricos:

- `authenticated`: sessão válida com `user.id`, produzindo apenas `issuer + subject`;
- `unauthenticated`: sessão ausente ou resposta 401/403 de sessão;
- `unavailable`: configuração inválida, falha de transporte/provider ou payload de sessão malformado.

`getVerifiedExternalIdentity()` preserva a interface F08 e retorna identidade somente no primeiro estado.

### 4. Gate antes do banco em modo persistente

Central e detalhe, quando `COMPRAS_PERSISTENT_READ_ENABLED=true`, verificam primeiro o estado da sessão:

- `unauthenticated` -> redirect local fixo para `/auth/sign-in`;
- `unavailable` -> estado genérico de indisponibilidade, sem demo fallback;
- `authenticated` -> segue para o reader existente, que executa novamente a fronteira F08 e deixa PostgreSQL/RLS decidir autorização.

Nenhum `team_id`, membership, `app_user_id`, issuer, subject ou email é passado ao reader como escopo.

### 5. Autenticação não provisiona autorização

Sign-in chama apenas o provider. Não existe `INSERT`/`UPDATE` de `app_users`, memberships ou qualquer tabela de domínio em F14.

Uma identidade existente no provider, mas ausente/desabilitada no domínio ou sem membership ativa, continua recebendo zero acesso pelas policies já validadas.

### 6. Redirects fixos

Server Actions leem somente `email` e `password` do formulário de sign-in. `callbackURL`, `redirectTo`, issuer, subject ou IDs fornecidos pelo browser são ignorados.

Destinos são constantes locais:

- sucesso de sign-in -> `/`;
- credenciais rejeitadas -> `/auth/sign-in?state=rejected`;
- Auth indisponível -> `/auth/sign-in?state=unavailable`;
- sign-out -> `/auth/sign-in?state=signed-out`.

Nenhum redirect externo é construído a partir de input do cliente.

## Red-team

A implementação deve provar:

- chamada direta a `/api/auth/sign-up/...` recebe deny-all e não chega ao SDK;
- OAuth, OTP, admin, reset ou outro endpoint lateral recebe a mesma barreira;
- rota operacional persistente sem sessão não tenta consultar PostgreSQL;
- erro de provider não vira demo nem expõe mensagem bruta;
- campos forjados de callback/issuer/subject/equipe/membership são ignorados;
- usuário autenticado sem autorização interna permanece sem registros;
- F08 continua recebendo apenas `issuer + subject` da sessão server-side;
- cookie secret e `DATABASE_URL` não são importados por módulo client-side;
- não existe chamada de signup ou mutação de domínio na jornada F14.

## Consequências

### Positivas

- superfície de Auth da aplicação fica menor que a superfície genérica do provider;
- ausência de botão de signup deixa de ser o único controle da aplicação;
- F08/RLS permanecem intactos;
- nenhum callback arbitrário é necessário;
- a implementação continua testável sem Auth hospedado.

### Limites

- o preview real ainda depende de `disable_sign_up=true` no provider;
- password reset, OAuth, OTP, MFA e administração continuam fora do produto;
- a jornada não cria usuários internos e exige bootstrap fictício separado na futura work unit.

## Próxima implementação permitida

Depois de F14 passar CI, a próxima slice pode provisionar um preview hospedado **fictício e descartável** conforme ADR-006/ADR-007, provar Deployment Protection, provider signup disabled, separação de roles PostgreSQL, migrations `0001`–`0003`, seed artificial, smoke de sign-in/RLS e deprovisionamento. Dados reais continuam proibidos.
