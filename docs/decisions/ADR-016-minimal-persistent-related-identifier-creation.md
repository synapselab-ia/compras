# ADR-016 - Criação persistente mínima e idempotente de identificador relacionado

**Status:** Accepted  
**Data:** 2026-09-18  
**Escopo:** desenho da primeira criação/vínculo persistente de `related_identifiers`; implementação pertence à work unit seguinte  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

O núcleo funcional define `Contratação` como entidade central e permite que uma mesma contratação agregue múltiplos processos ou identificadores administrativos relacionados.

A fundação persistente já contém:

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

Também existe FK composta para a contratação, `UNIQUE (team_id, contracting_id, id)`, `FORCE RLS`, leitura protegida por membership e referência opcional `related_identifier_id` em `contracting_events`.

O read model persistente já apresenta identificadores ativos no detalhe, mas ainda não existe boundary de escrita para criar o vínculo.

As fontes canônicas mantêm questões relevantes abertas:

- Q-003: quais tipos de identificadores/processos podem coexistir e quais relações exigem semântica própria;
- Q-009: política multiusuário quando o piloto individual terminar.

Portanto, a primeira escrita não pode inventar taxonomia fechada, formato, máscara, normalização ou unicidade de negócio.

Os precedentes F29, F32, F35 e F38 estabeleceram o padrão de escrita persistente:

- scope e actor derivados de identidade confiável e do banco;
- capability PostgreSQL específica e least privilege;
- runtime normal sem DML direto;
- `SECURITY DEFINER` com `search_path = pg_catalog`;
- RLS como enforcement adicional;
- mudança e evento atômicos;
- resultado externo sanitizado;
- guard pilot-only enquanto Q-009 estiver aberta.

## Decisão

A primeira criação persistente de identificador relacionado será uma operação específica, pilot-only e idempotente por UUID preparado no servidor.

A futura implementação deverá materializar primitive conceitualmente equivalente a:

```text
create_related_identifier(
  p_contracting_id uuid,
  p_related_identifier_id uuid,
  p_identifier_kind text,
  p_identifier_value text,
  p_source_system text,
  p_note text,
  p_event_id uuid
) returns text
```

O nome exato pode variar sem alterar esta decisão.

Nenhum argumento de scope, identidade ou auditoria confiável vem do browser.

## 1. Payload e fronteira de confiança

A interface server-only da futura implementação aceita semanticamente apenas:

```text
contractingId
relatedIdentifierId
identifierKind
identifierValue
sourceSystem
note
```

Semântica:

- `contractingId`: seletor candidato da contratação alvo, nunca authority;
- `relatedIdentifierId`: UUID opaco preparado pelo servidor confiável antes da primeira submissão e reutilizado nos retries da mesma solicitação;
- `identifierKind`: `string | null`;
- `identifierValue`: `string`, pois a coluna física é `text NOT NULL`;
- `sourceSystem`: `string | null`;
- `note`: `string | null`.

O UUID do evento é gerado no servidor confiável em cada tentativa e não faz parte do contrato aceito do browser.

O browser nunca define como authority:

- `team_id`;
- actor;
- membership;
- issuer;
- subject;
- `linked_at`;
- `unlinked_at`;
- UUID de evento;
- timestamps de auditoria.

`relatedIdentifierId` também não é authority. Ele funciona apenas como identidade estável da nova row e chave técnica de idempotência. Alterá-lo não permite escolher equipe, ator ou contratação autorizada.

## 2. Semântica textual

A operação preserva exatamente o contrato físico existente.

### Campo NOT NULL

`identifierValue` é `string` e não sofre:

- `trim`;
- uppercase/lowercase;
- máscara;
- regex de formato;
- normalização;
- validação de conteúdo;
- limite de tamanho de negócio inventado.

Como o schema exige somente `NOT NULL`, continuam tecnicamente distintos e permitidos:

- `''`;
- spaces-only;
- leading/trailing spaces;
- qualquer outro texto aceito pelo tipo PostgreSQL `text`.

A boundary não cria regra non-empty enquanto não existir fonte canônica para isso.

### Campos nullable

`identifierKind`, `sourceSystem` e `note` preservam a distinção entre:

- `NULL`;
- `''`;
- spaces-only;
- leading/trailing spaces.

Não existe conversão implícita empty-to-NULL.

Uma futura UI deverá transportar explicitamente `text` versus `NULL`, sem depender de placeholder ou apresentação humana.

## 3. Semântica de UUID e idempotência

### UUID do identificador

`relatedIdentifierId` é gerado no servidor confiável antes da primeira submissão da futura jornada e pode ser ecoado pelo browser nos retries.

A chave é estável apenas para a mesma intenção preparada. Não é segredo e não concede autorização.

### UUID do evento

`eventId` é gerado no servidor confiável a cada tentativa de persistência.

Ele não precisa permanecer estável entre retries, pois um replay reconhecido não cria novo evento.

### Replay autorizado

Se já existir row com o mesmo `relatedIdentifierId`, o resultado só pode ser `already-linked` quando, depois de validar novamente a autorização pilot-only da contratação candidata, a implementação conseguir provar que a row existente corresponde exatamente à solicitação original:

- mesmo `team_id` derivado da contratação alvo;
- mesmo `contracting_id`;
- `unlinked_at IS NULL`;
- mesmo `identifier_kind` por comparação null-safe;
- mesmo `identifier_value` por comparação exata;
- mesmo `source_system` por comparação null-safe;
- mesmo `note` por comparação null-safe.

Além da row, deve existir o fato de criação esperado em `contracting_events`:

- `event_type = 'related_identifier_linked'`;
- mesmo `team_id`;
- mesmo `contracting_id`;
- mesmo `related_identifier_id`;
- `actor_membership_id` igual à membership pilot-only derivada;
- `occurred_at = related_identifiers.linked_at`;
- `field_key IS NULL`;
- `old_value IS NULL`;
- `new_value IS NULL`;
- `note IS NULL`;
- `item_id IS NULL`.

A existência desse evento evita transformar uma colisão arbitrária de UUID em replay-success apenas porque os textos coincidem.

Se a prova exata e autorizada não for possível, a colisão retorna negação sanitizada.

Uma row anteriormente desvinculada nunca é reconhecida como replay de criação. Re-link permanece fora do escopo.

### Ausência de deduplicação de negócio

Não existe unicidade ou deduplicação por:

- número/identificador;
- tipo;
- origem;
- observação;
- combinação desses campos.

Dois UUIDs diferentes com textos iguais representam duas criações distintas enquanto Q-003 não definir semântica adicional.

Essa decisão preserva cardinalidade maior que 1 e evita inventar chave de negócio.

## 4. Concorrência

### Mesmo UUID e mesmo payload

Duas ou mais tentativas concorrentes com o mesmo `relatedIdentifierId` preparado devem produzir:

- exatamente uma row;
- exatamente um evento `related_identifier_linked`;
- uma tentativa `created`;
- as demais `already-linked`, somente depois da prova exata autorizada.

A primary key global `related_identifiers(id)` é o backstop de unicidade técnica.

A implementação pode tratar `unique_violation` em subtransação e executar releitura autorizada posterior, como o precedente corrigido da criação de contratação, desde que nenhuma colisão diferente seja convertida em sucesso.

### Mesmo UUID e payload diferente

No máximo uma tentativa pode criar a row. Qualquer outra tentativa com o mesmo UUID e dados diferentes deve retornar negação sanitizada. Não existe merge, overwrite ou last-write-wins.

### UUIDs diferentes e payload igual

Ambas as criações podem concluir. Nenhuma deduplicação semântica é aplicada.

### Colisão cross-team ou em outra contratação

A existência da row não pode ser revelada. A resposta externa é a mesma negação usada para recurso inexistente, cross-team ou inativo.

### Colisão do UUID de evento

Colisão do `eventId` nunca é replay-success. A tentativa falha tecnicamente e toda a criação da row deve ser revertida pela transação.

Um retry posterior pode usar novo `eventId` com o mesmo `relatedIdentifierId`.

## 5. Autorização pilot-only por equipe alvo

A autorização segue o guard target-team de F26/F32/F35/F38, e não o guard global de criação F29.

A capability só autoriza quando:

1. `current_app_user_id()` resolve para app_user ativo;
2. a contratação candidata existe no escopo visível da identidade corrente;
3. a contratação está ativa, com `archived_at IS NULL` e `cancelled_at IS NULL`;
4. o usuário possui membership `revoked_at IS NULL` na equipe da contratação;
5. essa equipe possui exatamente uma membership com `revoked_at IS NULL`.

Uma segunda membership não revogada na equipe alvo bloqueia, inclusive se o app_user correspondente estiver desabilitado.

Uma membership adicional do mesmo usuário em outra equipe não bloqueia por si só.

Inexistente, cross-team, usuário desabilitado, membership ausente/revogada, segundo membro, contratação arquivada, contratação cancelada e colisão de UUID sem prova exata devem colapsar para a mesma negação externa.

Q-009 permanece aberta.

A verificação de replay só ocorre depois de o guard da contratação candidata ter sido satisfeito. O identificador candidato não pode ser usado como oracle de existência ou scope.

## 6. Capability dedicada e least privilege

A implementação deve criar role técnica equivalente a:

`compras_related_identifier_create_owner`

A role permanece:

- `NOLOGIN`;
- `NOINHERIT`;
- `NOSUPERUSER`;
- `NOBYPASSRLS`;
- `NOCREATEDB`;
- `NOCREATEROLE`;
- `NOREPLICATION`;
- sem `rolconfig` persistente;
- sem ownership de tabelas-base;
- sem membership utilizável.

O lifecycle segue ADR-005 e os precedentes F29/F35/F38.

A primitive deve:

- ser `SECURITY DEFINER`;
- fixar `search_path = pg_catalog`;
- usar SQL estático/parametrizado;
- ter `PUBLIC EXECUTE` revogado.

Runtime normal recebe somente `EXECUTE` da primitive por provisioning explícito e separado da migration.

### Grants máximos esperados

A capability pode receber apenas o necessário para:

- resolver identidade corrente;
- ler memberships do guard pilot-only;
- localizar a contratação alvo e seu estado sem write authority;
- ler somente colunas de `related_identifiers` necessárias à prova de replay;
- ler somente colunas de `contracting_events` necessárias à prova de replay;
- inserir as colunas aprovadas de `related_identifiers`;
- inserir as colunas aprovadas de `contracting_events`;
- executar helpers de identidade indispensáveis.

O `INSERT` em `related_identifiers` é coluna-a-coluna, limitado a:

- `id`;
- `team_id`;
- `contracting_id`;
- `identifier_kind`;
- `identifier_value`;
- `source_system`;
- `note`;
- `linked_at`.

`unlinked_at` nasce `NULL` e não entra no grant de insert.

O `INSERT` em `contracting_events` é coluna-a-coluna, limitado a:

- `id`;
- `team_id`;
- `contracting_id`;
- `actor_membership_id`;
- `event_type`;
- `occurred_at`;
- `related_identifier_id`;
- `created_at`.

A capability não recebe:

- `UPDATE` ou `DELETE` em `related_identifiers`;
- qualquer `UPDATE` em `contractings`;
- `UPDATE` ou `DELETE` em `contracting_events`;
- authority sobre itens, allocator ou outras primitives;
- authority de F26, F29, F32, F35 ou F38.

As capabilities anteriores também não recebem authority de identificador relacionado.

## 7. Atomicidade e auditoria

Uma criação bem-sucedida insere exatamente:

1. uma row em `related_identifiers`;
2. um evento em `contracting_events`.

Ambos pertencem à mesma transação.

### Estado do identificador

A row criada recebe:

- `id = relatedIdentifierId`;
- `team_id` derivado da contratação autorizada;
- `contracting_id` igual à contratação autorizada;
- textos conforme payload, sem transformação;
- `linked_at = operation_at`;
- `unlinked_at = NULL`.

`operation_at` é definido dentro da primitive PostgreSQL, não pelo browser.

### Evento

O evento automático usa:

- `event_type = 'related_identifier_linked'`;
- `team_id` e `contracting_id` derivados da contratação;
- `actor_membership_id` derivado do banco;
- `related_identifier_id` igual à row criada;
- `occurred_at = operation_at`;
- `created_at = operation_at`;
- `field_key = NULL`;
- `old_value = NULL`;
- `new_value = NULL`;
- `note = NULL`;
- `item_id = NULL`.

Os textos do identificador permanecem no estado estruturado da row. O evento não duplica o payload em texto livre ou JSON opaco.

Falha do evento reverte a row de identificador.

`contractings.updated_at` não é alterado por esta operação. O histórico relevante continua derivado de `contracting_events`.

O nome `related_identifier_linked` identifica apenas este fato específico e não fecha taxonomia geral de eventos de processo.

## 8. RLS esperada na implementação

A futura migration adiciona somente policies específicas da nova capability para os writes.

### Related identifier insert

A policy de `related_identifiers FOR INSERT` deve, no mínimo:

- exigir `unlinked_at IS NULL`;
- exigir contratação correspondente ativa;
- exigir `team_id` igual ao team canônico da contratação;
- exigir membership não revogada do usuário corrente na equipe alvo;
- exigir exatamente uma membership não revogada na equipe alvo.

### Event insert

A policy de `contracting_events FOR INSERT` deve, no mínimo:

- exigir `event_type = 'related_identifier_linked'`;
- exigir `related_identifier_id IS NOT NULL`;
- exigir `item_id IS NULL`;
- exigir `field_key IS NULL`;
- exigir `old_value IS NULL`;
- exigir `new_value IS NULL`;
- exigir `note IS NULL`;
- exigir actor membership do usuário corrente na mesma equipe;
- exigir exatamente uma membership não revogada na equipe alvo;
- exigir contratação correspondente ativa;
- exigir que `related_identifier_id` referencie row ativa da mesma `team_id + contracting_id`;
- exigir `occurred_at = related_identifiers.linked_at`;
- exigir `created_at = occurred_at`.

As policies de leitura existentes permanecem inalteradas, salvo necessidade técnica demonstrada pela implementação. Não se amplia leitura pública ou runtime DML.

## 9. Resultados externos

A primitive pode distinguir internamente:

- `created`;
- `already-linked`;
- `denied`.

A interface server-only expõe somente:

- `created`;
- `already-linked`;
- `not-available` para qualquer negação protegida;
- `unavailable` para falha técnica, configuração, conexão, contexto, UUID técnico inválido, colisão de event UUID ou resultado impossível.

`already-linked` só é permitido após prova exata e autorizada da row e do evento original.

A resposta não retorna:

- team;
- actor;
- membership;
- timestamps;
- IDs internos adicionais;
- SQL;
- razão detalhada da negação.

Falha persistente nunca cai para demo ou fixture.

## 10. Matriz adversarial obrigatória da implementação

A futura implementação deve provar, em PostgreSQL descartável e testes server-only, pelo menos:

1. piloto autorizado cria row + exatamente um evento;
2. team, actor, contratação e `operation_at` são derivados de contexto confiável;
3. `relatedIdentifierId` preparado não concede scope nem actor;
4. event UUID não vem do browser;
5. claims ausentes, malformados e desconhecidos falham fechado;
6. app_user desabilitado falha fechado;
7. membership ausente ou revogada falha fechado;
8. segundo membro não revogado na equipe alvo bloqueia;
9. segundo membro desabilitado mas não revogado também bloqueia;
10. membership adicional do mesmo usuário em outra equipe não bloqueia por si só;
11. contratação inexistente, cross-team, arquivada e cancelada são externamente indistinguíveis;
12. colisão cross-team de `relatedIdentifierId` não vira oracle;
13. mesmo UUID + mesmo payload em retry retorna `already-linked` e não cria segundo evento;
14. mesmo UUID + payload diferente não vira sucesso;
15. mesmo UUID + row sem evento de vínculo esperado não vira replay-success;
16. mesmo UUID + row desvinculada não vira replay-success;
17. UUIDs diferentes + mesmo payload criam rows distintas;
18. `identifierValue = ''` é preservado;
19. `identifierValue` spaces-only e leading/trailing spaces são preservados;
20. `identifierKind`, `sourceSystem` e `note` preservam `NULL`, vazio e espaços;
21. nenhum trim, case-folding, máscara, regex ou deduplicação de negócio é aplicado;
22. `linked_at`, event `occurred_at` e event `created_at` usam o mesmo `operation_at`;
23. evento aponta para o related identifier correto;
24. falha do evento reverte a row de identificador;
25. colisão de event UUID reverte a row e retorna apenas `unavailable`;
26. chamadas concorrentes com mesmo UUID/payload geram uma row e um evento;
27. chamadas concorrentes com mesmo UUID/payload divergente não fazem overwrite;
28. chamadas concorrentes com UUIDs distintos e mesmo payload podem criar duas rows;
29. runtime normal não possui DML direto em `related_identifiers` ou `contracting_events`;
30. capability não possui UPDATE em `contractings`;
31. capability não possui LOGIN, SUPERUSER, BYPASSRLS, ownership de tabela-base ou membership utilizável;
32. capability não consegue editar/desvincular/excluir identificador existente;
33. F26/F29/F32/F35/F38 não ganham authority adicional;
34. migrations `0001..0009` permanecem byte-for-byte imutáveis;
35. suites existentes de Auth, RLS, F22, F29, F32, F35 e F38 permanecem verdes;
36. nenhum provider hosted write, secret ou dado real é usado.

## 11. Red-team da decisão

O desenho é rejeitado se qualquer implementação:

- aceitar team, actor, membership, issuer, subject, timestamps ou event UUID como authority do browser;
- derivar autorização do `relatedIdentifierId`;
- permitir create em contratação cross-team, arquivada ou cancelada;
- tratar segundo membro como política multiusuário resolvida;
- conceder DML direto à runtime normal;
- ampliar F26/F29/F32/F35/F38;
- normalizar, trimar, mascarar ou validar `identifierValue` por regra não documentada;
- colapsar `NULL`, vazio e espaços sem codificação explícita;
- criar unicidade por número, tipo, origem ou combinação sem requisito canônico;
- reconhecer colisão de UUID como sucesso sem prova exata da row e evento;
- reconhecer row desvinculada como replay;
- criar evento fora da mesma transação;
- duplicar payload em JSON opaco ou nota livre por conveniência;
- atualizar `contractings.updated_at` apenas para sinalizar movimentação;
- reescrever migrations aplicadas;
- resolver Q-003, Q-004 ou Q-009 implicitamente;
- cair para demo em falha protegida;
- exigir provider hosted, secret ou dado real.

## 12. Consequências

### Positivas

- primeira escrita de processos relacionados nasce com authority isolada;
- cardinalidade maior que 1 permanece preservada;
- retries da mesma intenção podem ser reconhecidos sem deduplicação por valor;
- colisões cross-team continuam opacas;
- textos respeitam exatamente nullability e conteúdo físico atual;
- row e evento são inseparáveis;
- Q-003 e Q-009 permanecem abertas;
- runtime continua sem DML direto.

### Custos

- a futura jornada precisa preparar e preservar `relatedIdentifierId` entre retries;
- a capability precisa ler row e evento para reconhecer replay com segurança;
- a migration F41 precisa de policies, grants, primitive e provas adversariais próprias;
- não existe taxonomia de tipo/origem nem validação de formato nesta fase.

## Fora do escopo

- edição de identificador existente;
- desvínculo ou re-link;
- exclusão física;
- taxonomia final de `identifier_kind` ou `source_system`;
- máscara ou validação específica de número de processo;
- importação automática de sistemas oficiais;
- pesquisa de preços/Q-004;
- política multiusuário Q-009;
- UI ou Server Action;
- provider hosted;
- dado real.

## Próxima implementação

A F41 deve implementar exatamente esta boundary, sem ampliar escopo: migration aditiva `0010`, capability dedicada, primitive, provisioning, adapter server-only, testes unitários/PostgreSQL/concorrência e workflow/regressões aplicáveis.
