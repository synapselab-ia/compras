# F15-HOSTED-PREVIEW-PROVISION-01 — Provisionar e provar o primeiro preview hospedado privado fictício

**Classe:** T3 — integração externa, com impacto de T2 — segurança  
**Estado:** READY após conclusão de F14  
**Dependências:** F08, F11, F14, ADR-003, ADR-005, ADR-006 e ADR-007  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

A aplicação já possui leitura persistente protegida, capability de diretório e admissão privada em código. Falta provar que essas fronteiras permanecem válidas em um ambiente hospedado real sem introduzir superfície pública, signup, secrets em escopo excessivo ou credencial PostgreSQL privilegiada.

F15 deve materializar o primeiro preview descartável exclusivamente com dados fictícios. O objetivo não é “colocar no ar” a qualquer custo: se o provider, plano ou conector não permitir provar a fronteira aprovada, a implementação deve parar em estado BLOCKED antes de ampliar exposição.

## 2. Resultado esperado

Provisionar e verificar um ambiente de Preview que combine:

```text
browser
  -> Vercel Deployment Protection
  -> Next.js Preview dedicado
  -> sign-in privado da F14
  -> Managed Better Auth com signup provider-side desabilitado
  -> sessão validada server-side
  -> F08
  -> role runtime PostgreSQL não privilegiada
  -> RLS/F11
  -> dados exclusivamente fictícios
```

Nenhum recurso dessa work unit pode conter dado real ou pré-publicação.

## 3. Revalidação externa obrigatória

Imediatamente antes de agir sobre os providers, confirmar nas fontes oficiais e, para recursos da conta, pelos conectores disponíveis:

### Vercel

- Deployment Protection/Vercel Authentication disponível para o ambiente escolhido;
- diferença atual entre proteção de Preview e production domains;
- escopo de environment variables por ambiente e branch;
- retenção/deprovisionamento de deployments;
- ausência de Shareable Link/Exception/bypass não autorizado.

### Neon

- região compatível com Managed Better Auth;
- semântica atual de roles criadas por control plane versus SQL;
- configuração de email/senha e `disable_sign_up`;
- trusted origins/métodos habilitados;
- branch/project lifecycle e deprovisionamento;
- connection strings e papéis necessários a migration/runtime.

Mudança material na capacidade do provider deve atualizar a decisão antes do provisionamento.

## 4. Ordem obrigatória

### Etapa A — proteção antes de secrets

1. criar/importar somente a superfície mínima de Preview necessária;
2. ativar Vercel Authentication/Deployment Protection;
3. provar anonimamente que a URL relevante não entrega a aplicação;
4. identificar qualquer production URL/deployment gerado;
5. se uma production surface servir a aplicação e não puder ser protegida adequadamente, parar BLOCKED;
6. somente depois anexar configuração sensível.

### Etapa B — Postgres e papéis

1. criar ambiente Neon descartável em região compatível;
2. tratar a credencial/control-plane inicial apenas como bootstrap;
3. criar/validar por SQL principal de migration separado;
4. criar por SQL role runtime com mínimo privilégio;
5. confirmar que runtime não é owner, superuser, `BYPASSRLS`, `CREATEROLE`, `neondb_owner` nem membro de `neon_superuser`;
6. aplicar migrations canônicas `0001`, `0002`, `0003` em ordem;
7. confirmar os preflights/postflights da capability F11/ADR-005;
8. nunca transformar a credencial bootstrap/migration em `DATABASE_URL` da aplicação.

### Etapa C — Auth privado

1. habilitar somente email/senha para a primeira prova;
2. confirmar `disable_sign_up=true` provider-side;
3. desabilitar métodos adicionais de criação/autenticação fora da F14;
4. limitar trusted origins à superfície protegida necessária;
5. criar somente identidade de teste fictícia por caminho administrativo;
6. não usar login como gatilho de criação de `app_users`/membership.

### Etapa D — seed fictício

Seed deve ser separado das migrations e conter guard explícito de ambiente/branch.

Criar apenas dados artificiais suficientes para provar:

- usuário interno fictício ativo ligado ao subject fictício do Auth;
- membership ativa em equipe A;
- outra equipe B com contratação conhecida apenas para teste cross-team;
- contratação visível em A;
- responsável colega fictício se necessário à capability F11;
- casos de membership revogada/usuário desabilitado quando necessários ao smoke.

Nenhum nome, processo, número, email ou conteúdo de trabalho real pode ser usado.

### Etapa E — secrets e ativação

Na Vercel, anexar somente ao ambiente/branch necessários:

- `DATABASE_URL` da role runtime;
- `NEON_AUTH_BASE_URL` confiável;
- `NEON_AUTH_COOKIE_SECRET` server-only;
- `COMPRAS_PERSISTENT_READ_ENABLED=true` apenas após etapas A–D validadas.

Credencial de bootstrap/migration e tokens de control plane não podem ser variáveis runtime da aplicação.

## 5. Smoke funcional e adversarial

Provar no ambiente hospedado:

### Proteção externa

- navegador sem sessão Vercel não acessa a aplicação;
- nenhuma production URL relevante está pública;
- nenhum shareable link/exception/bypass abre o preview.

### Admissão

- após passar a proteção externa, usuário sem sessão da aplicação chega ao sign-in privado;
- `/api/auth/sign-up/...` e endpoints laterais da aplicação continuam deny-all;
- tentativa direta de signup email/senha no endpoint gerenciado do provider é rejeitada porque `disable_sign_up=true`;
- OAuth/OTP/reset não estão habilitados;
- identidade fictícia previamente criada consegue sign-in;
- sign-out encerra acesso da aplicação.

### Autorização/RLS

- usuário fictício autorizado vê somente dados da própria equipe;
- UUID conhecido de contratação da equipe B permanece invisível/not-found;
- identidade válida no provider sem `app_user`/membership interna não ganha dados;
- membership revogada ou usuário interno desabilitado perde acesso conforme regressões existentes;
- responsible directory não expõe issuer/subject.

### Fail-closed

- configuração inválida ou indisponibilidade Auth/DB não retorna demo;
- nenhum erro público contém connection string, cookie secret, claims ou endpoint administrativo.

## 6. Observabilidade e exposição

No primeiro preview:

- não habilitar analytics/session replay externa por default;
- revisar logs de build/runtime apenas para sinais sanitizados;
- não registrar senha, cookie, token, claims completos, connection string ou payload sensível;
- não persistir screenshots/logs com secrets em GitHub público;
- evidência documental deve usar somente estados, nomes de controles e identificadores públicos/sanitizados indispensáveis.

## 7. Rollback e deprovisionamento

Definir e testar a sequência segura:

1. desabilitar `COMPRAS_PERSISTENT_READ_ENABLED` ou remover exposição do deployment quando necessário;
2. remover/revogar secrets runtime;
3. invalidar/remover identidade fictícia e sessões, se o ambiente for descartado;
4. remover seed/branch/database/project descartável conforme capacidade do provider;
5. remover deployments/aliases que não devam permanecer;
6. verificar que nenhuma URL órfã continua acessível;
7. documentar somente estado sanitizado residual.

Se o preview permanecer para uso técnico após F15, ele deve continuar privado, fictício e explicitamente marcado como não-produção.

## 8. Condições de bloqueio

Não contornar nenhum destes problemas:

- Deployment Protection insuficiente para toda superfície relevante;
- production URL pública sem controle compatível;
- provider não permite provar signup desabilitado;
- método lateral obrigatório cria usuário implicitamente;
- única role runtime possível é owner/superuser/`BYPASSRLS`/`neon_superuser`;
- migration/capability exige membership técnica insegura não prevista pela ADR-005;
- secrets só podem ser injetados em escopo amplo de PRs/branches públicas;
- conector necessário não permite verificar ação crítica e não há caminho seguro observável;
- qualquer dado real seria necessário para concluir o smoke.

Nesses casos: registrar blocker, não relaxar a fronteira e deixar a próxima ação focada em resolver o blocker.

## 9. Verificação obrigatória

- providers revalidados no momento da execução;
- estado real das contas/recursos recuperado por conectores antes de escrever;
- proteção anônima: PASS;
- production surface pública: AUSENTE ou PROTEGIDA;
- `disable_sign_up`: CONFIRMADO;
- métodos adicionais: DESABILITADOS;
- runtime role: NÃO PRIVILEGIADA;
- migration/runtime credentials: DISTINTAS;
- migrations `0001`–`0003`: PASS;
- F11 capability postflight: PASS;
- seed fictício + guard: PASS;
- smoke sign-in/sign-out: PASS;
- smoke cross-team/unknown identity: PASS;
- fail-closed: PASS;
- secrets/logs públicos: NÃO ENCONTRADOS;
- CI GitHub: PASS para qualquer alteração versionada;
- rollback/deprovisionamento: PASS ou residual privado justificado;
- `REAL_DATA_ALLOWED`: NO.

## 10. Fora do escopo

Não:

- dados ou usuários reais;
- produção;
- domínio público produtivo;
- analytics/session replay;
- mutations/CRUD de contratação;
- Q-009;
- Q-010;
- OAuth/magic link/OTP/reset/MFA;
- cópia/branch de futura produção com dados reais.

## 11. Critério de encerramento

F15 termina quando o primeiro preview hospedado privado fictício estiver comprovadamente protegido e funcional ponta a ponta sob ADR-006/ADR-007, ou quando um blocker real impedir a prova sem relaxamento. O checkpoint deve refletir o estado externo efetivamente observado e deixar exatamente uma nova `NEXT_ACTION` pequena e coerente.
