# Open Questions — Compras

**Versão:** 0.1  
**Regra:** estas questões não podem ser resolvidas silenciosamente por inferência.

## P0 — necessárias antes de modelar detalhes definitivos

### Q-001 — Taxonomia final de etapas

Quais etapas devem aparecer para o usuário e quais são apenas detalhes internos de uma etapa maior?

**Impacto:** workflow, filtros, métricas e transições.

### Q-002 — Taxonomia final de status

Quais estados precisam ser diferenciados na operação diária, especialmente tipos de espera e análise externa?

**Impacto:** Central do Setor e regras de alerta.

### Q-003 — Relação entre contratação e processos relacionados

Quais tipos de identificadores/processos podem coexistir na mesma contratação e quais relações precisam de semântica própria?

**Impacto:** cardinalidade e modelo de dados.

### Q-004 — Regra exata de pesquisa de preços e faixa de ±25%

Existe necessidade de automatizar uma regra operacional envolvendo conjunto de preços e limites de +25% / -25%, mas a fórmula exata e suas exceções devem ser reproduzidas a partir da fonte operacional validada antes da implementação.

**Impacto:** cálculo, descarte/aceite e conclusão automática da pesquisa por item.

## P1 — importantes para o primeiro uso real

### Q-005 — Inatividade

Após quantos dias sem movimentação um processo deve ser classificado como atenção, parado ou crítico? O valor deve ser configurável?

### Q-006 — Próxima ação e pendências

Quando uma simples `próxima ação` deve virar uma entidade `Pendência` com prioridade, responsável e resolução própria?

### Q-007 — Localização de pasta/arquivo

O produto deve apenas armazenar/copiar um caminho de referência ou existe ambiente autorizado para abrir pastas/documentos diretamente?

### Q-008 — Importação inicial

Quais controles existentes serão importados no primeiro teste e quais serão mantidos apenas como referência histórica?

## P2 — multiusuário e evolução

### Q-009 — Permissões

Quando o sistema deixar de ser piloto individual, todos os membros autorizados poderão editar todas as contratações ou haverá perfis/escopos distintos?

### Q-010 — Auditoria de leitura

Além de alterações, existe necessidade operacional/jurídica de registrar visualizações de contratações sensíveis? Qual retenção é apropriada?

### Q-011 — Integração com fontes públicas

Quais fontes entram primeiro na pesquisa integrada e quais filtros/rankings representam maior ganho operacional?

### Q-012 — IA

Quais funções de IA podem operar somente sobre dados públicos e quais, se houver, poderão receber conteúdo interno após análise de privacidade, segurança e infraestrutura?

## Como resolver

Não é necessário responder tudo antes do primeiro protótipo.

A regra é resolver cada pergunta quando ela bloquear a próxima slice real. Respostas aprovadas devem migrar para `PROJECT_DESIGN`, `DOMAIN_MODEL`, `BUSINESS_WORKFLOW`, `SECURITY`, requisitos ou ADR apropriado; a questão então é marcada como resolvida em vez de deixar duas fontes conflitantes.
