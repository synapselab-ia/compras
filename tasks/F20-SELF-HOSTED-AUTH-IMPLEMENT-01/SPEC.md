# F20-SELF-HOSTED-AUTH-IMPLEMENT-01 — Implementar Better Auth self-hosted mantendo a fronteira F14/F08

**Classe:** T1 — feature, com impacto T2 — segurança e T3 — integração externa  
**Estado:** DONE / PASS — CI `33869932738`  
**Dependências:** F14, F18, F19, ADR-006, ADR-007, ADR-008, ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A ADR-009 adotou Better Auth self-hosted porque o Managed Neon Auth observado não oferece o enforcement obrigatório de signup restrito. O repositório ainda usa `@neondatabase/auth` no runtime F14 e não possui schema/migration Auth próprio, role boundary Auth nem dependência direta do Better Auth.

## Resultado esperado

Substituir o adaptador Managed Neon Auth por Better Auth self-hosted no código e nos testes, sem provisionar ambiente hospedado persistente, sem usuário real e sem dados reais.

Ao final, a aplicação deve preservar a interface operacional existente:

- sign-in email/senha somente por Server Action;
- sign-out somente por Server Action;
- sessão validada no servidor;
- `/api/auth/[...path]` permanece deny-all;
- identidade confiável permanece `issuer + subject`;
- autorização final continua em `app_users` + membership + PostgreSQL/RLS;
- signup permanece negado pelo motor Auth e pela superfície HTTP.

## Implementação obrigatória

1. tornar `better-auth` dependência direta e com versão exata compatível;
2. adicionar `pg`/tipos necessários se a implementação PostgreSQL escolhida exigir;
3. remover a dependência runtime de `@neondatabase/auth` somente depois que todos os call sites equivalentes estiverem cobertos;
4. criar módulo `server-only` de configuração Better Auth;
5. usar configuração mínima da ADR-009:
   - email/senha habilitado;
   - `disableSignUp=true`;
   - `socialProviders={}`;
   - nenhum plugin de método lateral;
   - `trustedOrigins` estritos;
   - CSRF/origin checks não desabilitados;
   - cookie cache não habilitado;
6. decidir e testar o transporte de cookies de Server Actions usando `nextCookies()` oficial ou forwarding explícito de `Set-Cookie`;
7. preservar `src/server/auth/private-admission.ts` e `readPrivateAuthSessionState()` como fronteira estreita, alterando implementação interna sem ampliar consumidores;
8. fixar `issuer = urn:compras:better-auth:self-hosted:v1` no servidor;
9. introduzir configuração server-only para `AUTH_DATABASE_URL`, `BETTER_AUTH_SECRET` e `COMPRAS_AUTH_BASE_URL`, com validação fail-closed;
10. separar a conexão Auth da conexão de domínio `DATABASE_URL`;
11. gerar SQL do schema Better Auth a partir da versão pinada e versioná-lo em diretório Auth próprio;
12. criar scripts/testes de role/grants Auth com PostgreSQL efêmero:
    - schema `auth`;
    - migrator separado;
    - runtime Auth sem superuser/BYPASSRLS/ownership;
    - runtime Auth sem grants de domínio;
13. criar prova local/efêmera de bootstrap one-shot apenas com usuário fictício, sem endpoint público;
14. provar depois do bootstrap que novo signup é rejeitado, sign-in existente funciona, sessão resolve `subject` e sign-out invalida cookie;
15. provar que autenticar não cria `app_users` nem membership;
16. remover ou atualizar a prova F19 para evitar duplicação, preservando os cenários de segurança relevantes.

## Configuração e secrets

Nenhum valor real entra no repositório.

Variáveis esperadas no futuro preview:

- `AUTH_DATABASE_URL` — role Auth runtime;
- `DATABASE_URL` — role domínio/RLS existente;
- `BETTER_AUTH_SECRET` — secret server-only;
- `COMPRAS_AUTH_BASE_URL` — origem exata do Preview;
- `COMPRAS_PERSISTENT_READ_ENABLED` continua desligado durante esta work unit local/CI.

A F20 não escreve essas variáveis em Vercel.

## Schema e roles

O SQL/versionamento deve deixar explícito:

- schema `auth` separado;
- ownership/migration fora do runtime;
- grants mínimos da role Auth runtime;
- ausência de grants Auth sobre tabelas do domínio;
- ausência de `BYPASSRLS` e privilégios administrativos;
- `search_path` Auth previsível e restrito;
- migrations Auth imutáveis depois de aplicadas.

Não reescrever `database/migrations/0001..0003`.

## Bootstrap de preview

Apenas desenhar/implementar o mecanismo local/efêmero e seus testes.

O mecanismo deve:

- ser one-shot e não roteável;
- falhar se usado fora de condição explicitamente habilitada;
- usar somente credenciais fictícias nos testes;
- não criar membership automaticamente;
- retornar/registrar apenas o `subject` necessário para uma futura etapa de provisionamento;
- não permanecer como signup público temporário.

A execução hospedada do bootstrap fica fora da F20.

## Rate limiting

Como `auth.api.*` server-side não herda o rate limiter client-side do Better Auth, F20 deve documentar e testar a fronteira de exposição:

- enquanto o preview estiver atrás da Vercel Authentication, essa barreira externa é obrigatória;
- não afirmar que o login está pronto para exposição pública ampla;
- se houver mecanismo simples e testável de throttling server-side sem nova infraestrutura prematura, ele pode ser incluído;
- caso contrário, deixar uma condição objetiva para a work unit de hospedagem antes de remover a proteção externa.

## Red-team obrigatório

Rejeitar PASS se qualquer um ocorrer:

- signup funciona apesar de `disableSignUp=true`;
- `/api/auth/[...path]` delega para handler Better Auth;
- OAuth, magic link, OTP, passkey, admin ou reset ganham rota pública não planejada;
- `trustedOrigins` aceita wildcard ou localhost em configuração hospedável;
- `BETTER_AUTH_SECRET` ou connection string aparece em bundle/log/test output;
- sessão/subject é aceito do browser sem validação server-side;
- Auth user cria `app_user`/membership por hook automático;
- role Auth é owner/superuser/BYPASSRLS ou lê domínio;
- role do domínio passa a ler tabelas Auth por conveniência;
- migration Auth depende de painel manual ou versão `latest` não pinada;
- Server Action informa sucesso sem cookie de sessão realmente persistido;
- sign-out informa sucesso sem invalidação real;
- erro Auth cai silenciosamente para modo demo em caminho persistente;
- dependência `@neondatabase/auth` é removida antes de equivalência funcional/testes;
- qualquer dado real ou recurso hosted persistente é criado.

## Verificação obrigatória

- lint;
- typecheck;
- testes unitários/integrados de Auth;
- teste adversarial de signup;
- teste de cookie/session/sign-out;
- PostgreSQL efêmero para schema/roles/grants Auth;
- suíte PostgreSQL/RLS existente sem regressão;
- build Next.js;
- revisão integral do diff;
- documentação/checkpoint atualizados.

## Fora do escopo

- criar projeto/branch Neon hospedado;
- anexar secrets à Vercel;
- habilitar `COMPRAS_PERSISTENT_READ_ENABLED=true` hospedado;
- criar usuário real;
- criar `app_user`/membership hospedado;
- usar dados internos ou pré-publicação;
- renomear projeto Vercel;
- remover Vercel Authentication;
- definir onboarding definitivo de usuários institucionais.

## Critério de encerramento

F20 fecha quando Better Auth self-hosted estiver implementado e provado local/CI como substituto funcional e de segurança do adaptador Managed Neon, com schema/roles/migrations reproduzíveis e sem provisionamento hosted. Deve deixar exatamente uma próxima work unit para o preflight/provisionamento privado com dados exclusivamente fictícios.

## Resultado executado

F20 foi concluída na PR `#36`. O commit funcional `49bd1f346373d2c97eb5f32b009b2b2ea6551408` passou integralmente a CI `33869932738`, incluindo `verify`, suíte PostgreSQL/RLS e `auth-database`. O checkpoint avançou para `F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01` sem permitir dados reais ou provisionamento hosted durante F20.
