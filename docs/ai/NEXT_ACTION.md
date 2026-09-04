# Next Action — Compras

## F22-PRIVATE-PREVIEW-SEED-SMOKE-ASSETS-01 — Versionar assets reproduzíveis de seed e smoke do preview privado

**Classe:** `T1 — feature de suporte` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** preparar e provar em PostgreSQL efêmero/CI os assets determinísticos de bootstrap, autorização fictícia e smoke adversarial que a F21 precisará quando o control plane Vercel estiver novamente executável, sem realizar writes hosted.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F21 recuperou o estado real dos providers e parou fail-closed antes de secrets:

- o Preview fictício F18 continua `READY` e protegido pela barreira de autenticação Vercel;
- a criação da branch F21 não gerou novo deployment automático;
- não existe projeto Neon dedicado a Compras e nenhum recurso Neon novo foi criado;
- a documentação atual confirma que Vercel suporta Deployment Protection e environment variables sensíveis de Preview escopadas por branch;
- porém a superfície Vercel autenticada disponível nesta sessão não expõe as operações de leitura/readback e CRUD necessárias para aplicar e verificar esses controles com segurança.

F21 entrou `ON HOLD` com `resume_when` objetivo. O protocolo não mantém blocker externo como frente ativa quando existe trabalho independente e seguro.

Os cenários de bootstrap, seed administrativo, identidade sem autorização e cross-team já são requisitos explícitos da F21 e podem ser transformados em assets reproduzíveis antes da hospedagem.

## Execução obrigatória

1. recuperar estado/contexto e confirmar que F21 continua `ON HOLD` pelo blocker documentado;
2. inspecionar bootstrap F20, migrations domínio/Auth e testes de RLS existentes para reutilizar fronteiras, não duplicá-las;
3. criar seed/preflight exclusivamente fictício e separado das migrations de produção;
4. usar somente `example.invalid`, UUIDs determinísticos e conteúdo explicitamente artificial;
5. criar duas equipes artificiais e os registros mínimos necessários a positivo/cross-team;
6. manter criação de `app_user`/membership separada do bootstrap Auth;
7. criar harness efêmero que prove Auth sem autorização interna -> DENY;
8. provar usuário autorizado -> somente própria equipe;
9. provar UUID conhecido de outra equipe -> DENY/not-found;
10. provar fail-closed para contexto/configuração inválidos;
11. provar isolamento Auth runtime -> domínio e domínio runtime -> Auth;
12. garantir que output não contenha passwords, cookies, tokens, connection strings ou secrets;
13. executar red-team integral da SPEC;
14. rodar lint, typecheck, testes, PostgreSQL/RLS e build;
15. revisar diff e atualizar checkpoint deixando exatamente uma próxima ação.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- somente dados/identidades fictícios;
- nenhum recurso Vercel/Neon hosted novo;
- nenhuma environment variable hosted;
- migrations canônicas aplicadas não são reescritas;
- bootstrap aceita somente `example.invalid` e continua não roteável;
- autenticação não cria autorização automaticamente;
- roles Auth/domínio permanecem separadas e não privilegiadas;
- RLS continua autoritativa;
- `/api/auth/[...path]` continua deny-all;
- signup normal continua negado;
- falha protegida não cai silenciosamente para demo;
- F21 permanece `ON HOLD` até o `resume_when` externo ser satisfeito.

## Fonte da tarefa

Executar `tasks/F22-PRIVATE-PREVIEW-SEED-SMOKE-ASSETS-01/SPEC.md`, reutilizando F20/F21, ADR-003, ADR-005, ADR-007, ADR-009, `docs/architecture/SECURITY.md` e `docs/architecture/DATABASE.md`.

## Critério de encerramento

F22 fecha quando os assets de bootstrap/seed/smoke necessários ao futuro preview estiverem reproduzíveis e integralmente provados em ambiente efêmero, com CI em PASS, sem hosted writes e sem dados reais. Ao final deve existir exatamente uma nova `NEXT_ACTION` executável.
