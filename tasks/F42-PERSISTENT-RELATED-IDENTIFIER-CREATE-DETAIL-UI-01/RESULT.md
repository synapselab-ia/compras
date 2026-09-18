# F42 - Resultado da criação persistente de identificador relacionado no detalhe

**Estado:** COMPLETED / PASS  
**PR de implementação:** `#67`  
**Head promovido:** `296b00a98402fa7a8dd534ea4cea9eda9b0e90cc`  
**Merge em main:** `53db535df7981f957674ca708bea7b30308992b3`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Resultado

A boundary F41 foi integrada ao detalhe persistente sem alterar a authority PostgreSQL existente.

Foram adicionados:

- Server Action dedicada `createPersistentRelatedIdentifierAction`;
- preparação server-side do `relatedIdentifierId` pelo helper F41;
- preservação do mesmo candidate somente no retry técnico `unavailable`;
- transporte explícito `null|text` para `identifierKind`, `sourceSystem` e `note`;
- formulário mínimo no painel de identificadores relacionados;
- feedback fixo e sanitizado para os quatro resultados F41;
- readback pela rota local e pelo read model persistente protegido;
- testes adversariais de action, candidate/retry, UI, demo e feedback.

O detalhe demo continua estritamente read-only.

## Contrato do browser

A Server Action aceita somente:

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

Além desses campos, somente transporte interno `$ACTION_*` do framework é tolerado e ignorado como authority.

Scalars duplicados, campos extras, IDs malformados e estados nullable inválidos falham fechado antes de F41.

O browser não fornece como authority:

- team;
- actor;
- membership;
- issuer;
- subject;
- event UUID;
- timestamps;
- `linked_at` ou `unlinked_at`;
- callback ou redirect arbitrário.

A action não executa SQL ou DML próprio e chama exclusivamente `createPersistentRelatedIdentifier(...)`.

## Candidate e idempotência

O candidate inicial é criado no servidor por `preparePersistentRelatedIdentifierCandidateId()`.

Após `created` ou `already-linked`, a intenção termina e um novo render persistente prepara outro candidate.

Após `not-available`, o candidate anterior não é reutilizado.

Após `unavailable`, o mesmo UUID validado é mantido na URL local somente para retry técnico da mesma intenção.

Um candidate válido ecoado pelo browser permanece apenas seletor técnico/idempotency key. Ele não concede scope, identidade ou autorização, que continuam validados por F41 e pelo banco.

Demo, falha protegida e detalhe indisponível não preparam nem expõem candidate de escrita.

## Semântica textual

Os campos nullable usam discriminador explícito:

```text
kind = null -> NULL
kind = text -> string exata
```

Portanto permanecem distintos:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

`identifierValue` continua aceitando string vazia e espaços conforme o contrato físico F41.

A UI/action não aplica:

- trim;
- case-folding;
- máscara;
- regex de negócio;
- catálogo fechado;
- deduplicação;
- conversão empty-to-NULL.

Q-003 permanece aberta.

## Feedback e navegação

Resultados externos aceitos:

- `created`;
- `already-linked`;
- `not-available`;
- `unavailable`.

Qualquer resultado impossível ou exceção técnica é colapsado para `unavailable`.

Navegação é sempre para a rota local fixa da contratação.

`created` e `already-linked` executam `revalidatePath` antes do redirect para que a lista seja relida pelo modelo persistente protegido.

Nenhum erro interno, SQL, claim, conexão ou motivo protegido é levado ao feedback.

## Red-team

A implementação foi rejeitada/testada contra:

- modo demo ou configuração inválida tentando escrever;
- candidate malformado;
- scalars duplicados;
- campos extras;
- team/actor/membership/issuer/subject forjados;
- event UUID, timestamps e lifecycle forjados;
- callback/redirect controlável pelo browser;
- colapso de NULL versus texto vazio;
- normalização de strings;
- resultado impossível da boundary;
- exceção técnica contendo detalhe de conexão;
- query F42 forjada em demo;
- candidate de retry malformado;
- troca automática de candidate após sucesso;
- ausência de candidate em falha protegida.

O primeiro run CI da PR encontrou somente duas falhas nos testes novos: uma asserção dependente da ordem de atributos renderizados e isolamento incompleto de aliases no teste da página. Lint e typecheck já estavam verdes. Os testes foram corrigidos sem alteração de comportamento de produção.

## Verificação

Head final `296b00a98402fa7a8dd534ea4cea9eda9b0e90cc`:

- CI `35382784877`: PASS, incluindo lint, typecheck, testes, build, banco e auth;
- F22 Private Preview Preflight `35382784984`: PASS;
- F29 Contracting Create `35382784990`: PASS;
- F32 Contracting Object Mutation `35382784911`: PASS;
- F35 Contracting Item Create `35382784957`: PASS;
- F38 Contracting Item Mutation `35382784934`: PASS;
- F41 Related Identifier Create `35382784907`: PASS.

A PR não possuía review thread pendente no fechamento.

## Imutabilidade

Nenhum arquivo de `database/migrations` ou `database/provisioning` foi alterado pela F42.

Os blobs de migrations `0001..0010` foram comparados antes da implementação e novamente no head promovido. Permaneceram byte-for-byte idênticos.

A migration `0010_related_identifier_create.sql` permaneceu com SHA:

`9a1dd6fec62181c506a5efad8d5518f53cf2e154`

O provisioning F41 `grant_related_identifier_create_runtime.sql` permaneceu com SHA:

`0f6ac20ddff00f9c547f6c99919acdef81c73e86`

## Invariantes preservados

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público tratado como superfície permanente;
- F21 permanece `ON HOLD`;
- Q-003, Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- F41 permanece a única boundary persistente de criação de identificador relacionado;
- runtime normal continua sem DML direto;
- migrations `0001..0010` permanecem imutáveis;
- falha protegida nunca vira demo fallback.
