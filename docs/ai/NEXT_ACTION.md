# Next Action — Compras

## F25-FIRST-PERSISTENT-MUTATION-DESIGN-01 — Definir a primeira mutação persistente rastreável

**Classe:** `T5 — decisão arquitetural pequena` com impacto `T2 — banco/segurança`  
**Estado:** READY  
**Objetivo:** fechar uma ADR pequena e executável para a primeira escrita persistente de `contractings.next_action`, preservando autorização pilot-only, atomicidade estado+evento, concorrência e fail-closed sem resolver Q-009 por inferência.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F24 implementou e provou a camada application-side distribuída de proteção do sign-in privado definida pela ADR-010:

- limiter PostgreSQL compartilhado em namespace isolado `auth_guard`;
- `compras_auth_runtime` somente com `USAGE/EXECUTE` no primitive estreito, sem DML direto/ownership/BYPASSRLS;
- buckets `source` 120/15 min, `identifier` 20/15 min e `pair` 8/5 min;
- consumo atômico usando relógio PostgreSQL;
- HMAC/HKDF com domain separation sem persistir email/IP em claro;
- origem hosted restrita a `x-forwarded-for` Vercel único e IP válido;
- limiter bloqueado -> `rejected`; limiter/config/store indisponível -> `unavailable`;
- Better Auth não é chamado quando o limiter bloqueia ou falha;
- concorrência real em PostgreSQL 17 comprovada sem `allow` acima do limite;
- signup/catch-all/Auth/RLS existentes permaneceram fechados e em PASS.

O head funcional F24 `3291a62f57b350edf8b882ec08cc2655ed54d99d` passou:

- CI `34476876653`: PASS (`verify`, `database`, `auth-database`);
- F22 Private Preview Preflight `34476876664`: PASS.

F21 continua `ON HOLD` porque seu `resume_when` externo ainda não foi satisfeito. A próxima frente independente útil é preparar a primeira mutação persistente do núcleo, sem depender de provider hosted.

## Execução obrigatória

1. recuperar estado/contexto e confirmar F24 integrada antes de editar;
2. ler diretamente `SECURITY.md`, `DATABASE.md`, ADR-003, ADR-005, ADR-009, migrations e testes de identidade/RLS;
3. confirmar no schema atual `contractings.next_action` e `contracting_events`;
4. revisar Q-009 e não inferir permissão multiusuário a partir de membership;
5. usar `next_action` como primeiro caso concreto de escrita, sem ampliar para etapa/status/responsável;
6. comparar transação server-side versus primitive PostgreSQL estreita;
7. definir como identidade/session -> app_user -> membership autorizada sem parâmetros confiáveis do browser;
8. avaliar guard de piloto individual que falhe fechado se houver segundo membro ativo no escopo;
9. definir atomicidade de update de estado + evento append-only;
10. definir estratégia explícita contra lost update/concorrência;
11. definir semântica mínima do evento sem criar taxonomia ampla;
12. definir grants/roles mínimos e rollback;
13. definir matriz de testes adversariais para a implementação seguinte;
14. produzir ADR versionada, red-team e CI;
15. revisar diff e deixar exatamente uma nova `NEXT_ACTION`.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- autenticação não é autorização;
- browser não escolhe `team_id`, `membership_id` ou actor confiável;
- membership por si só não resolve Q-009;
- estado rastreável e evento devem ser atômicos;
- `contracting_events` permanece append-only;
- sem CRUD amplo como atalho;
- runtime normal sem superuser/BYPASSRLS/ownership/CREATEROLE;
- migrations aplicadas não são reescritas;
- stage/status/taxonomias abertas não são congeladas nesta work unit.

## Fonte da tarefa

Executar `tasks/F25-FIRST-PERSISTENT-MUTATION-DESIGN-01/SPEC.md` seguindo `PROJECT_DESIGN.md`, `DOMAIN_MODEL.md`, `BUSINESS_WORKFLOW.md`, `OPEN_QUESTIONS.md`, `SECURITY.md`, `DATABASE.md` e as ADRs já aceitas.

## Critério de encerramento

F25 fecha quando existir uma ADR aceita e suficiente para implementar depois a primeira mutação persistente de `next_action`, com autorização pilot-only sem inferir Q-009, atomicidade estado+evento, concorrência explicitamente tratada, plano de testes adversariais e toda CI em PASS. Ao final deve existir exatamente uma nova `NEXT_ACTION` executável.