# Current State — Compras

**PROJECT_STATUS:** F18_HOSTED_DEMO_READY_PRIVATE_PREVIEW_ON_HOLD  
**CURRENT_PHASE:** F18 concluída; F17 ON HOLD por capacidade externa do Neon; F19 pronta  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** HOSTED_DEMO_AVAILABLE_PRIVATE_PERSISTENT_PATH_IMPLEMENTED_NOT_HOSTED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_TEAM_DIRECTORY_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** PRIVATE_SIGNIN_SIGNOUT_AND_DENY_ALL_ADMISSION_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** VERCEL_PREVIEW_READY_DEMO_ONLY_PROTECTED_NO_SECRETS_GIT_AUTODEPLOY_DISABLED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `6c3891d0e4839daa067741bbcf5eafdea542a329`  
**LAST_GOOD_CI_RUN:** `33670574481`  
**F18_INPUT_COMMIT:** `848b9fcf31760e86fb0f7a164025fb28eed97c73`  
**F18_INPUT_CI_RUN:** `33798974291`  
**F18_DEPLOYED_COMMIT:** `cb874445f97f851871090cb51f6ef3364520da37`  
**F18_DEPLOYMENT_ID:** `dpl_BqWDpoiotNstrTDhtU3mJ4k9pCZa`  
**F18_DEPLOYMENT_STATE:** READY / Preview (`target = null`)  
**ON_HOLD:** `F17-B2` — Managed Better Auth observado não permite WRITE + READBACK de `disable_sign_up=true`  

## Estado real

A F17 deixou de ser a frente ativa e passou a `ON HOLD` conforme a regra canônica para dependência externa objetiva. A prova real já demonstrou:

- Vercel control plane: PASS;
- Neon Managed Better Auth: BLOCKED / fail-closed por indisponibilidade do controle obrigatório de signup;
- Auth e projeto Neon descartáveis: removidos;
- nenhum dado real, usuário, migration hospedada ou secret foi criado.

Como `ON HOLD` não deve paralisar work units independentes, e por override explícito do usuário para continuar avançando, a F18 criou uma faixa de demonstração hospedada conforme ADR-008. Essa faixa não substitui o futuro preview privado/persistente.

## F18 — Hosted demo

### Classificação

- conteúdo permitido: PUBLIC / FICTITIOUS ONLY;
- `REAL_DATA_ALLOWED = NO`;
- sem PostgreSQL hospedado;
- sem Neon Auth;
- sem `DATABASE_URL`;
- sem `NEON_AUTH_BASE_URL`/`NEON_AUTH_COOKIE_SECRET`;
- sem `COMPRAS_PERSISTENT_READ_ENABLED=true`;
- sem token/secret operacional.

O código continua definindo modo `demo` quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`. A página raiz identifica esse estado como `Protótipo com dados fictícios` e `Persistência operacional desabilitada neste ambiente`. As fixtures versionadas usam somente objetos/pessoas/setores explicitamente demonstrativos.

### Preflight adversarial que encontrou problema real

Antes da F18 formal, uma tentativa controlada na branch `f18-demo-hosted-preview` habilitou Git deployment para observar o comportamento real do projeto Vercel preservado.

A Vercel classificou aquela primeira tentativa como `production`. O agente falhou fechado imediatamente e restaurou `git.deploymentEnabled=false` sem anexar qualquer env/secret/dado.

Esse deployment terminou `ERROR` com `STATIC_BUILD_NO_OUT_DIR`: o projeto havia sido criado com preset `Other`/`framework=null` e procurou um diretório `public`. Ele nunca ficou `READY`/live e não continha configuração sensível.

Esse achado foi incorporado à ADR-008 e à SPEC F18 em vez de ser contornado com secrets ou configuração manual opaca.

### Correção F18

Na branch dedicada `f18-public-demo-hosted-01`:

1. ADR-008 definiu a faixa demo independente e seus invariantes;
2. `vercel.json` passou a declarar explicitamente `framework: "nextjs"`;
3. Git deployment foi habilitado somente no commit deliberado `cb874445f97f851871090cb51f6ef3364520da37`;
4. a Vercel criou o deployment `dpl_BqWDpoiotNstrTDhtU3mJ4k9pCZa` com `target = null`, ou seja, não Production;
5. o build detectou Next.js 16.3.3, compilou, executou TypeScript, gerou as rotas e concluiu `READY`;
6. `git.deploymentEnabled` foi restaurado para `false` depois da publicação deliberada;
7. após essa restauração, nenhum novo deployment foi criado.

O projeto Vercel continua com nome provisório `compras-f17-control-proof`; ele foi reutilizado para evitar recriação/retrabalho. Renomear não faz parte da F18.

### Deployment Protection

A URL do deployment Preview continua interceptada pela Vercel Authentication: uma requisição sem sessão recebeu `302` para o fluxo SSO da Vercel e `x-robots-tag: noindex`. A proteção não foi removida para facilitar a demo.

Uma URL temporária de compartilhamento foi gerada somente durante tentativa de smoke automatizado, sem ser persistida no GitHub/checkpoint e sem conter acesso a dados sensíveis; o canal ainda retornou para o fluxo SSO. Ela não é mecanismo de acesso do produto e expira automaticamente.

O conteúdo pós-proteção não foi declarado como visualmente smoke-tested nesta sessão, pois o canal disponível não concluiu o handshake SSO. Isso não autoriza remover a proteção. O build hospedado, a lógica demo versionada, a CI e a barreira externa foram verificados separadamente.

## Red-team F18

- Production acidental: detectada na tentativa preliminar e tratada fail-closed; a publicação F18 efetiva foi Preview (`target=null`);
- framework errado: detectado pelo erro `STATIC_BUILD_NO_OUT_DIR`; corrigido por `framework: "nextjs"` versionado;
- secret/env para “fazer funcionar”: rejeitado; nenhum foi criado;
- persistência acidental: não habilitada; modo demo permanece default explícito;
- dado real/interno/pré-publicação: nenhum;
- Neon project/Auth: nenhum criado em F18;
- remoção da Vercel Authentication: rejeitada; proteção permaneceu ativa;
- Shareable Link como mecanismo permanente: rejeitado;
- Git auto-deploy residual: removido; estado final `deploymentEnabled=false`;
- projeto Vercel alheio: nenhum alterado.

## Verificação

### GitHub

- `main` de entrada F18: `848b9fcf31760e86fb0f7a164025fb28eed97c73`;
- CI de entrada `33798974291`: PASS (`verify` e `database`, incluindo lint/typecheck/test/build e testes PostgreSQL/RLS);
- nenhuma PR concorrente aberta no início da F18;
- contexto estável permaneceu válido.

### Vercel

- projeto reutilizado: identificado e ligado a `synapselab-ia/compras`;
- deployment F18: `READY`;
- target F18: Preview (`null`), não Production;
- build Next.js: PASS;
- Vercel Authentication: observada por redirect SSO;
- env/secret operacional criado por F18: NÃO;
- Git auto-deploy final: desabilitado no repositório.

### Neon

Nenhuma escrita ou recurso Neon foi criado em F18. O blocker F17 permanece evidência histórica válida e não foi reexecutado por inércia.

## Decisão de arquitetura para continuar avançando

Esperar indefinidamente pelo controle Managed Better Auth não é mais a única rota de progresso.

A documentação oficial atual do Better Auth confirma PostgreSQL direto, configuração `emailAndPassword.disableSignUp`, `trustedOrigins` e schema/migrations controláveis pela aplicação. Por isso a próxima work unit é F19, que deve decidir se o Auth deve ser self-hosted em PostgreSQL e assim remover a dependência do controle indisponível do Managed Neon Auth, preservando F14/F08/RLS.

Isso é uma hipótese arquitetural a provar, não uma autorização para hospedar dados reais.

## Last good

O last-good funcional privado continua F14/`6c3891d0e4839daa067741bbcf5eafdea542a329` com CI `33670574481` até que uma work unit hospedada persistente passe todos os gates.

A F18 adiciona um last-good **de demonstração hospedada** separado: deployment Vercel `dpl_BqWDpoiotNstrTDhtU3mJ4k9pCZa`, commit `cb874445f97f851871090cb51f6ef3364520da37`, estado `READY`, sem secrets, Auth interno, banco ou dados reais.

## Próxima ação

Executar somente `F19-AUTH-PORTABILITY-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e sua SPEC. F17 permanece ON HOLD e só volta a ser frente ativa se a rota Managed Neon Auth voltar a ser escolhida e sua condição `RESUME_WHEN` estiver satisfeita.
