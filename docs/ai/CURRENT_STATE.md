# Current State — Compras

**PROJECT_STATUS:** BLOCKED_NEON_RESTRICTED_SIGNUP_CONTROL_UNAVAILABLE
**CURRENT_PHASE:** F17 — Authenticated Provider Control Session (BLOCKED fail-closed no Neon)
**REPO_VISIBILITY:** PUBLIC
**APPLICATION_STATUS:** PRIVATE_AUTH_ADMISSION_AND_PERSISTENT_READ_IMPLEMENTED_NOT_HOSTED
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_TEAM_DIRECTORY_VALIDATED_IN_EPHEMERAL_CI
**AUTH_STATUS:** PRIVATE_SIGNIN_SIGNOUT_AND_DENY_ALL_ADMISSION_IMPLEMENTED_NOT_PROVISIONED
**DEPLOYMENT_STATUS:** VERCEL_CONTROL_PROJECT_EMPTY_PROTECTED_NO_DEPLOYMENTS
**REAL_DATA_ALLOWED:** NO
**CONTEXT_STATUS:** VALID
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`
**LAST_GOOD_COMMIT:** `6c3891d0e4839daa067741bbcf5eafdea542a329`
**LAST_GOOD_CI_RUN:** `33670574481`
**F17_INPUT_COMMIT:** `20916b6bf2a606b59bf49f94b5a61dea8f6d82ef`
**F17_INPUT_CI_RUN:** `33790024970`
**BLOCKERS:** `F17-B2` o Neon Auth disponível nesta conta não permite aplicar e ler de volta `disable_sign_up=true`; o console informa que signup restrito ainda não é suportado e apresenta o controle de signup desabilitado
**RESUME_WHEN:** o Neon expuser, no mesmo canal oficial autenticado, WRITE + READBACK observável de `/auth/email_and_password` com `disable_sign_up=true`, `/auth/plugins` e métodos laterais/OAuth desabilitados antes de qualquer uso

## Estado real

A work unit `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01` foi executada em 2026-09-03 pelo protocolo canônico, partindo da `main` em `20916b6bf2a606b59bf49f94b5a61dea8f6d82ef`.

A sessão oficial autenticada e observável foi estabelecida nos consoles Vercel e Neon sem transferir credenciais, tokens, cookies, connection strings ou secrets para chat ou Git. A prova Vercel passou. A prova Neon encontrou uma indisponibilidade real do controle crítico de signup restrito e encerrou fail-closed, com rollback completo do recurso Neon descartável.

F17 permanece aberta e é a única `NEXT_ACTION`. F18 não existe e não deve ser criada enquanto `F17-B2` persistir.

## Recuperação e contexto

- `main` recuperada em `20916b6bf2a606b59bf49f94b5a61dea8f6d82ef`;
- nenhuma PR aberta no início da execução;
- a frente ativa confirmada foi `F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01`;
- os 10 inputs estáveis do `CONTEXT_MANIFEST` coincidiram com os blobs esperados;
- `CONTEXT_STATUS = VALID`;
- CI de entrada `33790024970`: PASS;
- `REAL_DATA_ALLOWED = NO` permaneceu ativo.

## Prova Vercel — PASS

A conta/equipe correta foi identificada e os projetos preexistentes foram apenas inspecionados. Nenhum projeto alheio foi alterado.

Foi criado o projeto mínimo `compras-f17-control-proof`, sem secret de aplicação e sem deployment, domínio ou alias. O projeto foi conectado a `synapselab-ia/compras` somente para validar o escopo de branch da variável fictícia.

### Deployment Protection

- Vercel Authentication foi configurada antes de qualquer variável;
- o plano Hobby expôs `Standard Protection`;
- foi executado WRITE + reload/readback do controle;
- estado final observado: `Require Log In` habilitado e formulário salvo;
- nenhum Shareable Link, Protection Bypass, exception ou URL obscura foi usado;
- nenhum deployment Production ou Preview foi criado.

### Variável fictícia Preview + branch

- branch dedicada: `f17-provider-control-proof`;
- variável inerte: `F17_INERT_PROOF`;
- tipo: Config;
- target observado: Preview;
- filtro observado: branch `f17-provider-control-proof`;
- WRITE + READBACK: PASS;
- remoção da variável + reload/readback de ausência: PASS;
- nenhum `DATABASE_URL`, cookie secret ou secret operacional foi usado.

### Estado residual Vercel

Por instrução explícita do usuário, o projeto Vercel **não foi excluído**. Ele permanece vazio, sem deployments e sem env vars, protegido por Vercel Authentication, para possível reaproveitamento futuro como projeto real do Compras. O nome é provisório.

`vercel.json` mantém auto-deploy por Git desabilitado enquanto F17 estiver bloqueada, evitando que commits exclusivamente documentais criem uma superfície Production no projeto preservado. Remover esse bloqueio pertence a uma futura work unit de provisionamento deliberado, depois que F17 fechar.

## Prova Neon — BLOCKED / FAIL-CLOSED

A organização correta foi identificada. Os três projetos preexistentes foram inspecionados read-only e permaneceram inalterados.

Foi criado o projeto descartável `compras-f17-control-proof` em região AWS suportada, inicialmente sem Neon Auth. Nenhuma tabela de negócio, migration, seed, usuário, `app_user`, membership ou dado de contratação foi criado.

Ao habilitar Managed Better Auth para a prova controlada, o próprio console exibiu imediatamente o alerta:

> Anyone on the web can sign up for your app. Support for restricted signups is coming soon.

Na aba Configuration:

- `Sign-up with Email` apareceu ativo por padrão;
- o controle correspondente estava desabilitado para interação, impedindo o WRITE exigido;
- portanto `disable_sign_up=true` não pôde ser aplicado nem lido de volta;
- `Allow Localhost` apareceu habilitado por padrão;
- um provider Google com `Shared keys` apareceu na seção OAuth;
- ausência/desativação de OAuth, magic link, phone e plugins laterais não pôde ser provada;
- nenhum domínio público foi adicionado e nenhum usuário foi criado.

O alerta e o controle desabilitado são evidência observável de que esta superfície Neon atual não satisfaz ADR-006, ADR-007 e a SPEC F17. Documentação ou GET genérico não substituem o WRITE + READBACK ausente.

## Rollback Neon — PASS

Após confirmação destrutiva explícita do usuário:

1. Neon Auth foi removido com `Clear all data associated with this integration` marcado;
2. a página voltou a oferecer `Enable Neon Auth`, confirmando o teardown da integração;
3. o projeto descartável `compras-f17-control-proof` foi excluído;
4. após reload, a lista da organização voltou a conter somente os três projetos preexistentes;
5. nenhum projeto Neon residual da F17 permaneceu.

## Red-team F17

- sessão parcialmente observável: rejeitada; Vercel teve readback real e Neon foi bloqueado onde o readback crítico faltou;
- sessão expirada entre WRITE e READBACK: não ocorreu; reloads autenticados confirmaram os estados usados como evidência;
- superfície Vercel Production pública: nenhuma foi criada;
- variável Preview sem branch: rejeitada; branch específica foi observada antes da remoção;
- URL obscura, Shareable Link ou bypass: não usados;
- signup race Neon: detectada pelo alerta/provider default e encerrada por teardown imediato;
- métodos laterais/OAuth: não considerados seguros sem readback; a presença de Google/Shared keys reforçou o bloqueio;
- deny-all da aplicação como substituto de provider: rejeitado;
- configuração Neon genérica como falsa prova: rejeitada;
- secret em Git/chat/log/screenshot público: nenhum;
- projeto alheio alterado: nenhum;
- dado real, interno ou pré-publicação: nenhum.

## Verificação

- GitHub `main`, PRs e branches de entrada: INSPECIONADOS;
- `CONTEXT_MANIFEST`: PASS / VALID;
- sessão Vercel autenticada: PASS;
- Vercel protection WRITE + READBACK: PASS;
- Vercel env Preview + branch WRITE + READBACK: PASS;
- Vercel env rollback: PASS;
- deployments/domains/aliases Vercel: INSPECIONADOS / AUSENTES;
- projeto Vercel residual: VAZIO, PROTEGIDO E JUSTIFICADO;
- sessão Neon autenticada: PASS;
- Neon `disable_sign_up=true` WRITE + READBACK: BLOCKED;
- Neon plugins/métodos laterais/OAuth: NÃO PROVADOS, tratados como inseguros;
- Neon Auth teardown: PASS;
- projeto Neon descartável removido + readback: PASS;
- secrets operacionais publicados: NÃO;
- dados reais utilizados: NÃO;
- projeto alheio alterado: NÃO.

## Limite atual

F17 não pode ser concluída porque o provider Neon observado não expõe o enforcement obrigatório de signup restrito. Não tentar novo projeto Neon, não montar o preview, não anexar secrets e não criar F18.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas.

## Last good

`6c3891d0e4839daa067741bbcf5eafdea542a329` continua sendo o `LAST_GOOD_COMMIT` funcional, validado pela CI `33670574481`. O checkpoint de entrada F17 em `20916b6bf2a606b59bf49f94b5a61dea8f6d82ef` possui CI `33790024970` em PASS.

## Próxima ação

Executar somente a ação descrita em `docs/ai/NEXT_ACTION.md`: manter F17 bloqueada até o Neon oferecer os controles provider-side exigidos e, então, retomar a prova Neon sem recriar ou excluir o projeto Vercel preservado.
