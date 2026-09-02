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
**LAST_GOOD_COMMIT:** `bac2f1a9bd9e66137ac8ae146593524d3f026113`  
**LAST_GOOD_CI_RUN:** `33668523711`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01` foi concluída e integrada à `main` pela PR #16.

A F13 foi exclusivamente arquitetural/documental: nenhum projeto Vercel, Neon hospedado, Auth operacional, usuário, secret, banco externo ou deploy foi criado. O repositório continua público e somente dados fictícios/sanitizados são permitidos.

A jornada persistente de leitura `Central → detalhe → Central` permanece implementada e opt-in por `COMPRAS_PERSISTENT_READ_ENABLED=true`. O modo demo continua padrão; falha de sessão/configuração/banco continua fail-closed e não retorna fixture como sucesso.

## F13 — fronteira do preview hospedado

A ADR-006 revalidou nas fontes oficiais atuais Vercel e Neon e definiu a fronteira mínima do primeiro preview privado fictício.

### Vercel

Vercel permanece adequado como alvo **condicional** de preview:

- Vercel Authentication é a barreira externa obrigatória de Deployment Protection;
- `Standard Protection` pode proteger previews, mas não deve ser tratado como proteção de production domain;
- se qualquer production surface servir a aplicação, ela precisa estar protegida por `All Deployments` ou o provisionamento falha antes de anexar secrets;
- obscuridade de URL não é controle de acesso;
- Shareable Links e Deployment Protection Exceptions ficam proibidos no primeiro preview;
- eventual bypass de automação futuro, se indispensável, deve usar secret por header, nunca query string;
- secrets de Preview serão branch-specific em uma branch hospedada dedicada, não propagados a todos os PRs do repositório público;
- retenção e remoção de deployments/snapshots fazem parte do deprovisionamento.

### Neon PostgreSQL

Neon permanece adequado como PostgreSQL de referência para o preview fictício.

A ADR-006 separa quatro responsabilidades:

1. bootstrap/control-plane potencialmente privilegiado, apenas para provisionamento;
2. principal de migration criado por SQL, separado do runtime e capaz de aplicar `0001`–`0003`;
3. role runtime criada por SQL, não-owner, sem superuser/`BYPASSRLS`/`CREATEROLE`, validada pela fronteira F08;
4. capability `compras_team_directory_view_owner` `NOLOGIN`, criada/reutilizada somente pela migration `0003` e nunca usada como credencial.

A documentação Neon atual registra que roles criadas por Console/CLI/API recebem membership em `neon_superuser`, enquanto roles criadas por SQL seguem privilégios normais do PostgreSQL. Por isso runtime e capability não podem ser criados pelo control plane por conveniência.

### Managed Better Auth

Managed Better Auth continua compatível com o adaptador server-side já implementado, condicionado à admissão privada:

- Managed Better Auth está atualmente disponível em regiões AWS e não em Azure;
- `createNeonAuth()`/`auth.getSession()` e cookie secret server-side continuam suportados;
- signup é permitido por padrão, mas a configuração email/senha atual possui `disable_sign_up`;
- APIs/plugins administrativos existem para gestão/criação administrativa de usuário;
- métodos adicionais possuem semântica própria de signup e não entram no primeiro preview sem prova específica.

A decisão inicial é usar somente email/senha, exigir `disable_sign_up=true` no provider antes da exposição e admitir somente identidades fictícias por caminho administrativo controlado. Login no provider continua separado da autorização do produto: nenhuma identidade ganha acesso sem `app_user` ativo + membership ativa no PostgreSQL.

## Ambientes

### Local/CI

- dados artificiais;
- PostgreSQL descartável/local;
- testes adversariais continuam gate canônico;
- nenhum secret operacional hospedado.

### Preview hospedado futuro

- não-produção;
- branch dedicada;
- dados somente fictícios;
- Deployment Protection efetivo;
- Auth interno privado;
- runtime sujeito a RLS;
- secrets server-only e branch-specific;
- migrations canônicas aplicadas por principal separado;
- seed fictício separado de migrations;
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
- tokens de provider/control plane como secrets administrativos, nunca browser/Git/log.

Nenhum valor operacional real foi criado ou documentado.

## Red-team de F13

O desenho foi atacado contra:

- URL de preview descoberta anonimamente;
- production domain público sob Standard Protection;
- proteção existente somente na UI;
- signup direto no endpoint de Auth apesar da ausência de botão;
- PR arbitrário recebendo secrets Preview;
- runtime usando role default/control-plane/owner/`BYPASSRLS`;
- capability criada pelo control plane e contaminada com `neon_superuser`;
- mesma credencial para migration e runtime;
- seed fictício aplicado no ambiente errado;
- claims/secrets/DB errors chegando a logs ou URLs;
- bypass por shareable link/query string;
- deployments/branches órfãos sobrevivendo ao teste.

Cada cenário possui controle ou critério explícito de bloqueio na ADR-006.

## Verificação de F13

- recuperação de `main`, PRs abertas e branches relacionadas: PASS — nenhuma frente concorrente ativa no início;
- `CONTEXT_MANIFEST` comparado aos blobs atuais: PASS (`CONTEXT_STATUS = VALID`);
- CI pós-checkpoint F12 `33666664123`: PASS;
- SECURITY/DATABASE/ADR-003/004/005 e runtime F08/Auth inspecionados diretamente: PASS;
- documentação oficial atual de Vercel Deployment Protection, ambientes e secrets: REVALIDADA;
- documentação oficial atual de Neon Auth, roles/PostgreSQL e Serverless Driver: REVALIDADA;
- matriz de capacidades, condicionais, riscos e rollback: DOCUMENTADA em ADR-006;
- diff integral da PR #16: somente documentação/checkpoint/spec, sem migration/runtime/infra: PASS;
- PR #16 head `c3308747e193ccfeb41f6f4ecde107d6eb33b663`: CI `33668314182` PASS — `verify` e `database`;
- PR #16 squash-merged em `bac2f1a9bd9e66137ac8ae146593524d3f026113`;
- CI da `main` após merge `33668523711`: PASS — `verify` e `database`;
- secret real, dado interno/pré-publicação, account/project ID privado ou URL privada: NÃO ENCONTRADOS;
- `REAL_DATA_ALLOWED`: continua `NO`.

## Limite atual

A fronteira de hosting está definida, mas a aplicação ainda não possui jornada operacional de login/admissão.

`src/server/auth/external-identity.ts` sabe validar/consumir uma sessão existente; o `src/app` ainda não possui sign-in/sign-out privado nem uma fronteira HTTP que prove a rejeição de signup público e endpoints laterais.

Provisionar Vercel/Neon antes dessa etapa criaria um ambiente hospedado incapaz de demonstrar o requisito de admissão privada no enforcement real.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. F13 não resolveu taxonomia, permissões funcionais ou auditoria de leitura por inferência.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F13. ADR-006, `CURRENT_STATE`, `NEXT_ACTION` e specs são lidos ao vivo pelo protocolo.

## Last good

`bac2f1a9bd9e66137ac8ae146593524d3f026113` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33668523711` com `verify` e `database` em PASS.

## Próxima ação

Executar `F14-PRIVATE-AUTH-ADMISSION-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F14-PRIVATE-AUTH-ADMISSION-01/SPEC.md`.
