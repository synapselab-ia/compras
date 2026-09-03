# F18-PUBLIC-DEMO-HOSTED-01 — Publicar demonstração hospedada sem Auth, banco ou secrets

**Classe:** T3 — integração externa, com impacto de T2 — segurança  
**Estado:** ACTIVE  
**Dependências:** F14, F17 em ON HOLD, ADR-006, ADR-007, ADR-008  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A frente privada/persistente está bloqueada por capacidade externa do Neon, mas a UI em modo demo é independente de Auth e banco e usa apenas dados fictícios já públicos. O projeto precisa continuar evoluindo sem transformar o blocker externo em paralisação total.

## Resultado esperado

Disponibilizar uma URL Vercel funcional que execute deliberadamente o modo demo público da aplicação, sem qualquer env var operacional, secret, Neon Auth, PostgreSQL ou dado real.

## Implementação

1. reutilizar o projeto Vercel preservado da F17;
2. usar uma branch dedicada desta work unit;
3. definir `framework: "nextjs"` em `vercel.json` para corrigir o preset `Other` observado no projeto;
4. habilitar temporariamente `git.deploymentEnabled=true` para o deployment deliberado;
5. aceitar target Vercel `production` exclusivamente porque ADR-008 classifica esta superfície como PUBLIC DEMO sem secrets/dados internos;
6. aguardar build e verificar o deployment;
7. acessar a URL sem bypass e confirmar a identificação explícita de protótipo/dados fictícios;
8. confirmar ausência de configuração persistente/operacional;
9. restaurar `git.deploymentEnabled=false` na branch/repositório após a prova.

## Critérios de aceite

- build Vercel `READY`;
- aplicação acessível como demonstração pública;
- banner contém `Protótipo com dados fictícios`;
- `COMPRAS_PERSISTENT_READ_ENABLED` não é habilitado;
- nenhum `DATABASE_URL`, `NEON_AUTH_*`, token ou secret é criado/usado;
- nenhum recurso Neon é criado;
- nenhum dado real/interno/pré-publicação é exibido;
- nenhum Shareable Link ou Protection Bypass é usado;
- Git auto-deploy volta a `false` após a publicação deliberada;
- GitHub CI da work unit passa;
- CURRENT_STATE/NEXT_ACTION são atualizados com exatamente uma próxima ação.

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
- a superfície for descrita como privada/operacional;
- o build exigir relaxar controles de segurança;
- auto-deploy permanecer aberto depois da prova.

## Rollback

Se o build falhar ou surgir comportamento não previsto:

1. restaurar imediatamente `git.deploymentEnabled=false`;
2. não adicionar secrets para contornar o erro;
3. registrar o deployment falho e o motivo;
4. manter `REAL_DATA_ALLOWED=NO`;
5. deixar uma única NEXT_ACTION executável ou blocker objetivo.
