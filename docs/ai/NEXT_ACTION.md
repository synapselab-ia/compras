# Next Action — Compras

## F12-PERSISTENT-CONTRACTING-DETAIL-READ-01 — Conectar detalhe à leitura persistente protegida

**Classe:** `T1 — feature de leitura` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** conectar `/contratacoes/[id]` ao caminho persistente server-only já validado, usando somente o ID opaco como seletor do recurso e deixando RLS determinar autorização, sem receber `team_id`/membership/user do browser, sem escrita e sem provisionar infraestrutura.

## Fonte da tarefa

Executar conforme `tasks/F12-PERSISTENT-CONTRACTING-DETAIL-READ-01/SPEC.md`, ADR-003, ADR-004, ADR-005 e migrations `0001`–`0003`.

## Resultado esperado

Ao final, o repositório deve possuir:

- leitura persistente server-side do detalhe executada exclusivamente por `withTrustedDatabaseContext()`;
- `id` de rota usado somente para localizar a contratação, nunca como prova de autorização;
- nenhuma API que aceite `team_id`, `membership_id`, `app_user_id`, issuer ou subject do cliente;
- RLS continuando responsável por tornar UUID conhecido de outra equipe invisível;
- responsável resolvido somente por `public.team_member_directory`;
- identificadores relacionados, itens e eventos lidos somente pelas tabelas já protegidas e pelas policies existentes;
- separação explícita entre detalhe demo, detalhe persistente, não encontrado e indisponível;
- falha persistente sem fallback silencioso para fixtures demo;
- Central em modo persistente podendo voltar a oferecer navegação para o detalhe persistente correspondente;
- nenhuma migration/policy de escrita nova salvo se uma necessidade estrutural objetiva e estritamente de leitura for descoberta e justificada.

## Regras obrigatórias

- reutilizar a fronteira F08 e `COMPRAS_PERSISTENT_READ_ENABLED`; não criar um segundo modo de ativação divergente;
- se necessário, extrair apenas um helper server-only mínimo para compartilhar a seleção demo/persistente entre Central e detalhe;
- validar o `id` opaco antes de passá-lo à query; usar parâmetro SQL, nunca interpolação;
- não aceitar ou derivar autorização de `team_id` fornecido por URL, query, body ou header;
- um registro inexistente e um registro existente fora do escopo devem resultar no mesmo estado externo de não encontrado, sem oracle de autorização;
- erro de sessão/configuração/banco/contexto deve resultar em estado indisponível genérico, não `not found` e não demo;
- não serializar erro, cookie, sessão, claim ou connection string;
- usar `team_member_directory` para nome de responsável e não reabrir `app_users`/`memberships` para colegas;
- não inventar taxonomias finais para etapa, status, tipo de identificador ou evento;
- Q-009 e Q-010 permanecem abertas;
- nenhum login/signup/admissão, infraestrutura hospedada, secret real ou dado real.

## Segurança mínima a provar

- UUID válido da própria equipe retorna somente o detalhe autorizado;
- UUID válido conhecido de outra equipe fica invisível por RLS e é indistinguível de inexistente;
- ID malformado não chega a SQL interpolado e não produz detalhe demo em modo persistente;
- tentativa de passar `team_id`, membership ou user por argumento/cast não altera escopo;
- responsável de colega ativo da mesma equipe é resolvido pela capability view;
- membership responsável revogada ou app_user desabilitado permanece fallback genérico;
- `related_identifiers`, `contracting_items` e `contracting_events` permanecem limitados ao registro/equipe autorizado;
- nenhum owner, superuser, `BYPASSRLS`, `neondb_owner` ou capability role é usado pela aplicação;
- falha do banco/sessão não vaza detalhes e não cai para demo;
- nenhum dado sensível entra em URL além do ID opaco já necessário à rota.

## Verificação obrigatória

- regressões `0001 + 0002 + 0003` e suites F07/F08/F10/F11: PASS;
- testes unitários/adversariais da leitura persistente do detalhe: PASS;
- testes de seleção de fonte/estados demo-persistent-not-found-unavailable: PASS;
- navegação da Central consistente com o modo selecionado: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI: PASS;
- diff integral sem secret, dado real ou infraestrutura provisionada.

## Fora do escopo

Não:

- mutations, CRUD ou policy/RPC de escrita;
- edição do detalhe;
- perfil/role funcional da Q-009;
- auditoria de leitura da Q-010;
- login/signup/admissão;
- criação de usuário real;
- provisionamento Neon/Auth/Vercel;
- deploy;
- dados reais;
- fechamento de taxonomias ainda abertas;
- pesquisa de preços.

## Critério de encerramento

A tarefa termina quando Central e detalhe possuem uma jornada de leitura persistente opt-in coerente, o ID da rota é apenas seletor de recurso e nunca escopo/autorização, registros cross-team permanecem invisíveis por RLS, falhas protegidas são indistinguíveis de sucesso demo e existe exatamente uma nova `NEXT_ACTION` executável para a próxima fronteira necessária.
