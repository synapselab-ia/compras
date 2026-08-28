# AI Work Protocol — Compras

**Status:** protocolo operacional canônico

## 1. Comando de continuação

Uma nova sessão deve poder começar com:

> Continue o projeto `synapselab-ia/compras` pelo protocolo canônico e execute a `NEXT_ACTION`.

O agente deve recuperar o estado pelo repositório. Não pedir ao usuário para repetir decisões que já estejam documentadas.

## 2. Ciclo FLOW-IA

Toda sessão substantiva segue:

`RECOVER → CLASSIFY → INSPECT → BOUND → IMPLEMENT → RED TEAM → VERIFY → PROMOTE → CHECKPOINT → REPORT`

### RECOVER

- ler startup mínimo;
- conferir Git/branch/commit/PR/Issue reais;
- validar `CONTEXT_MANIFEST`;
- não confiar no chat como estado canônico.

### CLASSIFY

Classificar a tarefa:

- `T0` descoberta/produto;
- `T1` feature normal;
- `T2` banco/segurança;
- `T3` integração externa;
- `T4` bug;
- `T5` arquitetura/refatoração;
- `T6` consulta/status somente leitura.

A classe determina leitura e gates adicionais.

### INSPECT

Antes de editar:

- procurar funcionalidade já existente;
- ler código, migrations, testes e dependências relevantes;
- ler ADR/spec do módulo;
- verificar documentação oficial atual para tecnologia externa mutável.

Não recriar comportamento existente.

### BOUND

Confirmar:

- problema;
- resultado esperado;
- critérios de aceite;
- fora do escopo;
- invariantes;
- impacto de segurança/dados.

Se não houver evidência suficiente para uma decisão de negócio, registrar `OPEN QUESTION` ou `DECISÃO NECESSÁRIA`.

### IMPLEMENT

Executar somente a work unit ativa.

Não adicionar feature futura, refatoração ampla ou infraestrutura não necessária.

### RED TEAM

Antes de declarar pronto, procurar deliberadamente:

- quebra de regra de negócio;
- vazamento de dados;
- autorização somente visual;
- race/concurrency quando relevante;
- duplicação/idempotência;
- perda de histórico;
- regressão;
- scope creep;
- comportamento inventado;
- erro em estados de loading/error/empty;
- acoplamento prematuro.

Corrigir ou registrar bloqueio real.

### VERIFY

Executar gates proporcionais ao escopo.

Nunca declarar comando executado quando não foi.

### PROMOTE

Somente estado validado pode ser promovido como concluído/last-good.

Work in progress pode existir sem ser rotulado como completo.

### CHECKPOINT

Atualizar o cursor operacional e deixar exatamente uma `NEXT_ACTION`.

### REPORT

Responder ao usuário somente com o que importa:

- o que terminou;
- decisões relevantes;
- verificações executadas;
- commit/PR quando aplicável;
- próxima ação;
- decisão/manual action realmente necessária.

## 3. Fast context

`CONTEXT_MANIFEST.md` compila regras estáveis e registra hashes/blobs das fontes usadas.

Se todos os inputs do manifest continuarem iguais, não reler todos os documentos por rotina.

Se um input mudou:

- abrir o input divergente;
- reconciliar;
- atualizar o manifest;
- então continuar.

Incerteza sempre expande leitura. Performance não autoriza adivinhação.

`CURRENT_STATE`, `NEXT_ACTION` e o work item ativo são lidos ao vivo e não devem ser tratados como cache estável.

## 4. Uma tarefa ativa

Executar exatamente uma `NEXT_ACTION` por sessão, salvo:

- override explícito do usuário;
- bloqueio que exija correção mínima de pré-requisito;
- tarefa pequena cuja própria especificação define subpassos inseparáveis.

Se ficar grande demais, dividir antes de continuar.

## 5. Work items

Work item relevante deve possuir especificação suficiente para ser executável.

Formato preferido:

```text
ID e título
problema
resultado esperado
comportamento
critérios de aceite
fora do escopo
invariantes
impacto em dados
impacto em segurança
verificação obrigatória
```

Não criar três documentos quando um `SPEC.md` pequeno for suficiente.

## 6. ON HOLD

Uma frente entra `ON HOLD` quando depende de condição externa objetiva.

Registrar `resume_when`.

Enquanto ON HOLD:

- não fabricar dados/evidência para desbloquear;
- não revalidar por inércia;
- não manter como frente ativa;
- promover a próxima work unit independente.

## 7. Segurança do repositório público

Enquanto `REPO_VISIBILITY = PUBLIC`, toda tarefa começa com um gate adicional:

> O diff contém qualquer informação interna real ou sensível?

Se sim, não persistir. Sanitizar ou bloquear até o repositório/fluxo adequado existir.

## 8. Banco e segurança

Tarefas `T2` exigem leitura direta de `SECURITY`, `DATABASE` quando existir, migrations e testes relacionados.

Testar enforcement real, incluindo acessos adversariais.

Nunca usar role privilegiada/BYPASSRLS como evidência de acesso normal do usuário.

## 9. Integrações externas

Tarefas `T3` exigem documentação oficial atual.

Registrar mudanças materiais de API, termos, privacidade, retenção ou custo que afetem arquitetura.

Persistir somente dados externos necessários e permitidos.

## 10. Decisões

Escalonar ao usuário apenas decisão semanticamente relevante que não possa ser derivada com segurança das fontes.

Para `DECISÃO NECESSÁRIA`:

- explicar a questão;
- recomendar opção;
- resumir trade-offs materiais;
- marcar tarefa como bloqueada quando realmente impedir continuação.

Preferências técnicas pequenas usam default simples e seguro.

## 11. Usuário não é operador da IA

Não pedir ao usuário para:

- rodar comando que a sessão consegue rodar;
- copiar arquivos que a ferramenta consegue ler;
- escrever migration/código manualmente;
- repetir contexto existente;
- gerenciar checkpoints da IA.

Pedir somente ação externa genuinamente impossível pela sessão ou decisão de produto real.

## 12. Persistência e Git

Preferir uma alteração lógica coerente por commit/PR.

Antes de integrar:

- conferir head atual;
- revisar diff completo;
- evitar sobrescrever trabalho concorrente;
- não force-push sobre estado canônico válido para esconder conflito.

## 13. Fechamento

Uma sessão substantiva termina somente após:

- verificação aplicável;
- persistência do estado correto;
- checkpoint atualizado;
- uma única próxima ação;
- limitações honestamente registradas.
