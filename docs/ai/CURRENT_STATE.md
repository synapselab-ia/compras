# Current State — Compras

**PROJECT_STATUS:** READY_FOR_DB_CORE_SCHEMA  
**CURRENT_PHASE:** F05 — DB Core Schema  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** CENTRAL_AND_DETAIL_PROTOTYPE  
**DATABASE_STATUS:** DESIGNED_NOT_APPLIED  
**AUTH_STATUS:** NOT_IMPLEMENTED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `b5ddfd6d00a196164413bdba2fe9ead719bf71ac`  
**LAST_GOOD_CI_RUN:** `33546364117`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F04-PERSISTENCE-FOUNDATION-DESIGN-01` foi concluída e integrada à `main` pela PR #6.

O repositório agora possui uma fundação de persistência canônica, ainda não aplicada:

- `docs/architecture/DATABASE.md` define o núcleo PostgreSQL relacional e portátil;
- ADR-002 registra as decisões estruturais de persistência/default-deny;
- `Contratação` permanece a raiz operacional;
- `teams`, `app_users` e `memberships` separam escopo, identidade e autorização;
- identidade externa é modelada por `issuer + subject`, sem assumir subject globalmente único;
- responsáveis/atores e subentidades usam relações compostas para impedir referência cross-team/cross-contracting quando aplicável;
- etapa, status e tipos de identificador permanecem `text` sem `ENUM` físico enquanto as taxonomias estiverem abertas;
- estado atual e `contracting_events` append-only são separados;
- arquivamento/cancelamento/revogação/desvínculo/retirada preservam registro em vez de exclusão silenciosa;
- RLS nasce como default-deny e nenhuma policy permissiva depende de Auth ainda inexistente;
- a primeira implementação de banco será PostgreSQL descartável em CI, sem banco hospedado ou segredo externo.

Nenhuma migration foi aplicada e nenhuma aplicação está conectada a banco.

## Verificação de F04

- recuperação de `main`, branches e PRs: PASS;
- leitura direta das fontes obrigatórias de produto, domínio, open questions, arquitetura, segurança e DoD: PASS;
- validação do `CONTEXT_MANIFEST` antes da edição: PASS;
- coerência cruzada do desenho com Project Design/Domain/Security/Open Questions: PASS após red-team;
- red-team estrutural e de segurança: PASS após correções;
- CI final da PR #6: PASS — run `33546289585`;
- CI da `main` após squash merge: PASS — run `33546364117`;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes da aplicação existentes: PASS;
- build: PASS;
- migrations/testes de banco: SKIPPED — ainda não existem por definição da F04;
- banco/Auth/RLS externo: SKIPPED — explicitamente fora do escopo;
- dados reais/internos/sensíveis no diff: NÃO ENCONTRADOS;
- dependências novas: nenhuma.

## Red-team e correções

A revisão adversarial encontrou e corrigiu antes da promoção:

1. **Regra quantitativa inventada:** o primeiro desenho tratava ordinal/quantidade positiva como constraint sem fonte aprovada. A fundação foi corrigida para não codificar faixa, sinal ou precisão de quantidade por convenção técnica.
2. **Identidade externa ambígua:** `auth_subject` isolado foi substituído conceitualmente por `auth_issuer + auth_subject`, evitando assumir unicidade global entre provedores.
3. **Integridade histórica:** referências de eventos para item/identificador passaram a exigir desenho composto de equipe + contratação + subentidade, impedindo associação histórica cruzada.
4. **Teste de RLS:** ficou explícito que grants amplos usados para exercitar RLS pertencem somente ao papel/ambiente de teste; a migration de produção mantém grants mínimos.
5. **Owner não prova segurança:** papel de migration/owner permanece separado do papel operacional e BYPASSRLS não serve como evidência de autorização.

Q-001, Q-002, Q-003, Q-004, Q-005, Q-006, Q-009 e Q-010 permanecem abertas. Nenhuma foi resolvida por conveniência de schema.

## Segurança e limites atuais

O repositório continua público e não há autenticação nem banco operacional. Portanto:

- somente dados fictícios/sanitizados podem aparecer em código, migrations futuras, testes, Issues, PRs, logs e artifacts;
- nenhum uso operacional com dados reais é permitido;
- `DATABASE.md` é desenho, não evidência de enforcement aplicado;
- RLS real só será considerada implementada após migration e testes adversariais passarem;
- nenhuma identidade fornecida pelo cliente será tratada como confiável em produção.

## Context manifest

F04 adicionou `docs/architecture/DATABASE.md` ao `INPUT_MANIFEST` e atualizou `SOURCE_OF_TRUTH.md`. O manifest foi recompilado como `CONTEXT_SCHEMA = 2` e os blobs estáveis coincidem com o estado integrado.

## Last good

`b5ddfd6d00a196164413bdba2fe9ead719bf71ac` é o `LAST_GOOD_COMMIT` atual, validado pela CI da `main` run `33546364117`.

## Próxima ação

Executar `F05-DB-CORE-SCHEMA-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F05-DB-CORE-SCHEMA-01/SPEC.md`.
