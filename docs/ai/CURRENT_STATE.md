# Current State — Compras

**PROJECT_STATUS:** BLOCKED_PENDING_AUTHENTICATED_PROVIDER_CONTROL_SESSION  
**CURRENT_PHASE:** F17 — Authenticated Provider Control Session (BLOCKED aguardando canal autenticado observável)  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** PRIVATE_AUTH_ADMISSION_AND_PERSISTENT_READ_IMPLEMENTED_NOT_HOSTED  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_TEAM_DIRECTORY_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** PRIVATE_SIGNIN_SIGNOUT_AND_DENY_ALL_ADMISSION_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED_BLOCKED_PRE_PROVISIONING  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `6c3891d0e4839daa067741bbcf5eafdea542a329`  
**LAST_GOOD_CI_RUN:** `33670574481`  
**BLOCKERS:** `F17-B1` a sessão atual continua sem executor autenticado de write + readback para os controles críticos de Vercel e Neon  
**MANUAL_ACTION_REQUIRED:** estabelecer uma única sessão de controle autenticada e observável nos consoles oficiais Vercel e Neon, acessível ao assistente sem colar tokens/secrets no chat, e então reexecutar F17

## Estado real

A work unit `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` foi reexecutada novamente em 2026-09-03 pelo protocolo canônico, partindo da `main` em `1b07ee26b2b47f7aa52b4e2e0b0d581974879442`, até sua condição explícita de bloqueio.

A pré-condição necessária continua ausente: esta sessão não oferece uma superfície oficial autenticada e observável capaz de escrever e ler de volta os controles críticos de Vercel e Neon sem transferir credenciais para o chat, GitHub público ou outro artefato persistente.

Nenhum projeto, deployment, banco, branch Neon, Managed Better Auth, usuário, secret, migration hospedada ou seed de Compras foi criado nesta tentativa. Nenhum projeto existente e alheio foi alterado.

A aplicação permanece no last-good funcional F14: sign-in email/senha e sign-out por Server Actions, catch-all Auth deny-all, gate de sessão antes do banco, identidade `issuer + subject` derivada no servidor e autorização final por `app_users` + membership + PostgreSQL/RLS.

## Recuperação e contexto desta tentativa F17

- `main` recuperada em `1b07ee26b2b47f7aa52b4e2e0b0d581974879442`;
- nenhuma PR aberta foi encontrada;
- nenhuma branch concorrente mais nova da F17 foi encontrada; somente branches/checkpoints históricos já integrados;
- os 10 inputs estáveis do `CONTEXT_MANIFEST` continuam exatamente iguais aos hashes esperados;
- `CONTEXT_STATUS = VALID`;
- CI de entrada `33768977830`: PASS (`verify` e `database`);
- `REAL_DATA_ALLOWED = NO` permaneceu ativo durante toda a tentativa.

## Reinspeção Vercel

A conta e o conector oficial disponível foram reinspecionados:

- a equipe acessível continua no plano Hobby;
- continuam existindo somente projetos alheios à work unit;
- não existe projeto Vercel ligado a `synapselab-ia/compras`;
- o conector continua com 24 ferramentas;
- permanecem ausentes operações para criação/importação explícita do projeto `compras`, escrita + readback de `ssoProtection`/Vercel Authentication, criação/listagem de env vars Preview + branch e deprovisionamento controlado.

A documentação oficial atual foi revalidada e confirma que o provider possui as capacidades necessárias por REST API/SDK/CLI: criação de projeto, `ssoProtection`, env vars `target: ["preview"]` com `gitBranch`, leitura/remoção de env vars e remoção de deployments/projetos.

`deploy_to_vercel` não foi chamado. Fazer deploy genérico antes de estabelecer e provar protection continuaria invertendo a ordem fail-closed definida por ADR-006/F17.

## Reinspeção Neon

A organização e o conector Neon foram reinspecionados:

- a organização acessível continua no plano Free;
- os projetos existentes continuam alheios;
- não existe projeto Neon dedicado a Compras;
- o conector Auth continua com 15 ferramentas;
- `update_auth_config` continua aceitando apenas `name` e não expõe os PATCH exigidos para `/auth/email_and_password` e `/auth/plugins`.

A documentação oficial atual de Managed Better Auth foi revalidada e continua confirmando os endpoints branch-scoped de email/senha, plugins, OAuth, domains e teardown de Auth.

Não foi criado projeto Neon nem provisionado Auth porque F17 exige que `disable_sign_up=true` e métodos laterais possam ser escritos e lidos de volta na mesma sessão controlada antes de qualquer exposição.

## Runtime e integrações adicionais

O runtime foi reinspecionado sem revelar valores de ambiente:

- `vercel`: AUSENTE;
- `neon`: AUSENTE;
- `neonctl`: AUSENTE;
- variáveis de ambiente com nomes de autenticação Vercel/Neon exportadas ao shell: AUSENTES.

O catálogo de plugins foi novamente pesquisado para gerenciamento Vercel de project/protection/env, configuração Neon Auth `email_and_password`/plugins e browser/web automation. Nenhuma integração instalável compatível foi encontrada.

## Red-team desta tentativa F17

Foram novamente rejeitados os falsos desbloqueios previstos no SPEC:

- conector que apenas lê conta/projeto sem escrita da configuração crítica;
- documentação pública como substituto de readback do estado real;
- `deploy_to_vercel` antes de protection observável;
- Preview/URL obscura como substituto de Deployment Protection;
- criação de Neon project/Auth antes de possuir o PATCH de `disable_sign_up`;
- deny-all da aplicação como substituto de enforcement provider-side;
- `update_auth_config(name)` tratado como controle de email/senha/plugins;
- instalação de CLI sem sessão autenticada;
- copiar token Vercel, Neon API key, password, cookie ou connection string para chat/Git;
- reutilizar projeto alheio como laboratório;
- configuração manual que o assistente não consiga observar/read-back.

Resultado: a condição de bloqueio da própria F17 foi atingida novamente. Nenhum controle foi enfraquecido para fabricar progresso.

## Verificação desta tentativa F17

- recuperação de `main`, PRs e branches: PASS;
- `CONTEXT_MANIFEST`: PASS / VALID;
- CI de entrada `33768977830`: PASS;
- conta Vercel e lista de projetos: REINSPECIONADAS;
- projeto Vercel `compras`: AUSENTE;
- ferramentas Vercel: REINSPECIONADAS, lacuna persiste;
- documentação oficial Vercel: REVALIDADA;
- conta Neon e lista de projetos: REINSPECIONADAS;
- projeto Neon `compras`: AUSENTE;
- ferramentas Neon Auth: REINSPECIONADAS, lacuna persiste;
- documentação oficial Neon Auth: REVALIDADA;
- catálogo de plugins/integradores: REINSPECIONADO, sem alternativa compatível;
- CLI autenticada Vercel/Neon no runtime: AUSENTE;
- sessão oficial capaz de write + readback dos controles críticos: NÃO DISPONÍVEL;
- write de provider realizado: NÃO;
- secret operacional criado/publicado: NÃO;
- dado real/interno/pré-publicação enviado: NÃO;
- alteração em projeto alheio: NÃO;
- `REAL_DATA_ALLOWED`: continua `NO`.

## Limite atual

A F17 determina explicitamente que, se a sessão autenticada oficial ainda não estiver acessível ao assistente, não devem ser executados writes de provider e não deve ser criada nova work unit de workaround.

Logo, o projeto permanece bloqueado de forma fail-closed e `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` continua sendo a única `NEXT_ACTION` canônica.

A única ação manual necessária permanece: **estabelecer uma sessão de controle autenticada nos consoles oficiais Vercel e Neon que seja acessível ao assistente sem revelar credenciais**. Não colar tokens, passwords, cookies, API keys ou connection strings no chat.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas.

## Last good

`6c3891d0e4839daa067741bbcf5eafdea542a329` continua sendo o `LAST_GOOD_COMMIT` funcional, validado pela CI da `main` run `33670574481`. O checkpoint F17 de entrada em `1b07ee26b2b47f7aa52b4e2e0b0d581974879442` possui CI pós-merge `33768977830` em PASS.

## Próxima ação

Reexecutar `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` somente depois que a ação manual única registrada em `docs/ai/NEXT_ACTION.md` estiver satisfeita.
