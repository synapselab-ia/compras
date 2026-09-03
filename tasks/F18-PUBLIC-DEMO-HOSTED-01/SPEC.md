# F18-PUBLIC-DEMO-HOSTED-01 — Publicar demonstração hospedada sem Auth, banco ou secrets

**Classe:** T3 — integração externa, com impacto de T2 — segurança  
**Estado:** COMPLETE / VERIFIED  
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

## Resultado executado em 2026-09-03

- uma tentativa preliminar revelou target Production + preset `Other`; ela falhou `STATIC_BUILD_NO_OUT_DIR`, sem secrets/dados, e o auto-deploy foi fechado imediatamente;
- ADR-008 formalizou a faixa demo independente;
- `framework: "nextjs"` foi versionado;
- o deployment deliberado `dpl_BqWDpoiotNstrTDhtU3mJ4k9pCZa`, commit `cb874445f97f851871090cb51f6ef3364520da37`, foi criado como Preview (`target=null`) e chegou a `READY`;
- o build detectou Next.js 16.3.3, compilou, passou TypeScript e gerou as rotas esperadas;
- acesso sem sessão continuou interceptado pela Vercel Authentication com redirect SSO;
- nenhum env/secret operacional ou recurso Neon foi criado;
- `git.deploymentEnabled` voltou a `false` e o commit de fechamento não gerou novo deployment;
- um link temporário de smoke chegou a ser gerado, mas não foi persistido e o canal permaneceu no handshake SSO; ele não é mecanismo de acesso do produto e expira automaticamente;
- a verificação funcional local/CI já prova que ausência de `COMPRAS_PERSISTENT_READ_ENABLED=true` seleciona o modo demo e que as fixtures usadas são fictícias.

## Rollback

Se a faixa demo deixar de ser necessária ou apresentar comportamento inesperado:

1. manter `git.deploymentEnabled=false`;
2. não anexar secrets;
3. retirar o deployment da circulação quando o control plane permitir de forma observável;
4. manter `REAL_DATA_ALLOWED=NO`;
5. não promover a demo para persistente sem uma work unit própria e todos os gates de Auth/banco.
