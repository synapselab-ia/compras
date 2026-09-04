# F23-PRIVATE-SIGNIN-ABUSE-CONTROL-DESIGN-01 — Fechar desenho de controle de abuso do sign-in privado

**Classe:** T0 — design/spike, com impacto T2 — segurança  
**Estado:** DONE / PASS — PR `#39` integrada; main CI `33908077415`, preflight `33908077522`  
**Dependências:** F14, F20, F22, F21 ON HOLD, ADR-007 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O sign-in privado é deliberadamente estreito: entra por Server Action, usa Better Auth self-hosted server-side, mantém signup fechado e não expõe o catch-all Auth. Essa fronteira já impede várias superfícies laterais, mas não resolve sozinha abuso de tentativas de autenticação.

A arquitetura precisa decidir onde vive um controle distribuído de tentativas e quais sinais podem ser tratados como confiáveis em ambiente serverless. Um limiter apenas em memória de uma instância não é suficiente; aceitar IP/header arbitrário do browser como chave de segurança também não é aceitável.

F21 continua `ON HOLD` por capacidade de control plane Vercel ausente na sessão. F23 é trabalho independente e não provisionou nem alterou providers hosted.

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

Foram lidos diretamente:

- `src/server/auth/private-admission.ts`;
- `src/server/auth/runtime.ts`;
- `src/server/auth/configuration.ts`;
- `docs/decisions/ADR-007-private-auth-admission.md`;
- `docs/decisions/ADR-009-self-hosted-better-auth.md`;
- `docs/architecture/SECURITY.md`;
- `docs/architecture/DATABASE.md`;
- checkpoint F22/F21 vigente.

A documentação oficial atual de Better Auth e Vercel relevante a rate limiting, headers/proxy e Deployment Protection foi revalidada em 2026-09-04 antes da decisão.

## Ameaças cobertas

O desenho cobre explicitamente:

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

## Alternativas comparadas

Foram comparadas:

1. controle em edge/provider antes da aplicação;
2. limiter distribuído apoiado em store compartilhado;
3. composição das duas camadas.

Limiter apenas process-local/in-memory foi rejeitado como enforcement distribuído.

A ADR-010 registra para as alternativas confiança de origem, atomicidade/concurrency, disponibilidade, fail-closed, privacidade/retenção, custo operacional, testabilidade, rollback e dependência de provider.

## Decisão implementada

A ADR-010 foi criada e aceita com a seguinte fronteira:

- PostgreSQL compartilhado como limiter application-side autoritativo;
- Vercel Firewall/WAF como defesa edge complementar;
- trusted source hosted limitada a `x-forwarded-for` Vercel estrito;
- buckets HMAC `source`, `identifier` e `pair` sem email/IP em claro;
- policy inicial versionada `120/15m`, `20/15m`, `8/5m`;
- consumo atômico antes do Better Auth;
- `rejected` para limite excedido e `unavailable` para falha do limiter;
- nenhum bypass silencioso;
- retenção, observabilidade, rollback e readbacks hosted definidos.

Também foi criada `tasks/F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01/SPEC.md` para materializar somente a camada application-side em PostgreSQL descartável/CI.

Nenhum provider hosted, secret, usuário ou dado real foi criado/alterado.

## Red-team executado

Rejeitados:

- limiter autoritativo somente em memória local;
- header arbitrário do browser definindo sozinho a origem confiável;
- email bruto/senha/cookie/token/session payload em logs;
- mensagens deliberadamente distintas para conta existente/inexistente;
- fail-open do limiter;
- chave global capaz de bloquear todos os usuários;
- reabertura de signup/catch-all/OAuth/OTP/Admin;
- remoção/redução de Vercel Authentication;
- secret no repositório/chat;
- provider Redis/KV/Neon/Vercel novo nesta unidade;
- Managed Neon Auth reintroduzido;
- alteração desnecessária de autorização/RLS.

Trade-off preservado: um atacante distribuído pode causar throttling temporário de uma identidade específica ao consumir seu bucket. A decisão usa janela curta, buckets source/pair e futura camada edge, sem transformar esse risco em bloqueio global.

## Verificação executada

PR `#39`:

- primeiro ciclo CI `33907728323`: PASS;
- primeiro preflight `33907728320`: PASS;
- head final `b151c7bc0fb9d5c251df9c76c229f47855c81043`;
- CI final `33907918844`: PASS em `verify`, `database` e `auth-database`;
- preflight final `33907918969`: PASS;
- lint, typecheck, testes completos, PostgreSQL/RLS/Auth e build: PASS;
- diff integral: somente documentação/SPEC;
- scan final: nenhum `postgresql://`, URL hosted Vercel/Neon, control-plane ID ou credencial persistida;
- hosted writes: NENHUM;
- dados/identidades reais: NENHUM.

Promoção:

- PR `#39`: MERGED;
- merge commit: `52f398901de0360d7e6b31b880f08d02e999c97b`;
- main CI `33908077415`: PASS em `verify`, `database` e `auth-database`;
- main F22 Private Preview Preflight `33908077522`: PASS.

## Fora do escopo preservado

- provisionar store/limiter/Firewall;
- alterar Deployment Protection;
- environment variables hosted;
- retomar F21;
- alterar schema Auth/domínio;
- criar dados/usuários reais;
- produção;
- onboarding institucional definitivo.

## Encerramento

F23 está encerrada e integrada. A única próxima ação canônica é `F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01`.
