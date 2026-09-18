# Next Action - Compras

## F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01 - Integrar criação persistente de identificador relacionado no detalhe

**Classe:** T1 - feature normal, com impacto T2 - autorização/escrita server-side  
**Estado:** READY após integração da F41  
**Objetivo:** tornar a boundary F41 utilizável no detalhe persistente por uma Server Action estreita e UI mínima, com UUID preparado estável em retry, transporte explícito de NULL/texto, feedback sanitizado, readback protegido e demo read-only, sem ampliar authority PostgreSQL.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F41 integrou a criação persistente mínima de `related_identifiers` com capability dedicada, RLS, primitive, provisioning, adapter server-only, auditoria atômica e replay seguro por UUID preparado.

O read model do detalhe já lista identificadores relacionados ativos. O próximo gap pequeno e independente é expor somente essa operação existente para uma pessoa autorizada, repetindo o padrão já usado para contratação, objeto e itens, sem abrir edição, desvínculo ou CRUD genérico.

A frente é independente de F21, não depende de pesquisa de preços e não resolve Q-003 nem Q-009.

## Execução obrigatória

1. recuperar `main` real e confirmar F41 integrada pela PR `#65`, merge `d460e38a4d5a6a1ef3408d72f10ac1d8765fee63`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente ADR-016, resultado F41 e `tasks/F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01/SPEC.md`;
4. confirmar migrations `0001..0010` byte-for-byte antes de editar;
5. inspecionar F30 como precedente de UUID preparado/retry e F36/F39 como precedentes de Server Action/UI;
6. inspecionar o read model, tipos, detalhe, actions e feedbacks atuais;
7. manter migrations, grants, policies, capabilities, primitive e provisioning F41 imutáveis;
8. renderizar a jornada somente em modo persistente válido;
9. manter demo e falha protegida estritamente read-only, sem fallback;
10. gerar o `relatedIdentifierId` inicial no servidor pelo helper F41;
11. preservar o mesmo candidate em retry da mesma intenção, especialmente após `unavailable`;
12. não gerar candidate no browser e não tratá-lo como authority;
13. criar Server Action dedicada que aceite somente os campos de transporte aprovados;
14. rejeitar scalars duplicados, campos extras e callback/redirect controlável pelo cliente;
15. validar `contractingId` e `relatedIdentifierId` como candidatos UUID antes de F41;
16. chamar exclusivamente `createPersistentRelatedIdentifier`, sem SQL/DML próprio;
17. codificar explicitamente `NULL` versus texto para identifierKind, sourceSystem e note;
18. preservar `''`, spaces-only e leading/trailing spaces exatamente;
19. não aplicar trim, case-folding, máscara, regex, taxonomia fechada ou deduplicação;
20. mapear `created`, `already-linked`, `not-available` e `unavailable` apenas para feedback fixo e sanitizado;
21. revalidar/readback somente pela rota local fixa e pelo modelo protegido;
22. impedir double-submit acidental por estado pending;
23. criar testes adversariais de action, UI, candidate/retry, NULL/texto, demo e navegação;
24. executar lint, typecheck, testes, build e regressões CI/F22/F29/F32/F35/F38/F41;
25. fazer red-team integral, confirmar `0001..0010` imutáveis, promover somente com gates aplicáveis verdes e atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser puder transformar `relatedIdentifierId` em scope/authority;
- candidate for gerado no browser;
- retry técnico trocar candidate automaticamente e puder duplicar a intenção;
- Server Action executar SQL/DML próprio ou contornar F41;
- team, actor, membership, issuer, subject, event UUID, timestamps ou estado de vínculo atravessarem como authority;
- callback/redirect externo for controlável pelo cliente;
- `NULL` e string vazia forem colapsados;
- texto for trimado, normalizado, mascarado ou validado por regra não documentada;
- UI criar taxonomia fechada ou deduplicação por valor/tipo/origem;
- `not-available` revelar existência cross-team ou motivo protegido;
- `unavailable` expor SQL, claims, conexão ou erro interno;
- demo/configuração inválida puder gravar;
- falha protegida cair para fixture/demo;
- migrations `0001..0010`, grants, policies, capability, primitive ou provisioning F41 forem alterados;
- F26/F29/F32/F35/F38/F41 ganharem authority adicional;
- escopo expandir para edit/unlink/re-link/delete;
- Q-003, Q-004 ou Q-009 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público continua tratado como superfície permanente;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-003, Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0010` permanecem imutáveis;
- F41 continua sendo a única boundary de criação persistente de identificador relacionado;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F42-PERSISTENT-RELATED-IDENTIFIER-CREATE-DETAIL-UI-01/SPEC.md`.

## Critério de encerramento

F42 fecha quando uma pessoa autorizada em modo persistente puder criar um identificador relacionado pelo detalhe usando exclusivamente F41, com candidate UUID preparado no servidor e estável em retry, transporte explícito de NULL/texto, payload sem authority controlada pelo browser, feedback sanitizado, readback protegido, demo read-only e regressões aplicáveis verdes.
