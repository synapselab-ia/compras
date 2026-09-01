# ADR-002 — Fundação relacional e autorização default-deny

**Status:** Accepted  
**Data:** 2026-09-01

## Contexto

A Central do Setor e o detalhe já validam, em protótipo, a necessidade de persistir contratação, responsabilidade operacional, itens, identificadores relacionados e timeline. Ao mesmo tempo, taxonomias de etapa/status, semântica final dos identificadores e política multiusuário continuam abertas.

Provisionar banco/Auth ou criar enums e políticas permissivas agora congelaria decisões sem evidência suficiente.

## Decisão

A primeira fundação persistente seguirá estes princípios:

1. PostgreSQL relacional e portátil como contrato de dados.
2. `Contratação` como raiz operacional, com UUID interno opaco independente de identificadores administrativos.
3. Toda linha operacional escopada por `team_id` quando necessário para autorização e integridade.
4. Identidade (`app_users`) separada de autorização (`memberships`).
5. Membership inicial representa apenas pertencimento ativo/revogado; não cria `role` nem política final de edição enquanto Q-009 estiver aberta.
6. Etapa, status e tipos de identificador permanecem chaves `text` sem `ENUM` físico ou lista fechada até validação das respectivas open questions.
7. Estado atual permanece estruturado nas tabelas do núcleo; fatos relevantes são preservados em `contracting_events` append-only para o papel operacional.
8. Arquivamento/cancelamento/desvínculo/retirada usam timestamps/estado e eventos, não exclusão silenciosa.
9. O núcleo não usa `jsonb` genérico para substituir relações conhecidas.
10. RLS nasce `deny-by-default`. A primeira migration não terá política permissiva dependente de Auth ainda inexistente.
11. Políticas de leitura/escrita só serão abertas quando a identidade corrente puder ser derivada de sessão/claim verificada e testada adversarialmente.
12. CRUD direto amplo do cliente não será a estratégia para mutações que exigem histórico; estado + evento devem ser atômicos por servidor/transação ou RPC estreita futura.

O detalhamento de tabelas, constraints e testes está em `docs/architecture/DATABASE.md`.

## Consequências positivas

- evita congelar Q-001/Q-002/Q-003/Q-009;
- permite testar schema e RLS sem provedor externo;
- usuário autenticado sem membership continua sem acesso;
- IDs conhecidos não se tornam autorização;
- histórico não depende apenas da linha atual;
- o schema não fica acoplado a Neon/Auth específico;
- migração futura de provedor não exige reescrever o domínio.

## Custos e limites

- após a primeira migration, a aplicação ainda não terá leitura/escrita real de banco;
- será necessária uma slice posterior para integrar identidade confiável e políticas permissivas;
- campos como `stage_key`/`status_key` terão validação semântica principalmente na aplicação até suas taxonomias serem aprovadas;
- consultas de última movimentação inicialmente dependem de `contracting_events`, sem coluna denormalizada em `contractings`.

## Alternativas rejeitadas

### Enums PostgreSQL agora

Rejeitada porque transformaria exemplos provisórios em contrato físico prematuro.

### Um único `process_number` como chave principal

Rejeitada porque contradiz a entidade central `Contratação` e a cardinalidade maior que 1 de identificadores relacionados.

### `user_id` direto em todas as tabelas, sem membership

Rejeitada porque acopla o piloto individual ao schema e não representa autorização por equipe.

### RLS permissiva baseada em `user_id` fornecido pelo cliente

Rejeitada porque permite forjar identidade/escopo e viola deny-by-default.

### `jsonb` como registro principal do processo/timeline

Rejeitada porque enfraquece FKs, constraints, consultas e integridade do núcleo já conhecido.

## Revisão futura

Este ADR deve ser reavaliado apenas se:

- a política institucional exigir outro modelo de escopo;
- o provedor de identidade escolhido impuser uma fronteira técnica incompatível;
- Q-009 introduzir permissões que exijam modelo adicional;
- medição real justificar projeções/índices além do núcleo descrito.
