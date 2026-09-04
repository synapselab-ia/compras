# F21-PRIVATE-PREVIEW-SELF-HOSTED-PROVISION-01 — Provisionar e provar preview privado fictício com Better Auth self-hosted

**Classe:** T3 — integração externa, com impacto T2 — segurança  
**Estado:** ON HOLD / BLOCKED  
**Dependências:** F11, F14, F18, F19, F20, ADR-003, ADR-005, ADR-006, ADR-007, ADR-008 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A F20 substituiu o Managed Neon Auth por Better Auth self-hosted no repositório e provou em CI a fronteira de autenticação, cookies, schema Auth, roles e isolamento Auth/domínio. Falta provar a mesma arquitetura em um Preview hospedado real, protegido externamente, usando somente dados e identidades fictícios.

A work unit não deve colocar o sistema em produção nem introduzir dados reais. Se o provider, plano, proteção de deployment, escopo de secrets ou controle de roles não permitir provar a fronteira aprovada, a execução deve parar em estado BLOCKED e fazer rollback seguro.

## Resultado da execução de 2026-09-04

A execução F21 recuperou o estado real do GitHub, Vercel e Neon antes de qualquer write de infraestrutura e revalidou a documentação oficial vigente.

### GitHub / contexto

- `main` estava no checkpoint F20 integrado e com CI integralmente em PASS;
- `CONTEXT_MANIFEST` foi revalidado e todos os blobs estáveis coincidiram;
- não existia frente F21 prévia; foi aberta a branch `f21-private-preview-self-hosted-provision` somente para registrar o checkpoint sanitizado;
- a criação da branch não disparou novo deployment Vercel, preservando a política de não ampliar exposição automaticamente.

### Vercel

O projeto já usado pela faixa F18 continua com um deployment Preview `READY`, sem deployment Production `READY` correspondente. O acesso ao Preview foi testado pela superfície autenticada do conector e retornou redirecionamento para a barreira de autenticação da Vercel, confirmando que a proteção externa continua efetiva.

A documentação oficial atual confirma que Vercel suporta:

- Deployment Protection/Vercel Authentication;
- environment variables de Preview escopáveis por branch Git;
- variáveis sensíveis;
- inspeção e alteração de proteção via control plane/CLI/API.

Entretanto, a superfície Vercel autenticada disponível nesta sessão não expõe as operações necessárias de leitura/readback e escrita para:

- estado completo de Deployment Protection e bypasses do projeto;
- criação/remoção/readback de environment variables sensíveis de Preview escopadas à branch F21.

Esses controles são gates obrigatórios da ADR-006/F21. Não é aceitável anexar secrets sem conseguir aplicar e verificar o escopo aprovado, nem contornar a proteção externa.

### Neon / PostgreSQL

O estado real da organização Neon foi recuperado. Não existe projeto dedicado a `compras`; os projetos existentes pertencem a outras frentes e não foram reutilizados.

A documentação Neon atual revalidou que:

- branches são ambientes isolados e descartáveis apropriados para preview;
- roles criadas por Console/CLI/API recebem membership em `neon_superuser`, incluindo poderes incompatíveis com runtime normal;
- roles limitadas devem ser criadas por SQL, preservando a decisão F20/ADR-005.

Nenhum projeto, branch, role, database, usuário ou secret Neon foi criado nesta execução.

### Decisão fail-closed

F21 fica **ON HOLD** antes da etapa de secrets e antes de qualquer recurso PostgreSQL novo.

Provisionar Neon sabendo que a sessão não consegue concluir/read-back o gate Vercel produziria recurso e credenciais sem caminho seguro para completar a cadeia hospedada. A execução parou antes disso, como exigido pela SPEC.

**resume_when:** existir na sessão uma superfície Vercel autenticada capaz de, sem expor valores sensíveis em chat/Git/logs:

1. ler/read-back Deployment Protection, Vercel Authentication e bypasses relevantes;
2. criar, atualizar, listar metadados e remover environment variables sensíveis de Preview escopadas à branch dedicada;
3. disparar/inspecionar o Preview resultante sem transformar Production em superfície pública.

Não é necessário reabrir Managed Neon Auth. Better Auth self-hosted continua sendo a arquitetura adotada.

### Rollback / residual

Como nenhum secret ou recurso hospedado novo foi criado, não há infraestrutura F21 a desfazer. O Preview fictício F18 preexistente permaneceu protegido e inalterado.

## Resultado esperado

Provisionar e verificar um Preview descartável com a seguinte cadeia de confiança:

```text
browser
  -> Vercel Authentication / Deployment Protection
  -> Next.js Preview dedicado
  -> Server Actions privadas de sign-in/sign-out
  -> Better Auth self-hosted (`disableSignUp=true`)
  -> sessão validada server-side
  -> issuer + subject fixos/confiáveis
  -> role de domínio não privilegiada
  -> PostgreSQL + RLS
  -> somente dados fictícios
```

Nenhum recurso desta work unit pode conter dado real, interno ou pré-publicação.

## Revalidação externa obrigatória

Imediatamente antes de escrever nos providers:

### Vercel

- recuperar o estado real do projeto/deployments existentes;
- confirmar Deployment Protection/Vercel Authentication no Preview escolhido;
- confirmar escopo atual de environment variables por ambiente e branch;
- confirmar que não há Shareable Link/Exception/bypass não autorizado;
- confirmar lifecycle/rollback de deployment;
- manter Git auto-deploy conforme estado canônico, sem ampliar exposição por conveniência.

### Neon/PostgreSQL

- recuperar o estado real dos projetos/branches disponíveis;
- confirmar lifecycle/deprovisionamento do recurso descartável;
- confirmar criação de roles e grants por SQL;
- usar Better Auth self-hosted; não reabrir Managed Neon Auth como dependência;
- confirmar que connection strings de migration, Auth runtime e domínio podem permanecer separadas por role;
- não usar credencial owner/superuser como runtime normal.

Mudança material de capacidade do provider que invalide ADR-006/ADR-009 deve ser registrada antes de continuar.

## Ordem obrigatória

### Etapa A — proteção antes de secrets

1. criar ou selecionar somente a superfície mínima de Preview necessária;
2. ativar/confirmar Vercel Authentication antes de anexar secrets;
3. provar que acesso anônimo não entrega a aplicação;
4. identificar qualquer URL de Production/alias criada incidentalmente;
5. se uma superfície relevante ficar pública e não puder ser protegida, parar BLOCKED.

### Etapa B — PostgreSQL e roles

1. criar ambiente Neon/PostgreSQL descartável somente para a prova fictícia;
2. manter credencial bootstrap/migration fora do runtime da aplicação;
3. criar role de domínio runtime não privilegiada;
4. criar role `compras_auth_runtime` não privilegiada conforme a migration F20;
5. confirmar `NOSUPERUSER`, `NOBYPASSRLS`, `NOCREATEDB`, `NOCREATEROLE`, `NOREPLICATION` e ownership separado;
6. aplicar `database/migrations/0001..0003` em ordem;
7. aplicar `database/auth/migrations/0001_better_auth_1_6_23.sql` e `0002_auth_runtime_boundary.sql`;
8. confirmar que Auth runtime não lê domínio e domínio runtime não lê schema `auth`.

### Etapa C — bootstrap e autorização fictícios

1. habilitar o bootstrap one-shot F20 somente durante a operação administrativa controlada;
2. criar uma única identidade `example.invalid` fictícia;
3. desabilitar imediatamente o modo de bootstrap após a criação;
4. criar separadamente `app_user` e membership fictícios necessários à prova, sem hook automático de Auth;
5. criar equipe/contratações exclusivamente artificiais suficientes para teste cross-team;
6. nunca reutilizar nomes, emails, números de processo ou conteúdo real.

### Etapa D — secrets e ativação do Preview

Anexar somente ao Preview/branch necessários:

- `AUTH_DATABASE_URL` — role Auth runtime;
- `DATABASE_URL` — role domínio runtime;
- `BETTER_AUTH_SECRET` — server-only;
- `COMPRAS_AUTH_BASE_URL` — origem HTTPS exata do Preview;
- `COMPRAS_PERSISTENT_READ_ENABLED=true` somente depois das etapas A–C em PASS.

Credenciais bootstrap/migration e tokens de control plane não podem virar variáveis runtime.

### Etapa E — smoke funcional e adversarial

Provar no ambiente hospedado:

- acesso anônimo bloqueado pela proteção Vercel;
- após a barreira externa, usuário sem sessão interna chega ao sign-in privado;
- `/api/auth/[...path]` continua deny-all;
- signup direto continua rejeitado pelo motor Better Auth;
- OAuth/OTP/magic link/passkey/admin/reset não aparecem como superfície pública;
- identidade fictícia existente consegue sign-in;
- cookie persistido resolve sessão e `subject` no servidor;
- sign-out invalida a sessão;
- usuário Auth sem `app_user`/membership não recebe dados;
- usuário autorizado vê somente sua equipe;
- UUID conhecido de outra equipe permanece invisível/not-found;
- indisponibilidade/configuração inválida de Auth ou banco falha fechada e não cai para demo.

## Rate limiting e exposição

O login server-side permanece apropriado somente atrás da Vercel Authentication nesta etapa. Não remover a proteção externa nem declarar o login pronto para exposição pública ampla sem work unit específica de throttling/rate limiting e revisão de abuso.

## Red-team obrigatório

Rejeitar PASS se qualquer um ocorrer:

- Preview acessível anonimamente;
- Production URL/alias relevante fica público por acidente;
- secret ou connection string aparece em GitHub, log, artifact, screenshot ou bundle;
- `AUTH_DATABASE_URL` e `DATABASE_URL` usam a mesma credencial runtime;
- role Auth ou domínio é owner/superuser/BYPASSRLS;
- Auth runtime lê domínio ou domínio runtime lê Auth;
- signup funciona;
- método lateral de autenticação/criação aparece habilitado;
- identidade/subject vem de input do browser sem sessão validada;
- login cria `app_user`/membership automaticamente;
- Server Action declara sucesso sem cookie/sessão reais;
- sign-out declara sucesso sem revogação;
- erro protegido cai silenciosamente para fixtures demo;
- qualquer dado ou identidade real é criado;
- Managed Neon Auth volta ao caminho crítico;
- proteção externa é removida para contornar problema de integração.

## Verificação obrigatória

- estado real dos providers recuperado antes de writes;
- documentação externa relevante revalidada no momento da execução;
- proteção anônima: PASS;
- surface Production pública: AUSENTE ou PROTEGIDA;
- roles/grants PostgreSQL: PASS;
- migrations domínio + Auth: PASS;
- bootstrap fictício one-shot: PASS;
- signup negado: PASS;
- sign-in/session/sign-out: PASS;
- Auth sem autorização interna: DENY;
- cross-team/RLS: DENY;
- fail-closed: PASS;
- secrets/logs públicos: NÃO ENCONTRADOS;
- CI GitHub: PASS para qualquer alteração versionada;
- rollback/deprovisionamento: PASS ou residual privado explicitamente justificado;
- `REAL_DATA_ALLOWED = NO`.

## Rollback

Se qualquer gate falhar:

1. desabilitar `COMPRAS_PERSISTENT_READ_ENABLED` ou remover exposição do Preview;
2. remover/revogar secrets runtime do escopo afetado;
3. invalidar a identidade fictícia e sessões quando aplicável;
4. remover seed/recurso PostgreSQL descartável quando aplicável;
5. remover deployments/aliases que não devam permanecer;
6. verificar que nenhuma URL órfã continua acessível;
7. registrar somente estado sanitizado no checkpoint.

## Fora do escopo

- dados ou usuários reais;
- produção;
- domínio público produtivo;
- remoção da Vercel Authentication;
- onboarding definitivo de usuários institucionais;
- OAuth, OTP, magic link, passkey, reset, MFA ou Admin API pública;
- mutations/CRUD de contratação;
- analytics/session replay;
- decisão sobre exposição pública ampla do login.

## Critério de encerramento

F21 termina quando o primeiro Preview privado fictício com Better Auth self-hosted estiver comprovadamente protegido e funcional ponta a ponta sob ADR-006/ADR-007/ADR-009, ou quando um blocker externo real impedir a prova sem relaxamento. O checkpoint deve refletir o estado externo efetivamente observado e deixar exatamente uma nova `NEXT_ACTION` pequena e coerente.
