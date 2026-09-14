# F34-PERSISTENT-CONTRACTING-ITEM-CREATE-DESIGN-01 - Desenhar adição persistente mínima de item

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** READY  
**Dependências:** fundação `contracting_items`, F26, F29, F32, SECURITY, DATABASE e modelo de domínio  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O núcleo funcional inicial prevê itens dentro de uma contratação, e a fundação física já possui `contracting_items`, mas ainda não existe boundary persistente autorizada para adicionar um item. A próxima slice deve desenhar essa mutação antes de escrever migration, primitive, adapter ou UI.

O desenho não pode inventar taxonomias, regras de pesquisa de preços, validações de quantidade/unidade ou política multiusuário ainda não aprovadas.

## Base canônica já existente

A tabela física integrada desde `0001_core_foundation.sql` possui:

```text
id uuid PK
team_id uuid NOT NULL
contracting_id uuid NOT NULL
ordinal integer NOT NULL
description text NOT NULL
quantity numeric NULL
unit text NULL
catalog_code text NULL
created_at timestamptz NOT NULL
updated_at timestamptz NOT NULL
retired_at timestamptz NULL
UNIQUE (contracting_id, ordinal)
```

`contracting_events` já pode referenciar `item_id` dentro do mesmo `team_id + contracting_id`.

O modelo conceitual prevê item com ordem, descrição, quantidade, unidade e código de catálogo, mas não aprova validações adicionais além das invariantes já canônicas. Q-004 sobre a regra de pesquisa de preços permanece aberta e está fora desta slice.

## Objetivo

Definir uma boundary mínima, least-privilege e auditável para adicionar um item a uma contratação existente, incluindo:

- payload mínimo confiável;
- derivação de team/actor/scope exclusivamente do servidor/banco;
- geração server-side dos UUIDs necessários;
- atribuição de `ordinal` segura sob concorrência;
- autorização pilot-only coerente com uma contratação já existente;
- capability PostgreSQL dedicada ou alternativa formalmente justificada;
- criação atômica da row e do evento correspondente;
- resultados externos sanitizados e indistinguíveis para negações;
- matriz adversarial e de concorrência para a futura implementação.

## Decisões obrigatórias

### 1. Payload e semântica dos campos

Definir o menor payload server-only necessário. O desenho deve partir do schema real e do domínio aprovado, sem criar regra de negócio nova.

Devem ser avaliados explicitamente:

- `contractingId` como seletor candidato, nunca fonte de scope;
- item UUID gerado server-side;
- event UUID gerado server-side;
- `description` como `text NOT NULL`, preservada conforme a semântica física/canônica aprovada;
- `quantity`, `unit` e `catalogCode` como nullable enquanto nenhuma regra mais restritiva estiver aprovada;
- ausência de team, actor, membership, issuer, subject e ordinal confiados ao browser.

O desenho não pode introduzir silenciosamente trim, empty-to-NULL, quantidade positiva obrigatória, unidade obrigatória, precisão/escala de negócio, catálogo obrigatório ou limites de tamanho.

### 2. Ordenação e concorrência

`ordinal` participa de `UNIQUE (contracting_id, ordinal)`. A ADR deve decidir como o banco atribui o próximo ordinal sem depender de valor confiado ao browser e sem race condition.

A solução deve especificar:

- mecanismo de serialização/lock;
- comportamento com duas ou mais criações concorrentes na mesma contratação;
- comportamento em contratações diferentes;
- se gaps existentes são preservados ou reutilizados;
- invariantes para evitar duplicidade e lost insert.

A escolha deve ser provável em PostgreSQL 17 por teste concorrente real na futura implementação.

### 3. Autorização pilot-only

Como a contratação alvo já existe e possui `team_id` canônico, o desenho deve partir do padrão por equipe alvo de F26/F32, e não copiar automaticamente o guard global de criação F29.

A decisão deve cobrir pelo menos:

- identidade interna ativa;
- contratação alvo visível, não arquivada e não cancelada;
- membership não revogada do usuário na equipe alvo;
- política pilot-only vigente enquanto Q-009 estiver aberta;
- segundo membro não revogado na equipe alvo;
- membership adicional do mesmo usuário em outra equipe;
- inexistente e cross-team externamente indistinguíveis.

Nenhuma política multiusuário nova pode ser inferida.

### 4. Capability e least privilege

Avaliar explicitamente capability própria para item create versus ampliação de capabilities existentes. A decisão deve preservar separação de authority.

Se houver primitive `SECURITY DEFINER`, o desenho deve exigir, no mínimo:

- owner técnico dedicado `NOLOGIN`, `NOINHERIT`, não privilegiado;
- `search_path = pg_catalog`;
- SQL estático;
- `PUBLIC EXECUTE` revogado;
- runtime normal sem DML direto;
- grant separado concedendo somente `EXECUTE` necessário;
- ausência de membership utilizável ou ownership indevido de tabelas-base.

F26 deve continuar exclusiva de `next_action`, F29 exclusiva de criação mínima de contratação e F32 exclusiva de mutação de `object`.

### 5. Atomicidade e auditoria

Definir evento automático para criação do item e seus campos mínimos, usando `contracting_events.item_id` já existente.

O desenho deve especificar:

- event type e semântica do evento;
- vínculo ao item criado;
- actor/team derivados;
- instante de banco consistente;
- item e evento na mesma transação;
- rollback integral se a auditoria falhar;
- nenhum evento em negação/falha anterior à criação.

Não inventar histórico textual duplicado quando campos estruturados existentes forem suficientes.

### 6. Resultados externos

Definir conjunto pequeno de resultados sanitizados. Negação por inexistência, cross-team, identidade inválida, membership inválida, segundo membro, arquivada ou cancelada deve permanecer sem oracle de existência.

Falhas técnicas não podem expor SQL, driver, claims, connection string ou detalhes internos e nunca podem cair para demo.

## Artefatos esperados

F34 é design-only. Deve produzir, no mínimo:

1. uma ADR nova, prevista como `ADR-014`, com as decisões acima;
2. atualização documental mínima necessária em SECURITY/DATABASE se a decisão materialmente exigir;
3. SPEC da futura implementação F35, com matriz PostgreSQL/adversarial/concurrency verificável;
4. checkpoint canônico apontando somente para F35 após todos os gates documentais.

## Testes e matriz a desenhar para F35

A SPEC futura deve exigir prova de, no mínimo:

- runtime sem DML direto;
- capability sem privilege escalation;
- Auth/read-only/F26/F29/F32 sem authority de item create;
- claims ausentes, malformados e desconhecidos;
- usuário desabilitado;
- membership ausente/revogada;
- segundo membro não revogado na equipe alvo;
- membership adicional do mesmo usuário em outra equipe;
- cross-team e inexistente indistinguíveis;
- arquivada/cancelada negadas;
- valores nullable preservados de acordo com a decisão;
- ausência de normalização inventada;
- item UUID e event UUID não controlados pelo browser;
- concorrência de múltiplos creates na mesma contratação sem ordinal duplicado;
- concorrência em contratações diferentes sem bloqueio global desnecessário;
- exatamente um evento por criação bem-sucedida;
- rollback do item se o evento falhar;
- nenhuma alteração das migrations aplicadas `0001..0006`.

## Red-team obrigatório

Rejeitar PASS do desenho se:

- browser puder definir team, actor, membership, issuer, subject, item UUID, event UUID ou scope confiável;
- `ordinal` controlado pelo cliente puder causar overwrite, collision ou authority indevida;
- a solução depender de retry cego não especificado para resolver corrida de ordinal;
- F26/F29/F32 forem ampliadas sem justificativa de least privilege;
- runtime receber DML direto;
- capability técnica puder ser usada como role de login normal ou ganhar authority ampla;
- Q-004 ou Q-009 forem resolvidas implicitamente;
- quantidade/unidade/catálogo ganharem validação de negócio não suportada pelas fontes;
- item puder ser criado em contratação arquivada/cancelada ou cross-team;
- evento não for atômico com o item;
- provider hosted, secret ou dado real forem usados;
- migrations `0001..0006` forem reescritas.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum provider hosted write;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-001/Q-002/Q-003/Q-004/Q-006/Q-009 continuam abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0006` permanecem imutáveis;
- nenhuma regra nova é aprovada só por aparecer como exemplo em documento draft.

## Fora do escopo

- implementar migration, SQL, provisionamento, adapter, Server Action ou UI de item;
- editar, reordenar, retirar ou restaurar item existente;
- pesquisa de preços, evidências, regra de +/-25% ou Q-004;
- alterar taxonomias de etapa/status;
- resolver Q-003 de processos relacionados;
- resolver política multiusuário Q-009;
- importar dado real;
- retomar F21.

## Critério de encerramento

F34 fecha quando existir uma decisão arquitetural completa e adversarialmente revisada para criação mínima de item, com payload, autorização, ordinal concorrente, capability, atomicidade/auditoria e matriz de implementação definidos sem inventar regras de negócio, deixando exatamente uma futura implementação F35 como `NEXT_ACTION`.