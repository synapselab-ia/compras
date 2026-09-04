# F24-PRIVATE-SIGNIN-ABUSE-CONTROL-IMPLEMENT-01 — Implementar limiter distribuído do sign-in privado

**Classe:** T1 — feature de suporte, com impacto T2 — segurança  
**Estado:** PLANNED / NEXT  
**Dependências:** F20, F22, F23, ADR-007, ADR-009 e ADR-010  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A ADR-010 definiu que o Server Action de sign-in privado precisa de limiter application-side distribuído e fail-closed antes de `auth.api.signInEmail`.

O rate limiter embutido do Better Auth não cobre chamadas server-side `auth.api`; limiter apenas em memória também não é enforcement aceitável em ambiente serverless.

A camada edge Vercel Firewall é defesa adicional e continuará para uma work unit hosted futura. F24 implementa somente a camada application-side reproduzível em PostgreSQL descartável/CI, sem provider writes.

## Resultado esperado

Implementar um limiter que:

1. usa PostgreSQL compartilhado e funciona entre múltiplas instâncias;
2. consome atomicamente buckets `source`, `identifier` e `pair` antes de chamar Better Auth;
3. deriva chaves HMAC/pseudônimas sem persistir email/IP em claro;
4. aceita como origem hosted apenas `x-forwarded-for` sob a fronteira Vercel definida na ADR-010;
5. rejeita chains/headers ambíguos e falha fechado quando não existe origem confiável;
6. retorna `rejected` quando limite é excedido e `unavailable` quando limiter/config/store falha;
7. nunca cai para sign-in sem limitação;
8. preserva o fluxo existente de cookie/session readback;
9. não altera signup/catch-all/OAuth/OTP/Admin;
10. não altera autorização de domínio/RLS.

## Implementação obrigatória

### 1. Namespace e migration

Criar nova migration versionada, sem reescrever migrations aplicadas.

O limiter deve ficar fora das tabelas geradas pelo Better Auth, em namespace próprio claramente identificado para segurança operacional.

A migration deve criar o mínimo necessário para:

- bucket pseudônimo;
- policy/bucket kind;
- início/fim de janela;
- contador;
- timestamps técnicos;
- índice para cleanup por expiração;
- função/primitive transacional de consumo dos três buckets.

`PUBLIC` não recebe grants.

A role `compras_auth_runtime` pode receber somente `USAGE/EXECUTE` estritamente necessários ao primitive do limiter; não receber DML amplo se uma função confinada puder fazer o enforcement.

Runtime continua:

- `LOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- sem ownership.

### 2. Política versionada

Aplicar os limites ADR-010:

| Bucket | Janela | Máximo |
|---|---:|---:|
| `source` | 15 min | 120 |
| `identifier` | 15 min | 20 |
| `pair` | 5 min | 8 |

Limites não são recebidos do browser nem ampliados por environment variable permissiva.

Mudança futura de policy exige nova migration/decisão versionada.

### 3. Atomicidade

Uma única operação de banco deve consumir os três buckets usando relógio do PostgreSQL.

Provar que concorrência não permite lost update ou `allow` acima do limite.

A operação deve contabilizar tentativa sintaticamente válida antes da chamada Better Auth, independentemente de conta existente/senha correta.

### 4. Trusted source

Criar resolver `server-only` que:

- exige ambiente Vercel hosted explicitamente identificável no caminho de produção;
- lê somente `x-forwarded-for` como fonte permitida;
- exige exatamente um IP válido;
- rejeita valor vazio, hostname, cadeia com vírgula, múltiplos tokens ou formato inválido;
- não aceita fallback para headers alternativos controláveis pelo cliente.

Testes locais/CI podem injetar origem por interface test-only sem criar header de produção alternativo.

### 5. Pseudonimização

Derivar chave exclusiva do limiter com domain separation a partir de `BETTER_AUTH_SECRET` usando HKDF/HMAC SHA-256.

Nenhuma nova secret é persistida.

Persistir somente digest opaco. Não persistir/logar:

- email em claro;
- IP em claro;
- password;
- cookie/token;
- Better Auth user id;
- team/membership;
- session payload.

### 6. Integração no Server Action

Fluxo esperado:

```text
normalize credentials
-> resolve trusted source
-> derive opaque bucket keys
-> consume limiter atomically
-> blocked => rejected
-> limiter unavailable => unavailable
-> allowed => existing Better Auth signInEmail
-> existing cookie/session readback
-> persist cookie only after session proof
```

Não duplicar o código de Auth já validado.

### 7. Cleanup/retention

Implementar purge oportunístico limitado para buckets expirados.

Requisitos:

- janela ativa máxima 15 minutos;
- linhas expiradas não participam de enforcement;
- purge não pode fazer full scan destrutivo por request;
- índice por expiração;
- teste demonstra remoção de registros expirados sem afetar buckets ativos;
- documentação mantém que retenção física formal para produção exige mecanismo periódico/readback próprio.

### 8. Observabilidade

Se houver logs, somente eventos sanitizados e agregáveis:

- `signin_limiter_allow`;
- `signin_limiter_reject`;
- `signin_limiter_unavailable`.

Nenhum valor de bucket individual deve ser logado.

Erro do driver deve ser convertido para estado genérico sem conexão/credential/SQL dump em log público.

## Testes obrigatórios

### Unitários

- normalize/pseudonimização determinística;
- domain separation não produz mesmo digest para tipos distintos;
- IP IPv4 válido;
- IP IPv6 válido;
- cadeia `x-forwarded-for` rejeitada;
- hostname/string arbitrária rejeitada;
- ausência de `VERCEL`/origem hosted -> unavailable no caminho de produção;
- email/IP/HMAC não aparecem em resultado público/log capturado;
- limiter reject mapeia para `rejected`;
- store/config error mapeia para `unavailable`;
- Better Auth não é chamado quando limiter bloqueia/está indisponível.

### PostgreSQL efêmero

- migration aplica em PostgreSQL 17;
- runtime não é owner/superuser/BYPASSRLS/CREATEROLE;
- runtime não possui acesso amplo à tabela do limiter;
- consumo autorizado ocorre somente pelo primitive/grant previsto;
- `source` bloqueia na tentativa 121 dentro de 15 min;
- `identifier` bloqueia na tentativa 21 dentro de 15 min;
- `pair` bloqueia na tentativa 9 dentro de 5 min;
- nova janela volta a permitir;
- burst concorrente acima do limite não obtém allows excedentes;
- buckets distintos não se contaminam;
- purge remove expirados e preserva ativos;
- Auth runtime continua sem acesso ao domínio;
- domínio runtime continua sem acesso Auth/limiter.

### Integração Auth

Com identidade exclusivamente `example.invalid`:

- signup continua fechado;
- primeiras tentativas dentro do limite chegam ao Better Auth;
- credencial inválida -> `rejected`;
- limite excedido -> `rejected` sem chamar Better Auth;
- indisponibilidade do limiter -> `unavailable` sem chamar Better Auth;
- login válido dentro da policy -> session/cookie readback existente continua PASS;
- sign-out continua PASS.

## Red-team obrigatório

Rejeitar PASS se:

- limiter autoritativo depender de memória local;
- header alternativo/browser-supplied puder escolher origem confiável;
- mesma string email/IP for armazenada em claro;
- digest/bucket individual aparecer em log;
- função SQL aceitar limites arbitrários do caller;
- race permitir exceder máximo;
- falha de banco deixar Better Auth ser chamado;
- limiter bloqueado for distinguido como conta existente/inexistente;
- signup/catch-all for reaberto;
- role runtime ganhar ownership/BYPASSRLS/CREATEROLE;
- Auth ganhar grants no domínio;
- migration anterior for reescrita;
- recurso Vercel/Neon/Redis/KV hosted for criado;
- dado/identidade real for usado.

## Verificação obrigatória

- lint;
- typecheck;
- testes unitários;
- PostgreSQL 17 efêmero;
- migrations domínio/Auth anteriores continuam PASS;
- migration nova limiter: PASS;
- concurrency/red-team SQL: PASS;
- integração Better Auth: PASS;
- build Next.js;
- revisão integral do diff;
- CI GitHub integral em PASS;
- nenhum hosted write;
- `REAL_DATA_ALLOWED = NO`;
- exatamente uma nova `NEXT_ACTION` ao fechar.

## Fora do escopo

- publicar regra Vercel Firewall;
- alterar Deployment Protection;
- environment variables hosted;
- retomar F21;
- Redis/KV/provider novo;
- rate limiting de outras rotas;
- MFA;
- password reset;
- usuário real;
- produção;
- alteração de autorização/RLS de domínio.

## Critério de encerramento

F24 fecha quando o limiter application-side distribuído estiver implementado, concorrência/fail-closed/privacidade estiverem provados em PostgreSQL descartável/CI e o sign-in existente continuar funcional dentro da policy, sem nenhum provider hosted alterado.
