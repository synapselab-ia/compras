# F17-AUTHENTICATED-PROVIDER-CONTROL-SESSION-01 — Estabelecer sessão autenticada de control-plane para Vercel e Neon

**Classe:** T3 — integração externa, com impacto de T2 — segurança  
**Estado:** MANUAL_ACTION_REQUIRED após F16  
**Dependências:** F13, F14, F15, F16, ADR-006, ADR-007  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

F16 confirmou que os providers possuem os controles técnicos necessários, mas a sessão atual não possui um executor autenticado capaz de escrever e ler de volta esses controles sem transferir credenciais.

No Vercel, as APIs/CLI oficiais suportam criação de projeto, Vercel Authentication/`ssoProtection`, env vars com target Preview e `gitBranch` e gerenciamento de recursos. O conector instalado, porém, não expõe essas escritas/readbacks.

No Neon, a API oficial possui endpoints específicos para `email_and_password`, plugins, domains e OAuth; a CLI `neon api` pode operar qualquer rota autenticada. O conector instalado não expõe os PATCH necessários e o runtime não possui CLI autenticada.

F17 deve tornar a sessão de controle observável e então provar as capacidades críticas. Não deve pedir credenciais pelo chat nem avançar para o preview completo.

## 2. Ação manual única necessária

Estabelecer uma sessão de controle autenticada nos consoles oficiais **Vercel e Neon**, acessível ao assistente sem que tokens, passwords, cookies, API keys ou connection strings sejam copiados para o chat.

O caminho preferencial, se disponível, é executar esta frente em **ChatGPT Work/Cloud Browser** e autenticar o navegador nos dois consoles oficiais. O navegador autenticado é o canal; as credenciais continuam fora da conversa.

Uma configuração manual que o assistente não consiga observar/read-back não fecha a tarefa.

## 3. Objetivo

Provar que a sessão autenticada consegue aplicar, verificar e desfazer os controles pré-requisito de F15, sem ainda provisionar o ambiente final.

## 4. Prova Vercel

A sessão deve conseguir:

1. identificar a equipe alvo correta sem alterar projetos alheios;
2. criar somente recurso de prova mínimo e descartável, se necessário, sem secrets de aplicação;
3. configurar Vercel Authentication/Deployment Protection antes de qualquer secret;
4. ler de volta o estado final de protection;
5. detectar automaticamente qualquer deployment/alias classificado como production;
6. provar env var `target=preview` + branch dedicada por configuração/readback sem usar valor operacional real;
7. provar remoção/rollback do recurso de prova.

Se a criação do projeto gerar production surface inesperada, não anexar secret e corrigir/remover antes de continuar.

## 5. Prova Neon

Somente depois da prova Vercel, a sessão deve conseguir:

1. criar recurso de prova Neon vazio e descartável, se necessário;
2. provisionar Managed Better Auth somente quando o mesmo canal puder aplicar imediatamente os controles de admissão;
3. PATCH + GET de `/auth/email_and_password` comprovando `disable_sign_up=true`;
4. PATCH + GET de `/auth/plugins` e endpoints específicos necessários para garantir que métodos laterais proibidos não criem conta;
5. confirmar ausência/desativação de OAuth providers;
6. confirmar trusted domains sem wildcard desnecessário;
7. provar disable/delete/rollback antes de qualquer usuário de teste ou dado de produto.

## 6. Dados e secrets

Não criar nem usar nesta work unit:

- `DATABASE_URL` operacional;
- cookie secret da aplicação;
- usuário de Auth hospedado;
- `app_user`/membership;
- seed/migrations hospedadas;
- dado de contratação;
- dado real, interno ou pré-publicação.

Se a UI/API mostrar secret de uso único, não copiar para chat, PR, log, screenshot público ou artifact. F17 não precisa dele para fechar a prova de control-plane.

## 7. Red-team obrigatório

### Sessão parcialmente observável

Se o browser permite clicar mas o estado final não pode ser read-back por UI/API, a capacidade não está provada.

### Sessão expirada

Interrupção de autenticação entre write e readback deve deixar a tarefa bloqueada até o estado real ser reinspecionado.

### Production surface Vercel

Projeto/preview que cria production deployment ou alias deve ser detectado. Nenhum secret pode ser anexado antes de remover/proteger essa superfície conforme ADR-006.

### Escopo de env

Variável Preview sem branch scope não satisfaz a prova quando branch-specific está disponível. Valor utilizado deve ser inerte/fictício.

### Neon signup race

Não criar Auth e deixar signup default exposto enquanto se procura o controle. O canal autenticado deve estar pronto para aplicar e verificar a configuração imediatamente e antes de qualquer trusted domain público/uso.

### Métodos laterais

`disable_sign_up=true` em email/senha não basta se magic link, OTP, OAuth ou outro plugin mantiver autocriação.

### Secrets

Nenhuma aceleração por copiar token/API key para conversa. Se o canal autenticado exigir isso, a solução é inválida.

### Projeto alheio

Read-only para descobrir capacidade pode ser tolerado quando indispensável, mas nenhum write em projeto alheio é permitido.

## 8. Verificação

Obrigatório:

- GitHub `main`, PRs/branches e context manifest: VALID;
- sessão oficial autenticada nos providers: DISPONÍVEL;
- Vercel protection write + readback: PASS;
- Vercel env scope write + readback: PASS;
- deployment target/aliases: INSPECIONADOS;
- Vercel rollback/deprovisionamento: PASS;
- Neon `disable_sign_up=true` write + readback: PASS;
- Neon plugins/métodos laterais: DESABILITADOS + READBACK;
- Neon OAuth/trusted domains: INSPECIONADOS;
- Neon rollback/deprovisionamento: PASS;
- nenhum dado real: PASS;
- nenhum secret publicado: PASS;
- nenhum projeto alheio alterado: PASS;
- qualquer recurso de prova residual vazio deve ser explicitamente justificado; preferir remoção quando possível;
- CI GitHub: PASS se houver alteração versionada.

## 9. Encerramento

### Sucesso

F17 fecha quando o canal autenticado e os controles necessários estiverem provados. A próxima `NEXT_ACTION` deve ser uma nova work unit de provisionamento do preview privado fictício, retomando F15 como slice nova e não reabrindo a work unit antiga.

### Blocker persistente

Se a sessão autenticada não estiver disponível ao assistente, não executar write de provider. Manter exatamente a mesma ação manual única até que ela seja satisfeita; não criar novas work units de workaround.

## 10. Fora do escopo

Não:

- preview completo;
- secrets da aplicação em Vercel;
- migrations/seed hospedados;
- usuário Auth de teste;
- smoke Central/detalhe;
- dados reais;
- mutations/CRUD;
- Q-009/Q-010.
