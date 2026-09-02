# Current State — Compras

**PROJECT_STATUS:** READY_FOR_PRIVATE_AUTH_ADMISSION  
**CURRENT_PHASE:** F14 — Private Auth Admission  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** PERSISTENT_CENTRAL_AND_DETAIL_READ_IMPLEMENTED_OPT_IN_AUTH_ADMISSION_NOT_IMPLEMENTED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_TEAM_DIRECTORY_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** SERVER_TRUST_ADAPTER_IMPLEMENTED_LOGIN_ADMISSION_NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `0f2433f47ab39e678190e863da090c31dc569938`  
**LAST_GOOD_CI_RUN:** `33666664123`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01` foi executada como decisão arquitetural, sem provisionar infraestrutura.

A jornada persistente de leitura `Central → detalhe → Central` permanece implementada e opt-in por `COMPRAS_PERSISTENT_READ_ENABLED=true`. O modo demo continua padrão; falha de sessão/configuração/banco continua fail-closed e não retorna fixture como sucesso.

Nenhum projeto Vercel, Neon hospedado, Auth operacional, usuário real, secret operacional ou deploy foi criado por F13. O repositório continua público e somente dados fictícios/sanitizados são permitidos.

O `LAST_GOOD_COMMIT` foi avançado para `0f2433f47ab39e678190e863da090c31dc569938` porque a CI pós-checkpoint da `main`, run `33666664123`, concluiu em PASS. Esse commit continua sendo a base executável validada; F13 altera somente documentação/decisão arquitetural.

## F13 — fronteira do preview hospedado

A ADR-006 revalidou em documentação oficial atual Vercel e Neon e fechou o desenho mínimo do primeiro preview privado fictício.

### Vercel

Vercel continua adequado como alvo **condicional** de preview.

Decisões:

- Vercel Authentication é a barreira externa obrigatória de Deployment Protection;
- `Standard Protection` pode proteger previews, mas não pode ser tratado como proteção de um production domain;
- se qualquer production surface servir a aplicação, ela precisa estar protegida por `All Deployments` ou o provisionamento deve falhar antes de anexar secrets;
- não usar obscuridade de URL como controle;
- não criar Shareable Links nem Deployment Protection Exceptions no primeiro preview;
- qualquer futuro bypass de automação, se realmente necessário, deve usar secret por header e nunca query string;
- secrets de Preview devem ser branch-specific para uma branch hospedada dedicada, não propagados a todos os PRs do repositório público;
- antigas snapshots/deployments entram no checklist explícito de retenção/deprovisionamento.

### Neon PostgreSQL

Neon continua adequado como PostgreSQL de referência para o preview fictício.

O desenho separa:

1. role bootstrap/control-plane potencialmente privilegiada, usada apenas no provisionamento;
2. principal de migration criado por SQL, separado do runtime e capaz de executar `0001`–`0003`;
3. role runtime criada por SQL, não-owner, sem superuser/`BYPASSRLS`/`CREATEROLE` e validada pelo adaptador F08;
4. capability `compras_team_directory_view_owner` `NOLOGIN`, criada/reutilizada somente pela migration `0003` e nunca usada como credencial.

A documentação Neon atual continua registrando que roles criadas por Console/CLI/API recebem membership em `neon_superuser`, enquanto roles criadas por SQL não recebem esse privilégio automaticamente. Por isso runtime/capability não podem ser criadas pelo control plane por conveniência.

### Managed Better Auth

Managed Better Auth continua compatível com o adaptador server-side existente e permanece candidato de Auth do preview, condicionado à implementação da admissão privada.

Achados atuais:

- Managed Better Auth está disponível atualmente em regiões AWS, não Azure;
- `createNeonAuth()`/`auth.getSession()` e cookie secret server-side continuam suportados;
- signup é possível por padrão, mas a API atual de configuração email/senha expõe `disable_sign_up`;
- APIs/plugins administrativos atuais permitem gestão/criação administrativa de usuários;
- métodos adicionais de autenticação possuem seu próprio comportamento de signup e não entram no primeiro preview sem prova específica.

A decisão para o primeiro preview é usar inicialmente somente email/senha, exigir `disable_sign_up=true` antes de considerar o Auth pronto e admitir exclusivamente identidades fictícias por caminho administrativo documentado. Autenticação externa continua separada de `app_users`/memberships: nenhum usuário autenticado ganha acesso por existir apenas no provider.

## Ambientes definidos

### Local/CI

- dados artificiais;
- PostgreSQL descartável/local;
- regressões/adversariais continuam gate canônico;
- nenhum secret operacional hospedado.

### Preview hospedado

- não-produção;
- branch dedicada;
- dados somente fictícios;
- Deployment Protection efetivo;
- Auth interno privado;
- runtime sujeito a RLS;
- secrets server-only e branch-specific;
- migrations canônicas aplicadas por principal separado;
- seed descartável separado de migrations;
- nenhuma analytics/session replay externa por padrão;
- destruição/recriação normal do ambiente.

### Produção futura

Permanece fora do escopo. Dados reais continuam proibidos e exigirão revisão formal separada.

## Configuração sensível prevista

A ADR-006 classifica:

- `DATABASE_URL` runtime como secret server-only da branch de Preview;
- connection string de bootstrap/migration como secret administrativo efêmero, nunca runtime;
- `NEON_AUTH_COOKIE_SECRET` como secret server-only;
- `NEON_AUTH_BASE_URL` como configuração server-side confiável;
- `COMPRAS_PERSISTENT_READ_ENABLED=true` somente depois de Auth/DB/smoke estarem validados;
- tokens de provider/control plane como secrets administrativos e nunca browser/Git/log.

Nenhum valor real foi criado ou documentado.

## Red-team de F13

O desenho foi atacado contra:

- URL de preview descoberta anonimamente;
- production domain ficando público sob Standard Protection;
- proteção somente na UI;
- signup direto no endpoint de Auth mesmo sem botão;
- PR arbitrário recebendo secrets Preview;
- runtime usando role default/control-plane/owner/`BYPASSRLS`;
- capability criada pelo control plane e contaminada com `neon_superuser`;
- mesma credencial para migration e runtime;
- seed fictício aplicado no ambiente errado;
- claims/secrets/DB errors chegando a logs ou URLs;
- bypass de Deployment Protection via shareable link/query string;
- deployments/branches órfãos sobrevivendo ao teste.

Cada cenário ficou associado a controle explícito ou critério de bloqueio na ADR-006.

## Verificação de F13

- recuperação de `main`, PRs abertas e branches relacionadas: PASS — não havia frente concorrente ativa;
- `CONTEXT_MANIFEST` comparado aos blobs atuais: PASS (`CONTEXT_STATUS = VALID`);
- CI pós-checkpoint anterior `33666664123`: PASS;
- SECURITY/DATABASE/ADR-003/004/005 lidos diretamente: PASS;
- runtime F08 e adaptador de Auth atual inspecionados: PASS;
- documentação oficial atual de Vercel Deployment Protection/env/secrets: REVALIDADA;
- documentação oficial atual de Neon Auth/roles/Postgres/Serverless Driver: REVALIDADA;
- matriz de capacidades, condicionais e riscos: DOCUMENTADA na ADR-006;
- nenhuma migration, código runtime ou infraestrutura alterada por F13: CONFIRMADO;
- nenhum secret, ID de conta/projeto, dado real ou URL privada persistido: CONFIRMADO;
- `REAL_DATA_ALLOWED`: continua `NO`.

## Limite atual

A fronteira de hosting está definida, mas o runtime ainda não possui jornada de login/admissão operacional.

`src/server/auth/external-identity.ts` sabe validar/consumir uma sessão já existente; o `src/app` atual não possui uma experiência canônica de sign-in privado nem uma fronteira de Auth que prove a ausência de signup público.

Provisionar Vercel/Neon antes dessa etapa criaria um ambiente hospedado incapaz de cumprir o requisito de admissão privada de forma demonstrável.

A próxima work unit independente é implementar essa jornada no repositório, ainda sem infraestrutura hospedada.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. F13 não resolveu taxonomia, permissões funcionais ou auditoria de leitura por inferência.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F13. ADR-006, `CURRENT_STATE`, `NEXT_ACTION` e specs de work units são lidos ao vivo pelo protocolo.

## Last good

`0f2433f47ab39e678190e863da090c31dc569938` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33666664123` em PASS.

## Próxima ação

Executar `F14-PRIVATE-AUTH-ADMISSION-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F14-PRIVATE-AUTH-ADMISSION-01/SPEC.md`.
