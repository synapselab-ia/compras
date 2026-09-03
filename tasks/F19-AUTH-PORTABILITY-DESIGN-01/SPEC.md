# F19-AUTH-PORTABILITY-DESIGN-01 — Desenhar alternativa self-hosted ao Managed Better Auth bloqueado

**Classe:** T5 — arquitetura, com impacto T2 — segurança e T3 — integração externa  
**Estado:** PLANNED / NEXT  
**Dependências:** F14, F17 em ON HOLD, F18, ADR-006, ADR-007, ADR-008  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Problema

A F17 comprovou que a superfície Managed Better Auth disponível na conta/região Neon não permite impor e ler de volta o bloqueio de signup exigido. Esperar indefinidamente por essa capacidade transformaria uma dependência de produto do provider em bloqueio estrutural do projeto.

O código atual já depende da API Better Auth por meio do SDK Neon e já implementa uma superfície de aplicação restrita: sign-in email/senha e sign-out via Server Actions, catch-all Auth deny-all, sessão server-side e autorização final no PostgreSQL/RLS.

## Evidência oficial a revalidar na execução

A documentação oficial atual do Better Auth deve ser lida novamente durante esta work unit. Em 2026-09-03 ela documentava:

- suporte oficial a PostgreSQL;
- geração/migration de schema Auth;
- `emailAndPassword.enabled=true`;
- `emailAndPassword.disableSignUp=true`;
- `trustedOrigins` explícitos;
- social providers somente quando configurados;
- plugins somente quando adicionados.

## Objetivo

Decidir se o primeiro preview privado deve deixar de depender do Managed Better Auth da Neon e passar a executar Better Auth self-hosted pela aplicação, usando PostgreSQL controlado e configuração versionada/validável que imponha signup fechado por construção.

Esta work unit é de **desenho e prova local/efêmera**, não de hospedagem com dados reais.

## Questões que o desenho deve fechar

1. Como manter a interface F14 (`signIn.email`, `signOut`, `getSession`) sem ampliar a superfície HTTP da aplicação.
2. Como configurar `disableSignUp=true` de forma versionada e testável.
3. Como manter `socialProviders` e plugins laterais ausentes por default.
4. Como definir `trustedOrigins` estritos para a futura URL Preview.
5. Como separar schema/tabelas Auth das tabelas de domínio Compras.
6. Qual role/connection string o runtime Auth usa e como impedir superuser/`BYPASSRLS`/owner desnecessário.
7. Como criar o primeiro usuário fictício por caminho administrativo controlado sem reabrir signup público.
8. Como migrar o adaptador atual `@neondatabase/auth` sem misturar identidade fornecida pelo browser com identidade validada no servidor.
9. Como preservar o contrato `issuer + subject` consumido pela F08/RLS.
10. Como gerar/aplicar migrations Auth de forma canônica e reproduzível, sem painel manual virar fonte de verdade.
11. Como fazer rollback/deprovisionamento e rotação de secret.
12. Qual impacto em dependências, bundle e manutenção de versão existe ao adotar `better-auth` diretamente.

## Red-team obrigatório

O desenho deve atacar explicitamente:

- endpoint de signup direto apesar de botão ausente;
- social/OAuth ou plugin criando usuário lateralmente;
- origem wildcard/localhost em hospedagem;
- usuário Auth automaticamente ganhando `app_user`/membership;
- Auth usando role privilegiada do banco;
- tabela Auth em schema/owner que permita contornar RLS de domínio;
- reset/password flows reabrindo superfície não planejada;
- segredo Auth em bundle client-side;
- sessão forjada no cliente;
- incompatibilidade de cookie/sessão com Next.js/Vercel;
- migration Auth não reproduzível;
- dependência transitiva usada sem pin/versionamento explícito.

## Critérios de aceite

- documentação oficial atual revalidada;
- arquitetura escolhida registrada em nova ADR;
- threat model explícito comparando Managed Neon Auth e Better Auth self-hosted;
- configuração mínima de Auth demonstrável em teste local/efêmero com signup negado;
- nenhum provider social/plugin lateral habilitado;
- estratégia de schema/role/migration definida;
- compatibilidade com F14/F08/RLS demonstrada ou mudanças necessárias delimitadas;
- nenhum secret, usuário real ou dado real criado;
- decisão final é uma de: `ADOPT`, `REJECT`, `BLOCKED` com motivo verificável;
- exatamente uma nova NEXT_ACTION executável ao final.

## Fora do escopo

- provisionar ambiente operacional;
- inserir dados reais;
- criar usuário real;
- promover a demo F18 a persistente;
- manter Managed Neon Auth apenas por inércia se a alternativa self-hosted provar controle superior e equivalente funcional.
