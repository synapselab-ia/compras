# Next Action — Compras

## F02-CENTRAL-PROTOTYPE-01 — Prototipar Central do Setor com dados fictícios

**Classe:** `T1 — feature/protótipo`  
**Estado:** READY  
**Objetivo:** transformar o shell neutro em um primeiro protótipo utilizável da visão compartilhada do setor, suficiente para validar organização da informação e reduzir incerteza de produto antes de banco, autenticação e regras definitivas.

## Fonte da tarefa

Executar conforme `tasks/F02-CENTRAL-PROTOTYPE-01/SPEC.md`.

## Resultado esperado

Ao final, a aplicação deve permitir avaliar a experiência principal do produto usando somente dados obviamente fictícios e memória local/estática:

- visualizar em uma única tela o trabalho de todo o setor fictício;
- localizar rapidamente uma contratação por busca;
- identificar responsável, etapa, status, aguardando, próxima ação e última movimentação;
- aplicar filtros operacionais simples;
- preservar uma apresentação densa no desktop e deliberada em telas menores;
- deixar claro na própria interface que se trata de protótipo sem dados reais e sem persistência.

## Regras obrigatórias

- não resolver silenciosamente as taxonomias abertas de etapas/status; valores usados no protótipo são provisórios;
- não definir ainda limites automáticos de processo parado;
- não criar banco, autenticação, RLS ou integração externa;
- não incluir números, objetos, nomes, setores, empresas ou qualquer dado derivado de processo real;
- usar identificadores e pessoas genéricas como `DEMO-001` e `Pessoa A`;
- lógica de busca/filtro deve ser testável fora de componentes React quando fizer sentido;
- manter o repositório público seguro em todas as superfícies;
- executar lint, typecheck, testes e build antes de promoção.

## Fora do escopo

Não:

- cadastro/edição persistente de contratação;
- banco ou migrations;
- login/permissões;
- importação de planilhas;
- documentos reais;
- PNCP/Compras.gov;
- pesquisa de preços;
- regra de ±25%;
- alertas definitivos de inatividade;
- fechar Q-001, Q-002, Q-004 ou Q-005 por inferência;
- deploy de produção.

## Critério de encerramento

A tarefa termina quando o protótipo da Central do Setor estiver implementado com dados estritamente fictícios, sua lógica relevante estiver testada, os gates de engenharia passarem, o diff tiver sido red-teamado e o checkpoint canônico apontar exatamente uma nova `NEXT_ACTION`.
