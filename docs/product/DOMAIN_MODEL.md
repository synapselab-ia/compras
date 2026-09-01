# Domain Model — Compras

**Versão:** 0.1  
**Status:** draft sanitizado

Este documento descreve o modelo conceitual inicial. Ele não define ainda o schema físico definitivo.

## 1. Contratação

Entidade central do produto.

Responsabilidades conceituais:

- representar uma necessidade de contratação ao longo de seu ciclo operacional;
- agregar processos/identificadores relacionados;
- possuir itens;
- possuir responsável interno;
- possuir etapa, status, pendência atual e próxima ação;
- possuir timeline;
- relacionar pesquisa de preços e documentos quando esses módulos existirem.

Uma contratação não deve ser reduzida a um único número de processo.

## 2. Processo relacionado

Representa identificadores administrativos ou registros externos vinculados à mesma contratação.

Campos conceituais iniciais:

- tipo;
- número/identificador;
- sistema/origem;
- data de vínculo;
- observação opcional;
- estado ativo/inativo quando aplicável.

O modelo deve aceitar cardinalidade maior que 1.

## 3. Item da contratação

Representa uma linha material ou de serviço que precisa ser acompanhada dentro da contratação.

Campos conceituais:

- número/ordem;
- descrição;
- quantidade;
- unidade;
- código de catálogo quando existir;
- estado da pesquisa de preços;
- metadados técnicos necessários ao acompanhamento.

Mudanças relevantes em quantidade ou descrição devem ser rastreáveis quando puderem invalidar trabalho dependente.

## 4. Usuário e membership

`Usuário` representa identidade autenticada.

`Membership` representa autorização para participar da equipe/escopo do sistema.

V0.1 pode possuir um único membro autorizado, mas o modelo não deve acoplar dados ao pressuposto de usuário único.

## 5. Responsabilidade operacional

Uma contratação deve distinguir:

- `responsável_interno`: pessoa que responde pelo acompanhamento dentro da equipe;
- `aguardando_tipo`: natureza de quem/onde está a próxima dependência;
- `aguardando_referencia`: referência legível, quando necessária;
- `aguardando_desde`;
- `motivo_aguardo`;
- `proxima_acao`.

Responsável e aguardando quem são conceitos diferentes.

## 6. Etapa

Representa onde a contratação está no fluxo macro.

Etapa não deve ser usada para representar todos os estados possíveis.

Taxonomia inicial proposta, ainda sujeita a validação:

- recebimento/triagem;
- análise inicial;
- autorização;
- pesquisa de preços;
- estudo técnico;
- requisição/financeiro;
- termo de referência/documentos;
- encaminhamento à área de compras;
- procedimento de contratação;
- resultado/finalização;
- arquivado.

A taxonomia final depende de validação operacional e não deve ser inferida além do documentado.

## 7. Status

Representa a condição corrente dentro de uma etapa.

Exemplos conceituais:

- não iniciado;
- em andamento;
- aguardando terceiro;
- aguardando unidade requisitante;
- aguardando assinatura/aprovação;
- em análise externa;
- pendente;
- suspenso;
- cancelado;
- concluído.

Etapa e status são campos distintos.

## 8. Evento / Timeline

Eventos registram fatos relevantes e preservam rastreabilidade.

Tipos esperados:

- criação;
- alteração de responsável;
- alteração de etapa;
- alteração de status;
- alteração de pendência/próxima ação;
- vínculo/desvínculo de processo;
- mudança relevante de item;
- criação/resolução de pendência;
- inclusão/seleção/descarte de evidência de preço;
- arquivamento/reabertura;
- nota manual.

Eventos automáticos devem capturar mudanças estruturadas. Observação livre complementa, não substitui, os campos operacionais.

## 9. Pendência

Objeto opcional para representar trabalho ou bloqueio que mereça acompanhamento próprio.

Campos conceituais:

- título;
- descrição;
- estado;
- prioridade;
- responsável;
- criada_em;
- resolvida_em;
- referência à contratação e, opcionalmente, ao item.

Não transformar cada microação em pendência por padrão.

## 10. Pesquisa de preços

Módulo posterior, relacionado a uma contratação e seus itens.

Deve separar:

- resultado externo consultado;
- referência escolhida;
- referência descartada e motivo;
- cálculo/validação aplicada;
- estado consolidado da pesquisa do item.

## 11. Evidência de preço selecionada

Uma referência selecionada para fundamentação deve ser persistida como snapshot auditável, e não apenas como ponteiro para conteúdo externo mutável.

Campos conceituais mínimos:

- item interno;
- fonte pública/mercado permitida;
- identificadores upstream;
- data da consulta;
- órgão/fornecedor quando aplicável;
- descrição observada;
- quantidade/unidade;
- preço unitário;
- marca/modelo quando disponível e relevante;
- URL/origem;
- selecionado_por;
- selecionado_em;
- snapshot/hash conforme estratégia técnica.

Alteração posterior na fonte externa não deve reescrever silenciosamente a evidência histórica já selecionada.

## 12. Documento e source manifest — futuro

Quando documentos entrarem no produto, a aplicação deve distinguir versão ativa, origem e dependências entre artefatos.

A alteração de uma fonte canônica relevante pode marcar documentos derivados como potencialmente desatualizados, em vez de editar silenciosamente seu conteúdo.

## 13. Invariantes iniciais

- toda contratação possui identidade interna estável;
- responsáveis são referências a membros/autorizados, não texto solto como única fonte;
- alteração relevante deixa rastro;
- arquivamento/cancelamento não apaga histórico;
- dados externos não sobrescrevem fatos internos automaticamente;
- evidência de preço selecionada preserva proveniência;
- autorização é aplicada fora da UI;
- nenhuma regra futura é considerada aprovada apenas por aparecer como exemplo neste draft.
