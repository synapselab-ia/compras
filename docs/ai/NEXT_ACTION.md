# Next Action — Compras

## F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01 — Retomar a prova Neon quando signup restrito estiver disponível

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`
**Estado:** BLOCKED_EXTERNAL_PROVIDER_CAPABILITY / RESUME_WHEN
**Objetivo:** concluir a etapa Neon da F17 somente quando o mesmo canal oficial autenticado permitir WRITE + READBACK de `disable_sign_up=true` e dos controles de plugins/métodos laterais antes de qualquer uso do Auth.

Esta é a única `NEXT_ACTION` canônica. Não criar F18 enquanto a condição abaixo não estiver satisfeita.

## Bloqueio observado

Em 2026-09-03, a sessão oficial autenticada do Neon foi operada diretamente no console da organização correta. Em um projeto vazio e descartável criado exclusivamente para F17, o console mostrou:

- alerta de que qualquer pessoa na web poderia criar conta e que signup restrito ainda estava por vir;
- `Sign-up with Email` ativo por padrão;
- controle de signup desabilitado para interação, impedindo o WRITE;
- `Allow Localhost` ativo por padrão;
- provider Google/`Shared keys` presente na seção OAuth.

Assim, não foi possível aplicar nem ler de volta `disable_sign_up=true`; também não foi possível provar plugins/métodos laterais e OAuth em estado seguro. O Auth foi removido com seus dados vazios e o projeto Neon descartável foi excluído. A lista final voltou aos três projetos preexistentes.

## Condição objetiva de retomada

Retomar F17 somente quando a conta/região Neon oferecer, em uma única sessão oficial autenticada e observável:

1. WRITE + READBACK específico de `/auth/email_and_password` com `disable_sign_up=true`;
2. WRITE + READBACK de `/auth/plugins` e dos endpoints específicos necessários para manter magic link, phone/OTP, organizações/admin ou outros métodos laterais desabilitados;
3. OAuth providers comprovadamente ausentes ou desabilitados;
4. trusted domains estritos, sem wildcard e sem localhost desnecessário;
5. caminho observável de teardown antes de criar usuário ou dado.

Documentação, endpoint Auth genérico, configuração apenas de nome da aplicação, deny-all da aplicação ou aparência da UI não satisfazem essa condição.

## Estado preservado da prova Vercel

A etapa Vercel da F17 já passou e não deve ser refeita por rotina:

- projeto `compras-f17-control-proof` preservado por instrução do usuário;
- Vercel Authentication ativa com readback;
- nenhum deployment, domínio ou alias;
- variável fictícia `F17_INERT_PROOF` provada como Preview + branch `f17-provider-control-proof` e removida com readback;
- nenhuma env var ou secret operacional residual;
- auto-deploy por Git desabilitado em `vercel.json` enquanto F17 estiver bloqueada.

Não excluir, recriar ou renomear o projeto Vercel nesta ação. Revalidar seu estado apenas por leitura se houver evidência concreta de mudança.

## Execução permitida ao retomar

1. recuperar GitHub/contexto e validar o manifest;
2. confirmar por leitura que o estado Vercel preservado não mudou;
3. confirmar a disponibilidade dos controles Neon antes de provisionar Auth;
4. criar no máximo um projeto Neon vazio e descartável, sem tocar projetos existentes;
5. aplicar imediatamente todos os controles críticos;
6. fazer READBACK específico de cada controle;
7. executar o red-team da SPEC;
8. remover Auth/projeto descartável mediante confirmação destrutiva quando exigida;
9. somente se tudo passar, fechar F17 e criar uma nova work unit que retome F15.

## Regras obrigatórias

- `REAL_DATA_ALLOWED = NO`;
- não criar usuário, `app_user`, membership, migration hospedada, seed ou dado de contratação;
- não usar `DATABASE_URL`, cookie secret ou outro secret operacional;
- não copiar credencial para chat, Git, PR, log, screenshot pública ou artifact;
- não reutilizar projeto Neon alheio;
- não criar novo projeto Neon apenas para tentar contornar o mesmo bloqueio observado;
- não deixar Auth com signup default exposto enquanto procura controles;
- não habilitar método lateral sem prova equivalente;
- não usar deny-all da aplicação como substituto de `disable_sign_up` do provider;
- não criar F18 antes do PASS integral da F17.

## Fonte da tarefa

Executar conforme `tasks/F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01/SPEC.md`, ADR-006, ADR-007, `docs/architecture/SECURITY.md` e `docs/ai/CURRENT_STATE.md`.

## Critério de encerramento

F17 fecha somente com Vercel e Neon em PASS por WRITE + READBACK + rollback observável, sem secrets ou dados reais. Enquanto o controle Neon de signup restrito permanecer indisponível, esta mesma F17 continua bloqueada e é a única `NEXT_ACTION`.
