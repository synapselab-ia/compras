# F22-PRIVATE-PREVIEW-SEED-SMOKE-ASSETS-01 — Versionar assets reproduzíveis de seed e smoke do preview privado

**Classe:** T1 — feature de suporte, com impacto T2 — segurança  
**Estado:** PLANNED / NEXT  
**Dependências:** F11, F14, F20, F21 ON HOLD, ADR-003, ADR-005, ADR-007 e ADR-009  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A F21 recuperou e revalidou a fronteira hosted, mas ficou `ON HOLD` antes de secrets porque a superfície Vercel autenticada disponível na sessão não permite aplicar/read-back os controles obrigatórios de Deployment Protection e environment variables sensíveis escopadas à branch.

Esse blocker externo não impede preparar e provar, em PostgreSQL efêmero/CI, os assets reproduzíveis que a F21 precisará quando o control plane estiver disponível: autorização fictícia separada do Auth, cenário cross-team, identidade sem autorização e smoke fail-closed.

Hoje esses cenários existem distribuídos entre migrations e testes anteriores, mas ainda não há um pacote operacional pequeno, determinístico e reutilizável para o futuro preflight hospedado.

## Resultado esperado

Adicionar ao repositório um conjunto mínimo de assets públicos e totalmente fictícios para reproduzir a etapa C/E da F21 em ambiente efêmero, sem criar Vercel/Neon hosted persistente.

Ao final deve existir um fluxo testável que:

1. aplica migrations canônicas de domínio e Auth em PostgreSQL descartável;
2. cria roles runtime separadas e não privilegiadas;
3. executa o bootstrap Better Auth one-shot somente com identidade `example.invalid`;
4. cria `app_user`/membership por seed administrativo separado, nunca por hook de Auth;
5. cria duas equipes e contratações artificiais suficientes para positivo e cross-team deny;
6. prova identidade Auth sem autorização interna -> zero dados;
7. prova usuário autorizado -> somente própria equipe;
8. prova UUID de outra equipe -> invisível/not-found;
9. prova configuração/identidade inválida -> fail-closed;
10. produz somente saída sanitizada de PASS/FAIL, sem senha, cookie, connection string ou secret.

## Implementação obrigatória

### Seed fictício

Criar asset separado das migrations de produção, com guard explícito de ambiente de teste/preflight.

O seed deve usar somente valores artificiais e determinísticos, por exemplo:

- issuer canônico `urn:compras:better-auth:self-hosted:v1`;
- subject retornado pelo bootstrap fictício;
- emails exclusivamente `example.invalid`;
- UUIDs artificiais estáveis;
- nomes/objetos claramente sintéticos;
- duas equipes distintas para provar isolamento.

Não copiar dados, nomes, objetos, números de processo ou exemplos oriundos do trabalho real.

### Harness de preflight/smoke

O harness deve ser executável somente contra ambiente explicitamente marcado como efêmero/fictício.

Deve reutilizar as fronteiras existentes do repositório e não criar um caminho paralelo de autorização.

A saída deve ser mínima e sanitizada. É proibido imprimir:

- passwords;
- cookies;
- tokens;
- connection strings;
- `BETTER_AUTH_SECRET`;
- payloads completos de sessão;
- dumps de banco.

### Segurança

- `AUTH_DATABASE_URL` e `DATABASE_URL` devem representar roles distintas nos testes;
- nenhuma runtime role pode ser owner/superuser/BYPASSRLS/CREATEROLE;
- Auth runtime não recebe grants no domínio;
- domínio runtime não recebe grants no schema Auth;
- bootstrap não cria autorização automaticamente;
- o seed administrativo não muda a política de signup;
- `/api/auth/[...path]` continua deny-all;
- `disableSignUp=true` permanece a configuração normal;
- nenhuma mudança habilita exposição pública do login.

## Red-team obrigatório

Rejeitar PASS se qualquer um ocorrer:

- asset aceita email fora de `example.invalid`;
- seed executa sem guard explícito de ambiente fictício;
- subject/issuer/equipe vêm de input não confiável do browser;
- bootstrap cria `app_users` ou memberships automaticamente;
- mesmo login/role é usado para Auth e domínio;
- role runtime é owner/superuser/BYPASSRLS/CREATEROLE;
- cross-team retorna linha;
- identidade Auth sem autorização interna retorna dado;
- erro de configuração vira demo silenciosamente;
- output de teste ecoa secret/connection string/cookie/password;
- migration canônica é reescrita para acomodar o seed;
- provider hosted persistente é criado nesta work unit.

## Verificação obrigatória

- lint;
- typecheck;
- testes unitários relevantes;
- PostgreSQL efêmero;
- migrations domínio `0001..0003`: PASS;
- migrations Auth `0001..0002`: PASS;
- bootstrap fictício: PASS;
- seed administrativo separado: PASS;
- Auth sem autorização interna: DENY;
- cross-team/UUID conhecido: DENY;
- fail-closed: PASS;
- isolamento Auth/domínio: PASS;
- build Next.js;
- revisão integral do diff;
- CI GitHub integral em PASS;
- nenhum recurso Vercel/Neon hosted criado;
- `REAL_DATA_ALLOWED = NO`.

## Fora do escopo

- retomar ou concluir F21;
- escrever environment variables Vercel;
- alterar Deployment Protection;
- criar projeto/branch Neon hospedado;
- criar usuário real;
- dados internos ou pré-publicação;
- produção;
- CRUD/mutações de contratação;
- rate limiting para exposição pública ampla;
- onboarding institucional definitivo.

## Critério de encerramento

F22 fecha quando os assets de bootstrap/seed/smoke necessários ao futuro preview estiverem reproduzíveis e integralmente provados em ambiente efêmero, sem hosted writes e sem dados reais. O checkpoint deve manter F21 `ON HOLD` com seu `resume_when` objetivo e deixar exatamente uma nova `NEXT_ACTION` independente ou de retomada quando a capacidade externa estiver disponível.
