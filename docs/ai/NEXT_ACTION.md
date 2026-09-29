# Next Action - Compras

## F46-PERSISTENT-RESPONSIBLE-MUTATION-DESIGN-01 - Desenhar edição persistente do responsável interno

**Classe:** T2 - banco/segurança, em fase de desenho  
**Estado:** READY após integração da F45  
**Objetivo:** definir a menor boundary persistente e auditável para alterar o responsável interno de uma contratação, sem implementar código de produção nesta frente e sem resolver silenciosamente a política multiusuário aberta em Q-009.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

O núcleo funcional inicial exige responder rapidamente quem é responsável por cada contratação. O read model já apresenta responsável interno e o diretório mínimo da equipe já existe, mas ainda não há contrato canônico de escrita para `contractings.responsible_membership_id`.

Após F45, as slices de objeto, próxima ação, itens, identificadores e nota manual já possuem boundaries persistentes estreitas. O próximo gap operacional de alto valor é desenhar a troca de responsável sem antecipar etapa/status/waiting, sem abrir DML genérico e sem assumir política multiusuário ainda não decidida.

## Execução obrigatória

1. recuperar `main` real e confirmar F45 integrada pela PR `#73`, merge `0800553d95bddc8d4f2febe29f418dd543c1c659`;
2. revalidar `CONTEXT_MANIFEST`;
3. ler integralmente `PROJECT_DESIGN.md`, `DOMAIN_MODEL.md`, `BUSINESS_WORKFLOW.md`, `OPEN_QUESTIONS.md`, ADR-003, ADR-004, ADR-005, ADR-011 a ADR-017 e resultados F26/F32/F38/F41/F45;
4. inspecionar schema, constraints, RLS, read model e apresentação atuais de `responsible_membership_id`;
5. confirmar migrations `0001..0011` imutáveis;
6. mapear estados existentes: responsável nulo, membership ativa/revogada, app_user ativo/inativo, cross-team e target arquivado/cancelado;
7. definir payload mínimo, expected value para optimistic concurrency e resultado externo sanitizado;
8. manter team, actor, issuer, subject e membership do ator derivados de contexto confiável;
9. tratar o responsável solicitado apenas como candidato, nunca como authority;
10. definir autorização compatível com o guard pilot-only vigente sem decidir Q-009;
11. definir auditoria atômica e event type/shape necessários sem criar primitive genérica de evento;
12. definir semântica de limpar responsável, somente se já estiver sustentada pelo schema/modelo canônico; caso contrário registrar decisão necessária;
13. definir comportamento de conflict/unchanged/not-available/unavailable e precedência;
14. definir concorrência, replay e rollback;
15. definir least privilege, capability dedicada, primitive SECURITY DEFINER e provisioning futuro;
16. fazer red-team de cross-team assignment, membership revogada, confused deputy, lost update, enumeração e vazamento por feedback;
17. produzir ADR-018 com a decisão;
18. produzir SPEC da implementação F47, sem implementá-la;
19. atualizar checkpoint deixando exatamente uma nova `NEXT_ACTION`.

## Red-team mínimo

Rejeitar PASS se o desenho:

- permitir que browser escolha team, actor ou identidade confiável;
- tratar membership candidata como prova de autorização;
- permitir atribuição cross-team;
- aceitar membership revogada sem regra explícita sustentada;
- contornar Q-009 por suposição;
- usar DML direto no runtime normal;
- abrir UPDATE genérico em `contractings`;
- omitir optimistic concurrency ou permitir lost update;
- revelar existência cross-team por resultado/erro;
- alterar migrations aplicadas;
- antecipar edição de etapa, status, waiting ou outras mutations;
- depender de provider hosted, secret ou dado real.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD` até seu `resume_when`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations `0001..0011` permanecem imutáveis;
- F46 é design-only.

## Fonte da tarefa

O desenho deve ser criado em:

`tasks/F46-PERSISTENT-RESPONSIBLE-MUTATION-DESIGN-01/SPEC.md`

e consolidado em ADR-018.

## Critério de encerramento

F46 fecha quando existir decisão arquitetural explícita e red-teamada para a mutation mínima de responsável interno, incluindo autorização, optimistic concurrency, auditoria, least privilege, semântica de nulidade e resultados opacos, sem código de produção e sem resolver Q-009 implicitamente.
