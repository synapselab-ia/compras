# Current State — Compras

**PROJECT_STATUS:** READY_FOR_SERVER_IDENTITY_READ_RLS  
**CURRENT_PHASE:** F07 — Server Identity / Read RLS  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_AND_DETAIL_PROTOTYPE  
**DATABASE_STATUS:** CORE_SCHEMA_DEFAULT_DENY_VALIDATED  
**AUTH_STATUS:** TRUST_BOUNDARY_DESIGNED_NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `f09f146a6e9dc5db50789e79a9e8e0a911623be4`  
**LAST_GOOD_CI_RUN:** `33549912472`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F06-TRUSTED-IDENTITY-RLS-DESIGN-01` foi concluída e integrada à `main` pela PR #8.

A documentação oficial atual da Neon foi revalidada em 2026-09-01 para Managed Better Auth, sessão server-side em Next.js, Data API/JWT+JWKS, Serverless Driver, RLS e `pg_session_jwt`. A decisão resultante está em `docs/decisions/ADR-003-trusted-identity-rls-boundary.md`.

A fronteira aprovada para a primeira integração operacional é:

```text
Browser
  → sessão/cookie de Auth
  → Next.js server valida a sessão
  → issuer + subject verificados
  → contexto LOCAL mínimo da transação
  → PostgreSQL com papel server-only, não owner e sem BYPASSRLS
  → RLS
```

Decisões fixadas pela F06:

- `auth_subject` é derivado da identidade retornada por sessão validada, não de parâmetro do browser;
- `auth_issuer` é derivado de configuração confiável do servidor para o provedor/endpoint que validou a sessão, não de hostname ou claim livre do cliente;
- a sequência autorizadora permanece `issuer + subject → app_user → membership ativa → team_id`;
- autenticação não cria automaticamente `app_user` nem membership;
- identidade autenticada desconhecida, `app_user` desabilitado, membership ausente/revogada ou falha de validação resultam em nenhum acesso;
- a primeira implementação não usará a Data API diretamente do browser como fronteira principal; a Data API permanece opção futura que exigirá integração e red-team próprios;
- `request.jwt.claims` ou variável equivalente pode servir apenas como transporte transacional definido por servidor confiável depois da validação; não é fonte autônoma de confiança;
- a próxima camada PostgreSQL deve usar helpers `STABLE`, `SECURITY INVOKER`, sem argumentos de identidade, e evitar recursão de RLS em `app_users`;
- a primeira abertura de RLS será somente para `SELECT`; nenhuma policy de escrita ou `role` de membership será criada enquanto Q-009 permanecer aberta;
- credencial de banco e cookie secret permanecem server-only; owner, `neondb_owner` e `BYPASSRLS` não são caminhos operacionais normais.

Nenhum recurso Neon, Auth, Data API, Vercel ou banco hospedado foi provisionado. Nenhum secret, JWT real, connection string, policy permissiva, migration ou alteração executável de aplicação foi introduzido pela F06.

## Verificação de F06

- recuperação de `main`, branches, PRs e Issues: PASS;
- nenhuma frente concorrente aberta encontrada antes da execução: PASS;
- validação do `CONTEXT_MANIFEST` contra todos os blobs estáveis: PASS;
- leitura direta de `ARCHITECTURE.md`, `SECURITY.md`, `DATABASE.md`, ADR-002, `OPEN_QUESTIONS.md`, migration/testes atuais e DoD: PASS;
- documentação oficial atual do Neon consultada e registrada em ADR-003: PASS;
- coerência com `issuer + subject`, membership ativa, deny-by-default e portabilidade: PASS;
- Q-009 e Q-010 preservadas sem inferência: PASS;
- diff integral da PR #8: PASS — somente ADR-003 e SPEC da F07, conteúdo público/sanitizado;
- secrets, credenciais ou dados reais/internos no diff: NÃO ENCONTRADOS;
- infraestrutura externa provisionada: NÃO;
- policy/grant/migration executável alterado: NÃO;
- CI final da PR #8: PASS — run `33549743602`, jobs `verify` e `database`;
- CI da `main` após squash merge: PASS — run `33549912472`, jobs `verify` e `database`;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes da aplicação: PASS;
- build: PASS;
- migration `0001` + testes de banco existentes: PASS;
- Auth real / banco hospedado / sessão real: SKIPPED — explicitamente fora do escopo.

## Red-team e achados

A revisão adversarial produziu e registrou os seguintes pontos antes da promoção:

1. **Signup público por padrão:** a documentação atual do Managed Better Auth informa que qualquer pessoa pode se cadastrar por padrão. Isso conflita com a baseline do projeto. A F06 não habilita Auth e mantém fail-closed porque autenticação não autoautoriza `app_user`/membership. Antes de expor Auth real, a futura integração deverá impor admissão controlada além de esconder UI.
2. **Variável de sessão não é identidade:** claims colocados em `request.jwt.claims` são forjáveis por quem possui credencial SQL. O desenho permite esse mecanismo somente como transporte `LOCAL` definido pelo servidor após validar a sessão; a credencial operacional nunca vai ao browser.
3. **Papel privilegiado não prova RLS:** owner, superuser, `neondb_owner` ou `BYPASSRLS` permanecem excluídos do caminho normal e dos futuros testes de autorização.
4. **Revogação não pode depender do cache de sessão:** membership ativa e `disabled_at` serão verificados no PostgreSQL a cada leitura autorizada; dados de autorização não serão congelados no cookie de sessão.
5. **Recursão de policy:** a futura policy de `app_users` deve comparar diretamente `auth_issuer + auth_subject` ao contexto, sem chamar helper que consulte `app_users` e provoque recursão de RLS.
6. **Data API não é pressuposto de segurança:** JWT/JWKS e RLS da Data API foram confirmados como capacidades atuais, mas sua adoção direta pelo cliente foi adiada para uma slice própria caso seja necessária.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. F06 não alterou taxonomias, regra de preços, inatividade, Pendência, permissões multiusuário nem auditoria de leitura.

## Segurança e limites atuais

O repositório continua público e nenhuma autorização permissiva foi aplicada. A aplicação continua demonstrativa e sem persistência operacional.

ADR-003 é um desenho de fronteira de confiança, não evidência de Auth funcionando. Nenhum uso com dados reais está autorizado. A futura integração de Auth deverá revalidar novamente o mecanismo de admissão/signup, secrets, sessão, região e demais capacidades mutáveis do provedor no momento da implementação.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados pela F06. Todos os blobs listados continuaram coincidentes no início da work unit; ADR-003 e o novo SPEC não invalidam o fast context.

## Last good

`f09f146a6e9dc5db50789e79a9e8e0a911623be4` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33549912472` com os jobs `verify` e `database` em PASS.

## Próxima ação

Executar `F07-SERVER-IDENTITY-READ-RLS-01` conforme `docs/ai/NEXT_ACTION.md`, `tasks/F07-SERVER-IDENTITY-READ-RLS-01/SPEC.md` e ADR-003.
