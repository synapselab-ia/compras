# Database — Compras

**Versão:** 0.1  
**Status:** desenho canônico da primeira fundação persistente; ainda não aplicado  
**Escopo:** PostgreSQL portátil, sem provedor/Auth real e sem dados reais

## 1. Objetivo

Definir o contrato mínimo de persistência para sustentar a Central do Setor, o detalhe da contratação, responsabilidade operacional e histórico sem congelar taxonomias, regras quantitativas ou permissões ainda abertas.

Este documento não é migration aplicada. Quando migrations existirem, elas passam a registrar a história executável do schema.

## 2. Princípios

- `Contratação` é a raiz operacional.
- IDs internos são opacos e independem de números administrativos externos.
- identidade autenticada e autorização por membership são conceitos separados.
- todo dado operacional pertence a um escopo de equipe (`team_id`).
- responsável interno, aguardando e próxima ação são campos distintos.
- fatos históricos relevantes não dependem apenas do estado atual da linha.
- arquivamento, cancelamento, revogação e desvínculo usam estado/timestamp, não exclusão silenciosa.
- taxonomias abertas não viram `ENUM` físico nesta fase.
- o núcleo relacional não usa `jsonb` como substituto de relações já conhecidas.
- autorização falha fechada; políticas permissivas só entram quando houver identidade confiável verificável.
- constraints de negócio só entram quando sustentadas pelas fontes; convenções técnicas não podem virar regra operacional por inferência.

## 3. IDs e tipos básicos

### IDs

Usar `uuid` para chaves internas. O valor pode ser gerado por camada confiável da aplicação ou por implementação PostgreSQL futura, sem depender de identificador externo.

Testes públicos usam somente UUIDs artificiais determinísticos.

### Tempo

Usar `timestamptz` para instantes persistidos.

### Texto de taxonomia ainda aberta

Enquanto Q-001, Q-002, Q-003 e Q-009 estiverem abertas, usar chaves `text` normalizadas quando necessário, sem `ENUM` PostgreSQL e sem `CHECK` que congele uma lista ainda não aprovada.

Isso permite adicionar catálogos/tabelas de referência depois sem migration destrutiva dos registros já existentes.

## 4. Tabelas candidatas do núcleo

### 4.1 `teams`

Escopo lógico de compartilhamento e autorização.

Campos mínimos:

- `id uuid primary key`;
- `name text not null`;
- `created_at timestamptz not null`;
- `archived_at timestamptz null`.

A V0.1 pode possuir uma única equipe, mas o schema não pressupõe isso.

### 4.2 `app_users`

Identidade interna correspondente a uma identidade autenticada externa.

Campos mínimos:

- `id uuid primary key`;
- `auth_issuer text not null`;
- `auth_subject text not null`;
- `display_name text not null`;
- `created_at timestamptz not null`;
- `disabled_at timestamptz null`.

Constraint:

- `unique (auth_issuer, auth_subject)`.

`auth_issuer + auth_subject` identifica a identidade autenticada sem assumir que um `subject` seja globalmente único entre provedores/emissores. Não é email nem segredo. A mecânica exata para obter ambos de uma sessão confiável permanece fora desta slice.

### 4.3 `memberships`

Vínculo de autorização entre usuário e equipe.

Campos mínimos:

- `id uuid primary key`;
- `team_id uuid not null references teams(id)`;
- `user_id uuid not null references app_users(id)`;
- `joined_at timestamptz not null`;
- `revoked_at timestamptz null`.

Constraints/índices:

- `unique (team_id, user_id)`;
- `unique (team_id, id)` para permitir FKs compostas que garantam mesmo escopo;
- índice por `user_id` e membership ativo.

Não existe coluna de `role` nesta fundação. Q-009 continua aberta. Uma membership ativa prova pertencimento ao escopo; permissões mais finas serão adicionadas somente quando houver regra aprovada.

### 4.4 `contractings`

Registro operacional central.

Campos mínimos candidatos:

- `id uuid primary key`;
- `team_id uuid not null references teams(id)`;
- `object text not null`;
- `responsible_membership_id uuid null`;
- `stage_key text null`;
- `status_key text null`;
- `waiting_type text null`;
- `waiting_reference text null`;
- `waiting_since timestamptz null`;
- `waiting_reason text null`;
- `next_action text null`;
- `created_by_membership_id uuid null`;
- `created_at timestamptz not null`;
- `updated_at timestamptz not null`;
- `archived_at timestamptz null`;
- `cancelled_at timestamptz null`.

Constraints estruturais:

- `unique (team_id, id)`;
- `(team_id, responsible_membership_id)` referencia `(team_id, id)` de `memberships`;
- `(team_id, created_by_membership_id)` segue o mesmo padrão.

Assim, quando uma referência existir, o banco impede apontar responsável/ator de outra equipe.

Nullability de `responsible_membership_id`, `stage_key`, `status_key` e `next_action` permanece permissiva na primeira fundação porque o fluxo de criação/importação ainda não definiu em qual instante cada campo se torna obrigatório. A aplicação pode exigir valores em jornadas específicas sem transformar hipótese de workflow em constraint prematura.

`updated_at` não é sinônimo automático de “última movimentação relevante”. A Central deve obter a última movimentação a partir de eventos até existir evidência de que uma projeção denormalizada é necessária.

### 4.5 `related_identifiers`

Aceita múltiplos identificadores/processos ligados à mesma contratação sem fechar Q-003.

Campos mínimos:

- `id uuid primary key`;
- `team_id uuid not null`;
- `contracting_id uuid not null`;
- `identifier_kind text null`;
- `identifier_value text not null`;
- `source_system text null`;
- `note text null`;
- `linked_at timestamptz not null`;
- `unlinked_at timestamptz null`.

Constraints estruturais:

- `(team_id, contracting_id)` → `contractings(team_id, id)`;
- `unique (team_id, contracting_id, id)` para permitir referência de evento preservando a contratação correta.

Não criar enum/constraint de `identifier_kind` nesta fase.

Não criar unicidade semântica além do ID interno até Q-003 esclarecer quando dois identificadores aparentemente iguais representam duplicação versus vínculos legítimos.

### 4.6 `contracting_items`

Itens pertencentes à contratação.

Campos mínimos candidatos:

- `id uuid primary key`;
- `team_id uuid not null`;
- `contracting_id uuid not null`;
- `ordinal integer not null`;
- `description text not null`;
- `quantity numeric null`;
- `unit text null`;
- `catalog_code text null`;
- `created_at timestamptz not null`;
- `updated_at timestamptz not null`;
- `retired_at timestamptz null`.

Constraints estruturais:

- `(team_id, contracting_id)` → `contractings(team_id, id)`;
- `unique (contracting_id, ordinal)` para que a ordem atual não tenha duas linhas com o mesmo identificador ordinal;
- `unique (team_id, contracting_id, id)` para referências históricas de mesmo escopo.

Não codificar nesta fundação faixa, sinal, precisão máxima ou obrigatoriedade de `quantity`, porque essas regras não foram aprovadas como invariantes de negócio. Quando houver fonte operacional suficiente, constraints poderão ser apertadas por nova migration.

Estado da pesquisa de preços, evidências e cálculos não entram nesta tabela nesta fase; pertencem ao módulo futuro de pesquisa.

Mudanças relevantes de descrição/quantidade devem gerar evento; `retired_at` evita exclusão silenciosa de item já histórico.

### 4.7 `contracting_events`

Timeline/auditoria operacional append-only.

Campos mínimos candidatos:

- `id uuid primary key`;
- `team_id uuid not null`;
- `contracting_id uuid not null`;
- `actor_membership_id uuid null`;
- `event_type text not null`;
- `occurred_at timestamptz not null`;
- `field_key text null`;
- `old_value text null`;
- `new_value text null`;
- `note text null`;
- `related_identifier_id uuid null`;
- `item_id uuid null`;
- `created_at timestamptz not null`.

Regras:

- `(team_id, contracting_id)` → `contractings(team_id, id)`;
- ator, quando presente, referencia membership da mesma equipe;
- `(team_id, contracting_id, related_identifier_id)` referencia o identificador da mesma contratação quando presente;
- `(team_id, contracting_id, item_id)` referencia o item da mesma contratação quando presente;
- eventos normais são imutáveis para o papel operacional: sem `UPDATE`/`DELETE` permissivos;
- `event_type` é chave extensível, não enum fechado nesta fase.

`old_value/new_value` registram representação auditável de uma alteração escalar; não substituem o estado estruturado atual. Não usar `jsonb` genérico como repositório paralelo do domínio.

Eventos de nota manual podem usar `note` sem `field_key`.

## 5. O que fica deliberadamente fora do primeiro schema

- entidade `Pendência`, enquanto Q-006 não bloquear uma jornada real;
- tabelas de pesquisa/evidência de preço;
- documentos/source manifest operacional;
- catálogos finais de etapa/status;
- papéis/perfis de permissão;
- auditoria de leitura, dependente de Q-010;
- cache de fontes públicas;
- constraints de quantidade não sustentadas por fonte aprovada.

Esses módulos podem ser adicionados por migrations posteriores sem alterar a identidade da contratação.

## 6. Índices mínimos

Para as consultas já prototipadas:

### Central

- `contractings(team_id)`;
- `contractings(team_id, responsible_membership_id)`;
- `contractings(team_id, stage_key)`;
- `contractings(team_id, status_key)`;
- índice parcial/adequado para ativos quando arquivamento/cancelamento começar a ser filtrado;
- `contracting_events(contracting_id, occurred_at desc)` para última movimentação/timeline.

### Busca por identificador

- `related_identifiers(team_id, identifier_value)`;
- `related_identifiers(contracting_id)`.

### Detalhe

- `contracting_items(contracting_id, ordinal)`;
- `contracting_events(contracting_id, occurred_at desc)`.

Full-text, trigram e índices específicos de performance entram somente com medição/consulta concreta.

## 7. Histórico e mutações

### Estado atual + eventos

`contractings` guarda o estado operacional atual necessário à Central.

`contracting_events` guarda fatos históricos relevantes.

Uma alteração rastreável deve atualizar estado e registrar evento na mesma transação lógica.

Para evitar mutação sem histórico, a direção arquitetural é não conceder CRUD direto amplo de tabelas internas ao cliente. A futura escrita deve passar por servidor/transação ou função/RPC estreita que imponha autorização e evento atomicamente.

A escolha entre transação server-side e função PostgreSQL específica será feita na slice de escrita; nenhuma delas pode permitir que cliente forneça `actor_user_id` confiável por parâmetro.

### Arquivamento/cancelamento

`archived_at`, `cancelled_at`, `revoked_at`, `unlinked_at` e `retired_at` preservam o registro.

Reabertura/restauração, quando permitida pelo produto, altera o estado corrente e acrescenta evento; não apaga o evento anterior.

## 8. Identidade, membership e fronteira de confiança

A aplicação precisa distinguir três coisas:

1. **identidade autenticada** — `issuer + subject` validados por provedor/servidor;
2. **`app_user`** — identidade interna estável;
3. **membership ativa** — autorização para um `team_id`.

Conhecer um UUID não concede acesso.

O cliente não pode escolher livremente `user_id`, `membership_id` ou `team_id` para obter autorização.

A implementação de `current_app_user()` deve derivar de credencial/sessão verificada. Um mecanismo baseado em variável de sessão configurável pelo próprio cliente não é aceitável como fronteira de produção.

## 9. Estratégia RLS / deny-by-default

### Fundação inicial

Primeira migration deve:

- criar tabelas e constraints;
- habilitar RLS nas tabelas internas que possam futuramente ser expostas;
- não criar política permissiva dependente de identidade ainda não integrada;
- manter grants de produção mínimos;
- manter papel proprietário/migration separado de qualquer papel operacional e sem usar `BYPASSRLS` como caminho normal;
- provar em teste que um papel operacional criado apenas no ambiente de teste, mesmo recebendo grants DML para exercitar o enforcement, continua sem enxergar/modificar linhas pela ausência de policies.

Assim os testes distinguem `permission denied` de enforcement real de RLS sem obrigar a migration de produção a conceder acesso amplo.

### Liberação futura de leitura

Somente após existir adaptador de identidade confiável:

- mapear `issuer + subject` autenticados → `app_user`;
- resolver memberships ativas;
- permitir `SELECT` apenas para linhas cujo `team_id` pertença às memberships autorizadas;
- testar usuário sem membership, membership revogada e ID conhecido de outra equipe.

### Escrita

Não inferir Q-009 a partir da existência de membership.

Enquanto houver apenas piloto individual, políticas de escrita podem ser implementadas para o único membership autorizado, mas antes de admitir segundo membro a política deve ser explicitamente revisada.

Nenhum papel com `BYPASSRLS` serve como evidência de autorização normal.

## 10. Migrations

Diretório canônico:

```text
database/
├── migrations/
└── tests/
```

Regras:

- nomes ordenáveis (`0001_...sql`, `0002_...sql`);
- migration aplicada nunca é reescrita para alterar história;
- correção vira nova migration;
- DDL deve ser transacional quando PostgreSQL permitir;
- objetos privilegiados devem fixar `search_path` e minimizar superfície;
- migrations não contêm secrets nem dados operacionais reais;
- seed de teste usa dados artificiais e fica separado de produção.

## 11. Testes de banco

Primeira estratégia: PostgreSQL descartável em CI, sem provedor hospedado e sem dados reais.

A suíte deve conseguir validar por SQL, no mínimo:

- criação do schema do zero;
- FKs e constraints de mesma equipe;
- cardinalidade múltipla de identificadores preservada;
- tentativa de apontar responsável de outra equipe rejeitada;
- evento não consegue apontar item/identificador de outra contratação/equipe;
- ordinal duplicado dentro da mesma contratação é rejeitado;
- eventos não podem ser alterados/excluídos pelo papel operacional;
- RLS default-deny para papel sem policy permissiva;
- conhecimento de UUID válido não contorna RLS;
- membership revogada não deverá conceder acesso quando policies de leitura forem implementadas.

Não criar teste para uma suposta faixa/positividade de quantidade antes de existir regra aprovada.

Preferir testes SQL simples e reproduzíveis antes de adicionar framework de banco sem necessidade.

## 12. Logs, fixtures e dados públicos do repositório

Enquanto `REPO_VISIBILITY = PUBLIC`:

- nenhuma migration, fixture, teste, Issue, PR ou log contém processo/nome/CNPJ/valor/documento/caminho real;
- UUIDs, issuers e subjects usados em testes são artificiais;
- nenhum JWT, token, connection string ou credencial real;
- eventos de teste usam textos `DEMO-*`/genéricos;
- logs não imprimem payload interno completo.

## 13. Decisões adiadas explicitamente

| Questão | Tratamento nesta fundação |
|---|---|
| Q-001 etapas | `stage_key text`, sem enum/lista fechada |
| Q-002 status | `status_key text`, sem enum/lista fechada |
| Q-003 processos relacionados | cardinalidade N; `identifier_kind text` sem taxonomia fechada |
| Q-004 ±25% | nenhum schema/cálculo nesta fase |
| Q-005 inatividade | nenhum limiar codificado; eventos permitem calcular depois |
| Q-006 Pendência | entidade adiada |
| Q-009 permissões | membership sem `role`; policies finas adiadas |
| Q-010 auditoria de leitura | não implementada; timeline registra alterações/fatos, não views |

Regras quantitativas de item que não constam dessas questões também não são inventadas por convenção de banco.

## 14. Primeira implementação recomendada

A primeira migration deve implementar somente esta fundação relacional e o estado **default-deny**, com testes locais/CI.

Ela não deve conectar a UI ao banco nem criar policy permissiva baseada em Auth ainda inexistente.

Depois desse gate, a próxima decisão técnica pode escolher o adaptador de identidade/RLS usando documentação oficial atual do provedor que realmente for adotado.
