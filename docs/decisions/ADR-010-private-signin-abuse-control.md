# ADR-010 — Controle distribuído de abuso do sign-in privado

**Status:** Accepted  
**Data:** 2026-09-04  
**Escopo:** proteção contra abuso do Server Action de sign-in privado; sem provisionamento hosted nesta decisão  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

A admissão privada atual é deliberadamente estreita:

- `/api/auth/[...path]` permanece deny-all;
- sign-in e sign-out entram somente por Server Actions;
- Better Auth é self-hosted e chamado server-side por `auth.api.*`;
- signup, OAuth, OTP, magic link, reset e Admin API não são expostos;
- sessão/subject são validados no servidor;
- autorização de domínio continua separada e RLS permanece autoritativa.

Essa superfície reduz métodos laterais, mas não limita tentativas abusivas de senha por si só.

A documentação Better Auth v1.6 revalidada em 2026-09-04 confirma que o rate limiter embutido não é aplicado a chamadas server-side por `auth.api`. Ela também registra que o storage padrão em memória não é adequado a muitos cenários serverless e que storage distribuído pode usar banco, secondary storage ou implementação customizada.

A documentação Vercel atual revalidada na mesma data confirma que:

- o Firewall/WAF executa antes da aplicação e suporta regras de rate limit por path/método/IP;
- o SDK de rate limiting do Firewall também admite `rateLimitKey` customizada quando existe uma `Request` apropriada;
- `x-forwarded-for` recebido pela Function contém o IP público do cliente e é sobrescrito pela Vercel para impedir spoofing, exceto quando uma configuração explícita de trusted proxy muda essa fronteira;
- Vercel Authentication continua disponível como Deployment Protection para Preview.

Fontes oficiais revalidadas:

- `https://better-auth.com/docs/1.6/concepts/rate-limit`
- `https://better-auth.com/docs/1.6/reference/security`
- `https://vercel.com/docs/headers/request-headers`
- `https://vercel.com/docs/vercel-firewall/vercel-waf/rate-limiting-sdk`
- `https://vercel.com/docs/cli/firewall`
- `https://vercel.com/docs/security/deployment-protection/methods-to-protect-deployments/vercel-authentication`

A F21 continua `ON HOLD` antes de secrets porque a superfície Vercel autenticada disponível nesta sessão ainda não expõe o readback/CRUD obrigatório de Deployment Protection/bypasses e sensitive Preview environment variables escopadas à branch. F23 não altera providers hosted.

## Threat model

O desenho cobre pelo menos:

1. password guessing dirigido a uma identidade;
2. credential stuffing distribuído entre várias identidades;
3. bursts concorrentes contra a mesma identidade;
4. múltiplas instâncias serverless sem memória compartilhada;
5. rotação e spoofing de headers de origem;
6. enumeração de conta por mensagem ou estado de rate limit;
7. bypass silencioso quando limiter/store fica indisponível;
8. DoS global causado por uma chave única mal escolhida;
9. retenção indevida de email/IP;
10. vazamento de senha, cookie, token, connection string ou sessão em log.

## Alternativas avaliadas

### A. Somente Vercel Firewall/WAF

**Vantagens**

- executa antes da Function e reduz custo/pressão sobre aplicação e PostgreSQL;
- rate limit por path, método e IP é simples de operar;
- rollback é rápido no control plane;
- nenhum email precisa chegar ao mecanismo edge.

**Limites**

- IP é um sinal grosseiro: NAT pode agrupar usuários legítimos e atacantes podem rotacionar IPs;
- o enforcement por IP não fecha sozinho password guessing distribuído contra uma identidade;
- counters/regra são provider-dependent e precisam de readback hosted;
- não substitui política application-side para múltiplas origens.

**Decisão:** obrigatório como defesa de disponibilidade para exposição hosted mais ampla, mas insuficiente como limiter único.

### B. Limiter distribuído em store compartilhado

Foram comparadas duas famílias.

#### Redis/KV dedicado

- atomicidade e TTL são naturais;
- boa latência para contador de alta frequência;
- exige novo recurso/provider, nova credencial e mais uma dependência operacional;
- aumenta a superfície de control plane exatamente enquanto F21 ainda está bloqueada.

#### PostgreSQL já usado pelo Auth

- fornece transação/atomicidade real entre instâncias;
- reproduzível integralmente em PostgreSQL descartável/CI;
- não exige novo provider nem nova credencial runtime se o limiter usar a conexão Auth já existente com grants mínimos;
- falha do mesmo PostgreSQL já torna o Auth indisponível, portanto o comportamento fail-closed é coerente;
- exige desenho cuidadoso para não transformar login em vetor de write-amplification e exige política explícita de limpeza/retention.

**Decisão:** adotar PostgreSQL compartilhado como store autoritativo application-side na próxima implementação.

### C. Composição edge + PostgreSQL

**Decisão final:** adotar duas camadas complementares:

1. **camada autoritativa application-side:** limiter PostgreSQL distribuído, chamado antes de `auth.api.signInEmail`;
2. **camada edge de defesa em profundidade:** Vercel Firewall/WAF rate limit para `POST /auth/sign-in` antes da Function.

A aplicação não depende do WAF para correção de autenticação; o WAF reduz volume e custo. Para declarar uma futura exposição hosted mais ampla pronta, ambos devem ser demonstrados por readback/smoke.

Um limiter somente process-local/in-memory permanece proibido como enforcement.

## Fronteira confiável de origem

### Vercel hosted

O runtime pode usar `x-forwarded-for` como sinal de origem somente quando:

- estiver em ambiente Vercel explicitamente identificado pelo runtime;
- o valor estiver presente;
- contiver exatamente um endereço IP válido, sem cadeia separada por vírgulas;
- o preflight hosted confirmar que a configuração de proxy não alterou a garantia de overwrite da Vercel.

Se qualquer condição falhar, o limiter fica `unavailable` e o sign-in falha fechado antes de consultar Better Auth.

Nenhum header arbitrário como `x-client-ip`, `client-ip`, `true-client-ip`, `forwarded` ou valor produzido pelo browser pode substituir essa fonte.

### Local/CI

Testes usam um adapter injetável/test-only para origem fictícia. O caminho de produção não aceita um header de teste como sinal confiável.

## Chaves e pseudonimização

O store nunca recebe email ou IP em claro.

A implementação derivará uma chave de pseudonimização via HKDF/HMAC a partir de `BETTER_AUTH_SECRET` com domain separation explícita, por exemplo contexto `compras/signin-limiter/v1`. Nenhuma nova secret é necessária apenas para hashing.

O email é normalizado apenas para formar bucket defensivo (`trim` + lowercase) e não vira identidade/autorização. A tentativa continua sendo autenticada exclusivamente pelo Better Auth.

São usados três buckets independentes por tentativa:

1. `source` = HMAC(IP confiável);
2. `identifier` = HMAC(email normalizado);
3. `pair` = HMAC(IP confiável + separador canônico + email normalizado).

Nenhum bucket global bloqueante existe. Uma origem atacante não pode esgotar um único contador global e negar sign-in a todos os usuários.

## Política inicial

Os valores iniciais são versionados em migration/configuração do limiter e não são recebidos do browser:

| Bucket | Janela | Máximo inicial | Finalidade |
|---|---:|---:|---|
| `source` | 15 min | 120 tentativas | credential stuffing sustentado de uma origem |
| `identifier` | 15 min | 20 tentativas | guessing distribuído contra uma identidade |
| `pair` | 5 min | 8 tentativas | guessing focado origem + identidade |

Todas as tentativas válidas sintaticamente consomem os três buckets **antes** da chamada Better Auth, independentemente de a conta existir ou a senha estar correta. A atualização dos três buckets deve ser atômica no banco.

Sucesso não reseta contador. Os buckets expiram pela janela. Isso evita uma escrita pós-auth cuja falha poderia deixar um login aceito sem estado de limiter consistente.

Alterar limites/janelas exige mudança versionada e nova revisão; environment variable arbitrária não pode ampliar os limites silenciosamente.

## Semântica de decisão

### Limite não excedido

- consumir tentativa atomicamente;
- continuar para Better Auth;
- manter o fluxo atual de readback de sessão/cookie.

### Limite excedido

- não chamar Better Auth;
- retornar o mesmo resultado externo genérico de credenciais rejeitadas (`rejected`);
- não expor qual bucket limitou, contagem, email ou existência de conta;
- não enviar `Retry-After` específico por identidade ao browser.

### Limiter/store/configuração indisponível

- não chamar Better Auth;
- retornar `unavailable`;
- não cair para sign-in sem limitação;
- não cair para demo.

A diferença `rejected` versus `unavailable` expressa credencial/limite versus indisponibilidade operacional, não existência de conta.

Não existe promessa de timing criptograficamente constante pela rede. A implementação não deve criar caminhos deliberadamente diferentes por conta existente/inexistente e deve evitar mensagens, consultas auxiliares ou sleeps condicionados à existência da conta.

## Atomicidade e concorrência

A próxima implementação deve usar uma operação PostgreSQL única, transacional e concorrência-safe para consumir os três buckets.

Requisitos:

- `INSERT ... ON CONFLICT ... DO UPDATE` ou função equivalente sob lock de linha;
- relógio do banco como referência da janela;
- incremento e decisão em uma única transação;
- burst concorrente não pode obter múltiplos `allow` acima do limite por lost update;
- tabela não é lida/escrita diretamente pelo browser;
- Auth runtime recebe apenas os grants mínimos necessários ao limiter e continua sem grants no domínio.

A tabela/função do limiter deve ficar em namespace próprio ou claramente separado das tabelas geradas pelo Better Auth, para que upgrades Better Auth não confundam schema customizado com schema gerado.

## Privacidade e retenção

Persistir somente:

- bucket pseudônimo HMAC;
- tipo/policy do bucket;
- início/fim de janela;
- contador;
- timestamps técnicos mínimos.

É proibido persistir no limiter:

- email em claro;
- IP em claro;
- senha;
- cookie/token;
- session payload;
- user id Better Auth;
- team/membership/domain identifiers.

Janela máxima de enforcement inicial: 15 minutos. Retenção física alvo: no máximo 24 horas após expiração.

F24 deve implementar purge oportunístico limitado e testado. Antes de produção com requisitos formais de retenção, a operação deve possuir mecanismo periódico de cleanup com readback; ausência desse mecanismo impede elevar a garantia de retenção para produção.

## Observabilidade

Logs/métricas permitidos:

- evento estável (`signin_limiter_allow`, `signin_limiter_reject`, `signin_limiter_unavailable`);
- bucket kind agregado;
- ambiente/deployment não sensível quando necessário;
- contadores agregados.

Não logar:

- email ou HMAC do email;
- IP ou HMAC do IP;
- senha;
- cookie/token;
- connection string;
- payload de sessão;
- erro bruto do driver contendo credencial/URL.

A UI continua recebendo somente os estados genéricos já definidos.

## Vercel Firewall hosted

Quando o control plane puder ser aplicado/read-back, a regra inicial deve:

- preservar Vercel Authentication/Deployment Protection;
- corresponder somente a `POST /auth/sign-in`;
- usar rate limit por IP como barreira volumétrica, começando em 30 requests/60s;
- não depender de um identificador controlável pelo browser;
- ser publicada e lida de volta antes de declarar proteção ativa;
- ter smoke que demonstra resposta de bloqueio sem remover Deployment Protection;
- possuir rollback explícito para a versão anterior da regra.

O valor de 30/60s é defesa externa grosseira e não substitui os buckets PostgreSQL.

## Red-team da decisão

Rejeitados:

- limiter autoritativo somente em memória: REJEITADO;
- confiar em header arbitrário do browser: REJEITADO;
- usar somente IP como defesa completa: REJEITADO;
- usar somente email como chave global: REJEITADO;
- reabrir `/api/auth/[...path]` para herdar rate limit do Better Auth: REJEITADO;
- reabrir signup/OAuth/OTP/Admin: REJEITADO;
- permitir sign-in quando store falha: REJEITADO;
- logar email/IP/HMAC individual/credenciais: REJEITADO;
- adicionar Redis/provider novo sem necessidade: REJEITADO nesta etapa;
- remover Vercel Authentication: REJEITADO;
- alterar RLS/autorização de domínio: REJEITADO.

## Consequências

### Positivas

- enforcement funciona entre múltiplas instâncias serverless;
- a camada application-side não depende de exposição do catch-all Better Auth;
- não há novo provider nem nova secret apenas para o limiter;
- concorrência pode ser provada localmente em PostgreSQL real;
- IP/email não são armazenados em claro;
- falha do limiter não abre bypass;
- edge e aplicação têm funções distintas e complementares.

### Custos/limites

- cada tentativa de sign-in válida sintaticamente gera write no PostgreSQL do limiter;
- account bucket pode temporariamente negar login legítimo quando um atacante concentra tentativas na mesma identidade; a janela curta e a barreira externa reduzem esse risco, mas ele deve ser observado;
- Vercel Firewall continua provider-dependent e precisa de readback hosted;
- retenção física estrita antes de produção exige cleanup operacional além do purge oportunístico;
- os limites iniciais podem precisar de ajuste por evidência operacional futura, sempre por mudança versionada.

## Rollback

A implementação deve permitir:

1. desativar uma mudança nova de código somente revertendo para a última versão validada — nunca por flag fail-open;
2. manter o limiter ativo durante rollback de UI/Auth não relacionado;
3. reverter regra WAF para sua versão anterior pelo control plane;
4. nunca desabilitar limiter/Deployment Protection como workaround para indisponibilidade.

## Critérios para proteção hosted futura

Antes de declarar o sign-in protegido em Preview/produção futura:

- limiter PostgreSQL aplicado e smoke concorrente em PASS;
- roles/grants lidos de volta;
- Vercel Authentication ainda ativa;
- trusted proxy/origem compatível com a garantia de `x-forwarded-for` lida de volta ou empiricamente comprovada;
- regra WAF publicada e lida de volta;
- smoke de limite edge em PASS;
- nenhum bypass não justificado;
- logs revisados sem PII/segredos.

## Próxima implementação

Implementar somente a camada application-side e seus testes em `F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01`, ainda sem writes hosted e com dados exclusivamente fictícios. A configuração WAF e a prova hosted permanecem para a work unit de provider apropriada quando o control plane estiver disponível.
