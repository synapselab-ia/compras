# Current State — Compras

**PROJECT_STATUS:** READY_FOR_HOSTED_PREVIEW_PROVISIONING  
**CURRENT_PHASE:** F15 — Hosted Preview Provisioning  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** PRIVATE_AUTH_ADMISSION_AND_PERSISTENT_READ_IMPLEMENTED_NOT_HOSTED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_TEAM_DIRECTORY_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** PRIVATE_SIGNIN_SIGNOUT_AND_DENY_ALL_ADMISSION_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `6c3891d0e4839daa067741bbcf5eafdea542a329`  
**LAST_GOOD_CI_RUN:** `33670574481`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F14-PRIVATE-AUTH-ADMISSION-01` foi concluída e integrada à `main` pela PR #18.

A aplicação agora possui jornada privada de sign-in/sign-out em código, mas nenhum Auth, banco ou hosting externo foi provisionado. O repositório continua público e somente fixtures/dados fictícios ou sanitizados podem ser usados.

A jornada persistente `Central → detalhe → Central` continua opt-in por `COMPRAS_PERSISTENT_READ_ENABLED=true`, usando a fronteira F08 `sessão validada -> issuer + subject -> contexto transacional LOCAL -> PostgreSQL/RLS`.

## F14 — admissão privada sem signup público

### Revalidação externa

Antes da implementação foram revalidadas as superfícies atuais necessárias do Managed Better Auth/SDK:

- Neon Next.js Server SDK e overview do Auth;
- configuração email/senha com `disable_sign_up`;
- pacote oficial `@neondatabase/auth@0.5.0-beta`, que coincide com a versão fixada no projeto;
- implementação oficial atual de `createNeonAuth()`, `auth.handler()`, `auth.signIn.email()`, `auth.signOut()` e `auth.getSession()`;
- formato atual de erros server-side e códigos estáveis de falha de transporte.

A evidência confirmou que sign-in/sign-out podem ser usados diretamente no servidor sem montar o handler catch-all, enquanto o handler genérico exporia uma superfície muito maior que a necessária.

### Fronteira implementada

A ADR-007 fixou a primeira integração de Auth como superfície estreita:

- sign-in somente por email/senha de identidade já admitida;
- sign-out explícito;
- leitura de sessão server-only;
- nenhum signup, OAuth, magic link, OTP, reset, Admin API ou organizações na superfície da aplicação;
- `/api/auth/[...path]` responde deny-all e não delega a `auth.handler()`;
- `getVerifiedExternalIdentity()` continua sendo a interface usada por F08 e continua retornando apenas `issuer + subject` derivados de configuração/sessão confiáveis.

O provider hospedado futuro continua obrigado a usar `disable_sign_up=true`. O deny-all da aplicação não substitui esse controle: ambos são necessários.

### Estados de sessão

O runtime server-only distingue:

1. `authenticated` — sessão válida com `user.id`; produz somente `issuer + subject`;
2. `unauthenticated` — ausência de sessão ou sessão rejeitada/expirada;
3. `unavailable` — configuração inválida, provider/transporte indisponível ou payload inconsistente.

Em modo persistente, Central e detalhe verificam esse estado antes da primeira consulta de domínio:

- sem sessão -> redirect fixo para `/auth/sign-in`;
- Auth indisponível -> indisponibilidade genérica;
- sessão válida -> segue para os readers protegidos e para RLS.

O detalhe continua validando UUID malformado antes de Auth/SQL.

### Autenticação continua separada de autorização

F14 não adicionou mutation ou auto-provisionamento.

Sign-in não cria nem altera:

- `app_users`;
- memberships;
- teams;
- contratações;
- policies/migrations.

Uma identidade autenticada, mas desconhecida/desabilitada no domínio ou sem membership ativa, continua sem dados pelo enforcement existente do PostgreSQL/RLS.

### Redirects

A aplicação não aceita `callbackURL`/`redirectTo` arbitrário para login ou logout. Os destinos são constantes locais. Campos de issuer, subject, email como identidade de autorização, `app_user_id`, membership ou `team_id` enviados pelo browser não participam da identidade usada por F08.

## Red-team de F14

A implementação e os testes atacaram deliberadamente:

- requisição direta a signup na superfície HTTP da aplicação;
- OAuth/OTP/admin/reset e outros endpoints laterais;
- rota persistente sem sessão tentando alcançar banco;
- sessão 401/403 e sessão malformada;
- provider/configuração indisponível;
- `callbackURL` externo e tentativa de open redirect;
- issuer/subject/IDs de equipe/membership forjados pelo browser;
- email conhecido tentando substituir o subject da sessão;
- identidade autenticada sem autorização interna;
- falha protegida retornando demo silenciosamente;
- regressão de UUID cross-team/inexistente;
- exposição acidental de erro bruto do provider;
- chamadas de signup ou writes de domínio na jornada F14.

Resultados:

- generic Auth API: DENY-ALL;
- open redirect: NÃO ENCONTRADO;
- identidade client-supplied: IGNORADA;
- DB access antes de sessão em caminho persistente: BLOQUEADO;
- auto-provisionamento de domínio: AUSENTE;
- fallback demo em falha Auth/persistente: AUSENTE;
- F08/RLS: PRESERVADOS.

## Verificação de F14

- recuperação de `main`, PRs abertas e branches: PASS — nenhuma frente F14 concorrente existia no início;
- `CONTEXT_MANIFEST` comparado aos blobs atuais: PASS (`CONTEXT_STATUS = VALID`);
- documentação oficial atual necessária ao SDK/Managed Better Auth: REVALIDADA;
- commit da feature `d2f3885ede1b0daea5c3d9b111553f6d95cf981f`;
- PR #18 CI `33670463890`: PASS — `verify` e `database`;
- lint: PASS;
- typecheck: PASS;
- testes existentes e novos testes adversariais de Auth: PASS;
- build: PASS;
- regressões PostgreSQL F07/F10/F11/F12: PASS;
- PR #18 squash-merged em `6c3891d0e4839daa067741bbcf5eafdea542a329`;
- CI da `main` após F14 `33670574481`: PASS — `verify` e `database`;
- migration/policy nova: NÃO;
- infraestrutura externa criada: NÃO;
- secret real ou dado interno/pré-publicação no diff: NÃO;
- `REAL_DATA_ALLOWED`: continua `NO`.

## Limite atual

A aplicação e a fronteira de Auth necessária ao primeiro preview estão implementadas, mas ainda não existe ambiente hospedado no qual provar os controles da ADR-006/ADR-007 em conjunto.

A próxima unidade independente é provisionar um preview descartável e fictício somente se for possível provar, antes da exposição, Deployment Protection, signup provider-side desabilitado, secrets restritos, roles PostgreSQL seguras, migrations canônicas, seed artificial e rollback/deprovisionamento.

Qualquer limitação de plano, connector ou provider que impeça esses controles deve bloquear F15 em vez de provocar enfraquecimento de segurança.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. F14 não resolveu taxonomia, permissões de escrita ou auditoria de leitura por inferência.

## Context manifest

Os inputs estáveis de `docs/ai/CONTEXT_MANIFEST.md` continuam sem alteração e foram validados antes da implementação F14. ADR-006, ADR-007, `CURRENT_STATE`, `NEXT_ACTION` e specs são lidos ao vivo.

## Last good

`6c3891d0e4839daa067741bbcf5eafdea542a329` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33670574481` com `verify` e `database` em PASS.

## Próxima ação

Executar `F15-HOSTED-PREVIEW-PROVISION-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F15-HOSTED-PREVIEW-PROVISION-01/SPEC.md`.
