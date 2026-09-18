# Next Action - Compras

## F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01 - Implementar vínculo persistente mínimo de identificador relacionado

**Classe:** T2 - banco/segurança  
**Estado:** READY após integração da F40  
**Objetivo:** implementar ADR-016 com uma capability persistente dedicada para criar/vincular `related_identifiers`, registrar auditoria atômica, reconhecer replay seguro por UUID preparado e preservar least privilege, sem UI ou Server Action nesta slice.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F40 integrou ADR-016 e fechou o desenho da primeira boundary de escrita para processos/identificadores relacionados.

O schema e a leitura protegida de `related_identifiers` já existem. O próximo gap pequeno e independente é materializar a operação server/database antes de expor qualquer jornada de UI.

A frente é independente de F21, não depende de pesquisa de preços e não resolve Q-003 nem Q-009.

## Execução obrigatória

1. recuperar `main` real e confirmar F40 integrada pela PR `#63`, merge `9463aab5dbfbda5b1c037b622ddb83859600253e`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente `docs/decisions/ADR-016-minimal-persistent-related-identifier-creation.md`;
4. executar `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/SPEC.md`;
5. confirmar migrations `0001..0009` byte-for-byte antes de editar;
6. criar somente migration aditiva `0010` ou equivalente ordenável;
7. criar capability dedicada de related identifier create;
8. criar apenas policies/grants estreitos necessários à nova capability;
9. materializar primitive `SECURITY DEFINER` com `search_path = pg_catalog` e `PUBLIC EXECUTE` revogado;
10. manter runtime normal sem DML direto;
11. criar provisioning separado que conceda somente `EXECUTE` da primitive;
12. criar adapter server-only com contrato estrito da ADR-016;
13. preservar `NULL`, vazio e espaços exatamente, sem trim ou normalização;
14. não criar unicidade/deduplicação por identificador, tipo, origem ou combinação;
15. implementar replay `already-linked` somente após autorização atual e prova exata da row ativa + exatamente um evento canônico;
16. garantir atomicidade entre row e evento `related_identifier_linked`;
17. tratar concorrência de mesmo UUID sem retry cego;
18. manter cross-team, inexistente, inativo, membership inválida e colisão não equivalente sem oracle;
19. criar testes SQL adversariais e prova PostgreSQL concorrente real;
20. criar testes unitários do adapter e workflow F41;
21. executar gates e regressões F22/F29/F32/F35/F38;
22. fazer red-team integral de grants, RLS, authority, replay e atomicidade;
23. confirmar migrations `0001..0009` imutáveis;
24. promover somente depois dos gates aplicáveis verdes;
25. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se:

- browser puder definir team, actor, membership, issuer, subject, timestamps ou event UUID como authority;
- `relatedIdentifierId` conceder scope ou autorização;
- runtime normal ganhar DML direto;
- a capability puder editar, desvincular ou excluir identificador existente;
- F26/F29/F32/F35/F38 ganharem authority adicional;
- contratação cross-team, arquivada ou cancelada aceitar vínculo;
- segundo membro não revogado for tratado como política multiusuário resolvida;
- texto for trimado, normalizado, mascarado ou validado por regra não documentada;
- `NULL`, vazio e espaços forem colapsados;
- existir deduplicação por número/tipo/origem sem requisito canônico;
- replay aceitar row desvinculada;
- replay aceitar row sem exatamente um evento canônico `related_identifier_linked`;
- replay aceitar payload diferente pela mesma PK;
- colisão de event UUID virar replay-success;
- evento de vínculo não for atômico;
- `contractings.updated_at` for alterado apenas para representar timeline;
- migrations `0001..0009` forem reescritas;
- Q-003, Q-004 ou Q-009 forem resolvidas implicitamente;
- falha protegida cair para demo;
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
- migrations aplicadas `0001..0009` permanecem imutáveis;
- falha protegida nunca vira demo fallback;
- F41 não inclui UI nem Server Action.

## Fonte da tarefa

Executar `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/SPEC.md`.

## Critério de encerramento

F41 fecha quando a criação persistente mínima de `related_identifiers` estiver implementada e provada contra a matriz adversarial da ADR-016, com row + evento atômicos, idempotência segura por UUID preparado, capability least-privilege, resultados sanitizados e regressões aplicáveis verdes, sem UI nesta slice.
