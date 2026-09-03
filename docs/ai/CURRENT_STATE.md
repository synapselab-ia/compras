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

A work unit `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` foi reexecutada novamente em 2026-09-03, desta vez partindo da `main` em `a6595d6761a8f8f2d3a1a0572a76f47223c00768`, até sua condição explícita de bloqueio.

A pré-condição necessária ainda não existe nesta sessão: não há uma superfície oficial autenticada e observável que permita escrever e ler de volta os controles críticos de Vercel e Neon sem transferir credenciais para o chat ou para superfícies públicas do repositório.

Nenhum projeto, deployment, banco, branch Neon, Managed Better Auth, usuário, secret, migration hospedada ou seed de Compras foi criado nesta tentativa. Nenhum projeto existente e alheio foi alterado.

A aplicação permanece no last-good funcional F14: sign-in email/senha e sign-out por Server Actions, catch-all Auth deny-all, gate de sessão antes do banco, identidade `issuer + subject` derivada no servidor e autorização final por `app_users` + membership + PostgreSQL/RLS.

## Recuperação e contexto desta tentativa F17

- `main` recuperada em `a6595d6761a8f8f2d3a1a0572a76f47223c00768`;
- nenhuma PR aberta foi encontrada;
- nenhuma branch concorrente mais nova da F17 foi encontrada; apenas checkpoints históricos já integrados;
- `CONTEXT_MANIFEST` foi revalidado contra os blobs atuais;
- todos os 10 inputs estáveis continuam iguais aos hashes esperados;
- `CONTEXT_STATUS = VALID`;
- CI de entrada `33752929644`: PASS (`verify` e `database`);
- `REAL_DATA_ALLOWED = NO` permaneceu ativo durante toda a tentativa.

## Reinspeção Vercel

A conta e o conector oficial disponível foram reinspecionados:

- a equipe acessível continua no plano Hobby;
- continuam existindo somente projetos alheios à work unit;
- não existe projeto Vercel ligado a `synapselab-ia/compras`;
- o conector continua com 24 ferramentas;
- permanecem ausentes operações para criação/importação explícita do projeto `compras`, escrita + readback de `ssoProtection`/Vercel Authentication, criação/listagem de env vars Preview + branch e deprovisionamento controlado.

A documentação oficial atual foi revalidada e confirma que o provider possui essas capacidades por REST API/SDK/CLI:

- criação explícita de projeto;
- atualização de Vercel Authentication por `ssoProtection`;
- env vars com `target: ["preview"]` e `gitBranch`;
- leitura/remoção de environment variables;
- remoção de deployments e projetos;
- CLI capaz de exibir/alterar project protection.

Portanto a capacidade do provider continua documentada, mas a sessão atual continua incapaz de executar write + readback autenticados desses controles.

`deploy_to_vercel` não foi chamado. Fazer deploy genérico antes de estabelecer protection observável continuaria invertendo a ordem fail-closed definida por ADR-006/F17.

## Reinspeção Neon

A organização e o conector Neon foram reinspecionados:

- a organização acessível continua no plano Free;
- os projetos existentes continuam alheios;
- não existe projeto Neon dedicado a Compras;
- o conector continua permitindo projetos, branches, SQL, roles, Auth base, usuários, OAuth e trusted domains;
- `update_auth_config` continua aceitando apenas `name` e não expõe os PATCH exigidos para email/senha e plugins.

A documentação oficial atual de Managed Better Auth foi revalidada e continua confirmando endpoints branch-scoped para:

- `/auth/email_and_password` — GET/PATCH;
- `/auth/plugins` — GET/PATCH;
- plugins específicos como magic link e phone number;
- `/auth/oauth_providers`;
- `/auth/domains`;
- disable de Auth, inclusive com opção de remoção dos dados Auth.

Assim como no Vercel, o provider possui a superfície necessária, mas ela continua fora das operações autenticadas disponíveis nesta sessão.

## Runtime e integrações adicionais

O runtime foi reinspecionado sem revelar valores de ambiente:

- `vercel`: AUSENTE;
- `neon`: AUSENTE;
- `neonctl`: AUSENTE;
- variáveis de ambiente com nomes de autenticação Vercel/Neon exportadas ao shell: AUSENTES.

O catálogo de plugins foi novamente pesquisado para:

- gerenciamento Vercel de project/protection/env;
- configuração Neon Auth `email_and_password`/plugins;
- browser/web automation.

Nenhuma integração instalável compatível foi encontrada.

## Red-team desta tentativa F17

A solução foi novamente atacada contra os falsos desbloqueios previstos no SPEC:

- conector autenticado que apenas lê conta/projeto, sem escrita de protection/config crítica: INSUFICIENTE;
- documentação pública usada como substituto de readback do estado real da conta: REJEITADO;
- `deploy_to_vercel` usado antes de configurar/provar protection: REJEITADO;
- inferir que Preview, URL obscura ou ausência de alias conhecido equivalem a protection: REJEITADO;
- criar projeto Neon ou Managed Better Auth antes de possuir o PATCH de `disable_sign_up`: REJEITADO;
- aceitar deny-all da aplicação como substituto do controle provider-side: REJEITADO;
- considerar `update_auth_config(name)` equivalente à configuração de email/senha/plugins: REJEITADO;
- instalar CLI sem sessão autenticada e chamar isso de control-plane: REJEITADO;
- solicitar/copiar token Vercel, Neon API key, password, cookie ou connection string para chat/Git: REJEITADO;
- reutilizar projeto existente como laboratório: NÃO EXECUTADO;
- executar configuração manual que o assistente não possa observar/read-back: REJEITADO.

Resultado: a condição de bloqueio da própria F17 foi atingida novamente. Nenhum controle de segurança foi enfraquecido para fabricar progresso.

## Verificação desta tentativa F17

- recuperação de `main`, PRs e branches: PASS;
- `CONTEXT_MANIFEST`: PASS / VALID;
- CI de entrada `33752929644`: PASS;
- conta Vercel: REINSPECIONADA;
- projeto Vercel `compras`: AUSENTE;
- ferramentas Vercel: REINSPECIONADAS, lacuna persiste;
- documentação oficial Vercel project/protection/env/rollback: REVALIDADA;
- conta Neon: REINSPECIONADA;
- projeto Neon `compras`: AUSENTE;
- ferramentas Neon Auth: REINSPECIONADAS, lacuna persiste;
- documentação oficial Neon Auth API: REVALIDADA;
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

`6c3891d0e4839daa067741bbcf5eafdea542a329` continua sendo o `LAST_GOOD_COMMIT` funcional, validado pela CI da `main` run `33670574481`. O checkpoint F17 anterior em `a6595d6761a8f8f2d3a1a0572a76f47223c00768` possui CI pós-merge `33752929644` em PASS.

## Próxima ação

Reexecutar `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` somente depois que a ação manual única registrada em `docs/ai/NEXT_ACTION.md` estiver satisfeita.
