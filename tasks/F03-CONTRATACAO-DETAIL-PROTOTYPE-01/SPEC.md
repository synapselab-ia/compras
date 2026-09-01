# F03-CONTRATACAO-DETAIL-PROTOTYPE-01 — Detalhe navegável da contratação demo

**Classe:** T1 — feature/protótipo  
**Estado:** READY  
**Dependência:** F02-CENTRAL-PROTOTYPE-01 concluída  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

A Central do Setor permite localizar e comparar trabalho, mas uma tabela não deve concentrar todo o contexto de uma contratação. A próxima incerteza de produto é validar a divisão entre visão de fila e visão de detalhe antes de congelar schema, relacionamentos ou taxonomias.

## 2. Resultado esperado

Adicionar uma jornada demonstrativa `Central → detalhe → Central` para registros `DEMO-*`, usando somente dados estáticos e inequivocamente fictícios.

O detalhe deve permitir compreender um registro sem depender da tabela e sem sugerir que já existe operação persistente.

## 3. Comportamento

### 3.1 Entrada no detalhe

Cada registro da Central deve oferecer uma forma clara e acessível de abrir seu detalhe demonstrativo.

Preferir URL estável baseada no identificador demo quando isso puder ser feito sem infraestrutura adicional.

### 3.2 Cabeçalho operacional

O detalhe deve repetir o contexto essencial do registro:

- identificador;
- objeto;
- responsável;
- etapa provisória;
- status provisório;
- aguardando;
- próxima ação;
- última movimentação.

### 3.3 Contexto adicional demonstrativo

Exibir pequenas seções fictícias para validar organização da informação, no mínimo:

- identificadores relacionados demonstrativos;
- itens demonstrativos;
- atividade/timeline demonstrativa recente.

Não transformar tipos/labels usados nessas seções em semântica canônica.

Exemplos seguros:

- `REF-DEMO-A1`;
- `Identificador demo A`;
- `Item demonstrativo 01`;
- `Evento demonstrativo 01`.

### 3.4 Registro inexistente

Uma URL/identificador demo que não exista deve produzir comportamento explícito e seguro, sem fallback silencioso para outro registro.

### 3.5 Navegação

Disponibilizar retorno claro para a Central do Setor. Não adicionar edição, exclusão, criação ou qualquer ação que sugira persistência.

## 4. Dados

Reutilizar a fonte demo existente quando fizer sentido e ampliar o dataset somente com conteúdo genérico.

É proibido usar:

- nomes de pessoas reais;
- números com aparência de processo real;
- sistemas ou setores internos reais;
- objetos derivados de contratações reais;
- empresas, valores, documentos ou descrições internas;
- caminhos de rede;
- qualquer conteúdo `INTERNAL` ou `SENSITIVE_PRE_PUBLICATION`.

## 5. Estrutura de código

Evitar duplicar a mesma informação demo entre lista e detalhe sem necessidade.

Lógica pequena de lookup/seleção deve permanecer testável fora de JSX quando aplicável.

Não criar repository/service abstractions vazias para dados estáticos.

## 6. Critérios de aceite

A work unit é aceitável quando:

- registros da Central abrem um detalhe demonstrativo coerente;
- a navegação de volta à Central é clara;
- o detalhe mostra os campos operacionais essenciais da Central;
- existem seções demonstrativas de identificadores relacionados, itens e atividade recente;
- todos os dados são inequivocamente fictícios;
- labels de etapa/status/relacionamentos continuam provisórios;
- identificador demo inexistente possui tratamento explícito;
- não existe botão ou fluxo de gravação/edição;
- a apresentação é deliberada em desktop e telas menores;
- controles/links e estrutura de headings possuem acessibilidade básica;
- lookup/seleção relevante possui teste automatizado;
- `npm run lint`: PASS;
- `npm run typecheck`: PASS;
- `npm test`: PASS;
- `npm run build`: PASS;
- CI: PASS;
- red-team não encontra dado interno/sensível ou resolução indevida de open question.

## 7. Open Questions preservadas

Esta slice NÃO resolve:

- Q-001 — taxonomia final de etapas;
- Q-002 — taxonomia final de status;
- Q-003 — semântica final entre contratação e processos/identificadores relacionados;
- Q-004 — regra de pesquisa de preços / ±25%;
- Q-005 — inatividade;
- Q-006 — quando próxima ação vira Pendência;
- Q-009 — permissões multiusuário.

## 8. Fora do escopo

- banco/migrations;
- Auth/RLS;
- cadastro ou edição persistente;
- timeline persistente;
- tipos definitivos de processo relacionado;
- quantidades/valores operacionais reais;
- importação;
- documentos;
- pesquisa de preços;
- PNCP/Compras.gov;
- alertas definitivos;
- deploy de produção.

## 9. Red-team obrigatório

Antes de promover:

- revisar todos os novos fixtures/textos para aparência ou origem real;
- confirmar que identificadores relacionados são explicitamente demo;
- confirmar que Q-003 não foi fechada por estrutura de UI;
- confirmar ausência de ações que simulem persistência;
- testar registro existente e inexistente;
- revisar navegação por teclado e headings;
- revisar comportamento de largura reduzida;
- revisar diff completo e dependências.

## 10. Verificação

Usar a cadeia reproduzível atual:

```text
npm ci
npm run lint
npm run typecheck
npm test
npm run build
```

Browser deve ser verificado quando houver ferramenta/ambiente adequado. Se não for executado, registrar `SKIPPED` sem afirmar fidelidade visual não comprovada.
