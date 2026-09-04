# Next Action — Compras

## F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01 — Fechar desenho de controle de abuso do sign-in privado

**Classe:** `T0 — design/spike` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** decidir e documentar uma fronteira distribuída, fail-closed e testável para limitar abuso do Server Action de sign-in privado antes de qualquer exposição mais ampla, sem realizar writes hosted e sem alterar a proteção externa vigente.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F22 transformou o bootstrap/seed/smoke do futuro preview persistente em assets determinísticos e integralmente reproduzíveis em PostgreSQL efêmero/CI. Ela também provou que autenticação continua separada de autorização, que cross-team permanece invisível e que as roles Auth/domínio continuam isoladas.

A F21 continua `ON HOLD` antes de secrets porque a superfície Vercel autenticada disponível na sessão ainda não oferece o readback/CRUD obrigatório de Deployment Protection/bypasses e sensitive Preview environment variables escopadas à branch. Portanto F21 não deve ser retomada por conveniência.

Resta uma frente independente já explicitamente fora do escopo da F22: controle de abuso/rate limiting do sign-in. O runtime privado chama Better Auth por API server-side através de Server Action estreita; antes de ampliar exposição, a arquitetura precisa decidir onde o limite distribuído vive, como identifica a origem confiável e qual é o comportamento quando o controle fica indisponível.

## Execução obrigatória

1. recuperar estado/contexto e confirmar F22 integrada/verde e F21 ainda `ON HOLD` pelo mesmo `resume_when`;
2. revalidar documentação oficial atual de Better Auth e Vercel relevante a rate limiting, Server Actions, proxy/origin e proteção de deployment;
3. inspecionar `src/server/auth/private-admission.ts`, configuração Better Auth, ADR-007, ADR-009 e fronteira Vercel atual;
4. modelar ameaças de credential stuffing, password guessing, burst concorrente, enumeração de email, origem/IP forjada e múltiplas instâncias serverless;
5. rejeitar como solução final qualquer limiter apenas em memória de uma instância;
6. comparar alternativas distribuídas compatíveis com a arquitetura atual, incluindo camada de edge/provider e store compartilhado, sem provisionar recursos nesta work unit;
7. definir quais sinais podem ser confiados pelo servidor e quais headers/identificadores do cliente não podem definir a chave de segurança;
8. definir política de chaveamento, janelas/limites, resposta genérica, privacidade/retention e ausência de enumeração de contas;
9. definir fail-closed/fail-safe explicitamente para indisponibilidade do limiter e como evitar bypass silencioso;
10. definir observabilidade sanitizada sem email bruto, senha, cookie, token, connection string, IP desnecessário ou payload de sessão;
11. definir testes unitários, concorrência, múltiplas instâncias e red-team necessários para a futura implementação;
12. registrar a decisão em ADR nova ou atualizar a decisão arquitetural adequada sem reescrever histórico aceito;
13. produzir uma SPEC executável para a implementação escolhida;
14. revisar diff, rodar validações aplicáveis e atualizar checkpoint deixando exatamente uma nova ação.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- nenhum dado/identidade real;
- nenhum secret em Git/chat/log/artifact;
- nenhum recurso Vercel/Neon/terceiro provisionado;
- Vercel Authentication existente não é reduzida;
- signup normal continua fechado;
- `/api/auth/[...path]` continua deny-all;
- sign-in continua Server Action estreita;
- autenticação continua separada de autorização;
- RLS permanece autoritativa;
- headers controláveis pelo browser não podem se tornar identidade/escopo confiável;
- erro protegido não pode cair silenciosamente para demo ou para sign-in sem limitação;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo ser satisfeito.

## Fonte da tarefa

Executar `tasks/F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01/SPEC.md`, usando ADR-007, ADR-009, `docs/architecture/SECURITY.md`, `docs/architecture/DATABASE.md`, o runtime Auth atual e evidência externa oficial revalidada.

## Critério de encerramento

F23 fecha quando existir uma decisão arquitetural explícita, adversarialmente revisada e implementável para controle distribuído de abuso do sign-in, com política de confiança/falha/privacidade/testes definida e exatamente uma próxima ação executável para materializar a decisão. Nenhum provider hosted deve ser alterado nesta work unit.
