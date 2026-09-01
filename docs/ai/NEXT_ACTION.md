# Next Action — Compras

## F06-TRUSTED-IDENTITY-RLS-DESIGN-01 — Revalidar Neon e especificar a fronteira de identidade/RLS

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** verificar na documentação oficial atual se a stack Neon de referência oferece uma fronteira de identidade/sessão compatível com o modelo `issuer + subject` e com RLS deny-by-default, e transformar essa evidência em um desenho implementável sem provisionar infraestrutura nem abrir acesso ao banco nesta slice.

## Fonte da tarefa

Executar conforme `tasks/F06-TRUSTED-IDENTITY-RLS-DESIGN-01/SPEC.md`.

## Resultado esperado

Ao final, o repositório deve possuir uma decisão técnica verificável que:

- revalide, em fontes oficiais atuais, Neon Postgres/Auth/Data API e o caminho de sessão/claims disponível no momento da execução;
- defina como uma identidade autenticada confiável será convertida em `auth_issuer + auth_subject` e resolvida para `app_users`;
- defina como memberships ativas serão usadas para autorização de leitura sem confiar em `user_id`, `membership_id` ou `team_id` fornecidos pelo cliente;
- especifique a futura interface `current_app_user()` ou mecanismo equivalente, incluindo sua fronteira de confiança;
- especifique as policies de leitura mínimas e seus testes adversariais, sem implementá-las ainda;
- registre incompatibilidades, mudanças de produto, custos ou riscos materiais do provedor que afetem a arquitetura;
- deixe clara a próxima slice de implementação apenas se a evidência externa for suficiente.

## Regras obrigatórias

- usar documentação oficial atual para toda afirmação mutável sobre Neon/Auth/Data API;
- não provisionar Neon, Vercel, banco, projeto Auth ou recurso externo;
- não criar nem solicitar secret, JWT, connection string ou credencial real;
- não criar policy permissiva nesta slice;
- não conectar a UI ao banco;
- não usar variável de sessão configurável pelo cliente como identidade confiável;
- não permitir que IDs enviados pelo browser definam escopo de autorização;
- manter Q-009 aberta; membership ativa não implica `role` nem política multiusuário final;
- preservar portabilidade do domínio e do schema;
- usar somente conteúdo público/sanitizado no repositório.

## Red-team mínimo

O desenho deve responder explicitamente a:

- um usuário autenticado sem membership consegue ler algo?
- membership revogada continua autorizando?
- conhecer UUID de outra equipe muda o resultado?
- o browser consegue forjar `issuer`, `subject`, `user_id`, `membership_id` ou `team_id`?
- alguma chave privilegiada precisaria chegar ao browser?
- conta/role com `BYPASSRLS` está sendo confundida com fluxo normal?
- falha de validação de sessão resulta em fail-closed?
- a proposta depende de comportamento do provedor que não esteja documentado oficialmente hoje?

## Fora do escopo

Não:

- Auth real;
- cadastro/login funcional;
- banco hospedado;
- policy RLS permissiva aplicada;
- CRUD persistente da aplicação;
- RPC de mutação;
- dados reais;
- deploy;
- definição de perfis/roles da Q-009.

## Critério de encerramento

A tarefa termina quando as capacidades atuais do provedor de referência estiverem verificadas em documentação oficial, a fronteira de confiança estiver documentada com testes adversariais planejados e não restar ambiguidade técnica que impeça especificar a próxima slice de implementação sem inventar política de negócio.
