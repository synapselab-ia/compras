# Next Action — Compras

## F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01 — Desenhar criação persistente mínima de contratação

**Classe:** `T5 — decisão/arquitetura` com impacto `T2 — autorização/banco`  
**Estado:** READY  
**Objetivo:** definir por ADR a fronteira mínima, pilot-only, auditável e idempotente para criar uma nova `contracting`, sem abrir CRUD genérico nem resolver silenciosamente Q-001/Q-002/Q-006/Q-009.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

F26/F27 fecharam a primeira escrita persistente útil: uma pessoa autorizada consegue alterar somente `Próxima ação` no detalhe, com estado+evento atômicos e runtime sem DML direto.

O próximo gap do núcleo funcional descrito em `PROJECT_DESIGN.md` é o cadastro de contratação. Porém criação não possui uma linha pré-existente da qual derivar `team_id`, e taxonomias/permissões relevantes continuam abertas. Implementar diretamente criaria risco de inventar escopo, actor, evento ou regras de formulário.

F28 deve fechar somente o desenho antes da implementação.

F21 continua `ON HOLD` sob seu `resume_when` externo e não é dependência da F28.

## Execução obrigatória

1. recuperar `main`, confirmar F27 integrada/verde e revalidar `CONTEXT_MANIFEST`;
2. inspecionar PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, OPEN_QUESTIONS, SECURITY, DATABASE, ADR-003/005/009/011, migrations `0001..0004` e boundary F26/F27;
3. definir o payload mínimo de criação sem tornar stage/status/responsável/waiting obrigatórios por inferência;
4. decidir explicitamente se `next_action` pode nascer na criação ou continua em mutação posterior;
5. definir como team/actor/created_by são derivados exclusivamente da identidade confiável + banco;
6. preservar Q-009 com regra pilot-only e falha fechada para escopo ambíguo/multi-member;
7. decidir capability/grants mínimos mantendo runtime sem `INSERT` direto amplo;
8. definir evento inicial atômico e rollback inseparável;
9. definir geração de IDs e comportamento de idempotência/double-submit/retry;
10. definir estados externos sanitizados e matriz PostgreSQL adversarial;
11. registrar a decisão em nova ADR e criar a SPEC executável da implementação seguinte;
12. fazer red-team documental, executar gates aplicáveis e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/exemplos fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 não são resolvidas silenciosamente;
- autenticação não é autorização;
- RLS permanece autoritativa;
- runtime normal continua sem CRUD amplo;
- migrations `0001..0004` permanecem imutáveis;
- F26/F27 continuam sendo a única escrita executável integrada durante esta work unit;
- falha protegida nunca vira demo fallback.

## Fonte da tarefa

Executar `tasks/F28-PERSISTENT-CONTRACTING-CREATE-DESIGN-01/SPEC.md` seguindo as fontes canônicas e ADRs listadas na SPEC.

## Critério de encerramento

F28 fecha quando a criação persistente mínima tiver uma ADR suficientemente precisa para implementação e testes adversariais, incluindo payload, derivação de escopo/ator, capability, evento e idempotência, sem inventar regras de negócio abertas e com exatamente uma nova `NEXT_ACTION`.
