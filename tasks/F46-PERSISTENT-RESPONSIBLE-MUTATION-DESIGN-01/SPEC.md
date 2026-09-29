# F46-PERSISTENT-RESPONSIBLE-MUTATION-DESIGN-01 - Desenhar edição persistente do responsável interno

**Classe:** T2 - banco/segurança, design-only  
**Estado:** READY / NEXT após F45  
**Dependências:** F45, diretório mínimo da equipe, ADR-003, ADR-004, ADR-005, ADR-011 a ADR-017  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A Central do Setor precisa responder quem é responsável por cada contratação. O modelo já contém `contractings.responsible_membership_id` e o read model já apresenta responsável, mas ainda não existe uma boundary de escrita específica, auditável e least-privilege para alterar esse vínculo.

## Objetivo

Produzir o desenho canônico da menor mutation persistente de responsável interno, com optimistic concurrency, autorização no banco, auditoria atômica e resultados opacos. Esta frente não implementa migration, primitive, adapter, Server Action ou UI.

## Questões que o desenho deve resolver

1. qual payload mínimo entra na futura boundary;
2. como representar expected/current e new responsible membership, inclusive nulidade já permitida pelo modelo;
3. quais memberships podem ser candidatas sem criar authority controlada pelo browser;
4. como impedir atribuição cross-team e membership revogada;
5. como o guard pilot-only vigente se aplica sem resolver Q-009;
6. precedência entre conflict, unchanged, denied/not-available e invalid candidate;
7. event type e shape de auditoria;
8. atomicidade entre alteração e evento;
9. least privilege e capability dedicada;
10. comportamento concorrente e rollback;
11. resultado externo sanitizado e não enumerável;
12. quais testes SQL/adversariais serão obrigatórios na implementação F47.

## Fora do escopo

- código de produção;
- migration;
- mudança de responsável em UI;
- etapa;
- status;
- waiting;
- próxima ação;
- política multiusuário definitiva;
- resolução de Q-009;
- provider hosted;
- dados reais.

## Entregáveis

- `docs/decisions/ADR-018-persistent-responsible-mutation.md`;
- `tasks/F47-PERSISTENT-RESPONSIBLE-MUTATION-IMPLEMENT-01/SPEC.md`;
- red-team documentado;
- checkpoint atualizado com exatamente uma nova NEXT_ACTION.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- migrations `0001..0011` imutáveis;
- autenticação não é autorização;
- browser nunca define team/actor/issuer/subject;
- membership candidata nunca é prova de autorização;
- runtime normal continua sem DML direto;
- nenhuma decisão aberta é resolvida silenciosamente.
