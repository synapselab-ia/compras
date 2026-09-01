# ADR-001 — Public Bootstrap com dados sanitizados

**Status:** Accepted  
**Data:** 2026-08-28  
**Revisão de segurança:** 2026-09-01

## Contexto

O repositório inicia sua vida como público por uma restrição operacional de uso de GitHub Actions em repositórios privados. O produto, porém, tratará informações internas de contratações que podem ser sensíveis antes da publicação oficial.

## Decisão

Adotar uma fase explícita `Foundation-00 — Public Bootstrap` em que somente documentação sanitizada, código genérico e dados fictícios podem ser publicados no GitHub.

Nenhum dado interno real ou `SENSITIVE_PRE_PUBLICATION` pode ser colocado em arquivos, commits, Issues, Pull Requests, reviews, comentários, logs, summaries, artifacts ou outras superfícies públicas do repositório enquanto ele estiver público.

Quando o repositório se tornar privado, a mudança de visibilidade não será tratada como autorização automática para importar dados reais. Antes disso haverá revisão de infraestrutura, segurança, autenticação/RLS e política de dados.

## Consequências

- a Foundation-00 descreve domínio e workflow em nível abstrato;
- documentos internos usados para compreender o problema não são republicados;
- exemplos reais são substituídos por exemplos fictícios;
- workflows públicos não recebem dados internos reais para teste, input ou artifact;
- tornar o repositório privado no futuro não permite presumir que commits, forks, logs, artifacts ou cópias públicas anteriores desapareceram;
- qualquer agente de IA deve verificar a visibilidade do repositório antes de persistir ou expor informação potencialmente sensível;
- tarefas futuras que precisem de detalhe interno podem ficar bloqueadas até existir contexto privado adequado.

## Não decidido aqui

- provedor definitivo de produção;
- política institucional final de classificação/retention;
- MFA final;
- regras multiusuário detalhadas;
- momento de importação de dados históricos.
