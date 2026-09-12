# F31-PERSISTENT-CONTRACTING-OBJECT-MUTATION-DESIGN-01 — Desenhar edição persistente do objeto

**Classe:** T2 — fronteira de autorização e mutação persistente  
**Estado:** PLANNED / NEXT  
**Dependências:** F25, F26, F27, F29, F30, ADR-011 e ADR-012  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

Após F30, a aplicação passa a permitir criar uma contratação persistente com `object`, mas esse campo ainda não possui uma boundary específica de edição. O núcleo funcional inicial prevê cadastro e edição de contratação, porém não é aceitável ampliar F26, reutilizar a capability de criação ou conceder `UPDATE` amplo por conveniência.

A próxima decisão precisa definir a menor mutação segura para alterar exclusivamente `contractings.object`, mantendo autorização pilot-only, RLS autoritativa, histórico atômico e Q-009 aberta.

## Objetivo

Produzir a decisão arquitetural canônica para uma futura edição persistente de `object`, sem implementar migration, SQL, Server Action ou UI nesta slice.

## Execução obrigatória

1. recuperar o estado canônico após F30 e revalidar `CONTEXT_MANIFEST`;
2. inspecionar ADR-011, ADR-012, F25/F26/F27, F29/F30, `SECURITY.md`, `DATABASE.md`, schema/migrations e testes de mutação existentes;
3. confirmar que migrations aplicadas permanecem imutáveis;
4. definir explicitamente a fronteira de confiança da edição de `object`;
5. decidir o payload mínimo, incluindo mecanismo de concorrência otimista compatível com o padrão já adotado, sem confiar team, actor, membership, issuer ou subject vindos do browser;
6. preservar a semântica já aprovada de `object`: string persistida exatamente, sem trim, limite de tamanho, regra non-empty ou coerção para `NULL` inventados;
7. definir autorização pilot-only sem resolver Q-009 como política multiusuário;
8. definir como estado atual e evento auditável serão atualizados atomicamente;
9. definir least privilege da futura capability sem ampliar F26 nem F29;
10. definir resultados externos sanitizados e tratamento de conflito/negação/falha sem oracle cross-team;
11. definir matriz adversarial mínima, rollback e propriedades de idempotência/concorrência aplicáveis;
12. registrar a decisão em nova ADR e atualizar somente documentação canônica necessária;
13. não implementar migration, primitive, adapter, Server Action ou UI nesta work unit;
14. executar red-team documental, verificar consistência com SECURITY/DATABASE e deixar exatamente uma nova `NEXT_ACTION` de implementação somente se a decisão ficar fechada.

## Red-team obrigatório

Rejeitar PASS se o desenho:

- permitir ao browser escolher team, actor, membership ou creator confiável;
- reutilizar F26/F29 sem provar least privilege e isolamento de autoridade;
- conceder DML direto amplo ao runtime;
- permitir mutação sem evento atômico;
- transformar string vazia em `NULL`, aplicar trim ou criar validação de conteúdo sem fonte canônica;
- inferir política multiusuário e encerrar Q-009 silenciosamente;
- revelar existência cross-team por conflito ou erro;
- exigir provider hosted, secret ou dado real;
- reescrever migrations aplicadas.

## Verificação

- consistência com ADR-011 e ADR-012;
- consistência com `SECURITY.md` e `DATABASE.md`;
- comparação explícita de alternativas e autoridade concedida;
- matriz de confiança/autorização/concorrência;
- diff documental sem dado real;
- exatamente uma nova `NEXT_ACTION` ao encerrar.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-006/Q-009 continuam abertas salvo decisão explícita e necessária;
- autenticação não é autorização;
- RLS/capabilities continuam autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas permanecem imutáveis;
- F26 continua exclusiva de `next_action`;
- F29 continua exclusiva de criação mínima.

## Fora do escopo

- implementação PostgreSQL;
- Server Action/UI de edição;
- edição de `next_action`;
- stage/status/responsável/waiting;
- itens e identificadores relacionados;
- arquivamento/cancelamento;
- política multiusuário;
- provider hosted;
- retomada F21;
- dado real.

## Critério de encerramento

F31 fecha quando existir uma ADR suficiente para implementar, em work unit posterior, uma mutação exclusiva de `object` com payload mínimo, autorização pilot-only, concorrência definida, evento atômico, least privilege e resultados sanitizados, sem alterar código operacional nesta slice.
