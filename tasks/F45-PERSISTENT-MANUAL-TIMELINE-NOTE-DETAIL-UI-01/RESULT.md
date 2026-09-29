# F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01 - Resultado

**Estado:** CONCLUÍDA E INTEGRADA  
**PR:** #73  
**Head validado:** `e5236dbbeef4fcb8bf2d568f37c2495e41a09f1a`  
**Merge em main:** `0800553d95bddc8d4f2febe29f418dd543c1c659`

## Entrega

F45 integrou a boundary F44 ao detalhe persistente sem ampliar authority PostgreSQL.

Foram adicionados:

- Server Action dedicada para `contractingId`, `eventId`, `noteKind` e `note`;
- validação fail-closed de campos extras, duplicados e UUIDs candidatos;
- transporte explícito `null|text` sem trim, empty-to-NULL ou normalização;
- candidate `eventId` preparado server-side e preservado somente em retry técnico `unavailable`;
- feedback fixo e sanitizado para `created`, `already-added`, `not-available` e `unavailable`;
- formulário mínimo de nota manual somente no detalhe persistente;
- revalidação local e confirmação pela timeline do read model protegido;
- testes adversariais de action, feedback, candidate/retry, página, componente e demo.

F45 não alterou migration, grant, policy, capability, primitive ou provisioning F44.

## Red-team

A revisão adversarial confirmou:

- candidate UUID não define scope nem authority;
- browser não gera candidate;
- retry técnico não troca candidate;
- Server Action não executa SQL/DML próprio;
- team, actor, membership, issuer, subject, event type, timestamps e shape estrutural não atravessam o payload;
- callback/redirect arbitrário não é aceito;
- `NULL`, vazio, spaces-only e espaços de borda permanecem distintos;
- não existe deduplicação por conteúdo;
- demo e falha protegida não ganham caminho de write;
- não existe edição/exclusão de evento, categoria, prioridade ou Pendência.

O diff final contém somente arquivos de UI/action/teste da F45. Migrations `0001..0011` permaneceram fora do diff e, portanto, byte-for-byte imutáveis.

## Verificação

No head final `e5236dbbeef4fcb8bf2d568f37c2495e41a09f1a`:

- CI: PASS;
- F22 Private Preview Preflight: PASS;
- F29 Contracting Create: PASS;
- F32 Contracting Object Mutation: PASS;
- F35 Contracting Item Create: PASS;
- F38 Contracting Item Mutation: PASS;
- F41 Related Identifier Create: PASS;
- F44 Manual Timeline Note Create: PASS.

CI inclui lint, typecheck, testes e build. Não havia review thread pendente na PR #73.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- F21 permanece ON HOLD;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- runtime normal continua sem DML direto;
- F44 continua sendo a única boundary persistente de criação de nota manual;
- migrations `0001..0011` permanecem imutáveis;
- falha protegida nunca vira demo fallback.
