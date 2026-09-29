# F48-PERSISTENT-RESPONSIBLE-MUTATION-DETAIL-UI-01 - Resultado

**Estado:** CONCLUÍDA E INTEGRADA  
**PR:** #81  
**Head validado:** `29064794dd75231f05a0fadb840a635e5d26d0de`  
**Merge em main:** `bc0704297c2326e6eea6dca91c16b0c5b1ec3ce7`  
**Classificação:** PUBLIC / FICTITIOUS ONLY

## Entrega

F48 integrou exclusivamente a boundary F47 ao detalhe persistente para alterar ou limpar o responsável interno.

A slice adicionou:

- precondição protegida `responsibleMembershipId: string | null` no read model;
- projeção humana `responsibleOptions` obtida somente de `public.team_member_directory`;
- transporte nullable explícito `null | membership`;
- Server Action dedicada e fail-closed;
- editor mínimo de responsável apenas no detalhe persistente;
- feedback fixo e sanitizado;
- cobertura adversarial para read model, action, componente, rota e estados degradados.

Nenhuma migration, grant, policy, capability, primitive ou provisioning F47 foi alterado.

## Read model protegido

O detalhe persistente agora preserva o UUID bruto de `contractings.responsible_membership_id` como precondição de optimistic concurrency.

O nome humano continua vindo de `team_member_directory`.

As opções humanas também vêm exclusivamente dessa view, restritas à equipe da contratação já exposta pelo target protegido. O browser não recebe `team_id`, `user_id`, issuer ou subject por essa jornada.

O UUID de membership continua sendo somente candidate/precondição. Ele nunca define equipe, actor ou autorização.

## Estado degradado

Se o responsável atual deixar de aparecer no diretório por revogação ou app_user desabilitado:

- o UUID bruto atual continua disponível como expected;
- a apresentação humana pode permanecer `Responsável não disponível`;
- a opção protegida ausente não é adicionada a `responsibleOptions`;
- a UI ainda permite limpar para `NULL` ou selecionar outra opção disponível;
- F47 continua sendo a única authority que decide se a operação é permitida.

Nenhum reparo automático foi introduzido.

## Transporte e Server Action

A action aceita somente:

```text
contractingId
expectedResponsibleKind
expectedResponsibleMembershipId
newResponsibleKind
newResponsibleMembershipId
```

Kinds permitidos:

```text
null
membership
```

`null` exige ausência do scalar de membership. `membership` exige exatamente um UUID sintaticamente válido.

Campos extras controlados pelo browser falham fechado, exceto os campos internos `$ACTION_*` do framework.

A action não executa SQL/DML, não aceita team/actor/user/issuer/subject/event/timestamp/callback/redirect e chama somente `mutatePersistentContractingResponsible`.

Resultados impossíveis ou exceções técnicas são convertidos em `unavailable`.

## UI e readback

No modo persistente, o detalhe apresenta:

- responsável atual;
- seletor com `Sem responsável`;
- opções humanas do diretório protegido;
- submit com bloqueio enquanto pending;
- feedback fixo.

`updated` e `conflict` revalidam somente a rota local fixa. O estado confirmado após a navegação vem novamente do read model protegido.

Demo permanece estritamente read-only. Falha protegida ou configuração inválida não cai para fixtures.

## Red-team

A revisão final rejeitou ou cobriu explicitamente:

- team/actor/identity controlados pelo browser;
- membership UUID ou lista de opções como authority;
- callback/redirect arbitrário;
- scalars duplicados;
- combinações ambíguas de kind/scalar;
- UUIDs malformados;
- candidate sintaticamente válida, porém forjada;
- candidate cross-team, inexistente, revogada ou disabled com feedback específico;
- clear por sentinela textual;
- current degradado autoajustado;
- stale write tratado como sucesso;
- falha técnica vazando SQL/connection string;
- escrita em demo/configuração inválida;
- fallback de falha protegida para demo;
- alteração da camada PostgreSQL F47;
- resolução implícita de Q-009.

O diff final continha somente código, testes e apresentação do detalhe. Não havia arquivo de migration, provisioning ou authority de banco no diff.

## Verificação

No head final `29064794dd75231f05a0fadb840a635e5d26d0de`:

- CI `36615545417`: PASS;
- F22 Private Preview Preflight `36615545383`: PASS;
- F29 Contracting Create `36615545712`: PASS;
- F32 Contracting Object Mutation `36615545393`: PASS;
- F35 Contracting Item Create `36615545414`: PASS;
- F38 Contracting Item Mutation `36615545456`: PASS;
- F41 Related Identifier Create `36615545466`: PASS;
- F44 Manual Timeline Note Create `36615545504`: PASS;
- F47 Contracting Responsible Mutation `36615545424`: PASS.

O job `verify` do CI executou lint, typecheck, testes e build com sucesso. Os jobs de banco e Auth também concluíram com sucesso.

Dois defeitos de integração foram encontrados em runs intermediários e corrigidos antes da promoção:

1. prop de estado da F48 não havia sido desestruturada no componente;
2. o teste da rota precisava mock explícito do novo módulo de feedback.

Nenhum dos dois exigiu ampliação de authority ou mudança de contrato F47.

## Imutabilidade

A comparação do branch F48 contra seu baseline não contém arquivos em `database/` nem em authority/provisioning F47.

A migration `0012_contracting_responsible_mutation.sql` permaneceu com o blob canônico:

`1635b6874cc3bd7f044b3c6ecff8423e14442e80`.

Migrations `0001..0012` permanecem baseline aplicado e imutável.

## Invariantes preservados

- `REAL_DATA_ALLOWED = NO`;
- somente dados e identidades fictícios;
- F21 permanece `ON HOLD`;
- Q-001, Q-002, Q-003, Q-004, Q-006, Q-009 e Q-010 permanecem abertas;
- autenticação não é autorização;
- RLS/capabilities continuam autoritativas;
- runtime normal continua sem DML direto;
- F47 continua sendo a única boundary persistente de alteração do responsável;
- `team_member_directory` continua sendo a superfície humana aprovada para membros;
- falha protegida nunca vira demo fallback.
