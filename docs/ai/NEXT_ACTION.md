# Next Action — Compras

## F03-CONTRATACAO-DETAIL-PROTOTYPE-01 — Prototipar detalhe navegável da contratação demo

**Classe:** `T1 — feature/protótipo`  
**Estado:** READY  
**Objetivo:** complementar a Central do Setor com a primeira jornada `lista → detalhe`, permitindo avaliar quanto contexto operacional deve aparecer ao abrir uma contratação sem sobrecarregar a tabela e sem introduzir persistência ou regras definitivas.

## Fonte da tarefa

Executar conforme `tasks/F03-CONTRATACAO-DETAIL-PROTOTYPE-01/SPEC.md`.

## Resultado esperado

Ao final, registros `DEMO-*` da Central devem poder abrir um detalhe demonstrativo que preserve o contexto principal e exponha, com dados exclusivamente fictícios:

- identificação e objeto;
- responsável, etapa, status, aguardando, próxima ação e última movimentação;
- identificadores relacionados demonstrativos;
- itens demonstrativos;
- atividade/timeline demonstrativa recente;
- navegação clara de volta para a Central.

## Regras obrigatórias

- continuar sem banco, Auth, RLS ou integração externa;
- nenhum dado real, derivado de processo real ou com aparência operacional interna;
- não resolver Q-001, Q-002 ou Q-003 por inferência;
- tipos/labels de identificadores relacionados, itens e eventos usados no protótipo devem ser explicitamente demonstrativos/provisórios;
- não adicionar edição, criação, exclusão ou botões que impliquem persistência;
- reutilizar a fonte de dados demo de forma coerente, evitando duplicação sem necessidade;
- lidar explicitamente com identificador demo inexistente;
- manter acessibilidade básica e estratégia responsiva;
- adicionar testes para a lógica de lookup/seleção que não precise ficar em JSX;
- executar lint, typecheck, testes e build antes de promoção.

## Fora do escopo

Não:

- schema definitivo;
- banco/migrations;
- login/permissões;
- timeline persistente;
- semântica final de tipos de processo relacionado;
- edição/cadastro;
- importação de planilhas;
- documentos;
- pesquisa de preços;
- PNCP/Compras.gov;
- alertas definitivos;
- deploy de produção.

## Critério de encerramento

A tarefa termina quando a jornada demonstrativa `Central → detalhe → Central` estiver implementada e verificável, todo conteúdo permanecer fictício, os gates de engenharia passarem, o diff for red-teamado e o checkpoint canônico apontar exatamente uma nova `NEXT_ACTION`.
