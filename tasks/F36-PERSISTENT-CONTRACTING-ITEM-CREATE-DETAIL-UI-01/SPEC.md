# F36-PERSISTENT-CONTRACTING-ITEM-CREATE-DETAIL-UI-01 - Integrar criação persistente de item no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** PLANNED / NEXT  
**Dependências:** F35, F33, ADR-003, ADR-009 e ADR-014  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F35 materializou a boundary PostgreSQL/server-only da ADR-014 para criar um item mínimo em uma contratação existente, mas o detalhe persistente ainda não oferece uma jornada de criação de item.

A próxima slice deve tornar somente essa operação utilizável, sem abrir CRUD de itens, sem ampliar authority, sem inventar regra de quantidade/unidade/catálogo e sem resolver Q-004 ou Q-009.

## Objetivo

No modo persistente autorizado, permitir adicionar um item pelo detalhe da contratação usando exclusivamente `createPersistentContractingItem({ contractingId, description, quantity, unit, catalogCode })`, com Server Action estreita, feedback sanitizado, readback protegido e modo demo estritamente read-only.

## Execução obrigatória

### 1. Recuperação e inspeção

- confirmar F35 integrada e gates pós-merge verdes;
- revalidar `CONTEXT_MANIFEST`;
- ler ADR-014 e esta SPEC;
- inspecionar os precedentes F27/F30/F33, o detalhe persistente atual, read model de itens, `persistent-read-mode` e o adapter F35;
- manter migrations `0001..0007` byte-for-byte imutáveis;
- não alterar grants, policies, capabilities ou primitives PostgreSQL nesta slice.

### 2. Disponibilidade da jornada

A criação deve existir somente quando o detalhe estiver em modo persistente válido.

- modo demo continua read-only e não renderiza formulário capaz de chamar F35;
- modo inválido ou falha protegida não cria caminho alternativo de write e não cai para demo;
- o ID da rota é somente `contractingId` candidato, nunca team/scope/authority;
- a própria Server Action deve verificar que persistence está habilitada, sem confiar somente na ausência/presença do formulário.

### 3. Server Action estreita

Criar uma Server Action dedicada a item create.

Ela deve:

- ler cada scalar esperado no máximo uma vez e rejeitar valor duplicado/ambíguo;
- aceitar do formulário apenas `contractingId`, `description`, `quantity`, `unit` e `catalogCode`;
- rejeitar/falhar fechado diante de tentativa de fornecer `teamId`, actor, membership, issuer, subject, ordinal, item UUID, event UUID, callback, redirect ou outra authority;
- não executar SQL/DML próprio;
- chamar exclusivamente `createPersistentContractingItem`;
- não criar UUID de item/evento no browser ou FormData;
- retornar/navegar somente por estados locais sanitizados;
- não incluir erro interno, claims, SQL, conexão ou detalhes de autorização em HTML, query string ou log;
- não possuir fallback demo.

### 4. Semântica exata dos campos

Preservar ADR-014/F35.

#### description

- exatamente uma string;
- `''`, spaces-only e leading/trailing spaces continuam válidos;
- não aplicar trim;
- não inventar `required` de negócio, tamanho máximo ou normalização.

#### unit e catalogCode

- texto digitado é encaminhado exatamente;
- string vazia permanece `''` e não vira `NULL` por conveniência;
- spaces-only e leading/trailing spaces são preservados;
- a UI não inventa obrigatoriedade.

#### quantity

- continua `string | null` até F35/PostgreSQL;
- não usar `Number`, `parseFloat` ou coerção JavaScript numérica;
- um campo sem valor numérico na UI representa `null`; essa é apenas a codificação de ausência do campo nullable, não regra de negócio;
- quando houver texto, encaminhá-lo exatamente como string, inclusive zero, negativo ou fração;
- não trimar nem corrigir o valor antes do PostgreSQL;
- entrada textual não convertível deve resultar somente em `unavailable` sanitizado, conforme F35.

A UI não decide positividade, escala, precisão, vínculo quantidade-unidade ou regra de pesquisa de preços. Q-004 permanece aberta.

### 5. Resultado e readback

Resultados externos permitidos pela boundary F35:

- `created`;
- `not-available`;
- `unavailable`.

Regras de integração:

- `created`: revalidar somente a rota local fixa do detalhe e apresentar feedback de sucesso; o novo item deve aparecer pelo read model protegido, sem confiar em ordinal/item UUID retornado pelo write;
- `not-available`: feedback genérico, sem distinguir contratação inexistente, cross-team, inativa ou problema de membership;
- `unavailable`: erro técnico sanitizado, sem fallback para demo;
- nenhuma resposta de F35 pode ser transformada em oracle de team, actor, membership, ordinal ou existência protegida;
- nenhum redirect/callback arbitrário vindo do cliente é aceito.

### 6. UI mínima

O detalhe persistente deve oferecer somente os campos necessários para criar item:

- descrição;
- quantidade opcional;
- unidade opcional;
- código de catálogo opcional;
- submit de criação.

A UI deve:

- manter os itens existentes visíveis pelo read model atual;
- usar labels acessíveis e navegação por teclado;
- desabilitar nova submissão enquanto a tentativa estiver pending para reduzir double-submit acidental;
- não expor inputs de `teamId`, actor, membership, ordinal, item UUID ou event UUID;
- não adicionar edição, reorder, retire/restore ou pesquisa de preços;
- não sugerir que demo grava dados.

F35 não possui deduplicação semântica. A UI reduz submissão repetida acidental por estado pending, mas esta slice não inventa idempotência persistente.

### 7. Testes adversariais

Provar no mínimo:

1. persistent mode autorizado renderiza a criação mínima no detalhe;
2. demo não renderiza write real nem chama F35;
3. modo inválido/falha protegida não chama F35 nem cai para demo;
4. action encaminha exatamente `contractingId`, `description`, `quantity`, `unit`, `catalogCode`;
5. scalars duplicados falham fechado antes de F35;
6. team/actor/membership/issuer/subject/ordinal/itemId/eventId forjados não atravessam a boundary;
7. callback/redirect forjado não controla navegação;
8. `contractingId` malformado não chega a F35;
9. description vazio/espaços e leading/trailing spaces não são normalizados;
10. unit/catalog vazio permanecem string vazia, não `NULL`;
11. unit/catalog spaces-only permanecem exatos;
12. quantity ausente na UI chega como `null`;
13. quantity `0`, negativa, fracionária e de alta precisão chega como string exata, sem `Number`/`parseFloat`;
14. quantity textual inválida produz apenas feedback `unavailable` sanitizado;
15. `created` provoca revalidação/readback apenas da rota local fixa;
16. `not-available` não distingue cross-team de inexistente;
17. erro contendo connection string/claims/SQL não aparece na UI ou navegação;
18. pending desabilita repetição acidental;
19. nenhum controle de update/reorder/retire ou pesquisa de preços é adicionado;
20. F22/F26/F29/F32/F35/Auth/RLS e build continuam verdes.

## Red-team obrigatório

Rejeitar PASS se:

- browser puder fornecer team/actor/membership/ordinal/UUID interno como authority;
- Server Action executar SQL/DML próprio ou contornar F35;
- demo/configuração inválida puder gravar;
- falha protegida cair para fixture/demo;
- description/unit/catalog forem trimados ou empty-to-NULL por conveniência;
- quantity passar por `Number` ou `parseFloat`;
- regra de positividade, required, escala, precisão ou pesquisa de preços for inventada;
- callback/redirect externo for controlável pelo cliente;
- `not-available` revelar existência cross-team;
- write confiar em ordinal/item UUID devolvido ao browser para readback;
- double-submit não tiver proteção pending na UI;
- UI liberar edição/reorder/retire de item;
- migrations `0001..0007`, grants, policies ou capabilities forem alterados;
- F26/F29/F32/F35 tiverem authority ampliada;
- Q-004 ou Q-009 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## Verificação

- lint;
- typecheck;
- unit/component tests;
- build;
- CI database/Auth;
- F22 Private Preview Preflight;
- F29 Contracting Create;
- F32 Contracting Object Mutation;
- F35 Contracting Item Create;
- diff/red-team integral.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities continuam autoritativas;
- runtime normal continua sem DML direto;
- F35 continua sendo a única boundary de item create;
- migrations aplicadas permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fora do escopo

- editar item existente;
- reordenar item;
- retirar/restaurar item;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- idempotência persistente/deduplicação semântica;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F36 fecha quando uma pessoa autorizada em modo persistente puder adicionar um item mínimo pelo detalhe usando exclusivamente F35, com payload restrito, sem authority de browser, sem normalização textual indevida, quantity transportada como string/null, readback protegido, feedback sanitizado, demo read-only e todos os gates/adversariais verdes.