# F43-PERSISTENT-MANUAL-TIMELINE-NOTE-DESIGN-01 - Desenhar criação persistente de nota manual na timeline

**Classe:** T2 - desenho arquitetural de escrita/auditoria  
**Estado:** READY / NEXT após integração da F42  
**Dependências:** fundação `contracting_events`, read model persistente do detalhe, F26/F29/F32/F35/F38/F41, SECURITY, DATABASE, PROJECT_DESIGN, DOMAIN_MODEL e BUSINESS_WORKFLOW  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O núcleo funcional inicial exige timeline rastreável e o modelo de domínio prevê explicitamente nota manual como fato da contratação.

O detalhe persistente já apresenta eventos automáticos gerados por criação e mutações estruturadas, mas uma pessoa autorizada ainda não possui uma operação estreita para registrar uma observação manual sem alterar estado estruturado da contratação.

O DATABASE já admite conceitualmente que eventos de nota manual usem `note` sem `field_key`. Portanto, esta é uma frente pequena e independente que amplia a utilidade da timeline sem resolver taxonomias de etapa/status, permissões multiusuário ou pesquisa de preços.

## Objetivo

Produzir a decisão canônica para a primeira criação persistente de nota manual em `contracting_events`, definindo payload, authorization guard, capability, least privilege, auditoria, idempotência/concorrência, semântica textual e resultados externos sanitizados para uma implementação posterior.

F43 é exclusivamente de desenho.

Não cria migration, policy, grant, primitive, provisioning, adapter, Server Action ou UI operacional.

## Base física existente

`contracting_events` já contém, entre outros:

```text
id uuid PRIMARY KEY
team_id uuid NOT NULL
contracting_id uuid NOT NULL
actor_membership_id uuid NULL
event_type text NOT NULL
occurred_at timestamptz NOT NULL
field_key text NULL
old_value text NULL
new_value text NULL
note text NULL
related_identifier_id uuid NULL
item_id uuid NULL
created_at timestamptz NOT NULL
```

O modelo de domínio lista `nota manual` entre os eventos esperados.

O DATABASE registra que eventos de nota manual podem usar `note` sem `field_key`.

Migrations aplicadas `0001..0010` são história imutável.

## Execução obrigatória

1. recuperar o `main` real após F42 e confirmar a PR `#67` integrada;
2. revalidar `CONTEXT_MANIFEST`;
3. ler PROJECT_DESIGN, DOMAIN_MODEL, BUSINESS_WORKFLOW, SECURITY e DATABASE nos pontos necessários;
4. inspecionar o schema físico e as RLS atuais de `contracting_events`;
5. inspecionar os padrões de eventos automáticos e capabilities de F26/F29/F32/F35/F38/F41;
6. comparar guards pilot-only existentes e escolher somente o precedente sustentado pela equipe alvo;
7. desenhar uma única operação de criação de nota manual, sem mutar estado de `contractings`, itens ou identificadores;
8. definir payload server-only mínimo e tudo que deve ser derivado pelo servidor/banco;
9. definir semântica exata para `note`, inclusive `NULL`, vazio e espaços, sem inventar regra non-empty;
10. decidir se a intenção necessita UUID preparado/idempotency key e como replay autorizado deve ser provado;
11. definir o `event_type` estrito desta capability sem transformar isso em taxonomia geral de eventos;
12. garantir que team, actor e timestamps sejam derivados de contexto confiável;
13. definir capability dedicada e grants máximos, sem ampliar F26/F29/F32/F35/F38/F41;
14. definir comportamento para contratação inexistente, cross-team, arquivada ou cancelada sem oracle;
15. definir concorrência e colisão de UUID/evento;
16. definir resultados externos sanitizados;
17. definir matriz adversarial da implementação posterior;
18. registrar a decisão em nova ADR;
19. criar exatamente uma SPEC executável para a implementação seguinte;
20. executar gates documentais aplicáveis e red-team antes de promover.

## Questões que o desenho deve fechar tecnicamente

### Payload e authority

A operação deve começar pelo mínimo necessário para registrar uma nota manual associada a uma contratação candidata.

O browser não pode definir como authority:

- `team_id`;
- actor ou membership;
- issuer ou subject;
- `occurred_at`;
- `created_at`;
- qualquer timestamp de auditoria.

F43 deve decidir se o UUID do evento é preparado no servidor para idempotência ou gerado dentro da tentativa, fundamentando a escolha nos precedentes existentes.

### Shape do evento

A decisão deve definir um shape fechado para esta capability específica.

Ela não pode usar nota manual como pretexto para permitir ao cliente escolher genericamente:

- `event_type`;
- `field_key`;
- `old_value`;
- `new_value`;
- `related_identifier_id`;
- `item_id`.

O desenho deve verificar se todos esses campos, salvo `note`, permanecem `NULL` para a operação.

### Semântica textual

Não inferir regra de negócio não documentada.

Avaliar e documentar explicitamente o comportamento de:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

Não criar por conveniência:

- trim;
- limite textual arbitrário;
- sanitização sem requisito;
- markdown/HTML como novo contrato;
- categoria/tipo selecionável pelo browser.

### Autorização e opacidade

A futura operação deve permanecer server/database authoritative e pilot-only enquanto Q-009 estiver aberta.

Inexistente, cross-team, usuário sem membership, membership revogada, segundo membro não revogado e contratação inativa não podem vazar diferenças protegidas desnecessárias.

### Least privilege

A futura capability deve possuir somente a authority necessária para:

- resolver identidade/membership;
- verificar contratação elegível;
- inserir o evento manual aprovado;
- provar replay, se houver;
- executar helpers indispensáveis.

Runtime normal continua sem INSERT direto em `contracting_events`.

Capabilities anteriores não recebem EXECUTE da nova primitive e a nova capability não recebe authority de mutação de contratação, item ou identificador.

## Fora do escopo

F43 não inclui:

- código operacional;
- migration aplicada;
- Server Action ou UI;
- edição ou exclusão de evento existente;
- edição/desvínculo de identificador relacionado;
- mutation de responsável, etapa, status ou aguardando;
- entidade `Pendência`;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- auditoria de leitura/Q-010;
- provider hosted ou secrets;
- dado real;
- retomada F21.

Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 não devem ser resolvidas implicitamente.

## Red-team mínimo

Rejeitar o desenho se:

- browser puder escolher team, actor, membership, issuer, subject ou timestamps;
- browser puder fornecer `event_type` arbitrário;
- nota manual virar primitive genérica para escrever qualquer evento;
- capability receber UPDATE/DELETE em `contracting_events`;
- runtime normal receber DML direto;
- F26/F29/F32/F35/F38/F41 ganharem authority adicional;
- contratação cross-team ou inativa puder receber evento;
- erro protegido revelar existência, scope ou motivo de negação;
- semântica de vazio/espaços for alterada sem fonte;
- o desenho inventar taxonomia, prioridade, categoria ou pendência;
- falha protegida cair para demo;
- migrations `0001..0010` forem alteradas;
- provider hosted, secret ou dado real for necessário.

## Artefatos esperados

F43 deve produzir somente documentação de desenho, preferencialmente:

- `docs/decisions/ADR-017-minimal-persistent-manual-timeline-note.md`;
- `tasks/F44-PERSISTENT-MANUAL-TIMELINE-NOTE-IMPLEMENT-01/SPEC.md`.

A nomenclatura pode ser ajustada se a inspeção encontrar conceito canônico mais preciso sem ampliar o escopo material.

## Verificação

Executar pelo menos:

- revisão integral do diff documental;
- coerência com schema físico e RLS existentes;
- red-team de authority, opacidade, idempotência, concorrência e least privilege;
- CI e gates de regressão disparados pela PR documental;
- confirmação de que migrations `0001..0010` permanecem byte-for-byte.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- repositório público continua tratado como superfície permanente;
- F21 permanece `ON HOLD` até seu `resume_when`;
- questões abertas não são resolvidas por inferência;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0010` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Critério de encerramento

F43 fecha quando existir uma decisão canônica e red-teamed para criação persistente mínima de nota manual na timeline, com payload, authority, authorization guard, capability, semântica textual, idempotência/concorrência e resultados sanitizados definidos, além de uma única SPEC de implementação seguinte pronta, sem código operacional nesta slice.
