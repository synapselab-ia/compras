# Next Action — Compras

## F10-TEAM-DIRECTORY-RLS-DESIGN-01 — Projetar leitura segura do diretório de responsáveis

**Classe:** `T2 — banco/segurança` com impacto de `T5 — arquitetura`  
**Estado:** READY  
**Objetivo:** definir e provar o menor desenho seguro que permita a um membro ativo identificar os responsáveis visíveis da própria equipe na Central, sem expor identificadores externos de Auth, sem aceitar escopo do cliente e sem enfraquecer `FORCE ROW LEVEL SECURITY`, a fronteira F08 ou as policies já validadas.

## Fonte da tarefa

Executar conforme `tasks/F10-TEAM-DIRECTORY-RLS-DESIGN-01/SPEC.md`, `docs/architecture/SECURITY.md`, `docs/architecture/DATABASE.md`, ADR-003 e migrations `0001`/`0002`.

## Problema concreto

A F09 provou a primeira leitura persistente da Central. `contractings` de uma equipe ficam visíveis por membership ativa, porém as policies atuais de `memberships` e `app_users` retornam somente a própria membership/identidade. Assim, a Central não consegue resolver com segurança o `display_name` de outra membership responsável.

A solução não pode simplesmente abrir `app_users`, pois essa tabela contém `auth_issuer` e `auth_subject`, nem pode criar policy autorreferente de `memberships` que provoque recursão de RLS.

## Resultado esperado

Ao final deve existir uma decisão arquitetural verificável para uma projeção/diretório mínimo contendo somente dados necessários à UI, por exemplo `team_id`, `membership_id` e `display_name`, com estas propriedades:

- um usuário sem membership ativa não vê diretório algum;
- um membro ativo vê somente membros permitidos do próprio escopo;
- identidade externa (`auth_issuer`, `auth_subject`) não entra na projeção de diretório;
- membership revogada e usuário desabilitado são tratados explicitamente;
- UUID conhecido de outra equipe não amplia acesso;
- nenhuma autorização depende de `team_id`, membership ou user enviados pelo browser;
- nenhuma role operacional usa owner, superuser ou `BYPASSRLS`;
- `FORCE ROW LEVEL SECURITY` não é removido apenas para evitar recursão;
- a solução não introduz `SECURITY DEFINER` ou bypass privilegiado sem análise explícita, necessidade demonstrada e red-team proporcional.

Se houver uma solução simples e segura compatível com os invariantes existentes, implementar migration/testes nesta mesma work unit. Se as alternativas exigirem mudança arquitetural material, registrar ADR e deixar a implementação como a próxima ação, sem enfraquecer segurança para encerrar a tarefa.

## Inspeção obrigatória

- reler `SECURITY.md`, `DATABASE.md` e ADR-003;
- revisar integralmente `0001_core_foundation.sql` e `0002_trusted_identity_read_policies.sql`;
- revisar suites F07 e a query da F09;
- analisar risco de recursão em policy autorreferente de `memberships`;
- validar comportamento PostgreSQL relevante em documentação oficial atual quando a decisão depender de `FORCE RLS`, views `security_invoker`, `SECURITY DEFINER`, ownership ou bypass;
- comparar pelo menos as alternativas de policy direta, view/projeção, função estreita e modelo relacional adicional antes de escolher.

## Regras obrigatórias

- não expor todas as colunas de `app_users` como solução de conveniência;
- não enviar `auth_issuer`/`auth_subject` ao Client Component para identificar responsável;
- não adicionar `team_id` aos claims confiáveis para contornar a derivação por membership sem nova decisão arquitetural explícita;
- não usar `neondb_owner`, owner de tabela, superuser ou `BYPASSRLS` como caminho normal;
- não remover `FORCE RLS` para fazer policy funcionar;
- não auto-provisionar usuário ou membership;
- não resolver Q-009 por inferência; a tarefa trata visibilidade mínima necessária à Central, não papéis de escrita;
- manter fixtures totalmente fictícias.

## Segurança mínima a provar

- identidade desconhecida: diretório vazio/negado;
- usuário desabilitado: diretório vazio/negado;
- membership revogada: diretório vazio/negado;
- membro ativo da equipe A: não vê membros da equipe B;
- UUID conhecido cross-team: não amplia escopo;
- projeção não contém `auth_issuer`/`auth_subject`;
- ausência de policy/objeto privilegiado desnecessário;
- suites `0001` default-deny e `0001 + 0002` continuam sem regressão.

## Verificação obrigatória

Se houver código/migration:

- migration histórica não reescrita;
- testes PostgreSQL adversariais: PASS;
- `npm ci`: PASS;
- lint: PASS;
- typecheck: PASS;
- testes: PASS;
- build: PASS;
- CI: PASS;
- diff integral sem secret, dado real ou recurso externo.

Se a saída for somente design/ADR por bloqueio arquitetural real, registrar os comandos executáveis como `SKIPPED` quando não houver alteração de runtime, mas provar coerência e red-team do desenho.

## Fora do escopo

Não:

- policy de escrita;
- papéis finais da Q-009;
- auditoria de leitura da Q-010;
- login/signup/admissão;
- provisionamento externo;
- detalhe persistente;
- pesquisa de preços;
- dados reais.

## Critério de encerramento

A tarefa termina quando existir uma solução segura e explícita para o diretório mínimo de responsáveis — implementada e testada quando tecnicamente segura nesta slice, ou documentada em ADR com bloqueio objetivo quando exigir decisão arquitetural adicional — e exatamente uma nova `NEXT_ACTION` executável.
