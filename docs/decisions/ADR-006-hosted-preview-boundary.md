# ADR-006 — Fronteira do primeiro preview hospedado privado

**Status:** Accepted  
**Data:** 2026-09-02  
**Escopo:** desenho e critérios de provisionamento; nenhum recurso externo é criado por esta decisão  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

A F12 completou a jornada persistente de leitura `Central → detalhe → Central` em código e PostgreSQL descartável. O caminho usa a fronteira F08: sessão validada no servidor → `issuer + subject` → contexto transacional `LOCAL` → PostgreSQL com papel operacional não privilegiado → RLS.

Ainda não existe ambiente hospedado. A arquitetura de referência cita Vercel e Neon, mas exige revalidação oficial antes de qualquer uso externo. O repositório continua público e `REAL_DATA_ALLOWED = NO`.

O runtime atual também impõe restrições concretas que esta decisão deve preservar:

- `src/server/auth/external-identity.ts` lê somente `NEON_AUTH_BASE_URL` e `NEON_AUTH_COOKIE_SECRET`, chama `auth.getSession()` no servidor e produz apenas `issuer + subject`;
- `src/server/database/trusted-context.ts` lê `DATABASE_URL`, abre uma transação `READ ONLY`, rejeita superuser/`BYPASSRLS`/owner das tabelas protegidas/`neondb_owner`/capability role, define claims com `set_config(..., true)` e destrói a conexão ao final;
- a aplicação ainda não possui jornada de login/admissão operacional; ela apenas sabe consumir uma sessão já existente.

## Evidência externa revalidada

Fontes oficiais consultadas em 2026-09-02.

### Vercel

- Deployment Protection: https://vercel.com/docs/deployment-protection
- Vercel Authentication: https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication
- bypass de Deployment Protection: https://vercel.com/docs/deployment-protection/methods-to-bypass-deployment-protection
- Environment Variables: https://vercel.com/docs/environment-variables
- gestão por ambiente/branch: https://vercel.com/docs/environment-variables/manage-across-environments
- Sensitive Environment Variables: https://vercel.com/docs/environment-variables/sensitive-environment-variables
- ambientes/deployments: https://vercel.com/docs/deployments/environments

Pontos materiais confirmados:

1. Vercel Authentication está disponível em todos os planos e pode proteger deployments sem depender de controle implementado na UI da aplicação.
2. `Standard Protection` protege previews e URLs geradas que não sejam production domains. Production domains continuam públicos sob esse escopo.
3. Proteger também production domains exige `All Deployments`, cuja disponibilidade depende do plano/capacidade contratada; a documentação atual associa essa proteção a Enterprise ou Pro com Advanced Deployment Protection.
4. Shareable Links e Protection Bypass for Automation são superfícies explícitas de bypass. Um bypass pode usar query string ou header; query string é inadequada para segredo neste projeto.
5. Variáveis podem ser separadas por ambiente e, em Preview, podem ser filtradas por branch Git específica.
6. valores sensíveis podem ser tratados como secrets/write-only pelo provedor; ainda assim não devem ser expostos a builds ou branches que não necessitem deles.
7. deployments antigos podem permanecer como snapshots por retenção; limpeza de preview é parte da fronteira, não detalhe operacional irrelevante.

### Neon / Managed Better Auth

- Managed Better Auth: https://neon.com/docs/auth/overview
- Auth production checklist: https://neon.com/docs/auth/production-checklist
- Next.js Server SDK: https://neon.com/docs/auth/reference/nextjs-server
- configuração email/senha: https://neon.com/docs/reference/api/auth/update-neon-auth-email-and-password-config
- criação administrativa de usuário: https://neon.com/docs/reference/api/auth/create-branch-neon-auth-new-user
- Admin plugin: https://neon.com/docs/auth/guides/plugins/admin
- branching de Auth: https://neon.com/docs/auth/branching-authentication
- roles: https://neon.com/docs/manage/roles
- compatibilidade PostgreSQL/`neon_superuser`: https://neon.com/docs/reference/compatibility
- Serverless Driver: https://neon.com/docs/serverless/serverless-driver

Pontos materiais confirmados:

1. Managed Better Auth continua sendo a oferta gerenciada atual da Neon e armazena usuários, sessões e configuração no Postgres da branch.
2. Managed Better Auth continua limitado a regiões AWS; Azure não é suportado atualmente. Portanto uma futura criação deve escolher região suportada e revalidar disponibilidade naquele momento.
3. o SDK server-side continua oferecendo `createNeonAuth()`/`auth.getSession()` e exige cookie secret server-side com no mínimo 32 caracteres; isso é compatível com o adaptador já implementado.
4. o checklist atual alerta que signup é permitido por padrão. Contudo a API atual de configuração email/senha expõe `disable_sign_up`, permitindo desligar novos cadastros por esse método.
5. métodos/plugins adicionais possuem controles próprios de signup. Eles não entram no primeiro preview enquanto não houver prova equivalente; OAuth/magic-link não devem ser habilitados por conveniência.
6. existe API administrativa de criação de usuário e o Admin plugin oferece gestão administrativa, mas o fluxo concreto de bootstrap de credenciais/admissão ainda precisa ser implementado e testado na aplicação antes do primeiro login hospedado.
7. Auth é branch-aware e cada branch possui endpoint isolado; isso é útil para preview, mas não autoriza copiar dados reais de uma futura produção para preview.
8. roles criadas pelo Console/CLI/API recebem membership em `neon_superuser`; roles criadas por SQL seguem privilégios normais de PostgreSQL e não recebem essa membership automaticamente.
9. isso torna inadequado criar a role runtime ou a capability F11 pelo control plane. Elas devem ser criadas por SQL/migrations e passar pelos preflights já existentes.
10. o Serverless Driver continua compatível com sessões/transações necessárias ao transporte transacional de identidade da F08.

## Matriz de decisão

| Tema | Capacidade confirmada | Decisão para o primeiro preview |
|---|---|---|
| Hosting | Vercel Preview + Deployment Protection | **Aceito condicionalmente** |
| Proteção externa | Vercel Authentication | obrigatória antes de anexar configuração sensível |
| Production domain | Standard Protection não o protege | nenhum production domain pode servir a aplicação privada sem `All Deployments`; caso exista URL pública, provisionamento falha |
| Postgres | Neon PostgreSQL + Serverless Driver | **Aceito** para preview fictício |
| Auth | Managed Better Auth server-side | **Aceito condicionalmente** após F14 implementar admissão privada |
| Signup | aberto por padrão; `disable_sign_up` existe para email/senha | provider deve estar com signup desabilitado antes da exposição; não basta remover botão |
| Roles | control-plane roles herdam `neon_superuser`; SQL roles não | migration/runtime/capability criados/validados por SQL; role control-plane nunca é runtime |
| Secrets | Vercel suporta secret + ambiente/branch | secrets somente server-side e somente na branch de preview dedicada |
| Schema | migrations Git `0001`–`0003` | continuam fonte canônica; painel não modela schema manualmente |
| Dados | Neon branching existe | primeiro preview usa projeto/ambiente fictício independente; não deriva de futura produção real |

## Decisão

### 1. Forma do primeiro preview

O primeiro ambiente hospedado será um **preview descartável e fictício**, não produção disfarçada.

Fluxo alvo:

```text
browser
  -> Vercel Deployment Protection
  -> aplicação Next.js em Preview
  -> autenticação interna Managed Better Auth
  -> sessão verificada server-side
  -> withTrustedDatabaseContext()
  -> runtime PostgreSQL não privilegiado
  -> RLS
  -> dados exclusivamente fictícios
```

Vercel Authentication é uma barreira externa adicional, não substitui Auth/RLS da aplicação. A aplicação deve continuar segura mesmo se uma URL interna for descoberta ou o controle externo for configurado incorretamente.

### 2. Regra para URLs de produção da Vercel

`Standard Protection` sozinho é insuficiente para um projeto cujo production domain sirva esta aplicação privada.

Portanto, a futura work unit de provisionamento deve usar uma destas duas condições verificadas:

1. existir apenas deployment **Preview** da aplicação, com Vercel Authentication e sem production domain/deployment acessível contendo a aplicação/configuração; ou
2. `All Deployments` estar efetivamente habilitado para proteger também production domains.

Se a criação/importação do projeto gerar uma production URL pública e o plano não permitir protegê-la, o preview é **BLOCKED** e os secrets não são anexados. Não aceitar “ninguém conhece a URL” como mitigação.

Toda URL relevante deve ser testada em sessão anônima/incógnita antes de habilitar o modo persistente.

### 3. Branch de preview dedicada

O primeiro preview não receberá secrets em todos os PRs do repositório público.

A futura implantação deve usar uma branch dedicada e branch-specific Preview environment variables. PRs/branches genéricos continuam sem `DATABASE_URL`, cookie secret ou configuração operacional do preview.

A automação Git/Vercel não pode transformar qualquer PR público em consumidor automático dos secrets.

### 4. Admissão privada

A aplicação não terá signup público.

Para a primeira integração:

- email/senha é o único método candidato inicial;
- a configuração hospedada deve definir `disable_sign_up = true` **antes** de o endpoint ser considerado pronto;
- OAuth, magic link e outros plugins permanecem desabilitados até que seu próprio comportamento de signup seja explicitamente controlado/testado;
- usuários de teste são admitidos apenas por caminho administrativo documentado;
- autenticar não auto-cria `app_users`/`memberships` do domínio Compras;
- a identidade externa só ganha acesso quando existe `app_user` fictício correspondente e membership fictícia ativa no banco da aplicação.

A Neon documenta controles e APIs administrativas suficientes para continuar a integração, porém o repositório ainda não possui UI/handler/jornada de login privada. Essa é a próxima fronteira F14 e deve ser resolvida antes do provisionamento completo.

### 5. Papéis PostgreSQL

O preview separa quatro responsabilidades:

#### Bootstrap/control plane

Role inicial do provedor, potencialmente membro de `neon_superuser`.

Pode ser usada somente para criar a estrutura administrativa necessária ao preview. Nunca entra em `DATABASE_URL` da aplicação e nunca é armazenada como runtime secret.

#### Migration principal

Role dedicada, criada por **SQL**, sem `neon_superuser`, capaz de aplicar `0001`–`0003` e cumprir o lifecycle de ADR-005.

Deve possuir somente os privilégios administrativos necessários ao schema/migrations e `CREATEROLE` quando exigido pela migration `0003`. Não é credencial contínua da aplicação.

#### Runtime

Role de `LOGIN` criada por SQL, não-owner, `NOSUPERUSER`, `NOBYPASSRLS`, sem `CREATEROLE` e sem membership utilizável em capability/admin roles.

Sua connection string é o único `DATABASE_URL` permitido ao runtime F08. O próprio adaptador continuará validando e rejeitando configuração privilegiada.

#### Capability

`compras_team_directory_view_owner`, `NOLOGIN`, criada/reutilizada somente pela migration `0003` e sujeita aos preflights ADR-004/005. Nunca vira credencial.

### 6. Configuração e secrets

Categorias:

| Valor | Classificação no preview | Superfície permitida |
|---|---|---|
| `DATABASE_URL` runtime | secret | Vercel Preview, branch dedicada, server-only |
| connection string bootstrap/migration | secret administrativo | somente executor controlado da migration; nunca runtime |
| `NEON_AUTH_COOKIE_SECRET` | secret | Vercel Preview, branch dedicada, server-only |
| `NEON_AUTH_BASE_URL` | configuração server-side | Vercel Preview da branch dedicada; não derivada do browser |
| `COMPRAS_PERSISTENT_READ_ENABLED=true` | configuração | somente depois de Auth/DB/smoke estarem prontos |
| provider/API tokens | secret administrativo | somente ferramenta/control plane necessário; nunca Git/browser |

Nenhum desses valores é versionado. Nenhum segredo usa prefixo público/client-side. Nenhum segredo é colocado em query string, título, URL, PR, log, summary ou artifact.

### 7. Migrations

Migrations continuam sendo aplicadas em ordem a partir do Git:

```text
0001_core_foundation.sql
0002_trusted_identity_read_policies.sql
0003_team_member_directory.sql
```

A futura execução hospedada deve:

1. usar a credencial de migration separada;
2. falhar com `ON_ERROR_STOP`/equivalente;
3. executar os preflights da `0003` antes de considerar o banco pronto;
4. nunca usar a credencial runtime para DDL/role management;
5. nunca “corrigir” schema manualmente no painel como nova fonte de verdade;
6. registrar apenas sucesso/falha sanitizados, sem ecoar connection strings.

### 8. Seed e smoke fictícios

O preview deve nascer recriável. O seed será separado de migrations e terá marcador explícito de dados artificiais.

Smoke positivo mínimo:

```text
identidade artificial admitida
-> app_user fictício
-> membership fictícia ativa
-> Central persistente
-> contratação fictícia
-> detalhe persistente da mesma contratação
-> retorno à Central
```

Smoke negativo mínimo:

- visitante anônimo não atravessa Deployment Protection;
- usuário não admitido não consegue signup;
- identidade autenticada sem `app_user`/membership recebe nenhum dado;
- UUID fictício de outra equipe é indistinguível de inexistente;
- runtime privilegiado é rejeitado pelo adaptador;
- falha de sessão/banco não cai para demo.

### 9. Logs, analytics e URLs

No primeiro preview:

- nenhuma ferramenta externa de analytics/session replay é adicionada;
- aplicação não loga claims, cookie, connection string, conteúdo da contratação ou payload de banco;
- logs operacionais, quando inevitáveis, devem se limitar a eventos genéricos/IDs de request do provedor;
- rota continua usando somente UUID opaco como identificador necessário;
- secrets e bypass tokens nunca vão para query strings;
- `auth` server adapter mantém `logLevel: "silent"` salvo decisão futura justificada.

### 10. Bypasses da proteção

Não criar Shareable Link no primeiro preview.

Não criar Deployment Protection Exception.

Protection Bypass for Automation só pode entrar em uma work unit futura se teste automatizado externo realmente exigir acesso. Nesse caso deve ser:

- secret separado;
- transmitido por header, não query string;
- escopado ao preview;
- revogável;
- ausente de logs e Git.

### 11. Rollback e deprovisionamento

O preview é descartável. Rollback operacional mínimo:

1. desligar `COMPRAS_PERSISTENT_READ_ENABLED` ou retirar o deployment da circulação se a leitura protegida falhar;
2. revogar/remover secrets de Preview;
3. remover deployment/alias e confirmar que as URLs deixaram de servir a aplicação;
4. desabilitar/remover Auth do ambiente fictício;
5. destruir branch/projeto PostgreSQL de preview quando não for mais necessário;
6. revogar credenciais/tokens administrativos usados somente no provisionamento;
7. respeitar retenção do provedor e não assumir que excluir branch Git apaga instantaneamente todo snapshot de deployment.

Como o ambiente contém somente dados fictícios, destruição/recriação é a estratégia normal, não recuperação manual de estado.

## Red-team da decisão

### Preview descoberto por URL

**Ataque:** URL `.vercel.app` é encontrada externamente.  
**Controle:** Vercel Authentication antes da aplicação + Auth interno + RLS. Incognito smoke obrigatório.

### Production domain público

**Ataque:** Standard Protection protege previews, mas a mesma aplicação fica pública no production domain.  
**Controle:** não anexar secrets até provar ausência de production surface ou habilitar `All Deployments`. Se não for possível no plano, bloquear.

### Signup direto no endpoint Neon Auth

**Ataque:** atacante ignora a UI e chama signup diretamente.  
**Controle:** `disable_sign_up=true` no provider antes da exposição; somente remover botão é insuficiente. Métodos adicionais permanecem desligados.

### PR público recebe secrets

**Ataque:** qualquer branch/PR ganha env Preview compartilhado.  
**Controle:** branch-specific variables para uma branch dedicada; sem default Preview secret reutilizável por todos os PRs.

### Runtime privilegiado

**Ataque:** usar default role/control-plane role facilita a conexão.  
**Controle:** runtime criado por SQL e validado por F08; default/control-plane role nunca vira `DATABASE_URL`.

### Capability contaminada por `neon_superuser`

**Ataque:** capability criada por Console/CLI/API recebe membership privilegiada.  
**Controle:** migration SQL + preflight ADR-005; configuração insegura falha.

### Migration usa credencial runtime

**Ataque:** simplificar para uma única connection string.  
**Controle:** credenciais separadas e ciclo administrativo efêmero; runtime sem DDL/`CREATEROLE`.

### Seed aplicado no ambiente errado

**Ataque:** script fictício é executado futuramente onde existam dados reais.  
**Controle:** seed fora de migrations, gate explícito de ambiente/fictitious-only na work unit de provisionamento e `REAL_DATA_ALLOWED=NO`.

### Logs capturam conteúdo interno

**Ataque:** exceção serializa claims/URL/DB error.  
**Controle:** adapters atuais convertem falha para erro genérico; nenhum analytics/replay; revisão de logs no smoke.

### Recurso abandonado

**Ataque:** deployment/branch continua ativo após teste.  
**Controle:** checklist de deprovisionamento e retenção; destruição explícita quando a work unit encerrar.

## Consequências

### Positivas

- Vercel e Neon continuam utilizáveis sem enfraquecer F08/RLS;
- o repositório público não precisa receber secrets ou dados reais;
- proteção do preview possui duas fronteiras independentes: hosting e aplicação;
- roles administrativas e runtime permanecem separadas;
- o risco específico de `neon_superuser` é tratado antes do primeiro banco hospedado;
- signup privado deixa de depender de “botão escondido” porque existe controle provider-side documentado;
- o preview pode ser destruído/recriado sem relevância operacional.

### Custos e condicionais

- Vercel Standard Protection não resolve um production domain privado; o provisionamento precisa provar a topologia real ou exigir `All Deployments`;
- Managed Better Auth precisa estar em região AWS suportada;
- a aplicação ainda precisa implementar uma jornada de login/admissão que não publique signup antes de receber configuração hospedada;
- a criação administrativa/bootstrap do primeiro usuário de teste deve ser testada na próxima fronteira, sem inferir comportamento apenas porque o provider possui APIs administrativas.

## Critérios para futura work unit de provisionamento

Provisionamento só pode começar depois que:

- F14 implementar e testar a jornada privada de Auth da aplicação;
- signup de aplicação for ausente/bloqueado e o desenho exigir `disable_sign_up=true` no provider;
- existir procedimento de admissão administrativa do usuário fictício sem janela de signup público;
- a topologia Vercel escolhida puder ser verificada como não anônima em todas as URLs que sirvam a aplicação;
- branch-specific secret scope estiver disponível;
- roles SQL de migration/runtime e preflight `0003` continuarem compatíveis com Neon atual.

Nenhum desses critérios autoriza dados reais. Produção permanece uma decisão futura separada.

## Próxima work unit

A próxima fronteira independente é `F14-PRIVATE-AUTH-ADMISSION-01`: implementar no repositório a jornada de autenticação privada necessária ao preview — sign-in sem signup público, handler/guard server-side, estados de sessão e testes adversariais — sem ainda criar Vercel/Neon hospedado.
