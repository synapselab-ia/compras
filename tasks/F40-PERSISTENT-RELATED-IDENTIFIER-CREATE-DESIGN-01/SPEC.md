# F40-PERSISTENT-RELATED-IDENTIFIER-CREATE-DESIGN-01 - Desenhar vínculo persistente mínimo de identificador relacionado

**Classe:** T2 - desenho arquitetural de escrita/autorização  
**Estado:** READY / NEXT após integração da F39  
**Dependências:** fundação `related_identifiers`, read model persistente, F26/F29/F32/F35/F38, SECURITY, DATABASE, PROJECT_DESIGN, DOMAIN_MODEL e BUSINESS_WORKFLOW  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

O núcleo funcional inicial prevê que uma contratação agregue múltiplos processos/identificadores administrativos relacionados. O detalhe persistente já lê e apresenta `related_identifiers`, mas ainda não existe boundary de escrita para vincular um identificador novo.

Após F39, contratação, objeto, próxima ação e itens já possuem slices mínimas de escrita. O próximo gap pequeno e independente no núcleo inicial é desenhar a primeira operação persistente de vínculo de identificador relacionado, sem antecipar desvínculo, edição, taxonomia definitiva ou pesquisa de preços.

## Objetivo

Produzir o desenho canônico da primeira boundary persistente de criação/vínculo de `related_identifiers`, com autorização, least privilege, auditoria, concorrência/idempotência e resultados sanitizados suficientemente definidos para uma implementação posterior.

F40 é exclusivamente de desenho. Não cria migration, policy, grant, primitive, adapter, Server Action ou UI operacional.

## Base física existente

O schema aplicado já contém:

```text
related_identifiers
  id uuid PRIMARY KEY
  team_id uuid NOT NULL
  contracting_id uuid NOT NULL
  identifier_kind text NULL
  identifier_value text NOT NULL
  source_system text NULL
  note text NULL
  linked_at timestamptz NOT NULL
  unlinked_at timestamptz NULL
```

Existe FK composta para a contratação e unique de escopo `(team_id, contracting_id, id)`. A tabela possui `FORCE RLS` e default-deny desde `0001`.

`contracting_events` já possui `related_identifier_id` opcional. O modelo de domínio prevê eventos de vínculo/desvínculo de processo, mas F40 deve definir apenas o fato de vínculo necessário à criação mínima.

Migrations `0001..0009` são histórico aplicado e não podem ser reescritas. Qualquer futura implementação começa, se necessária, em migration aditiva `0010` ou posterior.

## Execução obrigatória

1. recuperar `main` real após F39 e confirmar PR #61 integrada e pós-merge verde;
2. revalidar `CONTEXT_MANIFEST`;
3. ler `PROJECT_DESIGN`, `DOMAIN_MODEL`, `BUSINESS_WORKFLOW`, `SECURITY` e `DATABASE` nos pontos necessários;
4. inspecionar `0001`, `0002` e policies/leitura atuais de `related_identifiers`;
5. inspecionar `contracting_events` e os padrões de auditoria já usados por F26/F29/F32/F35/F38;
6. inspecionar as ADRs de capabilities e escrita mais recentes, especialmente ADR-012 a ADR-015;
7. confirmar o contrato de leitura atual do detalhe para identificadores;
8. desenhar uma única operação de criação/vínculo, sem editar ou desvincular identificador existente;
9. definir explicitamente o payload server-only mínimo e quais valores são derivados pelo banco/servidor;
10. preservar a cardinalidade maior que 1 prevista pelo domínio;
11. não inventar taxonomia fechada de `identifier_kind` ou `source_system`;
12. não inventar regra de formato, máscara, unicidade de negócio ou non-empty para `identifier_value` sem fonte canônica;
13. decidir e documentar semântica exata de `NULL`, vazio e espaços para os textos nullable e NOT NULL conforme o schema e as fontes permitirem;
14. definir autorização pilot-only coerente com a equipe alvo e Q-009 ainda aberta;
15. definir capability dedicada e grants máximos, sem ampliar F26/F29/F32/F35/F38;
16. definir atomicidade entre row de identificador e evento de vínculo;
17. definir semântica de concorrência/idempotência para retries e colisões de UUID, sem deduplicação por valor inventada;
18. definir resultados externos sanitizados e impedir oracle de existência/scope;
19. definir matriz adversarial da implementação posterior;
20. registrar a decisão em nova ADR e criar exatamente uma SPEC executável para a implementação seguinte;
21. executar gates documentais aplicáveis e red-team do desenho antes de promover.

## Questões que o desenho deve fechar tecnicamente

### Payload e authority

Determinar o contrato mínimo da futura boundary. O desenho deve partir dos campos conceituais documentados:

- contratação candidata;
- tipo opcional;
- número/identificador;
- sistema/origem opcional;
- observação opcional.

Team, actor, membership, issuer, subject, timestamps e UUIDs de auditoria não podem virar authority do browser.

F40 deve decidir se o UUID do novo identificador é sempre gerado server-side e como retries são reconhecidos sem introduzir chave de negócio não documentada.

### Semântica textual

O schema permite `NULL` em `identifier_kind`, `source_system` e `note`, e exige somente que `identifier_value` seja não nulo.

O desenho deve preservar o que o schema e o domínio realmente permitem. Não criar por conveniência:

- trim;
- uppercase/lowercase;
- máscara de processo;
- regex de formato;
- limite de tamanho de negócio;
- catálogo fechado de tipos;
- empty-to-NULL implícito;
- unicidade por valor/origem/tipo sem fonte.

### Autorização

A futura operação deve continuar server/database authoritative. O desenho deve comparar os precedentes F29 e F35 para escolher corretamente o guard de equipe alvo e a semântica pilot-only enquanto Q-009 permanecer aberta.

Cross-team, contratação inexistente/inativa e falhas de membership não podem produzir diferenças observáveis indevidas.

### Auditoria

Definir um evento atômico de vínculo que referencie o `related_identifier_id` criado e derive team/contracting/actor de contexto confiável. O nome e shape exatos do evento devem seguir os padrões existentes e o modelo de domínio, sem inventar payload JSON opaco.

Falha de auditoria deve reverter a criação.

### Least privilege

Desenhar uma capability dedicada, selada e não privilegiada, com somente a authority estritamente necessária para:

- provar identidade/membership/contratação elegível;
- inserir o identificador aprovado;
- inserir o evento de vínculo correspondente;
- executar helpers indispensáveis.

Runtime normal deve continuar sem DML direto e receber somente EXECUTE explícito da primitive futura.

## Fora do escopo

F40 não inclui:

- migration ou código operacional;
- Server Action ou UI;
- edição de identificador existente;
- desvínculo/revinculação;
- exclusão física;
- taxonomia final de tipos/sistemas;
- importação automática de sistemas oficiais;
- validação de formato específica de processo;
- pesquisa de preços/Q-004;
- política multiusuário/Q-009;
- reorder/retire/delete de item;
- provider hosted ou secrets;
- dado real;
- retomada F21.

## Red-team mínimo

Rejeitar o desenho se:

- browser puder escolher team, actor, membership, issuer, subject, linked_at ou event UUID como authority;
- a operação permitir vínculo em contratação cross-team, arquivada ou cancelada;
- um segundo membro não revogado for tratado implicitamente como política multiusuário resolvida;
- runtime normal receber INSERT direto em `related_identifiers` ou `contracting_events`;
- F26/F29/F32/F35/F38 ganharem authority adicional;
- retry puder criar duplicidade silenciosa por acidente sem semântica documentada;
- colisão de UUID virar sucesso sem prova exata e autorizada;
- `identifier_value` for normalizado ou validado por regra de negócio inventada;
- valores nullable perderem distinção entre `NULL`, vazio e espaços sem decisão fundamentada;
- for criada deduplicação por número/tipo/origem sem requisito canônico;
- evento de vínculo não for atômico;
- falha protegida cair para demo;
- migrations `0001..0009` forem alteradas;
- Q-004 ou Q-009 forem resolvidas implicitamente;
- provider hosted, secret ou dado real for necessário.

## Artefatos esperados

A F40 deve produzir apenas documentação de desenho, preferencialmente:

- `docs/decisions/ADR-016-minimal-persistent-related-identifier-creation.md`;
- `tasks/F41-PERSISTENT-RELATED-IDENTIFIER-CREATE-IMPLEMENT-01/SPEC.md`.

A nomenclatura final pode ser ajustada se a inspeção revelar um conceito canônico já existente, sem mudar o escopo material da work unit.

## Verificação

Executar pelo menos:

- revisão integral do diff documental;
- checagem de coerência com schema físico e RLS existentes;
- red-team de authority, concorrência, atomicidade e auditoria;
- CI e gates de regressão disparados pela PR documental;
- confirmação de que migrations `0001..0009` permanecem byte-for-byte.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- GitHub público continua tratado como superfície permanente;
- F21 permanece `ON HOLD` até seu `resume_when` objetivo;
- Q-004 e Q-009 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities permanecem autoritativas;
- runtime normal continua sem DML direto;
- migrations aplicadas `0001..0009` permanecem imutáveis;
- falha protegida nunca vira demo fallback.

## Critério de encerramento

F40 fecha quando existir uma decisão canônica e red-teamed para a criação/vínculo persistente mínimo de `related_identifiers`, com payload, autorização, capability, auditoria, concorrência/idempotência, resultados sanitizados e matriz adversarial definidos, e uma única SPEC de implementação seguinte pronta para execução, sem código operacional nesta slice.
