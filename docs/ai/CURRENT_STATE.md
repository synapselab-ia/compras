# Current State — Compras

**PROJECT_STATUS:** READY_FOR_HOSTED_PREVIEW_DESIGN  
**CURRENT_PHASE:** F13 — Hosted Preview Boundary Design  
**REPO_VISIBILITY:** PUBLIC  
**APPLICATION_STATUS:** PERSISTENT_CENTRAL_AND_DETAIL_READ_IMPLEMENTED_OPT_IN  
**DATABASE_STATUS:** PROTECTED_READ_MODEL_AND_TEAM_DIRECTORY_VALIDATED_IN_EPHEMERAL_CI  
**AUTH_STATUS:** SERVER_TRUST_ADAPTER_IMPLEMENTED_NOT_PROVISIONED  
**DEPLOYMENT_STATUS:** NOT_CONFIGURED  
**REAL_DATA_ALLOWED:** NO  
**CONTEXT_STATUS:** VALID  
**FOUNDATION_BASELINE_COMMIT:** `40c3297094d700552896d2945e10b18b982186da`  
**LAST_GOOD_COMMIT:** `8a771dcf7f98d7000ed746afd5e5f5f9a87bdc88`  
**LAST_GOOD_CI_RUN:** `33666134609`  
**BLOCKERS:** none  
**MANUAL_ACTION_REQUIRED:** none

## Estado real

A work unit `F12-PERSISTENT-CONTRACTING-DETAIL-READ-01` foi concluída e integrada à `main` pela PR #14.

A jornada `Central → detalhe → Central` agora possui um caminho persistente completo de **leitura**, opt-in por `COMPRAS_PERSISTENT_READ_ENABLED=true`, usando a fronteira F08 (`sessão validada -> issuer + subject -> contexto transacional LOCAL -> PostgreSQL/RLS`) tanto na Central quanto em `/contratacoes/[id]`.

O modo demo continua sendo o default. Configuração inválida ou falha de sessão/banco/contexto em modo persistente produz indisponibilidade genérica e nunca cai silenciosamente para fixtures.

Nenhum banco/Auth/Vercel hospedado foi provisionado. Não existe login/signup operacional, secret real, dado real ou deploy. O repositório continua público e somente dados fictícios/sanitizados são permitidos.

## F12 — detalhe persistente protegido

A implementação adicionou uma leitura server-only do detalhe que:

- executa exclusivamente por `withTrustedDatabaseContext()`;
- valida o identificador da rota antes da consulta e usa UUID apenas como seletor de recurso;
- usa SQL parametrizado com `$1::uuid`, sem interpolação;
- não recebe `team_id`, `membership_id`, `app_user_id`, issuer ou subject do browser;
- deixa PostgreSQL/RLS decidir se o recurso é visível;
- torna UUID inexistente e UUID conhecido de outra equipe externamente equivalentes como `not found`;
- resolve responsável somente por `public.team_member_directory`;
- lê identificadores relacionados ativos, itens ativos e eventos somente das tabelas protegidas existentes;
- deriva a última movimentação de `contracting_events.occurred_at`, não de `updated_at`;
- mantém fallback genérico quando o responsável não é exposto pelo diretório;
- não introduz mutation, CRUD, policy de escrita ou migration nova.

Foi extraído um helper `server-only` mínimo para compartilhar a semântica exata de `COMPRAS_PERSISTENT_READ_ENABLED` entre Central e detalhe: ausente/`false` = demo, exatamente `true` = persistente e qualquer outro valor = configuração inválida/indisponível.

A Central persistente voltou a oferecer navegação para o detalhe correspondente. A tela do detalhe distingue explicitamente fonte demo de leitura persistente e permanece somente leitura.

## Red-team de F12

A prova adversarial cobre deliberadamente:

- ID malformado rejeitado antes de entrar no contexto confiável ou chegar a SQL;
- UUID próprio visível e UUID cross-team invisível mesmo quando conhecido;
- inexistente e cross-team produzindo o mesmo estado externo;
- tentativa de fornecer argumentos extras de escopo sem efeito sobre a consulta;
- query usando bind parameter e sem reabrir `app_users`/`memberships` para colegas;
- responsável ativo da mesma equipe resolvido pela capability view;
- responsável revogado/desabilitado permanecendo fallback genérico;
- identificadores desvinculados e itens aposentados excluídos da leitura ativa;
- identificadores, itens e eventos cross-team permanecendo invisíveis;
- timeline ordenada por `occurred_at`;
- caller sem contexto, desconhecido, sem membership, desabilitado ou revogado permanecendo sem acesso pelas regressões RLS;
- falha protegida retornando apenas estado indisponível, sem serializar erro ou retornar fixture demo;
- nenhuma credencial owner/superuser/`BYPASSRLS`/capability usada como role operacional.

Durante a primeira execução da PR, o red-team/CI encontrou uma incompatibilidade de resolução de alias no Vitest para o novo helper compartilhado. A correção foi reduzida a imports relativos nos dois seletores de fonte; nenhuma fronteira de segurança foi afrouxada. A segunda execução da PR passou integralmente.

## Verificação de F12

- recuperação de `main`, branches e PRs antes da implementação: PASS;
- `CONTEXT_MANIFEST` comparado às fontes estáveis: PASS (`CONTEXT_STATUS = VALID`);
- diff integral da PR #14 revisado: PASS;
- primeira CI da PR detectou falha de resolução de módulo em testes: DETECTADA E CORRIGIDA;
- CI final da PR #14 run `33665994543`: PASS — `verify` e `database`;
- PR #14 squash-merged em `8a771dcf7f98d7000ed746afd5e5f5f9a87bdc88`;
- CI da `main` após merge run `33666134609`: PASS;
- `npm ci`, lint, typecheck, testes e build: PASS;
- regressões PostgreSQL `0001`, `0001 + 0002`, F07/F08/F10/F11 e `0001 + 0002 + 0003`: PASS;
- prova adversarial F12 de detalhe protegido: PASS;
- testes de seleção `demo/persistent/not-found/unavailable`: PASS;
- secret real, dado interno/pré-publicação ou infraestrutura externa: NÃO ENCONTRADOS.

## Limite atual

O repositório agora possui uma jornada persistente de leitura coerente e verificável, mas somente contra bancos efêmeros da CI. A arquitetura de referência cita PostgreSQL/Neon e Vercel, porém permanece explicitamente **não provisionada** e exige revalidação das capacidades/termos atuais antes de implementação externa.

Antes de criar recursos hospedados ou um primeiro preview autenticado, a próxima fronteira independente é fechar o desenho operacional e de segurança desse ambiente: separação de ambientes/roles, admissão privada, secrets, execução de migrations, dados exclusivamente fictícios, logging/analytics e rollback/deprovisionamento.

F13 não deve resolver por inferência as taxonomias nem as questões de permissão/auditoria de leitura. `Q-009` e `Q-010` permanecem abertas, assim como as demais questões ainda marcadas como abertas em `docs/product/OPEN_QUESTIONS.md`.

## Context manifest

Os inputs estáveis do `CONTEXT_MANIFEST` não foram alterados por F12. Código runtime, testes F12, `CURRENT_STATE`, `NEXT_ACTION` e specs de work units são lidos ao vivo pelo protocolo.

## Last good

`8a771dcf7f98d7000ed746afd5e5f5f9a87bdc88` é o `LAST_GOOD_COMMIT`, validado pela CI da `main` run `33666134609` em PASS.

## Próxima ação

Executar `F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01` conforme `docs/ai/NEXT_ACTION.md` e `tasks/F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01/SPEC.md`.
