# F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01 - Integrar criação persistente de identificador relacionado no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY / NEXT após integração da F41  
**Dependências:** F41, ADR-016, F39, F30, ADR-003 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

F41 materializou a boundary PostgreSQL/server-only da ADR-016 para criar um `related_identifier` mínimo em uma contratação existente, com UUID preparado, replay seguro, auditoria atômica e least privilege.

O detalhe persistente já lê e apresenta identificadores relacionados ativos, mas ainda não oferece uma jornada de criação. A próxima slice deve tornar somente a operação F41 utilizável, sem ampliar authority PostgreSQL, sem criar edição/desvínculo/re-link/delete, sem inventar taxonomia ou deduplicação e sem resolver Q-003 ou Q-009.

## Objetivo

No modo persistente autorizado, permitir vincular um identificador relacionado pelo detalhe da contratação usando exclusivamente:

```text
preparePersistentRelatedIdentifierCandidateId()

createPersistentRelatedIdentifier({
  contractingId,
  relatedIdentifierId,
  identifierKind,
  identifierValue,
  sourceSystem,
  note
})
```

A integração deve manter o UUID preparado estável durante retries da mesma intenção, preservar `NULL`, vazio e espaços exatamente, apresentar feedback sanitizado, fazer readback somente pelo modelo protegido e manter demo estritamente read-only.

## 1. Recuperação e limites

Antes de implementar:

1. recuperar `main` real após F41;
2. revalidar `CONTEXT_MANIFEST`;
3. confirmar PR F41 integrada e gates do head final verdes;
4. ler ADR-016, resultado F41 e esta SPEC;
5. inspecionar F30 como precedente de UUID preparado/retry e F36/F39 como precedentes de Server Action/UI no detalhe;
6. inspecionar `persistent-read.ts`, tipos, página/componente de detalhe, actions e feedbacks atuais;
7. manter migrations `0001..0010` byte-for-byte imutáveis;
8. não alterar grants, policies, capabilities, primitive ou provisioning F41.

F42 não implementa nova authority de banco.

## 2. Disponibilidade da jornada

A criação deve existir somente quando o detalhe estiver em modo persistente válido e autorizado.

- modo demo continua read-only e não renderiza formulário capaz de chamar F41;
- modo inválido ou falha protegida não cria caminho alternativo de write e não cai para demo;
- `contractingId` da rota continua sendo somente seletor candidato;
- o UUID do novo vínculo deve ser preparado no servidor por `preparePersistentRelatedIdentifierCandidateId()`;
- o UUID preparado é idempotency key opaca, não segredo e não authority;
- a própria Server Action deve verificar novamente que persistence está habilitada.

## 3. UUID preparado e retry seguro

O `relatedIdentifierId` representa a identidade estável de uma única intenção de criação.

Requisitos:

- gerar o candidate UUID no servidor antes da primeira submissão;
- reutilizar o mesmo candidate em retry da mesma intenção;
- não gerar candidate no browser;
- não trocar o candidate automaticamente depois de `unavailable`, pois a primeira tentativa pode ter concluído no banco antes da falha de transporte;
- `created` e `already-linked` encerram a intenção;
- uma nova intenção explícita recebe novo candidate;
- candidate forjado pelo browser não concede acesso e continua sujeito integralmente à autorização F41;
- candidate malformado falha fechado antes do adapter;
- qualquer estado usado para preservar candidate em redirect/query deve conter somente o UUID opaco validado e estados locais fixos, nunca erro interno ou authority.

Não criar deduplicação textual como substituto do UUID preparado.

## 4. Server Action estreita

Criar uma Server Action dedicada a related identifier create.

Ela deve:

- exigir modo persistente;
- ler cada scalar esperado no máximo uma vez;
- rejeitar scalars duplicados ou ambíguos;
- aceitar somente os campos de transporte definidos nesta SPEC, além de `$ACTION_*` internos do framework;
- validar `contractingId` e `relatedIdentifierId` como UUIDs candidatos;
- não executar SQL/DML próprio;
- chamar exclusivamente `createPersistentRelatedIdentifier`;
- não aceitar event UUID do browser;
- não aceitar team, actor, membership, issuer, subject, linkedAt, unlinkedAt ou timestamps;
- não aceitar callback, redirect ou URL arbitrária;
- nunca cair para demo write;
- sanitizar erro técnico ou resultado impossível como `unavailable`;
- construir navegação somente com a rota local fixa do `contractingId` validado.

### Campos de transporte

A action pode aceitar somente:

```text
contractingId
relatedIdentifierId
identifierKindKind
identifierKind
identifierValue
sourceSystemKind
sourceSystem
noteKind
note
```

Os campos `identifierKindKind`, `sourceSystemKind` e `noteKind` aceitam somente:

```text
null
text
```

Para `kind = null`, a action constrói `null`. Para `kind = text`, usa exatamente a string correspondente, inclusive `''`, spaces-only e leading/trailing spaces.

`identifierValue` deve existir exatamente uma vez como string. String vazia e espaços são valores válidos pela boundary atual.

## 5. Semântica textual

Preservar ADR-016/F41 sem inferir regra de negócio nova.

### identifierValue

- string NOT NULL por shape técnico;
- `''` é preservado;
- spaces-only é preservado;
- leading/trailing spaces são preservados;
- sem trim, case-folding, máscara, regex, max length de negócio ou empty-to-NULL.

### identifierKind, sourceSystem e note

Cada campo deve distinguir explicitamente:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

A UI precisa oferecer escolha acessível e explícita entre `Texto` e `Ausente (NULL)`, ou controle materialmente equivalente. Campo vazio não pode ser convertido implicitamente para `NULL`.

Não criar lista fechada de tipo/origem.

## 6. Resultado, navegação e readback

Resultados externos F41:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

Semântica:

- `created`: revalidar somente a rota local fixa do detalhe, informar sucesso e confirmar o vínculo pelo read model protegido;
- `already-linked`: tratar como replay idempotente da mesma intenção, revalidar/readback e usar feedback fixo sem criar novo fato;
- `not-available`: feedback genérico sem distinguir inexistente, cross-team, inativo, membership ou colisão protegida;
- `unavailable`: feedback técnico sanitizado e candidate preservado para retry seguro da mesma intenção;
- resultado impossível vira `unavailable`;
- nenhuma resposta pode revelar team, actor, membership, evento, SQL, claims, connection string ou existência cross-team.

O readback usa a lista de `relatedIdentifiers` já carregada pelo modelo protegido. A UI não confia em row/evento devolvido pelo write para decidir scope.

## 7. UI mínima

No detalhe persistente, expor somente o necessário para criar um vínculo:

- tipo opcional, com distinção texto/NULL;
- valor do identificador;
- sistema de origem opcional, com distinção texto/NULL;
- nota opcional, com distinção texto/NULL;
- submit.

A UI deve:

- manter a lista atual de identificadores visível;
- usar labels acessíveis e navegação por teclado;
- desabilitar repetição enquanto a tentativa estiver pending;
- não expor inputs de team, actor, membership, issuer, subject, event UUID ou timestamps;
- não sugerir que demo grava dados;
- não adicionar edição, desvínculo, re-link, delete, ordenação ou deduplicação.

## 8. Demo e falhas protegidas

Demo permanece estritamente read-only:

- nenhum formulário F42;
- nenhum candidate operacional;
- nenhuma chamada da Server Action F42;
- query string forjada não produz feedback que sugira write real.

Persistence inválida ou falha de leitura protegida não habilita formulário e não cai para fixtures.

## 9. Matriz adversarial obrigatória

Provar no mínimo:

1. persistent mode autorizado renderiza criação mínima de identificador;
2. demo não renderiza formulário, candidate ou write real;
3. persistence inválida/falha protegida não chama F41 e não cai para demo;
4. candidate inicial vem do helper server-side F41;
5. retry de `unavailable` reutiliza o mesmo candidate;
6. nova intenção após `created` ou `already-linked` recebe novo candidate;
7. action encaminha exatamente os seis campos do contrato F41 após decodificar os kinds;
8. scalars duplicados falham fechado antes de F41;
9. campos extras browser-controlled falham fechado;
10. team/actor/membership/issuer/subject/event UUID/linkedAt/unlinkedAt/timestamps forjados não atravessam a action;
11. callback/redirect forjado não controla navegação;
12. `contractingId` malformado não chega a F41;
13. `relatedIdentifierId` malformado não chega a F41;
14. candidate válido forjado não vira authority;
15. `identifierValue = ''` permanece vazio;
16. `identifierValue` spaces-only e leading/trailing spaces permanecem exatos;
17. identifierKind distingue `NULL`, `''` e spaces-only;
18. sourceSystem distingue `NULL`, `''` e spaces-only;
19. note distingue `NULL`, `''` e spaces-only;
20. não existe trim, case-folding, máscara ou regex de negócio;
21. não existe deduplicação por valor/tipo/origem;
22. `created` revalida apenas a rota local fixa e o readback vem do modelo protegido;
23. `already-linked` não cria segunda row/evento e termina a mesma intenção;
24. `not-available` não distingue cross-team/inexistente/inativo/membership;
25. `unavailable` não expõe erro interno e preserva candidate para retry;
26. resultado impossível é sanitizado;
27. erro contendo conexão/SQL/claims não aparece no HTML ou navegação;
28. pending desabilita repetição acidental;
29. nenhum controle de edit/unlink/re-link/delete ou pesquisa de preços é criado;
30. migrations `0001..0010` permanecem byte-for-byte;
31. F26/F29/F32/F35/F38/F41 não recebem authority nova;
32. CI, F22, F29, F32, F35, F38 e F41 continuam verdes.

## 10. Red-team obrigatório

Rejeitar PASS se:

- browser puder transformar candidate UUID em scope/authority;
- candidate for gerado no browser;
- retry técnico trocar o candidate e puder duplicar a intenção;
- Server Action executar SQL/DML próprio ou contornar F41;
- `NULL` virar vazio ou vazio virar `NULL` implicitamente;
- texto for trimado, normalizado, mascarado ou validado por regra não aprovada;
- UI introduzir taxonomia fechada ou deduplicação;
- demo/configuração inválida puder gravar;
- protected failure cair para fixture/demo;
- callback/redirect externo for controlável pelo cliente;
- feedback revelar existência ou estado protegido;
- migrations/grants/policies/capability/primitive/provisioning F41 forem alterados;
- escopo expandir para edit/unlink/re-link/delete;
- Q-003, Q-004 ou Q-009 forem resolvidas implicitamente;
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
- diff/red-team integral;
- confirmação byte-for-byte de migrations `0001..0010`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-003, Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- F41 continua sendo a única boundary de related identifier create;
- migrations aplicadas `0001..0010` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fora do escopo

- editar identificador existente;
- desvincular/re-link;
- deletar identificador;
- taxonomia fechada;
- deduplicação por valor/tipo/origem;
- importação externa;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F42 fecha quando uma pessoa autorizada em modo persistente puder criar um identificador relacionado pelo detalhe usando exclusivamente F41, com candidate UUID preparado no servidor e estável em retry, transporte explícito de `NULL`/texto, payload sem authority controlada pelo browser, feedback sanitizado, readback protegido, demo read-only e todos os gates/adversariais verdes.
