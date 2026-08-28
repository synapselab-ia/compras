# Business Workflow — Compras

**Versão:** 0.1  
**Status:** draft público sanitizado  
**Objetivo:** representar o fluxo operacional em nível suficiente para orientar o produto sem publicar detalhes internos sensíveis.

## 1. Entrada e triagem

Uma demanda chega à equipe e precisa ser identificada, vinculada ao setor requisitante e conferida quanto às informações mínimas necessárias.

Possíveis resultados:

- seguir para tratamento;
- devolver para correção/complementação;
- aguardar informação externa;
- arquivar/cancelar com justificativa.

## 2. Registro e autorização

A contratação passa a possuir identificadores administrativos relacionados e, quando aplicável, aguarda autorização ou condição formal necessária para avançar.

O sistema operacional não substitui o sistema oficial: ele registra referência, estado e próxima ação.

## 3. Pesquisa de preços

A equipe busca referências compatíveis com os itens e registra proveniência, validade, compatibilidade e motivo de eventual descarte.

O módulo futuro deve:

- acompanhar o progresso por item;
- aplicar regras de validação configuradas e documentadas;
- consumir fontes públicas oficiais quando útil;
- manter evidência selecionada de forma auditável;
- não tratar um resultado encontrado como automaticamente válido.

## 4. Estudo técnico e definição da solução

Com informações suficientes, são consolidados os elementos técnicos necessários à contratação.

O produto inicialmente apenas acompanha a etapa e seus estados. Geração/validação documental é evolução posterior.

## 5. Requisição e informações financeiras

A contratação pode depender de registros em sistemas oficiais e/ou informações financeiras antes de seguir.

O sistema deve permitir representar dependência, data de envio/retorno e próxima ação sem fingir ser o sistema financeiro oficial.

## 6. Termo de referência e documentos correlatos

A equipe prepara, revisa ou acompanha documentos exigidos para o encaminhamento da contratação.

O workflow deve permitir ciclos de revisão, devolução, assinatura/aprovação e atualização de fontes sem perder histórico.

## 7. Encaminhamento para área responsável pelo procedimento

Após a preparação interna, a contratação pode ser encaminhada para outra área/unidade responsável pela continuidade do procedimento.

A partir desse momento, `responsável_interno` pode continuar existindo enquanto `aguardando` aponta para a área externa ao núcleo operacional.

## 8. Procedimento de contratação

O produto pode acompanhar estados posteriores relevantes — análise, ajustes, publicação, disputa, homologação ou equivalentes — sem tentar reproduzir integralmente o sistema oficial correspondente.

A taxonomia exata deve ser refinada somente com evidência operacional.

## 9. Finalização

Quando o ciclo operacional pertinente termina, a contratação pode ser marcada como concluída/arquivada, preservando:

- identificadores;
- itens;
- responsáveis históricos;
- timeline;
- evidências selecionadas;
- resultados/metadados que fizerem parte do escopo futuro.

## 10. Fluxos de exceção permanentes

O modelo deve aceitar, sem precisar prever toda exceção antecipadamente:

- devolução para etapa anterior;
- mudança de responsável;
- espera por terceiro;
- correção de item/quantidade;
- suspensão;
- cancelamento;
- arquivamento;
- reabertura;
- múltiplos processos/identificadores relacionados.

O uso real do sistema deve revelar exceções adicionais. Elas serão incorporadas como regras somente quando houver evidência, evitando complexidade hipotética.

## 11. Regra operacional central

Em qualquer ponto do fluxo, uma pessoa autorizada deve conseguir responder:

1. qual é a contratação;
2. quem é o responsável interno;
3. em que etapa ela está;
4. qual é o status;
5. com quem/onde a ação está pendente;
6. desde quando;
7. qual é a próxima ação;
8. qual foi a última movimentação relevante.
