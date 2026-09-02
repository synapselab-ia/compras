# F10-TEAM-DIRECTORY-RLS-DESIGN-01 — Diretório seguro de membros para responsáveis

**Classe:** T2 — banco/segurança, com impacto de T5 — arquitetura  
**Estado:** READY após conclusão de F09  
**Dependências:** F07, F08, F09, ADR-003 e migrations `0001`/`0002`  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

A Central compartilhada precisa identificar quem está responsável por cada contratação. A F09 conectou a leitura persistente sem ampliar a superfície de autorização e revelou um limite real: `contractings` da equipe são visíveis a membros ativos, mas `memberships` e `app_users` foram deliberadamente abertas apenas para a própria identidade.

Usar `responsible_membership_id` não basta para a experiência final, e abrir `app_users` diretamente exporia `auth_issuer`/`auth_subject` além do necessário. Uma policy de `memberships` que consulte a própria tabela também pode introduzir recursão de RLS.

## 2. Resultado esperado

Definir a projeção mínima e segura necessária para a Central resolver responsáveis da própria equipe. A solução deve preferir um contrato contendo somente:

- `team_id` necessário ao enforcement;
- `membership_id` estável para associação com `contractings.responsible_membership_id`;
- `display_name` necessário à UI;
- estado mínimo indispensável para excluir membership revogada/usuário desabilitado, sem duplicar identidade externa.

A work unit deve produzir uma das duas saídas válidas:

### A — implementação segura demonstrada

Se o desenho puder ser implementado sem quebrar invariantes:

- criar nova migration ordenável, sem reescrever `0001`/`0002`;
- criar somente view/tabela/função/policy estritamente necessária;
- adicionar testes PostgreSQL adversariais;
- atualizar a query da F09 para usar o diretório e mostrar nomes autorizados.

### B — ADR por bloqueio arquitetural real

Se toda alternativa segura exigir decisão material sobre ownership, `SECURITY DEFINER`, duplicação de estado ou outro trade-off estrutural:

- registrar ADR com alternativas analisadas;
- explicar por que não é seguro escolher por conveniência;
- preservar o rótulo genérico da F09;
- deixar uma próxima action de implementação/decisão claramente delimitada.

## 3. Invariantes

- `FORCE ROW LEVEL SECURITY` permanece nas tabelas protegidas;
- identidade continua `issuer + subject -> app_user -> membership ativa -> team_id`;
- browser não escolhe identidade nem escopo;
- role operacional não é owner, superuser ou `BYPASSRLS`;
- não expor `auth_issuer` ou `auth_subject` à Central como dado de diretório;
- membership revogada não concede visibilidade;
- usuário desabilitado não concede visibilidade;
- conhecer UUID de membership/team de outro escopo não concede acesso;
- Q-009 continua aberta; ler nome de colega não equivale a criar papel/permissão de escrita.

## 4. Alternativas que precisam ser comparadas

No mínimo:

1. expandir policy direta de `memberships`/`app_users`;
2. view/projeção com `security_invoker` ou mecanismo PostgreSQL equivalente atual;
3. função estreita, avaliando rigorosamente `SECURITY INVOKER` versus `SECURITY DEFINER`;
4. tabela/projeção relacional dedicada para diretório, avaliando sincronização e duplicação;
5. manter resolução apenas server-side sem alterar RLS, se existir forma que não use credencial privilegiada nem bypass.

Não assumir que uma alternativa funciona sem testar comportamento real de RLS/ownership/recursão em PostgreSQL descartável.

## 5. Documentação oficial

Quando a decisão depender de detalhe de PostgreSQL, consultar documentação oficial atual para:

- row security e `FORCE ROW LEVEL SECURITY`;
- ownership e `BYPASSRLS`;
- `SECURITY DEFINER`/`SECURITY INVOKER`;
- views `security_invoker`, quando consideradas;
- comportamento de policies que consultam tabelas também protegidas.

Separar claramente comportamento do PostgreSQL de decisão arquitetural do projeto.

## 6. Testes mínimos se houver implementação

Fixtures continuam artificiais e devem cobrir pelo menos duas equipes e identidades distintas.

Provar:

- sem contexto -> nenhum diretório;
- identidade desconhecida -> nenhum diretório;
- usuário desabilitado -> nenhum diretório;
- membership revogada -> nenhum diretório;
- membro ativo A1 -> vê somente diretório permitido da equipe A;
- membro ativo A1 -> consegue resolver display name de A2 quando A2 for membro permitido;
- A1 não vê B1 da equipe B;
- UUID conhecido de B1 não produz linha;
- `auth_issuer` e `auth_subject` não fazem parte da projeção retornável;
- nenhuma policy de escrita foi aberta;
- regressões F05/F07/F08/F09 continuam PASS.

## 7. Red-team obrigatório

Procurar deliberadamente:

- recursão infinita de policy em `memberships`;
- view que execute com privilégios do owner e ignore RLS sem intenção;
- função `SECURITY DEFINER` com `search_path` inseguro ou superfície ampla;
- exposição de auth identifiers por `SELECT *`;
- helper que aceite user/team/membership do cliente como autorização;
- remoção de `FORCE RLS`;
- criação de role BYPASSRLS para facilitar teste/produção;
- diretório cross-team por UUID conhecido;
- membership revogada ou usuário desabilitado ainda visível;
- duplicação de dados sem estratégia transacional clara;
- alteração de taxonomia ou Q-009 por acidente.

## 8. Fora do escopo

- login/signup/admissão;
- infraestrutura real;
- policies de escrita;
- perfis/roles finais;
- auditoria de leitura;
- detalhe persistente;
- documentos e pesquisa de preços;
- dados reais.

## 9. Encerramento

Concluir somente após red-team e verificação proporcionais. Se implementar, integrar apenas com CI verde e deixar uma única próxima action. Se não implementar por risco arquitetural real, ADR e checkpoint devem tornar o bloqueio reproduzível sem pedir contexto já documentado ao usuário.
