# F02-CENTRAL-PROTOTYPE-01 — Central do Setor com dados fictícios

**Classe:** T1 — feature/protótipo  
**Estado:** READY  
**Dependência:** F01-BOOTSTRAP-01 concluída  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

A principal incerteza agora não é infraestrutura: é validar como a equipe enxerga e encontra o trabalho do setor em uma única tela.

As exceções operacionais ainda não são totalmente conhecidas. Antes de congelar schema e taxonomias, o produto precisa de uma interface utilizável o suficiente para revelar gaps reais sem introduzir dados internos ou persistência prematura.

## 2. Resultado esperado

Construir a primeira versão navegável da **Central do Setor** usando um dataset pequeno, estático e obviamente fictício.

A tela deve responder rapidamente, para cada registro demonstrativo:

- qual contratação é;
- qual identificador demonstrativo a representa;
- qual é o objeto fictício;
- quem é o responsável fictício;
- em qual etapa provisória está;
- qual status provisório possui;
- com quem/onde está aguardando;
- qual é a próxima ação;
- quando ocorreu a última movimentação.

## 3. Comportamento

### 3.1 Visão padrão

A home passa a representar a Central do Setor e mostra todos os registros fictícios da demonstração.

A visão desktop deve favorecer densidade e comparação entre linhas. Em largura menor, adotar comportamento deliberado — tabela com overflow bem sinalizado ou cards responsivos — sem esconder os campos operacionais essenciais.

### 3.2 Busca

Disponibilizar busca client-side simples por campos úteis, no mínimo:

- identificador demonstrativo;
- objeto;
- responsável.

Normalização básica de caixa/acentos é desejável quando implementável sem complexidade desnecessária.

### 3.3 Filtros

Disponibilizar filtros simples derivados do dataset fictício, por exemplo responsável, etapa e status.

Não transformar os valores usados no protótipo em taxonomia canônica. Eles servem apenas para testar a experiência.

### 3.4 Sinalização de protótipo

A interface deve indicar de forma visível que:

- os dados são fictícios;
- não existe persistência;
- não existe conexão com sistemas oficiais ou base interna.

## 4. Dataset permitido

Usar exclusivamente registros artificiais e inequivocamente genéricos.

Exemplos seguros:

- `DEMO-001`, `DEMO-002`;
- `Pessoa A`, `Pessoa B`;
- `Setor Alfa`, `Setor Beta`;
- objetos como `Aquisição demonstrativa A` ou `Serviço demonstrativo B`.

Não usar nomes de pessoas reais, números com aparência de processo administrativo real, setores internos reais, objetos reais, valores, empresas, documentos ou descrições derivadas das fontes internas do projeto.

## 5. Estrutura de código

Evitar arquitetura vazia, mas separar a lógica pura que já mereça teste.

Forma sugerida, não obrigatória:

```text
src/
├── app/
│   └── page.tsx
├── features/
│   └── sector-central/
│       ├── components/
│       ├── demo-data.ts
│       └── filtering.ts
└── shared/
```

A busca/filtro não deve ficar enterrada em JSX se puder ser representada como função pura pequena.

## 6. Critérios de aceite

A work unit é aceitável quando:

- a home mostra uma Central do Setor funcional com múltiplos registros fictícios;
- todos os registros são demonstrativos e não derivam de dados reais;
- busca por identificador, objeto e responsável funciona;
- existem filtros operacionais simples;
- limpar busca/filtros restaura a visão completa;
- estado sem resultados possui feedback claro;
- responsável, etapa, status, aguardando, próxima ação e última movimentação permanecem visíveis/acessíveis;
- a interface é utilizável em desktop e possui estratégia explícita para telas menores;
- a natureza fictícia/não persistente do protótipo fica evidente;
- lógica relevante de busca/filtro possui testes automatizados;
- `npm run lint`: PASS;
- `npm run typecheck`: PASS;
- `npm test`: PASS;
- `npm run build`: PASS;
- CI: PASS;
- red-team não encontra dado interno/sensível ou escopo antecipado.

## 7. Open Questions preservadas

Esta slice NÃO resolve:

- Q-001 — taxonomia final de etapas;
- Q-002 — taxonomia final de status;
- Q-004 — regra exata de pesquisa de preços / ±25%;
- Q-005 — limites de inatividade;
- Q-009 — permissões multiusuário.

Labels de etapa/status do dataset são `PROVISIONAL_DEMO_VALUES`.

## 8. Fora do escopo

- criação/edição persistente;
- banco;
- migrations;
- Auth/RLS;
- usuários reais;
- importação de dados;
- links para pastas internas;
- alertas definitivos;
- cálculo de dias como regra de negócio definitiva;
- timeline persistente;
- detalhe completo da contratação;
- pesquisa pública;
- pesquisa de preços;
- documentos;
- deploy de produção.

## 9. Red-team obrigatório

Antes de promover:

- procurar qualquer dado com aparência real ou derivado de fonte interna;
- confirmar que filtros não foram tratados como regras de negócio canônicas;
- conferir que nenhum limite de inatividade foi inventado;
- conferir que nenhum botão sugere persistência inexistente;
- testar zero resultados e limpeza de filtros;
- revisar acessibilidade básica de controles e cabeçalhos;
- revisar comportamento de largura reduzida;
- revisar diff completo e dependências adicionadas.

## 10. Verificação

Usar a cadeia reproduzível já estabelecida em F01:

```text
npm ci
npm run lint
npm run typecheck
npm test
npm run build
```

Browser deve ser verificado quando houver ferramenta/ambiente adequado. Se não for executado, registrar `SKIPPED` sem afirmar fidelidade visual não comprovada.

## 11. Não decidido nesta work unit

A eventual aprovação visual/operacional do protótipo não autoriza uso com dados reais. Banco, autenticação, RLS, infraestrutura e política de dados permanecem gates próprios posteriores.
