# Project Design — Compras

**Versão:** 0.1  
**Status:** draft da Foundation-00  
**Classificação:** documentação pública sanitizada

## 1. Problema

Equipes de compras públicas frequentemente acompanham processos em planilhas, pastas, sistemas oficiais e controles paralelos. Isso fragmenta a informação operacional, aumenta tempo de procura, dificulta saber quem está com cada processo e favorece retrabalho.

O produto deve reduzir esse custo operacional sem criar um novo sistema oficial de processo administrativo.

## 2. Proposta

Criar uma central operacional que permita responder rapidamente:

- quais contratações estão ativas;
- quem é responsável por cada uma;
- em qual etapa estão;
- qual é o status atual;
- com quem a ação está pendente;
- qual é a próxima ação;
- quando ocorreu a última movimentação;
- quais itens e evidências de pesquisa estão associados;
- quais processos/documentos se relacionam à mesma contratação.

## 3. Usuários

### V0.1

Um usuário piloto autenticado.

### Evolução

Arquitetura preparada para múltiplos membros autorizados da mesma equipe, com visão compartilhada do trabalho e permissões progressivamente refinadas.

Não existe cadastro público de usuários como requisito do produto.

## 4. Entidade central

A entidade principal é `Contratação`, não uma tarefa isolada nem um único número de processo.

Uma contratação pode relacionar múltiplos identificadores/processos administrativos, itens, documentos, eventos, responsáveis e evidências de pesquisa ao longo do tempo.

## 5. Experiência principal

A entrada do produto deve ser uma **Central do Setor**, orientada a trabalho e atenção operacional, não a gráficos decorativos.

A visão deve permitir:

- enxergar o trabalho de todos os membros autorizados;
- localizar uma contratação sem saber previamente quem é o responsável;
- identificar rapidamente itens que exigem ação;
- detectar processos sem movimentação relevante;
- filtrar por responsável, etapa, status, setor, período e outros campos úteis;
- pesquisar globalmente por identificadores, objeto, itens e demais metadados permitidos.

## 6. Núcleo funcional inicial

A primeira versão útil deve substituir com vantagem os controles de fila fragmentados.

Escopo inicial pretendido:

- cadastro e edição de contratação;
- relacionamentos com processos/identificadores externos;
- itens da contratação;
- responsável interno;
- etapa atual;
- status;
- aguardando quem/qual entidade;
- próxima ação;
- timeline de eventos;
- busca e filtros;
- alertas simples de inatividade;
- histórico e arquivamento sem exclusão silenciosa.

## 7. Evolução prevista

Somente após o núcleo operacional estar utilizável:

- pesquisa de preços integrada;
- consumo de APIs públicas oficiais;
- validações automáticas de pesquisa;
- snapshots imutáveis de referências selecionadas;
- biblioteca de itens e fornecedores;
- validações de consistência documental;
- automações adicionais;
- recursos de IA, sempre subordinados às fontes canônicas e à política de dados.

## 8. Pesquisa pública

O produto pode consultar dados públicos oficiais em tempo real ou sob cache controlado, sem necessidade de manter uma cópia integral de grandes bases públicas.

A estratégia inicial é federar consultas a fontes oficiais, normalizar respostas e persistir somente o que for necessário para o processo interno — especialmente referências efetivamente selecionadas.

Resultados externos não são automaticamente verdade interna. Dados escolhidos para fundamentar uma pesquisa devem preservar proveniência e snapshot suficiente para auditoria.

## 9. Segurança como requisito de produto

Informações de contratações antes de sua publicação podem ser sensíveis.

Consequentemente:

- dados internos são privados por padrão;
- ausência de autorização significa ausência de dados;
- a UI não é fronteira de segurança;
- o banco deve aplicar políticas de acesso quando exposto por Data API;
- nenhum dado sensível deve ser enviado a serviço externo por conveniência;
- desenvolvimento e testes usam dados fictícios ou sanitizados;
- logs, URLs e analytics devem minimizar exposição de metadados internos.

## 10. Fora do escopo inicial

- substituir o processo administrativo oficial;
- substituir sistema oficial de requisição/empenho;
- substituir portal oficial de publicação;
- armazenar cópia integral de bases públicas nacionais;
- gerar automaticamente documentos oficiais sem revisão e regras definidas;
- criar IA autônoma com poder de alterar registros canônicos sem validação;
- implementar dezenas de exceções hipotéticas antes de uso real.

## 11. Estratégia de evolução

O produto será desenvolvido por slices verticais pequenas e verificáveis.

Cada slice deve resolver uma necessidade operacional real, possuir critérios de aceite e fora do escopo, passar pelos gates aplicáveis e deixar o repositório em estado recuperável por outra sessão de IA.

## 12. Métrica qualitativa principal

O sistema deve reduzir o tempo necessário para responder:

> Onde está esta contratação, quem está com ela e o que precisa acontecer agora?

A evolução deve priorizar economia de tempo operacional e redução de procura/retrabalho, não quantidade de telas ou funcionalidades.
