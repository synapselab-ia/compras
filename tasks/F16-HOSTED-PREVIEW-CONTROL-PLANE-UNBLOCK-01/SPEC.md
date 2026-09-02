# F16-HOSTED-PREVIEW-CONTROL-PLANE-UNBLOCK-01 — Desbloquear o control-plane seguro do preview hospedado

**Classe:** T3 — integração externa, com impacto de T2 — segurança  
**Estado:** READY após blocker seguro de F15  
**Dependências:** F13, F14, ADR-006, ADR-007  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

F15 foi interrompida corretamente antes de qualquer provisionamento porque as integrações atuais não conseguem provar todos os controles exigidos antes da exposição.

No Vercel, o conector disponível permite inspeção e deploy genérico, mas não expõe criação/importação explícita de projeto, escrita de Deployment Protection/`ssoProtection`, environment variables restritas a Preview/branch ou deprovisionamento verificável.

No Neon, o conector possui criação de projeto, SQL, roles e Managed Better Auth, mas a ação de atualização da configuração Auth não expõe os campos necessários para definir e provar `disable_sign_up=true` e a desativação dos métodos adicionais proibidos.

F16 deve desbloquear o control-plane. Ela não deve contornar o problema criando recursos primeiro e configurando segurança depois.

## 2. Resultado esperado

Ao final, deve existir uma superfície de controle autorizada, observável e segura que permita retomar o preview hospedado fictício sem relaxar nenhum requisito de F15.

A capacidade deve ser provada para Vercel e Neon antes de nova work unit de provisionamento.

## 3. Vercel — capacidades mínimas

Deve ser possível, por ferramenta oficial autorizada:

1. criar/importar explicitamente projeto ligado a `synapselab-ia/compras`;
2. escolher/confirmar que o alvo usado é Preview e detectar se o provider classificou diferente;
3. ler e alterar Vercel Authentication/Deployment Protection;
4. provar proteção antes de qualquer secret de aplicação;
5. garantir uma das fronteiras:
   - `All Deployments`/equivalente para toda production surface que possa servir a aplicação; ou
   - Preview-only verificável, sem production surface recebendo aplicação/configuração privada;
6. criar env vars server-only com escopo de Preview e branch dedicada quando suportado;
7. listar/inspecionar deployments e aliases relevantes;
8. remover/deprovisionar os recursos temporários por caminho verificável.

Standard Protection não pode ser confundido com proteção de production domain.

## 4. Neon — capacidades mínimas

Deve ser possível, por ferramenta oficial autorizada:

1. criar projeto/branch dedicado quando a fronteira Vercel já estiver comprovada;
2. provisionar Managed Better Auth;
3. configurar e ler de volta `disable_sign_up=true` para email/senha;
4. desabilitar e ler de volta OAuth, magic link, OTP, reset e demais métodos fora de escopo;
5. configurar trusted domains estritamente necessários;
6. preservar operações de SQL, roles, migrations, usuários fictícios e inspeção de privilégios;
7. não expor passwords, connection strings ou tokens na saída pública.

A aplicação F14 continua sendo defesa adicional; não substitui o bloqueio provider-side.

## 5. Caminhos aceitáveis

É aceitável concluir F16 se uma destas soluções for disponibilizada e testada:

- expansão das ações dos conectores oficiais instalados;
- instalação de integração oficial adicional que ofereça as ações faltantes;
- CLI/API oficial já autenticada e acessível à sessão sem copiar token/secret para chat/Git;
- ajuste de plano/configuração do provider quando isso for necessário para obter a capacidade de proteção exigida.

Não assumir upgrade como única solução se houver uma topologia Preview-only realmente verificável. Não assumir plano atual suficiente sem prova.

## 6. Estado de conta observado no início

O preflight F15 encontrou, sem alterar recursos:

- Vercel: equipe em plano Hobby, sem projeto `compras`;
- Neon: organização em plano Free, sem projeto `compras`;
- projetos já existentes nos providers são alheios e não podem ser reutilizados.

IDs, URLs privadas e detalhes de projetos alheios não devem ser persistidos no repositório público.

## 7. Segurança

Proibido:

- pedir que o usuário cole API key/token/password/connection string no chat;
- registrar credencial em Issue/PR/Action/artifact;
- criar projeto apenas para testar defaults se a proteção não puder ser configurada antes da exposição relevante;
- habilitar Auth com signup default e “corrigir depois”;
- usar Shareable Links, bypass por query string ou Deployment Protection Exception como solução;
- usar projeto alheio para acelerar a prova;
- adicionar secret client-public;
- alterar `REAL_DATA_ALLOWED = NO`.

## 8. Red-team obrigatório

Testar deliberadamente:

### Controle incompleto

Ferramenta que lê, mas não escreve, ou escreve sem permitir verificação final não fecha o blocker.

### Classificação de deployment

Pedido de Preview que resulta em Production deve ser detectado e interromper o fluxo antes de secret.

### Production alias

Alias/domain de produção automático deve ser identificado. Se não puder ser protegido ou excluído da configuração privada, bloquear.

### Escopo de env

Env var não pode vazar para production ou para todos os PRs do repositório público quando a branch dedicada puder ser usada.

### Neon signup

Não basta confirmar ausência de botão. `disable_sign_up=true` precisa estar no provider e ser lido de volta.

### Métodos laterais

OAuth/OTP/magic link/reset não podem permanecer ativos por default.

### Exposição de segredo

Se uma ferramenta retorna segredo integral, não persistir/repetir esse valor e reavaliar se ela pode ser usada com segurança.

### Workaround manual opaco

Configuração manual não observável pela sessão não deve ser marcada como provada.

## 9. Verificação

Obrigatório:

- GitHub `main`, PRs e contexto: recuperados/VALID;
- providers e planos: reinspecionados;
- catálogo de plugins/integradores oficiais: reinspecionado quando necessário;
- Vercel protection write + readback: PROVADOS;
- Vercel env scope write + readback: PROVADOS;
- Vercel deployment classification/aliases: INSPECIONÁVEIS;
- Vercel rollback/deprovisionamento: DISPONÍVEL E VERIFICÁVEL;
- Neon `disable_sign_up` write + readback: PROVADOS;
- Neon métodos adicionais write + readback: PROVADOS;
- nenhuma credencial publicada: PASS;
- nenhum projeto alheio modificado: PASS;
- CI: PASS para qualquer alteração versionada.

## 10. Condição de encerramento

### Sucesso

F16 é concluída quando todas as capacidades acima estão disponíveis e verificadas. A nova `NEXT_ACTION` deve então ser uma work unit pequena de retomada do preview hospedado fictício.

### Persistência do blocker

Se as capacidades continuarem indisponíveis, F16 deve registrar exatamente uma ação manual concreta necessária para desbloqueio e permanecer fail-closed. Não reabrir F15 por expectativa.

## 11. Fora do escopo

Não:

- criar preview completo;
- anexar secrets reais;
- criar usuário hospedado;
- migrations/seed hospedados;
- smoke funcional de contratação;
- dados reais;
- mutations/CRUD;
- Q-009/Q-010.
