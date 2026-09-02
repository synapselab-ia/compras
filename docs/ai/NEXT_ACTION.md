# Next Action — Compras

## F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01 — Desbloquear o control-plane seguro do preview hospedado

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`  
**Estado:** READY / BLOCKER-RESOLUTION  
**Objetivo:** obter e provar, sem provisionar dados reais nem enfraquecer ADR-006/ADR-007, uma superfície de controle auditável que permita à próxima work unit criar o preview privado com Deployment Protection configurável, secrets com escopo restrito e Managed Better Auth com `disable_sign_up=true` e métodos adicionais desabilitados.

## Fonte da tarefa

Executar conforme `tasks/F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01/SPEC.md`, ADR-006, ADR-007 e o blocker registrado em `docs/ai/CURRENT_STATE.md`.

## Contexto

F15 parou corretamente antes de qualquer provisionamento porque as integrações atualmente disponíveis não permitem provar todos os controles críticos antes da exposição:

- Vercel: o conector atual não cria/importa projeto com alvo controlado, não altera `ssoProtection`, não cria env vars branch-specific e não oferece deprovisionamento verificável;
- Neon: o conector atual não oferece escrita dos campos necessários para provar provider-side `disable_sign_up=true` e métodos adicionais desabilitados;
- nenhum projeto/deployment/banco/Auth de Compras foi criado e nenhum secret foi anexado.

## Resultado esperado

Ao final, deve existir **capacidade de controle verificável**, e não necessariamente o preview em si.

A F16 fecha quando for possível demonstrar, por ferramenta/connector/CLI/API autorizada e observável, todos os itens abaixo:

### Vercel

- criar/importar explicitamente um projeto ligado a `synapselab-ia/compras` sem depender de deploy genérico não controlado;
- ler e alterar Deployment Protection/Vercel Authentication;
- provar Vercel Authentication antes de secrets;
- garantir uma destas fronteiras:
  - `All Deployments`/proteção equivalente sobre toda production surface que possa servir a aplicação; **ou**
  - topologia verificável em que nenhuma production surface recebe a aplicação/configuração privada e somente Preview protegido é usado;
- criar environment variables server-only limitadas a Preview e, quando suportado, à branch hospedada dedicada;
- listar deployment alvo e sua classificação real (`preview`/`production`);
- possuir caminho verificável para rollback/deprovisionamento do recurso criado.

### Neon

- criar projeto/branch dedicado somente quando a etapa Vercel acima estiver comprovada;
- provisionar Managed Better Auth;
- **definir e ler de volta** `disable_sign_up=true` para email/senha;
- **definir e ler de volta** que OAuth, magic link, OTP, reset e demais métodos não permitidos estão desabilitados;
- configurar/inspecionar trusted domains necessários sem wildcard desnecessário;
- manter suporte às operações já disponíveis de SQL, roles, migrations e usuários fictícios;
- não expor connection strings, passwords ou tokens em GitHub/chat/log/artifact.

## Caminhos aceitáveis de desbloqueio

F16 pode ser concluída por qualquer um destes caminhos, desde que o resultado seja verificável:

1. os conectores oficiais instalados ganham as ações faltantes;
2. é disponibilizada uma integração oficial adicional capaz de executar as ações faltantes;
3. uma CLI/API oficial já autenticada e segura fica acessível à sessão sem copiar token/secret para GitHub ou chat;
4. o plano/configuração do provider é ajustado, quando necessário, para tornar a proteção exigida disponível e verificável.

Não assumir que upgrade de plano é obrigatório se uma topologia Preview-only realmente puder ser provada. Também não assumir que Hobby/Free são suficientes sem prova dos controles exigidos.

## Regras obrigatórias

- revalidar ferramentas disponíveis antes de concluir que o blocker persiste;
- pesquisar integrações/plugins oficiais adicionais antes de propor workaround manual;
- não solicitar nem registrar API token, password, connection string ou cookie secret em mensagem/repositório;
- não usar browser client-side como fonte de segredo;
- não criar projeto/deployment apenas para “ver o que acontece” se a proteção não puder ser configurada antes da exposição relevante;
- não provisionar Managed Better Auth se `disable_sign_up` não puder ser definido e verificado;
- não alterar projetos Vercel/Neon alheios a Compras;
- não reutilizar os projetos já existentes da conta;
- não converter Standard Protection em sinônimo de production-domain protection;
- não usar Shareable Links, protection exceptions ou query-string bypass como solução;
- manter `REAL_DATA_ALLOWED = NO`;
- não resolver Q-009/Q-010 nem iniciar mutations.

## Red-team mínimo

Atacar deliberadamente:

- nova ferramenta que só lê proteção, mas não consegue configurá-la;
- ferramenta que configura proteção mas não permite verificar estado final;
- deploy que aparece como production apesar de solicitado como preview;
- production alias criado automaticamente e deixado público;
- env var configurada para todos os previews/PRs do repo público em vez da branch dedicada;
- secret exibido na resposta do conector/log;
- Neon Auth provisionado com signup default e tentativa de corrigir depois;
- configuração que desliga signup somente na UI e não no provider;
- OAuth/OTP/reset permanecendo ativos por default;
- reutilização de projeto alheio para evitar o blocker;
- proposta de colar token/API key no chat para liberar automação.

## Verificação obrigatória

- estado GitHub/contexto: VALID;
- estado atual das integrações Vercel/Neon: REINSPECIONADO;
- catálogo de integrações oficiais adicionais: REINSPECIONADO se ainda houver lacuna;
- capacidade de configurar **e verificar** Deployment Protection: PROVADA;
- capacidade de restringir env vars a Preview/branch: PROVADA;
- capacidade de evitar/proteger production surface: PROVADA;
- capacidade de configurar **e verificar** `disable_sign_up=true`: PROVADA;
- capacidade de desabilitar e verificar métodos Auth adicionais: PROVADA;
- caminho de rollback/deprovisionamento: PROVADO;
- nenhum secret/dado real criado ou publicado durante o desbloqueio: PASS;
- nenhuma alteração em projeto alheio: PASS;
- CI GitHub: PASS se documentação/config versionada for alterada;
- exatamente uma nova `NEXT_ACTION` ao encerrar F16.

## Condição de bloqueio

Se nenhuma superfície de controle segura estiver disponível, manter o projeto bloqueado e registrar **uma única ação manual concreta** necessária para desbloqueio. Não retornar F15 a READY por expectativa.

## Fora do escopo

Não:

- provisionar o preview completo;
- anexar secrets operacionais;
- criar usuário hospedado;
- executar migrations hospedadas;
- criar seed;
- fazer smoke funcional contra dados hospedados;
- deploy com configuração privada;
- usar dados reais;
- mutation/CRUD;
- Q-009/Q-010.

## Critério de encerramento

F16 termina quando a sessão dispõe de um control-plane verificável que consegue cumprir as pré-condições de segurança de F15 sem revelar secrets. Somente então uma nova work unit poderá retomar o provisionamento do preview privado fictício.
