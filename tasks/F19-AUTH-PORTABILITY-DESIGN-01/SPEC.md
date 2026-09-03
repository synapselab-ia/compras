# F19-AUTH-PORTABILITY-DESIGN-01 — Desenhar alternativa self-hosted ao Managed Better Auth bloqueado

**Classe:** T5 — arquitetura, com impacto T2 — segurança e T3 — integração externa  
**Estado:** COMPLETED / ADOPT  
**Dependências:** F14, F17 em ON HOLD, F18, ADR-006, ADR-007, ADR-008  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A F17 comprovou que a superfície Managed Better Auth disponível na conta/região Neon não permite impor e ler de volta o bloqueio de signup exigido. Esperar indefinidamente por essa capacidade transformaria uma dependência de produto do provider em bloqueio estrutural do projeto.

O código atual já depende da API Better Auth por meio do SDK Neon e já implementa uma superfície de aplicação restrita: sign-in email/senha e sign-out via Server Actions, catch-all Auth deny-all, sessão server-side e autorização final no PostgreSQL/RLS.

## Evidência oficial revalidada

Em 2026-09-03 a documentação oficial Better Auth v1.6 foi revalidada e confirmou:

- suporte oficial a PostgreSQL e schema não-default via `search_path`;
- geração/migration do schema Auth;
- `emailAndPassword.enabled=true`;
- `emailAndPassword.disableSignUp=true`;
- `trustedOrigins` explícitos;
- `auth.api.signInEmail`, `auth.api.getSession` e `auth.api.signOut` server-side;
- integração Next.js para cookies de Server Actions;
- social providers e plugins somente quando configurados;
- cookie cache desabilitado por padrão;
- chamadas `auth.api` server-side fora do rate limit client-side, exigindo decisão consciente de proteção.

## Objetivo

Decidir se o primeiro preview privado deve deixar de depender do Managed Better Auth da Neon e passar a executar Better Auth self-hosted pela aplicação, usando PostgreSQL controlado e configuração versionada/validável que imponha signup fechado por construção.

Esta work unit é de **desenho e prova local/efêmera**, não de hospedagem com dados reais.

## Questões fechadas pelo desenho

1. A interface F14 pode ser mantida com `auth.api.*` server-side sem montar handler HTTP Better Auth.
2. `disableSignUp=true` é configuração versionada e foi exercitada em teste real.
3. `socialProviders={}` e ausência de plugins de método lateral são explícitos.
4. `trustedOrigins` deve conter somente a origem privada aprovada.
5. Auth usará schema PostgreSQL dedicado `auth`.
6. Auth terá migrator/owner separado da role runtime, e runtime sem superuser/BYPASSRLS/ownership/grants de domínio.
7. O primeiro usuário fictício será criado por bootstrap one-shot não roteável; runtime permanece com signup desabilitado.
8. O adaptador `@neondatabase/auth` pode ser substituído internamente preservando as funções estreitas consumidas por F14/F08.
9. O contrato de identidade permanece `issuer + subject`, com issuer estável `urn:compras:better-auth:self-hosted:v1` e subject vindo de sessão server-side.
10. Migrations Auth serão geradas a partir de versão Better Auth pinada, revisadas e versionadas em diretório próprio.
11. Secret e conexão Auth serão separados do banco de domínio; rotação/deprovisionamento ficam sob controle da aplicação/provider de secrets.
12. `better-auth` deve virar dependência direta e exata na implementação; o proof F19 usou a versão transitiva já fixada no lockfile somente como laboratório.

## Prova local/efêmera executada

`src/server/auth/self-hosted-proof.test.ts` usa SQLite em memória, secret fictício e endereços `.invalid`.

A CI comprovou:

- signup rejeitado com `disableSignUp=true` antes de qualquer tabela existir;
- configuração sem social providers/plugins laterais;
- migrations programáticas em storage descartável;
- bootstrap one-shot em instância separada não exposta por HTTP;
- novo signup continua rejeitado no runtime guardado depois do bootstrap;
- usuário existente autentica por `auth.api.signInEmail`;
- cookie emitido permite `auth.api.getSession` retornar usuário/subject;
- sign-out emite invalidação de sessão/cookie.

Nenhum secret operacional, usuário real, dado real ou recurso hospedado foi criado.

## Red-team executado

- endpoint de signup direto: coberto por deny-all HTTP existente + `disableSignUp=true` no motor;
- social/OAuth/plugin lateral: não configurados; integração de cookie Next.js será tratada como plugin de transporte, não método de admissão;
- wildcard/localhost hospedado: proibidos pelo desenho;
- Auth -> `app_user`/membership automático: rejeitado;
- role Auth privilegiada: rejeitada; desenho exige role runtime mínima e separada;
- Auth com grants no domínio: rejeitado;
- reset/password/admin/OTP/magic link públicos: continuam fora da superfície HTTP;
- secret no client: rejeitado; configuração será `server-only`;
- sessão forjada: subject só vem de `getSession` server-side;
- cookies de Server Actions: identificado requisito de `nextCookies()` oficial ou forwarding explícito testado;
- migration não reproduzível: rejeitada; SQL deverá ser gerado de versão pinada e versionado;
- dependência transitiva: identificada e transformada em gate obrigatório da F20;
- brute force: identificado que `auth.api` server-side não herda rate limit client-side; Vercel Authentication continua barreira obrigatória no primeiro preview e exposição mais ampla exige controle específico;
- cookie cache: não será habilitado no primeiro preview para evitar atraso de revogação.

## Decisão

**ADOPT.** A decisão completa, threat model e fronteira escolhida estão em `docs/decisions/ADR-009-self-hosted-better-auth.md`.

Neon pode permanecer como PostgreSQL hospedado, mas Managed Neon Auth deixa de ser dependência do caminho crítico. F17 permanece `ON HOLD` como evidência histórica do blocker do provider.

## Critérios de aceite

- documentação oficial atual revalidada: PASS;
- arquitetura escolhida registrada em nova ADR: PASS / ADR-009;
- threat model explícito Managed vs self-hosted: PASS;
- configuração mínima com signup negado em teste local/efêmero: PASS;
- nenhum provider social/plugin lateral habilitado no proof: PASS;
- estratégia de schema/role/migration definida: PASS;
- compatibilidade F14/F08/RLS demonstrada/delimitada: PASS;
- nenhum secret, usuário real ou dado real criado: PASS;
- decisão final: ADOPT;
- nova NEXT_ACTION: F20-SELF-HOSTED-AUTH-IMPLEMENT-01.

## Fora do escopo

- provisionar ambiente operacional;
- inserir dados reais;
- criar usuário real;
- promover a demo F18 a persistente;
- manter Managed Neon Auth apenas por inércia.
