# Current State — Compras

**PROJECT_STATUS:** BLOCKED_HOSTED_PREVIEW_CONTROL_PLANE  
**CURRENT_PHASE:** F15 — Hosted Preview Provisioning (BLOCKED no preflight de controle)  
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
**BLOCKERS:** `F15-B1` Vercel control-plane insuficiente para provar/configurar a fronteira antes de secrets; `F15-B2` Neon control-plane insuficiente para configurar e provar `disable_sign_up=true` e métodos adicionais desabilitados  
**MANUAL_ACTION_REQUIRED:** disponibilizar uma superfície de controle verificável que satisfaça F16 sem expor secrets; eventual ajuste de plano/provider somente se necessário para cumprir a fronteira

## Estado real

A work unit `F15-HOSTED-PREVIEW-PROVISION-01` foi iniciada pelo protocolo canônico e encerrada com **BLOCKER SEGURO antes de qualquer provisionamento**.

Nenhum projeto, deployment, banco, branch, Auth, usuário, secret, migration hospedada ou seed foi criado para Compras. O bloqueio ocorreu na etapa 1 da sequência de segurança: revalidação de provider/plano/conectores.

A aplicação continua no last-good F14: sign-in email/senha e sign-out por Server Actions, catch-all Auth deny-all, gate de sessão antes do banco, identidade `issuer + subject` derivada no servidor e autorização final por `app_users` + membership + PostgreSQL/RLS.

## Recuperação e contexto de F15

- `main` recuperada em `3e8c7f8eff1584edba9e87eb2c76fcebe6afeade` no início da work unit;
- nenhuma PR aberta/branch F15 concorrente foi localizada;
- todos os blobs estáveis de `CONTEXT_MANIFEST` continuam iguais ao manifest esperado;
- `CONTEXT_STATUS = VALID`;
- `REAL_DATA_ALLOWED = NO` permaneceu ativo durante todo o preflight.

## Revalidação Vercel

O estado da conta foi lido pelo conector oficial disponível:

- existe uma única equipe acessível no plano **Hobby**;
- não existe projeto Vercel ligado ao repositório `synapselab-ia/compras`;
- os projetos existentes são alheios a esta work unit e não foram alterados.

A documentação oficial atual foi revalidada:

- Vercel Authentication/Standard Protection está disponível em todos os planos, inclusive Hobby;
- Standard Protection protege previews e deployment URLs, mas **não deve ser tratado como proteção do production domain**;
- a API/documentação suporta escopos de SSO como `preview`, `prod_deployment_urls_and_all_previews` e `all`;
- proteção de toda superfície de produção exige capacidade adicional ou, alternativamente, uma topologia que prove que nenhuma production surface recebe a aplicação/configuração privada.

### Blocker `F15-B1`

O conector Vercel atualmente disponível permite listar equipes/projetos/deployments, obter detalhes/logs e acionar um deploy genérico, mas **não expõe ações para**:

- criar/importar explicitamente o projeto `compras` com alvo controlado;
- configurar ou atualizar `ssoProtection`/Deployment Protection;
- criar environment variables server-only com escopo Preview + branch dedicado;
- provar antes do deploy que uma production surface não será criada/receberá configuração privada;
- remover/deprovisionar projeto/deployment por uma ação controlada e verificável.

Usar `deploy_to_vercel` nessas condições inverteria a ordem de segurança da ADR-006/F15: um deployment poderia existir antes de ser possível configurar e provar a proteção exigida. Portanto **nenhum deploy foi tentado**.

Também foi pesquisado o catálogo de plugins disponível para uma integração Vercel mais capaz e nenhuma alternativa instalável compatível foi encontrada.

## Revalidação Neon

O estado da conta Neon foi lido pelo conector oficial disponível:

- a organização acessível está no plano **Free**;
- não existe projeto Neon dedicado a Compras;
- os projetos existentes são alheios à work unit e não foram alterados;
- Managed Better Auth continua disponível em projetos AWS/Free segundo a documentação pública atual.

O conector possui operações de projeto, branch, SQL, roles, provisionamento de Managed Better Auth, usuários, trusted domains e leitura da configuração Auth.

### Blocker `F15-B2`

A fronteira F15 exige **antes da exposição** prova provider-side de:

- `disable_sign_up=true` para email/senha;
- métodos adicionais/autocriação desabilitados.

A superfície de escrita Auth atualmente exposta pelo conector não oferece esses campos: `update_auth_config` permite apenas atualizar o nome da configuração. `get_neon_auth_config` pode ler configuração depois do provisionamento, mas não existe ação disponível para definir de forma verificável `disable_sign_up` e os métodos exigidos.

Provisionar Auth apenas para descobrir depois que signup está habilitado violaria a ordem fail-closed da work unit. Portanto **nenhum projeto/Auth Neon foi criado**.

Também foi pesquisado o catálogo de plugins para uma integração Neon Auth mais capaz e nenhuma alternativa instalável compatível foi encontrada.

## Red-team de F15

O preflight foi atacado contra os principais caminhos de enfraquecimento:

- assumir que URL obscura ou default do provider equivale a proteção: REJEITADO;
- criar deployment primeiro e configurar proteção depois: REJEITADO;
- confiar que Hobby/Standard protege production domain: REJEITADO;
- anexar secrets antes de proteção observável: NÃO EXECUTADO;
- criar Neon e aceitar signup default temporariamente: REJEITADO;
- confiar somente no deny-all da aplicação e ignorar `disable_sign_up` provider-side: REJEITADO;
- usar projeto/banco já existente e alheio para contornar o blocker: REJEITADO;
- reutilizar credencial/role privilegiada disponível por conveniência: NÃO EXECUTADO;
- publicar account IDs, connection strings, secrets ou URLs privadas no GitHub: NÃO EXECUTADO;
- procurar integração alternativa antes de declarar ausência de capacidade: EXECUTADO, sem resultado compatível.

Resultado do red-team: avançar para provisionamento com as ferramentas atuais exigiria remover pelo menos um controle explícito de ADR-006/ADR-007/F15. O protocolo proíbe esse enfraquecimento.

## Verificação de F15

- recuperação de `main` e PRs abertas: PASS;
- `CONTEXT_MANIFEST`: PASS / VALID;
- Vercel account/plan/projects: INSPECIONADOS por conector oficial;
- Neon org/plan/projects: INSPECIONADOS por conector oficial;
- documentação Vercel Deployment Protection atual: REVALIDADA;
- documentação Neon Managed Better Auth atual: REVALIDADA;
- Vercel project/deployment de Compras criado: NÃO;
- Neon project/branch/Auth de Compras criado: NÃO;
- secret real criado/anexado: NÃO;
- dado real/interno/pré-publicação enviado: NÃO;
- migration/seed hospedado executado: NÃO;
- alteração em projetos alheios: NÃO;
- blocker compatível com critério explícito de F15: SIM;
- `REAL_DATA_ALLOWED`: continua `NO`.

## Limite atual

F14 tornou o código apto à primeira prova hospedada, porém o control-plane disponível nesta sessão não consegue demonstrar os controles necessários **antes** da criação/exposição dos recursos.

O próximo passo não é relaxar F15 nem provisionar parcialmente. É desbloquear uma superfície de controle auditável para Vercel e Neon que permita configurar e verificar os controles críticos sem expor secrets.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas.

## Last good

`6c3891d0e4839daa067741bbcf5eafdea542a329` continua sendo o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33670574481` com `verify` e `database` em PASS. F15 não alterou código nem infraestrutura e parou antes de qualquer write externo.

## Próxima ação

Executar `F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01/SPEC.md`.
