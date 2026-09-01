# Current State — Compras

**PROJECT_STATUS:** READY_FOR_TRUSTED_IDENTITY_RLS_DESIGN  
**CURRENT_PHASE:** F06 — Trusted Identity / RLS Design  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_AND_DETAIL_PROTOTYPE  
**DATABASE_STATUS:** CORE_SCHEMA_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `e5118957cd1714bfd6a34dd693e62217f2e1a16d`  
**LAST_GOOD_CI_RUN:** `33547862171`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F05-DB-CORE-SCHEMA-01` foi concluída e integrada à `main` pela PR #7.

O repositório agora possui a primeira fundação executável de persistência, ainda sem provedor externo:

- `database/migrations/0001_core_foundation.sql` cria `teams`, `app_users`, `memberships`, `contractings`, `related_identifiers`, `contracting_items` e `contracting_events`;
- identidade externa permanece `auth_issuer + auth_subject`, separada de membership/autorização;
- responsáveis, criadores, atores, itens e identificadores usam FKs compostas quando necessário para impedir relações cross-team/cross-contracting;
- cardinalidade múltipla de identificadores por contratação permanece permitida;
- `stage_key`, `status_key`, `identifier_kind` e `event_type` permanecem extensíveis em `text`, sem `ENUM` físico;
- nenhuma regra de sinal/faixa/precisão de `quantity` foi inventada;
- RLS está habilitada e forçada nas sete tabelas internas;
- a migration não cria policy permissiva e revoga privilégios de tabela de `PUBLIC`;
- um papel operacional existe somente nos testes descartáveis e recebe grants DML apenas para provar enforcement real de RLS;
- a CI sobe PostgreSQL efêmero, aplica a migration do zero e executa testes adversariais antes dos gates da aplicação.

A aplicação continua sem conexão real com banco. Não há Auth, Data API operacional, policy de leitura para membership, banco hospedado nem dados reais.

## Verificação de F05

- recuperação do estado real de `main`, branches e PRs: PASS;
- validação do `CONTEXT_MANIFEST` contra blobs estáveis: PASS;
- leitura direta de `DATABASE.md`, `SECURITY.md`, ADR-002, DoD e SPEC da F05: PASS;
- migration em PostgreSQL 17 descartável: PASS;
- integridade cross-team/cross-contracting: PASS;
- cardinalidade N de identificadores: PASS;
- ordinal duplicado por contratação: rejeitado como esperado;
- ausência deliberada de constraint quantitativa inventada: PASS;
- RLS habilitada + `FORCE ROW LEVEL SECURITY` nas sete tabelas: PASS;
- zero policies permissivas na fundação: PASS;
- papel operacional de teste com grants não lê linhas e não contorna RLS conhecendo UUID: PASS;
- INSERT/UPDATE/DELETE sob papel operacional sem policy: bloqueados/sem linhas afetadas como esperado;
- imutabilidade operacional de `contracting_events`: PASS;
- PR #7, CI final antes do merge: PASS — run `33547766053`;
- CI da `main` após squash merge: PASS — run `33547862171`;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes da aplicação: PASS;
- build: PASS;
- dados reais/internos/sensíveis no diff: NÃO ENCONTRADOS;
- banco/Auth externo: SKIPPED — explicitamente fora do escopo.

## Red-team e correções

A revisão adversarial da F05 encontrou e corrigiu antes da promoção:

1. **Cleanup do papel operacional de teste:** a primeira execução validou os checks, mas falhou ao remover o papel por ACLs remanescentes. O teste passou a executar `DROP OWNED` antes de `DROP ROLE` e a CI ficou verde.
2. **Cobertura de FKs compostas:** a suíte foi ampliada para tentar também `created_by_membership_id` cross-team, evento ligado diretamente a contratação de outra equipe e evento apontando identificador de outra equipe.
3. **RLS versus falta de grant:** o papel operacional recebe grants amplos somente no banco descartável de teste, garantindo que o resultado vazio/bloqueado prove RLS e não apenas `permission denied` por ausência de privilégio de tabela.
4. **Regra quantitativa não aprovada:** um fixture artificial com quantidade negativa confirma que a fundação não introduziu positividade por convenção técnica.
5. **Superfície pública:** migrations, testes, workflow e PR usam apenas UUIDs artificiais, issuer `.invalid` e textos `DEMO-*`; nenhum secret ou dado operacional foi publicado.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. Nenhuma foi resolvida por conveniência da implementação.

## Segurança e limites atuais

O repositório continua público. A existência da migration e de RLS testada em PostgreSQL efêmero não autoriza uso com dados reais.

Antes de qualquer policy permissiva ou integração operacional é necessário derivar a identidade corrente de sessão/claim verificada, mapear essa identidade para `app_users` e membership ativa e provar que IDs fornecidos pelo cliente não ampliam acesso.

A arquitetura mantém Neon como provedor de referência sujeito a revalidação oficial no momento da implementação. A próxima work unit é deliberadamente de pesquisa/desenho: não provisionará banco, Auth ou secret.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados pela F05. A validação realizada no início da work unit permanece válida; `CURRENT_STATE`, `NEXT_ACTION`, migration, testes e CI são lidos ao vivo pelo protocolo.

## Last good

`e5118957cd1714bfd6a34dd693e62217f2e1a16d` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33547862171` com os jobs `verify` e `database` em PASS.

## Próxima ação

Executar `F06-TRUSTED-IDENTITY-RLS-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F06-TRUSTED-IDENTITY-RLS-DESIGN-01/SPEC.md`.
