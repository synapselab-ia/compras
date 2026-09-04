# F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01 — Fechar desenho de controle de abuso do sign-in privado

**Classe:** T0 — design/spike, com impacto T2 — segurança  
**Estado:** PLANNED / NEXT  
**Dependências:** F14, F20, F22, F21 ON HOLD, ADR-007 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O sign-in privado é deliberadamente estreito: entra por Server Action, usa Better Auth self-hosted server-side, mantém signup fechado e não expõe o catch-all Auth. Essa fronteira já impede várias superfícies laterais, mas não resolve sozinha abuso de tentativas de autenticação.

A arquitetura precisa decidir onde vive um controle distribuído de tentativas e quais sinais podem ser tratados como confiáveis em ambiente serverless. Um limiter apenas em memória de uma instância não é suficiente; aceitar IP/header arbitrário do browser como chave de segurança também não é aceitável.

F21 continua `ON HOLD` por capacidade de control plane Vercel ausente na sessão. F23 é trabalho independente e não deve provisionar nem alterar providers hosted.

## Resultado esperado

Produzir uma decisão arquitetural implementável para controle de abuso do sign-in privado que:

1. seja distribuída entre múltiplas instâncias de aplicação;
2. preserve a barreira Vercel Authentication já existente;
3. não reabra signup/catch-all/OAuth/OTP/Admin;
4. não confie em identidade, equipe, email ou IP arbitrariamente fornecido pelo cliente;
5. não revele existência de conta por mensagens/timing deliberadamente distintos;
6. defina limites/janelas/chaves e comportamento concorrente;
7. defina comportamento explícito quando o limiter/store estiver indisponível;
8. minimize dados armazenados e defina retenção/privacidade;
9. produza observabilidade sanitizada;
10. tenha plano de teste adversarial e rollback.

## Inspeção obrigatória

Ler diretamente:

- `src/server/auth/private-admission.ts`;
- `src/server/auth/runtime.ts`;
- `src/server/auth/configuration.ts`;
- `docs/decisions/ADR-007-private-auth-admission.md`;
- `docs/decisions/ADR-009-self-hosted-better-auth.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- checkpoint F22/F21 vigente.

Revalidar documentação oficial atual de Better Auth e Vercel antes de assumir comportamento de rate limiting, headers/proxy, Deployment Protection ou Server Actions.

## Ameaças mínimas

O desenho deve cobrir explicitamente:

- password guessing dirigido a uma conta;
- credential stuffing em múltiplas contas;
- bursts concorrentes;
- distribuição entre múltiplas instâncias serverless;
- tentativa de rotação/forja de headers de origem;
- enumeração de conta;
- bypass por falha do store/limiter;
- DoS provocado por chaveamento mal escolhido;
- retenção indevida de email/IP;
- logs contendo credenciais ou payloads de sessão.

## Alternativas mínimas a comparar

Sem provisionar nada nesta work unit, comparar pelo menos:

1. controle em edge/provider antes da aplicação;
2. limiter distribuído apoiado em store compartilhado;
3. composição das duas camadas quando fizer sentido.

Uma solução apenas process-local/in-memory deve ser tratada como insuficiente para enforcement distribuído, podendo no máximo ser otimização auxiliar não autoritativa.

Para cada alternativa registrar:

- confiança nos sinais de origem;
- atomicidade/concurrency;
- latência e disponibilidade;
- fail-closed/fail-safe;
- privacidade e retenção;
- custo/complexidade operacional;
- testabilidade local/CI;
- rollback;
- dependência de provider.

## Decisões obrigatórias

A ADR resultante deve definir:

- camada(s) autoritativa(s) de enforcement;
- chave(s) do limiter e origem confiável dos sinais;
- janelas/limites iniciais e como serão parametrizados;
- política para sucesso, falha de credencial e indisponibilidade;
- resposta externa genérica para evitar enumeração;
- tratamento de concorrência/atomicidade;
- minimização, hashing/pseudonimização quando aplicável e retenção;
- observabilidade sanitizada;
- comportamento de rollback;
- quais partes podem ser provadas em CI sem provider;
- quais readbacks externos serão exigidos antes de declarar proteção hosted.

## Red-team obrigatório

Rejeitar a decisão se qualquer um ocorrer:

- limiter autoritativo somente em memória local;
- header arbitrário do browser define sozinho a chave confiável;
- email bruto/senha/cookie/token/session payload é logado;
- mensagens externas distinguem conta existente de inexistente de forma deliberada;
- falha do limiter permite bypass silencioso sem decisão explícita;
- uma única identidade atacante consegue bloquear globalmente todos os usuários por desenho trivial;
- signup/catch-all é reaberto para aproveitar rate limiting do provider/Auth;
- proteção Vercel é removida;
- solução exige secret no repositório/chat;
- recurso hosted é criado nesta work unit;
- Managed Neon Auth é reintroduzido;
- autorização de domínio/RLS é alterada sem necessidade.

## Verificação obrigatória

- documentação oficial externa revalidada e fontes registradas no material de decisão;
- threat model explícito;
- alternativas comparadas;
- confiança de headers/origem explicitada;
- política de falha e concorrência definida;
- privacidade/retenção definida;
- red-team documentado;
- ADR criada/atualizada;
- SPEC da implementação seguinte criada;
- lint/test/build somente se código executável for alterado;
- revisão integral do diff;
- nenhum hosted write;
- `REAL_DATA_ALLOWED = NO`;
- exatamente uma nova `NEXT_ACTION` ao fechar.

## Fora do escopo

- provisionar store/limiter/Firewall;
- alterar Deployment Protection;
- environment variables hosted;
- retomar F21;
- alterar schema Auth/domínio;
- criar dados/usuários reais;
- produção;
- onboarding institucional definitivo.

## Critério de encerramento

F23 fecha quando o repositório contiver uma decisão arquitetural explícita e implementável para controle distribuído de abuso do sign-in privado, acompanhada de threat model, red-team, estratégia de testes/rollback e uma única próxima ação de implementação. F21 continua `ON HOLD` até seu `resume_when` externo.
