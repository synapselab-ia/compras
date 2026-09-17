# Next Action - Compras

## F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01 - Desenhar vínculo persistente mínimo de identificador relacionado

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** READY após integração da F39  
**Objetivo:** definir a primeira boundary persistente para vincular um processo/identificador administrativo a uma contratação, com payload mínimo, autorização, least privilege, auditoria, concorrência/idempotência e resultados sanitizados, sem código operacional nesta slice.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F39 integrou a edição dos quatro campos mutáveis de item ao detalhe persistente e fechou o ciclo ADR-015/F37/F38/F39.

O núcleo funcional inicial também exige relacionamentos com múltiplos processos/identificadores externos. O schema e o read model de `related_identifiers` já existem e o detalhe já os apresenta, mas ainda não há boundary de escrita para criar o vínculo.

Essa frente é independente de F21, não depende de pesquisa de preços e não exige resolver Q-009.

## Execução obrigatória

1. recuperar `main` real e confirmar F39 integrada pela PR #61;
2. confirmar os seis gates pós-merge verdes em `09737ac6d11046af5d149b7926997e7e630557cc`;
3. revalidar `CONTEXT_MANIFEST`;
4. executar `tasks/F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01/SPEC.md`;
5. inspecionar schema, RLS, read model e auditoria de `related_identifiers`;
6. comparar os padrões recentes de capability e escrita F29/F32/F35/F38;
7. não alterar migrations `0001..0009`;
8. não implementar migration, policy, grant, primitive, adapter, Server Action ou UI na F40;
9. não inventar máscara, formato, unicidade de negócio, taxonomia fechada ou normalização de identificadores;
10. manter team, actor, membership, issuer, subject, timestamps e UUIDs de auditoria fora da authority do browser;
11. desenhar atomicidade entre o identificador novo e o evento de vínculo;
12. definir semântica segura de retry/concorrência sem deduplicação por valor inventada;
13. manter cross-team, contratação inexistente/inativa e falhas de membership sem oracle indevido;
14. preservar Q-004 e Q-009 abertas;
15. fazer red-team documental integral;
16. produzir uma ADR canônica e exatamente uma SPEC executável para a implementação seguinte;
17. atualizar o checkpoint apenas depois dos gates da slice de desenho ficarem verdes.

## Red-team mínimo

Rejeitar PASS se:

- browser puder definir scope, actor, membership ou UUIDs internos como authority;
- runtime normal ganhar DML direto;
- a operação futura puder vincular identificador em contratação cross-team, arquivada ou cancelada;
- texto for trimado, normalizado ou validado por regra de negócio não documentada;
- `NULL`, vazio e espaços forem colapsados sem decisão fundamentada;
- for criada deduplicação por identificador/tipo/origem sem requisito canônico;
- retry ou colisão de UUID forem tratados como sucesso sem prova exata e autorizada;
- evento de vínculo não for atômico;
- F26/F29/F32/F35/F38 ganharem authority adicional;
- migrations `0001..0009` forem reescritas;
- F21, Q-004 ou Q-009 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público continua tratado como superfície permanente;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0009` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01/SPEC.md`.

## Critério de encerramento

F40 fecha quando o vínculo persistente mínimo de `related_identifiers` estiver completamente desenhado e red-teamed, com decisão canônica para payload, autorização, least privilege, auditoria, concorrência/idempotência e resultados, e uma única SPEC de implementação seguinte pronta, sem código operacional na própria F40.
