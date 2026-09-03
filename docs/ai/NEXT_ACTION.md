# Next Action — Compras

## F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01 — Estabelecer sessão autenticada de control-plane para Vercel e Neon

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`  
**Estado:** MANUAL_ACTION_REQUIRED / BLOCKER-RESOLUTION  
**Objetivo:** tornar disponível ao assistente uma sessão oficial, autenticada e observável de controle dos providers Vercel e Neon, sem copiar tokens/secrets para chat ou Git, e então provar por write + readback as capacidades críticas já confirmadas documentalmente.

## Reinspeção mais recente

Em 2026-09-03, partindo da `main` em `9606e926306c8c6073037be36cefacc62f8b7415` com CI `33772827732` em PASS, esta work unit foi reexecutada novamente até sua condição explícita de bloqueio.

O estado permanece:

- Vercel e Neon estão acessíveis por superfícies oficiais autenticadas de inspeção, mas não pelo conjunto completo de controles exigidos pela F17;
- o conector Vercel continua com 24 ferramentas e sem write/readback de Deployment Protection, env vars Preview + branch e deprovisionamento controlado;
- a superfície Neon Auth continua expondo inspeção/gestão parcial (`get_neon_auth_config`, OAuth, trusted domains e enable/disable), mas `update_auth_config` segue restrito ao nome da aplicação e não há write + readback de `/auth/email_and_password` e `/auth/plugins`;
- não existe CLI `vercel`, `neon` ou `neonctl` autenticada no runtime;
- não existem variáveis de autenticação Vercel/Neon exportadas ao shell;
- nenhuma integração adicional compatível foi encontrada;
- não existe projeto `compras` nos providers;
- nenhum recurso de Compras foi provisionado.

Por regra do próprio F17, **não criar F18 nem nova work unit de workaround enquanto a ação manual abaixo não estiver satisfeita**.

## Ação manual única necessária

**Estabelecer uma sessão de controle autenticada nos consoles oficiais Vercel e Neon que seja acessível ao assistente sem revelar credenciais e então reexecutar esta work unit.**

O caminho operacional preferido, quando disponível na conta, é executar esta frente em **ChatGPT Work/Cloud Browser** e autenticar o navegador nos consoles oficiais Vercel e Neon. Não enviar API key, bearer token, password, cookie, connection string ou secret pelo chat.

Se esse modo não estiver disponível, F17 continua bloqueada até existir uma superfície oficial equivalente já autenticada e observável pela sessão. Não substituir isso por instruções manuais opacas que o assistente não consiga verificar.

## Fonte da tarefa

Executar conforme `tasks/F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01/SPEC.md`, ADR-006, ADR-007, `docs/architecture/SECURITY.md` e o checkpoint F17 em `docs/ai/CURRENT_STATE.md`.

## Contexto confirmado

As reinspeções F16/F17 eliminaram a ambiguidade de capacidade dos providers:

- o Vercel possui APIs/SDK/CLI oficiais para criação de projeto, `ssoProtection`, env vars Preview + `gitBranch`, leitura/remoção de envs e gerenciamento/rollback;
- o Neon possui API oficial branch-scoped para `/auth/email_and_password`, `/auth/plugins`, métodos específicos, domains, OAuth e teardown de Managed Better Auth;
- a documentação Neon atual confirma que `/auth/config` altera apenas o nome da aplicação, enquanto `email_and_password` e `plugins` exigem endpoints próprios;
- o problema atual é a indisponibilidade, nesta sessão, de um executor oficial autenticado que exponha **todos** esses controles com write + readback;
- nenhum recurso de Compras foi provisionado.

## Resultado esperado

F17 termina somente quando o assistente consegue, pela sessão autenticada e sem secrets em texto público, executar e verificar as seguintes provas **sem ainda montar o preview completo**.

### Vercel

1. confirmar a conta/equipe alvo e que nenhum projeto `compras` preexistente será sobrescrito;
2. criar, se necessário para a prova, um recurso mínimo descartável e sem secrets de aplicação, somente depois de confirmar caminho de rollback;
3. escrever Vercel Authentication/Deployment Protection em modo compatível com a ADR-006;
4. ler de volta o estado efetivo de protection;
5. provar que env vars podem ser restritas a `preview` + branch dedicada, sem inserir valor operacional real nesta work unit;
6. identificar deployment target e aliases/domains relevantes;
7. provar caminho verificável de remoção/deprovisionamento.

### Neon

1. somente depois da prova Vercel, criar recurso mínimo descartável se necessário;
2. provisionar Managed Better Auth apenas se for possível aplicar imediatamente os controles exigidos;
3. escrever e ler de volta `disable_sign_up=true` em `/auth/email_and_password`;
4. escrever e ler de volta plugins/métodos laterais desabilitados conforme ADR-006/ADR-007;
5. confirmar OAuth providers ausentes/desabilitados e trusted domains estritos;
6. provar caminho de disable/delete/rollback antes de qualquer usuário ou dado de produto.

## Regras obrigatórias

- usar somente consoles, CLI ou API oficiais autenticados;
- não solicitar ao usuário que cole credenciais no chat;
- não persistir token, password, cookie, connection string ou secret em Git, PR, Issue, log ou artifact;
- não usar projetos Vercel/Neon alheios como laboratório;
- não criar deploy com secret antes de protection comprovada;
- não provisionar Neon Auth se `disable_sign_up` não puder ser escrito e lido de volta na mesma sessão controlada;
- não confundir ausência de botão de signup com enforcement provider-side;
- não usar Shareable Links, protection exceptions ou query-string bypass;
- não habilitar `COMPRAS_PERSISTENT_READ_ENABLED`;
- não criar usuário hospedado, seed, migrations hospedadas ou dado de contratação;
- manter `REAL_DATA_ALLOWED = NO`;
- não resolver Q-009/Q-010.

## Red-team mínimo

Atacar deliberadamente:

- browser autenticado que consegue clicar mas não permite verificar estado final;
- sessão que expira no meio da mudança e deixa recurso parcialmente configurado;
- criação de projeto Vercel que gera production deployment/alias inesperado;
- protection aplicada somente a Preview enquanto production surface recebe app;
- env var sem branch scope apesar de aparentar Preview-only;
- Shareable Link/protection bypass usado como falso substituto de Deployment Protection;
- secret visível em resposta/UI/log e risco de persistência acidental;
- Neon Auth criado com signup default antes do PATCH de bloqueio;
- `get_neon_auth_config` ou enable/disable de Auth usados como falso substituto para o PATCH inexistente de `email_and_password`/plugins;
- `disable_sign_up` aplicado a email/senha mas plugin lateral continua permitindo criação de conta;
- método OAuth/provider habilitado por default;
- rollback disponível apenas por instrução manual não observável;
- tentativa de reutilizar projeto já existente;
- tentativa de colar token no chat para acelerar a execução.

## Verificação obrigatória

- GitHub/contexto revalidado antes da prova;
- sessão autenticada oficial: DISPONÍVEL E OBSERVÁVEL;
- Vercel protection write + readback: PASS;
- Vercel env scope write + readback: PASS;
- classificação de deployment/aliases: INSPECIONADA;
- Vercel rollback/deprovisionamento: PROVADO;
- Neon `disable_sign_up=true` write + readback: PASS;
- métodos/plugins adicionais: DESABILITADOS E LIDOS DE VOLTA;
- trusted domains/OAuth state: INSPECIONADOS;
- rollback Neon: PROVADO;
- nenhum secret operacional publicado: PASS;
- nenhum projeto alheio alterado: PASS;
- nenhum dado real: PASS;
- qualquer recurso de prova residual deve estar vazio de dados e explicitamente justificado ou removido;
- CI GitHub: PASS se houver alteração versionada;
- exatamente uma `NEXT_ACTION` ao encerrar F17.

## Condição de bloqueio

Se a sessão autenticada ainda não estiver acessível ao assistente com **todos** os controles exigidos, não executar writes de provider. Manter o blocker e repetir **somente a ação manual única** descrita no topo; não voltar a F15 e não criar uma nova work unit de workaround.

## Fora do escopo

Não:

- provisionar o preview completo;
- anexar `DATABASE_URL`, cookie secret ou credencial runtime à Vercel;
- migrations/seed hospedados;
- usuário Auth de teste;
- smoke funcional Central/detalhe;
- dados reais;
- mutation/CRUD;
- Q-009/Q-010.

## Critério de encerramento

F17 fecha quando o control-plane autenticado estiver efetivamente acessível e as capacidades críticas forem provadas por write + readback + rollback sem revelar secrets. Até lá, **F17 permanece a única `NEXT_ACTION` canônica**.
