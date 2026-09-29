# F45-PERSISTENT-MANUAL-TIMELINE-NOTE-DETAIL-UI-01 - Resultado

**Estado:** CONCLUÍDA E INTEGRADA  
**PR:** #73  
**Head validado:** `e5236dbbeef4fcb8bf2d568f37c2495e41a09f1a`  
**Merge em main:** `0800553d95bddc8d4f2febe29f418dd543c1c659`  
**Revisão pós-integração:** PR #75  
**Head validado da revisão:** `36157c0e78783789e0d7f69700e2cb55686e4030`  
**Merge da revisão em main:** `60bcd9b7c86788f87d6dc76d8eec07a27611e59a`

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


## Revisão pós-integração da F45

Uma segunda revisão adversarial identificou duas lacunas de qualidade sem impacto na authority ou na persistência:

- o seletor permitia escolher `Ausente (NULL)`, mas o `textarea` continuava visível;
- a suíte de página/action não materializava individualmente todos os cenários de candidate/retry exigidos pela SPEC.

A PR #75 fechou ambas sem alterar a boundary F44.

Na UI, `ManualTimelineNoteEditor` passou a manter o `noteKind` como estado explícito. O campo `note` só é renderizado no modo `Texto`. Em `Ausente (NULL)`, nenhum scalar de texto é submetido, e a Server Action continua convertendo o transporte exatamente para `note = null`.

A cobertura adversarial foi ampliada para provar explicitamente:

- candidate novo após `created`, `already-added` e `not-available`;
- preservação do mesmo candidate somente em `unavailable`;
- descarte de candidate malformado;
- query state duplicado sem ganhar semântica de retry;
- ausência de candidate/feedback em demo;
- ausência de candidate quando a leitura protegida está indisponível;
- modo não persistente sem chamada à F44;
- UUIDs candidatos malformados rejeitados antes da boundary;
- transporte nullable inválido rejeitado antes da boundary;
- `NULL` sem scalar `note`;
- payloads duplicados ou browser-controlled adicionais rejeitados;
- `already-added` como sucesso idempotente com revalidação;
- erro interno, resultado impossível, SQL/connection string/claims não vazando para feedback.

O primeiro CI da revisão falhou somente em uma nova fixture de teste: usar `undefined` como segundo argumento acionava o valor default da função auxiliar e criava acidentalmente um campo `note`. A fixture foi corrigida para usar um sentinela explícito de ausência. Nenhum código de produção precisou ser alterado por essa falha.

No head final `36157c0e78783789e0d7f69700e2cb55686e4030`:

- CI: PASS;
- F22 Private Preview Preflight: PASS;
- F29 Contracting Create: PASS;
- F32 Contracting Object Mutation: PASS;
- F35 Contracting Item Create: PASS;
- F38 Contracting Item Mutation: PASS;
- F41 Related Identifier Create: PASS;
- F44 Manual Timeline Note Create: PASS.

Não havia review thread pendente na PR #75.

O diff da revisão contém somente três arquivos da F45, sendo UI e testes. Migrations `0001..0011`, grants, policies, capability, primitive e provisioning permaneceram imutáveis.

## Invariantes preservadas

- `REAL_DATA_ALLOWED = NO`;
- F21 permanece ON HOLD;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- runtime normal continua sem DML direto;
- F44 continua sendo a única boundary persistente de criação de nota manual;
- migrations `0001..0011` permanecem imutáveis;
- falha protegida nunca vira demo fallback.
