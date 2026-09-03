# F18-PUBLIC-DEMO-HOSTED-01 — Publicar demonstração hospedada sem Auth, banco ou secrets

**Classe:** T3 — integração externa, com impacto de T2 — segurança  
**Estado:** ACTIVE  
**Dependências:** F14, F17 em ON HOLD, ADR-006, ADR-007, ADR-008  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A frente privada/persistente está bloqueada por capacidade externa do Neon, mas a UI em modo demo é independente de Auth e banco e usa apenas dados fictícios já públicos. O projeto precisa continuar evoluindo sem transformar o blocker externo em paralisação total.

## Resultado esperado

Disponibilizar um deployment Vercel funcional em modo demo, sem qualquer env var operacional, secret, Neon Auth, PostgreSQL ou dado real, preservando a Vercel Authentication já configurada quando ela se aplicar à URL.

## Implementação

1. reutilizar o projeto Vercel preservado da F17;
2. usar uma branch dedicada desta work unit;
3. definir `framework: "nextjs"` em `vercel.json` para corrigir o preset `Other` observado no projeto;
4. habilitar temporariamente `git.deploymentEnabled=true` para o deployment deliberado;
5. exigir deployment Preview (`target` ausente/null); se surgir Production, falhar fechado antes de qualquer secret/dado;
6. aguardar build e verificar o deployment;
7. confirmar que a URL continua atrás da Vercel Authentication já provada;
8. confirmar pela lógica versionada e pelo build que, sem `COMPRAS_PERSISTENT_READ_ENABLED=true`, a aplicação usa apenas o modo demo e as fixtures fictícias;
9. quando o canal autenticado permitir, fazer smoke da página sem transformar bypass em requisito do produto;
10. restaurar `git.deploymentEnabled=false` na branch/repositório após a prova.

## Critérios de aceite

- deployment Vercel Preview `READY`;
- Vercel Authentication continua interceptando acesso sem sessão;
- build inclui a aplicação Next.js e conclui sem env/secret operacional;
- lógica versionada mantém o banner `Protótipo com dados fictícios` no modo demo;
- `COMPRAS_PERSISTENT_READ_ENABLED` não é habilitado;
- nenhum `DATABASE_URL`, `NEON_AUTH_*`, token ou secret é criado/usado;
- nenhum recurso Neon é criado;
- nenhum dado real/interno/pré-publicação é incluído;
- nenhum Shareable Link persistente é criado como mecanismo de acesso do produto;
- Git auto-deploy volta a `false` após a publicação deliberada;
- GitHub CI da work unit passa;
- CURRENT_STATE/NEXT_ACTION são atualizados com exatamente uma próxima ação.

O smoke visual pós-proteção é evidência adicional desejável, mas sua ausência por limitação do canal autenticado não transforma o build em preview privado/persistente nem autoriza relaxar Deployment Protection.

## Fora do escopo

- concluir F17;
- criar login hospedado;
- criar usuário Auth;
- aplicar migrations hospedadas;
- usar PostgreSQL hospedado;
- usar dados reais;
- transformar a demo em ambiente operacional;
- renomear o projeto Vercel nesta work unit.

## Red-team

Rejeitar como PASS se:

- qualquer secret/env operacional for necessário;
- a aplicação entrar em modo persistente;
- um dado não fictício aparecer;
- a superfície for descrita como produção operacional;
- o build exigir relaxar controles de segurança;
- Vercel Authentication for removida para facilitar acesso;
- auto-deploy permanecer aberto depois da prova.

## Rollback

Se o build falhar ou surgir comportamento não previsto:

1. restaurar imediatamente `git.deploymentEnabled=false`;
2. não adicionar secrets para contornar o erro;
3. registrar o deployment falho e o motivo;
4. manter `REAL_DATA_ALLOWED=NO`;
5. deixar uma única NEXT_ACTION executável ou blocker objetivo.
