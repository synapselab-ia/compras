# Current State — Compras

**PROJECT_STATUS:** BLOCKED_PENDING_AUTHENTICATED_PROVIDER_CONTROL_SESSION  
**CURRENT_PHASE:** F16 — Hosted Preview Control Plane Unblock (BLOCKED após reinspeção)  
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
**BLOCKERS:** `F16-B1` sessão atual não possui escrita/readback de Deployment Protection/env scope/deprovisionamento Vercel; `F16-B2` sessão atual não possui escrita dos endpoints Neon Auth `email_and_password`/plugins apesar de o provider suportá-los  
**MANUAL_ACTION_REQUIRED:** estabelecer uma única sessão de controle autenticada e observável nos consoles oficiais Vercel e Neon, acessível ao assistente sem colar tokens/secrets no chat (preferencialmente ChatGPT Work/Cloud Browser, se disponível), e então executar F17

## Estado real

A work unit `F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01` foi executada pelo protocolo canônico. O blocker de F15 foi reduzido de uma dúvida sobre capacidade de provider para uma limitação concreta da **superfície de controle disponível nesta sessão**.

Nenhum projeto, deployment, banco, branch, Auth, usuário, secret, migration hospedada ou seed foi criado para Compras durante F16. Nenhum projeto existente e alheio foi alterado.

A aplicação continua no last-good funcional F14: sign-in email/senha e sign-out por Server Actions, catch-all Auth deny-all, gate de sessão antes do banco, identidade `issuer + subject` derivada no servidor e autorização final por `app_users` + membership + PostgreSQL/RLS.

## Recuperação e contexto de F16

- `main` recuperada em `88fe3ec1ff120ae0e1d50f925e2b9e00d379437f` no início da work unit;
- nenhuma PR aberta foi encontrada;
- nenhuma branch F16/control-plane concorrente foi localizada antes da implementação;
- todos os blobs estáveis de `CONTEXT_MANIFEST` continuam iguais ao manifest esperado;
- `CONTEXT_STATUS = VALID`;
- CI pós-checkpoint F15 `33678376270`: PASS;
- `REAL_DATA_ALLOWED = NO` permaneceu ativo durante todo o trabalho.

## Reinspeção Vercel

A conta e a superfície do conector oficial foram reinspecionadas:

- a equipe acessível continua em plano Hobby;
- não existe projeto Vercel ligado a `synapselab-ia/compras`;
- os projetos existentes continuam alheios e não foram modificados;
- o conector atual expõe 24 ferramentas, concentradas em leitura de projetos/deployments/logs, acesso a deployment protegido, comentários e `deploy_to_vercel` genérico.

A superfície continua **sem** operações para:

- criar/importar explicitamente o projeto `compras` por control-plane;
- escrever e ler de volta `ssoProtection`/Vercel Authentication;
- criar/listar environment variables sensíveis com target `preview` + `gitBranch` dedicado;
- excluir projeto/deployment como rollback controlado.

A leitura `get_project` foi validada de forma read-only em projeto alheio apenas para capacidade do conector: ela mostra target do deployment e domains, mas não expõe estado de Deployment Protection nem environment variables. Nenhuma alteração foi feita nesse projeto.

A documentação oficial atual confirma que o provider **tem** as capacidades faltantes em REST API/CLI:

- criação de projeto pela API;
- atualização de Vercel Authentication via `ssoProtection`;
- env vars com `target: ["preview"]` e `gitBranch`;
- remoção de env vars e APIs de gerenciamento de projeto.

Portanto `F16-B1` não é mais tratado como ausência comprovada de capacidade do Vercel; é ausência de um executor autenticado dessas operações na sessão atual.

## Reinspeção Neon

A organização e o conector Neon foram reinspecionados:

- organização acessível continua em plano Free;
- não existe projeto Neon dedicado a Compras;
- projetos existentes continuam alheios e não foram alterados;
- o conector continua com operações suficientes para projetos, branches, SQL, roles, Auth base, usuários, OAuth e trusted domains.

A limitação crítica permanece: `update_auth_config` só aceita `name`; não há ferramenta exposta para gravar os campos de email/senha ou plugins necessários a F15.

A documentação oficial atual eliminou a incerteza sobre o provider: o Neon API possui endpoints branch-scoped próprios para:

- `/auth/email_and_password` — GET/PATCH;
- `/auth/plugins` — GET/PATCH;
- `/auth/plugins/magic-link` e demais plugins específicos;
- `/auth/domains`, `/auth/oauth_providers`, usuários e configuração relacionada.

A documentação atual da CLI também registra que `neon api` é um passthrough autenticado para qualquer rota da Neon API e usa credenciais de `neon auth` por padrão.

O runtime disponível nesta sessão, porém, não possui `neon`, `neonctl` ou `vercel` instalados/autenticados. As credenciais dos conectores não são exportadas ao shell e não devem ser solicitadas/copiedas.

Portanto `F16-B2` também foi reduzido a uma limitação da superfície de controle desta sessão, não a uma ausência de capacidade do Neon.

## Catálogo de integrações adicionais

Foram repetidas buscas por integrações/plugins capazes de suprir as operações faltantes para:

- Vercel project/protection/env management;
- Neon Auth configuration;
- browser/web automation.

Nenhuma integração adicional instalável compatível foi encontrada.

## Red-team de F16

A solução foi atacada contra os caminhos de falso desbloqueio:

- ferramenta que só lê proteção e não escreve: INSUFICIENTE;
- ferramenta que escreve sem readback verificável: INSUFICIENTE;
- tratar `deploy_to_vercel` como criação segura de projeto antes de protection: REJEITADO;
- inferir proteção pela existência de URL/target Preview: REJEITADO;
- usar `get_project` como prova de `ssoProtection` mesmo sem esse campo: REJEITADO;
- usar documentação pública como prova do estado real da conta: REJEITADO;
- provisionar Neon Auth com defaults para depois tentar bloquear signup: REJEITADO;
- aceitar deny-all da aplicação como substituto de `disable_sign_up=true` provider-side: REJEITADO;
- instalar CLI sem sessão autenticada e chamar isso de control-plane: REJEITADO;
- copiar Vercel token, Neon API key, password ou connection string para chat/Git: REJEITADO;
- alterar projeto existente para testar capacidade: NÃO EXECUTADO;
- esconder blocker com workaround manual não observável: REJEITADO.

Resultado: os providers possuem APIs oficiais aptas, mas a sessão atual não consegue executar e verificar essas operações autenticadas sem introduzir segredo ou etapa opaca. F16 permanece fail-closed.

## Verificação de F16

- recuperação de `main`, PRs e branches relacionadas: PASS;
- `CONTEXT_MANIFEST`: PASS / VALID;
- CI inicial `33678376270`: PASS;
- Vercel tools: REINSPECIONADAS;
- Neon tools: REINSPECIONADAS;
- catálogo de plugins/integradores: REINSPECIONADO, sem alternativa compatível;
- documentação oficial Vercel de project/protection/env: REVALIDADA;
- documentação oficial Neon Manage Auth API + CLI `api`: REVALIDADA;
- capacidade do provider Vercel para os controles necessários: DOCUMENTADA, mas não executável pela sessão;
- capacidade do provider Neon para `email_and_password`/plugins: DOCUMENTADA, mas não executável pela sessão;
- CLI Vercel/Neon autenticada no runtime: AUSENTE;
- Vercel project/deployment de Compras criado: NÃO;
- Neon project/branch/Auth de Compras criado: NÃO;
- secret real criado/anexado: NÃO;
- dado real/interno/pré-publicação enviado: NÃO;
- alteração em projeto alheio: NÃO;
- `REAL_DATA_ALLOWED`: continua `NO`.

## Limite atual

O blocker agora é específico: falta uma sessão de controle autenticada, observável e capaz de operar os dashboards/APIs oficiais Vercel e Neon sem transferir credenciais para o chat ou para superfícies públicas do repositório.

A ação manual exigida é única: **estabelecer essa sessão de controle autenticada para os dois providers e então retomar pela F17**. Uma opção operacional é abrir esta mesma frente no ChatGPT Work/Cloud Browser, se esse modo estiver disponível, autenticar nos consoles oficiais e deixar o assistente fazer a prova por UI/readback. Não é necessário nem permitido colar tokens no chat.

Enquanto isso não ocorrer, F15 não volta a READY e nenhum provisionamento deve começar.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas.

## Last good

`6c3891d0e4839daa067741bbcf5eafdea542a329` continua sendo o `LAST_GOOD_COMMIT` funcional, validado pela CI da `main` run `33670574481`. O checkpoint F15 em `88fe3ec1ff120ae0e1d50f925e2b9e00d379437f` possui CI pós-merge `33678376270` em PASS.

## Próxima ação

Executar `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01/SPEC.md`.
