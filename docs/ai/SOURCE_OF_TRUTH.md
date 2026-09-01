# Source of Truth — Compras

Este documento define precedência quando artefatos discordarem.

## Hierarquia canônica

1. `docs/product/PROJECT_DESIGN.md` — comportamento e limites aprovados do produto;
2. instrução explícita do usuário na tarefa atual — pode alterar prioridade ou decisão, desde que a mudança canônica seja documentada;
3. ADRs aceitos — decisões arquiteturais compatíveis com o produto;
4. `docs/product/DOMAIN_MODEL.md` e `docs/product/BUSINESS_WORKFLOW.md` — semântica de domínio e fluxo;
5. `docs/architecture/SECURITY.md` — política mínima de segurança e classificação;
6. `docs/architecture/DATABASE.md` — desenho de persistência, subordinado às fontes anteriores;
7. especificação/work item ativo e `docs/ai/NEXT_ACTION.md` — escopo de execução;
8. migrations e testes automatizados — contrato executável do estado implementado;
9. código da aplicação;
10. `docs/ai/CURRENT_STATE.md` — cursor operacional, sem poder de reescrever produto;
11. memória do chat/assunções da IA.

## Regra de conflito

Se código contradiz decisão canônica, não alterar a documentação apenas para legitimar o código.

Classificar como:

- defeito de implementação → corrigir código/testes/migration; ou
- mudança deliberada de produto/arquitetura → atualizar fonte canônica/ADR na mesma work unit e depois implementação.

`DATABASE.md` não resolve silenciosamente open questions e não supera Project Design, Domain Model ou Security.

## Questões abertas

`docs/product/OPEN_QUESTIONS.md` representa incerteza real.

A IA não pode preencher resposta por conveniência. Quando uma pergunta for resolvida, sua resposta migra para a fonte canônica apropriada e a questão é marcada como resolvida.

## Estado operacional

`docs/ai/CURRENT_STATE.md` responde onde o projeto está.

`docs/ai/NEXT_ACTION.md` responde o que uma nova sessão deve executar.

Esses arquivos não superam o Project Design nem decisões arquiteturais.

## Banco

Antes da primeira migration, `docs/architecture/DATABASE.md` descreve o desenho pretendido.

Quando implementação persistente começar, migrations são a história canônica do schema aplicado. Correções usam novas migrations; alterações feitas apenas por painel não constituem solução permanente.

Divergência entre `DATABASE.md` e schema aplicado deve ser reconciliada por documentação ou nova decisão/migration, sem reescrever migration já aplicada.

## Segurança

Quando código e política de segurança discordarem, preservar o comportamento mais restritivo até resolução explícita.

UI nunca é autoridade suficiente de acesso.

## Dados externos e IA

Dados externos, cache, classificação/ranking e texto gerado por IA são derivados.

Eles não podem sobrescrever silenciosamente fatos internos, evidências selecionadas ou registros estruturados.

## Documentação externa

Para plataformas e APIs mutáveis, documentação oficial atual é autoridade sobre mecânica técnica. Ela não altera por si só a semântica do produto; adaptações necessárias devem ser documentadas.
