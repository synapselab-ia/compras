# F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01 - Integrar criação persistente de nota manual no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY / NEXT após integração da F44  
**Dependências:** F44, ADR-017, F42, F39, F30, ADR-003 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F44 materializou a boundary PostgreSQL/server-only da ADR-017 para criar um evento `manual_note_added` em uma contratação existente, com UUID preparado, replay exato, concorrência segura e least privilege.

O detalhe persistente já lê `contracting_events` pelo modelo protegido e exibe a atividade recente, mas ainda não oferece uma jornada de criação de nota manual. A próxima slice deve tornar somente a operação F44 utilizável no detalhe, sem ampliar authority PostgreSQL, sem criar edição/exclusão de eventos e sem transformar a nota em entidade genérica, categoria, prioridade ou Pendência.

## Objetivo

No modo persistente autorizado, permitir adicionar uma nota manual à timeline da contratação usando exclusivamente:

```text
preparePersistentManualTimelineNoteEventId()

createPersistentManualTimelineNote({
  contractingId,
  eventId,
  note
})
```

A integração deve manter o `eventId` preparado estável durante retries técnicos da mesma intenção, preservar `NULL`, vazio e espaços exatamente, apresentar feedback sanitizado, fazer readback somente pelo modelo protegido e manter demo estritamente read-only.

## 1. Recuperação e limites

Antes de implementar:

1. recuperar `main` real após F44;
2. revalidar `CONTEXT_MANIFEST`;
3. confirmar PR F44 integrada e gates do head final verdes;
4. ler ADR-017, resultado F44 e esta SPEC;
5. inspecionar F42 como precedente principal de UUID preparado/retry e Server Action no detalhe;
6. inspecionar F27/F36/F39 como precedentes complementares de writes restritos;
7. inspecionar `persistent-read.ts`, `types.ts`, `actions.ts`, página e componente do detalhe;
8. confirmar que a timeline persistente continua sendo lida por `contracting_events`;
9. manter migrations `0001..0011` byte-for-byte imutáveis;
10. não alterar grants, policies, capability, primitive ou provisioning F44.

F45 não implementa nova authority de banco.

## 2. Disponibilidade da jornada

A criação deve existir somente quando o detalhe estiver em modo persistente válido e autorizado.

- modo demo continua read-only e não renderiza formulário capaz de chamar F44;
- modo inválido ou falha protegida não cria caminho alternativo de write e não cai para demo;
- `contractingId` da rota continua sendo somente seletor candidato;
- o UUID do novo evento deve ser preparado no servidor por `preparePersistentManualTimelineNoteEventId()`;
- o UUID preparado é idempotency key opaca, não segredo e não authority;
- a própria Server Action deve verificar novamente que persistence está habilitada.

## 3. UUID preparado e retry seguro

O `eventId` representa a identidade estável de uma única intenção de adicionar nota manual.

Requisitos:

- gerar o candidate UUID no servidor antes da primeira submissão;
- reutilizar o mesmo candidate somente no retry técnico da mesma intenção;
- não gerar candidate no browser;
- não trocar automaticamente o candidate depois de `unavailable`, pois a tentativa pode ter concluído no banco antes de uma falha de transporte;
- `created` e `already-added` encerram a intenção;
- `not-available` não mantém a intenção como retry técnico;
- uma nova intenção explícita recebe novo candidate;
- candidate válido forjado pelo browser não concede acesso e continua sujeito integralmente à autorização F44;
- candidate malformado falha fechado antes do adapter;
- qualquer estado usado para preservar candidate em redirect/query deve conter somente o UUID opaco validado e estados locais fixos, nunca erro interno ou authority.

Não criar deduplicação por conteúdo da nota como substituto do UUID preparado.

## 4. Server Action estreita

Criar uma Server Action dedicada à criação da nota manual.

Ela deve:

- exigir modo persistente;
- ler cada scalar esperado no máximo uma vez;
- rejeitar scalars duplicados ou ambíguos;
- aceitar somente os campos de transporte definidos nesta SPEC, além de `$ACTION_*` internos do framework;
- validar `contractingId` e `eventId` como UUIDs candidatos;
- não executar SQL ou DML próprio;
- chamar exclusivamente `createPersistentManualTimelineNote`;
- não aceitar team, actor, membership, issuer, subject, `event_type`, timestamps, field/old/new, item ou related identifier;
- não aceitar callback, redirect ou URL arbitrária;
- nunca cair para demo write;
- sanitizar erro técnico ou resultado impossível como `unavailable`;
- construir navegação somente com a rota local fixa do `contractingId` validado.

### Campos de transporte

A action pode aceitar somente:

```text
contractingId
eventId
noteKind
note
```

`noteKind` aceita somente:

```text
null
text
```

Para `noteKind = null`, a action constrói `null`.

Para `noteKind = text`, a action exige exatamente um scalar `note` e usa a string sem alteração, inclusive `''`, spaces-only e leading/trailing spaces.

## 5. Semântica textual

Preservar ADR-017/F44 sem inferir regra de negócio nova.

A interface precisa distinguir explicitamente:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

A UI deve oferecer escolha acessível e explícita entre `Texto` e `Ausente (NULL)`, ou controle materialmente equivalente.

Campo textual vazio não pode ser convertido implicitamente para `NULL`.

Não aplicar:

- trim;
- case-folding;
- empty-to-NULL;
- máscara;
- limite de negócio inventado;
- interpretação Markdown/HTML;
- categoria;
- prioridade;
- deduplicação por texto.

## 6. Resultado, navegação e readback

Resultados externos F44:

- `created`;
- `already-added`;
- `not-available`;
- `unavailable`.

Semântica:

- `created`: revalidar somente a rota local fixa do detalhe, informar sucesso e confirmar a nova movimentação pelo read model protegido;
- `already-added`: tratar como replay idempotente da mesma intenção, revalidar/readback e usar feedback fixo sem criar novo evento;
- `not-available`: feedback genérico sem distinguir inexistente, cross-team, inativo, membership ou colisão protegida;
- `unavailable`: feedback técnico sanitizado e candidate preservado para retry seguro da mesma intenção;
- resultado impossível vira `unavailable`;
- nenhuma resposta pode revelar team, actor, membership, SQL, claims, connection string, timestamps internos ou existência cross-team.

O readback usa `detail.activity` carregado pelo modelo persistente protegido. A UI não confia em row/evento devolvido pelo write para decidir scope.

Se for necessário ajustar a apresentação de `manual_note_added`, a alteração deve ser somente de apresentação. Não criar consulta paralela, não contornar RLS e não introduzir novo contrato de banco.

## 7. UI mínima

No detalhe persistente, expor somente o necessário para criar uma nota:

- seletor explícito de estado `Texto` ou `Ausente (NULL)`;
- campo de texto multilinha quando o estado for textual;
- submit;
- feedback fixo da operação.

A UI deve:

- manter a atividade recente visível;
- usar labels acessíveis e navegação por teclado;
- desabilitar repetição enquanto a tentativa estiver pending;
- não expor inputs de team, actor, membership, issuer, subject, event type, timestamps, field/old/new, item ou related identifier;
- não sugerir que demo grava dados;
- não adicionar edição ou exclusão de evento;
- não adicionar categoria, prioridade, anexos, menções ou Pendência;
- não transformar a timeline em editor genérico.

## 8. Demo e falhas protegidas

Demo permanece estritamente read-only:

- nenhum formulário F45;
- nenhum candidate operacional;
- nenhuma chamada da Server Action F45;
- query string forjada não produz feedback que sugira write real.

Persistence inválida ou falha de leitura protegida não habilita formulário, não prepara candidate e não cai para fixtures.

## 9. Matriz adversarial obrigatória

Provar no mínimo:

1. persistent mode autorizado renderiza criação mínima de nota manual;
2. demo não renderiza formulário, candidate ou write real;
3. persistence inválida/falha protegida não chama F44 e não cai para demo;
4. candidate inicial vem do helper server-side F44;
5. retry de `unavailable` reutiliza o mesmo candidate;
6. nova intenção após `created` ou `already-added` recebe novo candidate;
7. `not-available` não é tratado como retry técnico;
8. action encaminha exatamente `contractingId`, `eventId` e `note` após decodificar `noteKind`;
9. scalars duplicados falham fechado antes de F44;
10. campos extras browser-controlled falham fechado;
11. team/actor/membership/issuer/subject/event type/timestamps/field/old/new/item/related identifier forjados não atravessam a action;
12. callback/redirect forjado não controla navegação;
13. `contractingId` malformado não chega a F44;
14. `eventId` malformado não chega a F44;
15. candidate válido forjado não vira authority;
16. `noteKind = null` produz exatamente `note = null`;
17. `noteKind = text` com `note = ''` permanece string vazia;
18. spaces-only e leading/trailing spaces permanecem exatos;
19. não existe trim, case-folding, empty-to-NULL ou validação de conteúdo inventada;
20. não existe deduplicação por conteúdo;
21. `created` revalida apenas a rota local fixa e o readback vem do modelo protegido;
22. `already-added` não cria segundo evento e termina a mesma intenção;
23. `not-available` não distingue cross-team/inexistente/inativo/membership/colisão;
24. `unavailable` não expõe erro interno e preserva candidate para retry;
25. resultado impossível é sanitizado;
26. erro contendo conexão, SQL ou claims não aparece no HTML ou navegação;
27. pending desabilita repetição acidental;
28. atividade criada é observada somente pelo read model protegido após revalidação;
29. nenhum controle de edit/delete de evento, categoria, prioridade ou Pendência é criado;
30. migrations `0001..0011` permanecem byte-for-byte;
31. F26/F29/F32/F35/F38/F41/F44 não recebem authority nova;
32. CI, F22, F29, F32, F35, F38, F41 e F44 continuam verdes.

## 10. Red-team obrigatório

Rejeitar PASS se:

- browser puder transformar candidate UUID em scope ou authority;
- candidate for gerado no browser;
- retry técnico trocar o candidate e puder duplicar a intenção;
- Server Action executar SQL/DML próprio ou contornar F44;
- browser controlar team, actor, membership, issuer, subject, event type ou timestamp;
- browser controlar field/old/new/item/related identifier;
- `NULL` virar vazio ou vazio virar `NULL` implicitamente;
- texto for trimado, normalizado ou interpretado por regra não aprovada;
- UI introduzir categoria, prioridade, Pendência ou deduplicação;
- demo/configuração inválida puder gravar;
- protected failure cair para fixture/demo;
- callback/redirect externo for controlável pelo cliente;
- feedback revelar existência ou estado protegido;
- migrations/grants/policies/capability/primitive/provisioning F44 forem alterados;
- escopo expandir para editar/excluir eventos;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 ou Q-010 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## 11. Verificação

Executar:

- lint;
- typecheck;
- unit/component tests;
- build;
- CI database/Auth;
- F22 Private Preview Preflight;
- F29 Contracting Create;
- F32 Contracting Object Mutation;
- F35 Contracting Item Create;
- F38 Contracting Item Mutation;
- F41 Related Identifier Create;
- F44 Manual Timeline Note Create;
- diff/red-team integral;
- confirmação byte-for-byte de migrations `0001..0011`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios em teste;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F44 continua sendo a única boundary persistente de criação de nota manual;
- migrations aplicadas `0001..0011` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fora do escopo

- editar nota/evento existente;
- excluir evento;
- primitive genérica de evento;
- categorias e prioridades;
- anexos ou menções;
- Pendência;
- mutations de responsável/etapa/status/waiting/próxima ação;
- edição/desvínculo de identificador;
- pesquisa de preços;
- política multiusuário/Q-009;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F45 fecha quando uma pessoa autorizada em modo persistente puder adicionar uma nota manual pelo detalhe usando exclusivamente F44, com candidate UUID preparado no servidor e estável em retry técnico, transporte explícito de `NULL`/texto, payload sem authority controlada pelo browser, feedback sanitizado, readback protegido, demo read-only e todos os gates/adversariais verdes.
