# F14-PRIVATE-AUTH-ADMISSION-01 — Implementar autenticação privada sem signup público

**Classe:** T1 — feature, com impacto de T2 — segurança e T3 — integração externa  
**Estado:** READY após conclusão de F13  
**Dependências:** F08, F09, F12, ADR-003 e ADR-006  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

A F13 definiu a fronteira do primeiro preview hospedado privado e revalidou que Vercel + Neon continuam tecnicamente adequados sob controles explícitos. Contudo o runtime atual apenas consome uma sessão já existente em `getVerifiedExternalIdentity()`.

Não existe ainda uma jornada canônica de sign-in/sign-out nem uma fronteira HTTP da aplicação que prove que usuários não podem se cadastrar diretamente. Provisionar Auth hospedado antes dessa etapa produziria uma integração incompleta: a arquitetura exigiria `disable_sign_up=true` no provider, mas a própria aplicação ainda não teria comportamento de admissão testável.

F14 deve implementar a menor jornada privada de Auth necessária para que uma próxima slice consiga provisionar o preview fictício sem introduzir signup público.

## 2. Resultado esperado

Implementar uma experiência de autenticação que:

- ofereça somente sign-in de usuário já admitido;
- possua sign-out explícito;
- preserve `getVerifiedExternalIdentity()` como fonte de `issuer + subject` para F08;
- não exponha signup pela UI;
- rejeite signup direto na superfície HTTP da aplicação;
- não habilite OAuth, magic link ou qualquer método com criação implícita de usuário;
- mantenha autorização exclusivamente em `app_users` + membership + RLS;
- trate sessão/configuração/provider indisponível de forma genérica e fail-closed;
- permaneça testável sem recurso Neon/Vercel hospedado e sem secrets reais.

## 3. Revalidação externa obrigatória

Antes da implementação, consultar documentação oficial atual somente para as superfícies usadas.

Confirmar, no mínimo:

- integração Next.js server/client atual do `@neondatabase/auth` usado no `package.json`;
- métodos/handler necessários a sign-in, sessão e sign-out;
- semântica atual de cookies e redirects;
- quais endpoints o handler genérico expõe e como restringir/rejeitar operações não permitidas;
- comportamento de `disable_sign_up` no Managed Better Auth para registrar o contrato de provisionamento futuro.

Se o SDK não permitir restringir adequadamente a superfície sem habilitar signup ou outro método implícito, não enfraquecer o requisito: registrar blocker e escolher integração server-side mais estreita suportada oficialmente.

## 4. Invariantes

Não alterar:

- `issuer` é `NEON_AUTH_BASE_URL` lida de configuração server-side confiável;
- `subject` vem da sessão validada;
- browser não define issuer/subject/`app_user_id`/membership/`team_id`;
- login no provider não cria automaticamente registro de domínio;
- membership ativa continua sendo a autorização de equipe;
- RLS continua enforcement final;
- runtime continua usando role não privilegiada;
- falha persistente nunca retorna fixture demo como fallback;
- `REAL_DATA_ALLOWED = NO`.

## 5. Superfície de Auth

A implementação deve preferir uma superfície estreita e explicitamente permitida.

### Permitido inicialmente

- leitura de sessão;
- sign-in email/senha;
- sign-out;
- callbacks estritamente necessários a esse método, se o SDK realmente exigir.

### Proibido inicialmente

- sign-up;
- OAuth/social providers;
- magic link;
- email OTP com auto-signup;
- recuperação/reset de senha;
- Admin API exposta ao browser;
- organização/role do Better Auth como substituto de membership Compras.

Não assumir que “não há botão” significa que a operação não existe. Se um catch-all handler expõe endpoint proibido, colocar uma barreira server-side testável antes de delegar ao SDK.

## 6. Rotas operacionais e sessão

O modo demo pode continuar acessível conforme a semântica já existente quando `COMPRAS_PERSISTENT_READ_ENABLED` não estiver habilitado.

Quando o modo persistente estiver habilitado:

- sessão ausente deve levar ao estado/rota de sign-in em vez de executar a jornada como usuário autenticado;
- sessão válida deve permitir que F08 derive a identidade e consulte o banco;
- sessão inválida/expirada deve retornar ao estado não autenticado;
- configuração inválida/provider indisponível deve produzir indisponibilidade genérica, sem detalhe de provider e sem demo fallback.

Não criar redirect arbitrário a partir de `callbackURL` fornecido pelo cliente. Destinos pós-login/pós-logout devem ser locais e permitidos pela aplicação.

## 7. Autorização após login

Três estados permanecem distintos:

1. **não autenticado** — não há sessão válida;
2. **autenticado sem autorização interna** — existe sessão/provider identity, mas não há `app_user` ativo + membership ativa;
3. **autenticado autorizado** — RLS permite o escopo correspondente.

F14 não deve criar `app_users`/memberships automaticamente para transformar o estado 2 em 3.

Uma identidade autenticada desconhecida recebe nenhum dado interno e mensagem genérica apropriada; não recebe indicação de IDs/equipes existentes.

## 8. Contrato com o preview hospedado futuro

F14 não provisiona provider, mas o código/documentação deve registrar que a próxima work unit só pode habilitar Auth real depois de configurar provider-side:

- email/senha como método inicial;
- `disable_sign_up=true`;
- métodos adicionais desabilitados;
- trusted origin somente para a superfície protegida necessária;
- usuário de teste fictício criado por caminho administrativo controlado;
- `app_user`/membership fictícios adicionados separadamente ao banco do produto;
- Vercel Deployment Protection ativo antes de expor a aplicação.

A barreira da aplicação e `disable_sign_up` são defesa em profundidade: ambas devem existir no preview.

## 9. Segurança de configuração

- `NEON_AUTH_COOKIE_SECRET` continua server-only;
- `DATABASE_URL` continua server-only;
- nenhum secret usa variável client-public;
- `NEON_AUTH_BASE_URL` pode ser configuração, mas sua origem continua ambiente server-side e não request;
- erros não serializam config, cookie, headers de sessão ou resposta bruta do provider;
- testes usam endpoints/domínios artificiais `.invalid` e secrets fictícios explícitos.

## 10. Red-team obrigatório

Provar pelo menos:

### Signup direto

Uma requisição direta ao caminho de signup da aplicação é rejeitada antes de criar usuário, independentemente da ausência de botão.

### Endpoint lateral

OAuth/magic-link/OTP/admin ou outro endpoint não permitido não pode ser usado para contornar a política de admissão.

### Sem sessão

Rota operacional persistente não mostra dados e encaminha ao estado autenticável correto.

### Sessão inválida

Não é convertida em identidade parcial e não mantém acesso.

### Forja de identidade

Query/body/header com issuer, subject, email, user ID, membership ou team ID não altera a identidade usada por F08.

### Usuário desconhecido

Sessão válida de identidade sem `app_user`/membership não ganha dados.

### Revogação/desabilitação

As regressões existentes continuam provando que membership revogada/app_user desabilitado retiram acesso no banco.

### Redirect

Parâmetro externo não transforma login/logout em open redirect.

### Exposição client-side

Bundle/props/HTML não contêm cookie secret, `DATABASE_URL` ou credencial administrativa.

### Falha do provider

Erro interno retorna estado genérico e não ativa demo silenciosamente em modo persistente.

## 11. Verificação

Obrigatório:

- `npm ci`;
- `npm run lint`;
- `npm run typecheck`;
- `npm test`;
- `npm run build`;
- testes novos de rota/guard/admissão;
- regressões de `external-identity` e `trusted-context`;
- regressões da Central/detalhe persistentes;
- inspeção de bundle/superfície quando aplicável para secrets client-side;
- CI completa.

Não declarar provider-side `disable_sign_up` executado nesta slice; apenas provar o contrato e a defesa da aplicação.

## 12. Fora do escopo

Não:

- projeto Neon/Vercel;
- secret real;
- Auth hospedado;
- usuário real ou hospedado;
- migration/policy de escrita;
- auto-provisionamento de identidade interna;
- OAuth/magic link/OTP;
- password reset;
- MFA;
- Q-009/Q-010;
- dados reais;
- deploy.

## 13. Critério de encerramento

F14 termina quando o repositório possui jornada privada de sign-in/sign-out e uma superfície de Auth que rejeita signup/endpoints não permitidos de forma adversarialmente testada, sem alterar a autorização F08/RLS, e quando existe exatamente uma nova `NEXT_ACTION` pequena para provisionar e provar o preview hospedado fictício da ADR-006.
