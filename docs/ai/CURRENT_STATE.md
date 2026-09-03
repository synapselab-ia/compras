# Current State — Compras

**PROJECT_STATUS:** F19_AUTH_PORTABILITY_ADOPTED_F20_READY  
**CURRENT_PHASE:** F19 concluída / ADOPT; F20 pronta; F17 ON HOLD  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_PRIVATE_AUTH_MIGRATION_DESIGNED_NOT_IMPLEMENTED  
**DATABASE_STATUS:** PROTECTED_DOMAIN_READ_MODEL_VALIDATED_AUTH_SCHEMA_NOT_YET_IMPLEMENTED  
**AUTH_STATUS:** SELF_HOSTED_BETTER_AUTH_ADOPTED_DESIGN_PROVEN_NOT_YET_RUNTIME  
**DEPLOYMENT_STATUS:** VERCEL_PREVIEW_READY_DEMO_ONLY_PROTECTED_NO_SECRETS_GIT_AUTODEPLOY_DISABLED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `6c3891d0e4839daa067741bbcf5eafdea542a329`  
**LAST_GOOD_CI_RUN:** `33670574481`  
**F19_INPUT_COMMIT:** `50fd91ced1f5b88761b241c3e9626a7defbb44a5`  
**F19_INPUT_CI_RUN:** `33800687046`  
**F19_PROOF_COMMIT:** `deee704c9dd94a430e051065e035d53599afec5f`  
**F19_PROOF_CI_RUN:** `33803957845`  
**F19_DECISION:** `ADOPT` — ADR-009  
**ON_HOLD:** `F17-B2` — Managed Better Auth observado não permite WRITE + READBACK de `disable_sign_up=true`

## Estado real

A F19 foi executada pelo protocolo canônico a partir da `main` `50fd91ced1f5b88761b241c3e9626a7defbb44a5`, cujo CI `33800687046` estava integralmente em PASS. O `CONTEXT_MANIFEST` permaneceu válido: os 10 inputs estáveis continuam com os blobs esperados.

A frente ativa era a PR/branch F19. Não houve necessidade de reabrir F17 nem de escrever em Vercel/Neon.

## F17 — ON HOLD

A prova provider-side anterior continua válida:

- Vercel control plane: PASS;
- Managed Neon Auth: BLOCKED porque signup restrito não pôde ser aplicado/read-back;
- Auth/projeto Neon descartáveis foram removidos;
- nenhum dado real, usuário ou secret foi criado.

A F17 permanece `ON HOLD` como evidência histórica. Ela não é mais dependência do caminho crítico depois da decisão F19.

## F18 — Hosted demo preservada

A demonstração Vercel continua sendo somente UI/dados fictícios:

- deployment Preview `READY`;
- Vercel Authentication na frente da URL;
- nenhum banco/Auth interno/secret;
- `COMPRAS_PERSISTENT_READ_ENABLED` não habilitado;
- Git auto-deploy restaurado para `false`.

F19 não alterou recurso provider, deployment ou configuração hosted.

## F19 — Auth Portability Design

### Documentação oficial revalidada

A documentação Better Auth v1.6 foi revalidada para PostgreSQL, database/migrations, options, server API, email/password, Next.js, session e rate limit.

Os pontos materiais confirmados foram:

- PostgreSQL direto e schema não-default via `search_path`;
- migrations/schema controláveis pela aplicação;
- `emailAndPassword.disableSignUp=true`;
- `trustedOrigins` explícitos;
- `auth.api.signInEmail`, `getSession` e `signOut` server-side;
- cookies de Server Actions precisam de integração/forwarding correto;
- social providers/plugins são opt-in;
- cookie cache é opt-in;
- `auth.api` server-side não herda o rate limit client-side.

### Prova executável

`src/server/auth/self-hosted-proof.test.ts` executou Better Auth real em SQLite em memória com somente valores fictícios.

O commit de prova reforçada `deee704c9dd94a430e051065e035d53599afec5f` passou a CI `33803957845`:

- `verify`: PASS — lint, typecheck, testes e Next.js build;
- `database`: PASS — toda a suíte PostgreSQL/RLS existente.

A prova demonstrou:

1. signup rejeitado com `disableSignUp=true` antes de qualquer tabela Auth existir;
2. ausência de social providers/plugins laterais na instância de prova;
3. migrations Better Auth programáticas em storage descartável;
4. bootstrap one-shot não roteável em instância separada;
5. novo signup continuou negado ao retornar para a configuração guardada;
6. usuário fictício existente autenticou por server API;
7. cookie emitido resolveu sessão server-side e `subject`;
8. sign-out emitiu invalidação de cookie.

Nenhum usuário real, secret operacional, banco hospedado, recurso Neon ou dado de contratação foi usado.

## Decisão F19 — ADOPT

ADR-009 adota Better Auth self-hosted e remove Managed Neon Auth do caminho crítico.

Neon pode continuar como PostgreSQL hospedado, porém a aplicação passa a controlar a política Auth versionada.

Fronteira escolhida:

- `/api/auth/[...path]` continua deny-all;
- sign-in/sign-out continuam Server Actions estreitas;
- sessão é validada server-side;
- `issuer = urn:compras:better-auth:self-hosted:v1`;
- `subject = Better Auth user.id` vindo de sessão validada;
- `app_users`/membership continuam autorização separada e nunca nascem automaticamente de Auth;
- schema Auth dedicado `auth`;
- migrator/owner separado de runtime Auth;
- runtime Auth sem superuser/BYPASSRLS/ownership e sem grants de domínio;
- `AUTH_DATABASE_URL` separado de `DATABASE_URL`;
- `BETTER_AUTH_SECRET` e `COMPRAS_AUTH_BASE_URL` server-only;
- `disableSignUp=true`, `socialProviders={}`, trusted origins estritos;
- nenhum plugin de método lateral;
- integration plugin `nextCookies()` pode ser usado apenas para transporte de cookies se F20 o provar corretamente;
- cookie cache não deve ser habilitado no primeiro preview.

O proof usou o `better-auth@1.6.23` transitivo já fixado no lockfile. Isso não é aceito para runtime final: F20 deve transformar Better Auth em dependência direta com versão exata antes da implementação.

## Red-team F19

- signup por endpoint direto apesar de botão ausente: rejeitado por dupla barreira planejada, deny-all HTTP + `disableSignUp=true`;
- OAuth/social/plugin lateral: não configurados;
- wildcard/localhost hosted: proibidos;
- Auth user ganhando autorização automaticamente: proibido;
- role Auth privilegiada ou com acesso ao domínio: proibida;
- reset/OTP/magic link/Admin API públicos: fora da superfície HTTP;
- secret no browser: configuração deve permanecer `server-only`;
- subject fornecido pelo cliente: rejeitado;
- cookie de Server Action presumido: identificado como gate explícito F20;
- migration via painel/manual/latest: rejeitada; versão pinada + SQL versionado;
- dependência transitiva: identificada e promovida a gate da F20;
- brute force: identificado que `auth.api` server-side não recebe rate limit client-side; Vercel Authentication continua obrigatória no primeiro preview e exposição mais ampla exigirá controle deliberado;
- cookie cache/revogação atrasada: cookie cache não será habilitado no primeiro preview.

## Verificação

- `main` de entrada: `50fd91ced1f5b88761b241c3e9626a7defbb44a5`;
- CI de entrada `33800687046`: PASS;
- `CONTEXT_MANIFEST`: VALID;
- documentação oficial Better Auth: REVALIDADA;
- runtime F14 atual: INSPECIONADO;
- catch-all deny-all: INSPECIONADO;
- proof F19 reforçado: PASS;
- CI proof `33803957845`: PASS em verify + database;
- provider writes durante F19: NENHUM;
- secret operacional: NENHUM;
- usuário/dado real: NENHUM.

## Last good

O last-good funcional privado continua F14/`6c3891d0e4839daa067741bbcf5eafdea542a329` com CI `33670574481` até que o novo Auth self-hosted seja implementado e o preview persistente passe todos os gates.

A F18 continua sendo o last-good de demonstração hospedada separado.

## Próxima ação

Executar somente `F20-SELF-HOSTED-AUTH-IMPLEMENT-01` conforme `docs/ai/NEXT_ACTION.md`, `tasks/F20-SELF-HOSTED-AUTH-IMPLEMENT-01/SPEC.md` e ADR-009.
