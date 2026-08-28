# ADR-001 — Public Bootstrap com dados sanitizados

**Status:** Accepted  
**Data:** 2026-08-28

## Contexto

O repositório inicia sua vida como público por uma restrição operacional de uso de GitHub Actions em repositórios privados. O produto, porém, tratará informações internas de contratações que podem ser sensíveis antes da publicação oficial.

## Decisão

Adotar uma fase explícita `Foundation-00 — Public Bootstrap` em que somente documentação sanitizada, código genérico e dados fictícios podem ser versionados.

Nenhum dado interno real ou `SENSITIVE_PRE_PUBLICATION` pode ser colocado no repositório enquanto ele estiver público.

Quando o repositório se tornar privado, a mudança de visibilidade não será tratada como autorização automática para importar dados reais. Antes disso haverá revisão de infraestrutura, segurança, autenticação/RLS e política de dados.

## Consequências

- a Foundation-00 descreve domínio e workflow em nível abstrato;
- documentos internos usados para compreender o problema não são republicados;
- exemplos reais são substituídos por exemplos fictícios;
- tornar o repositório privado no futuro não permite presumir que cópias públicas anteriores desapareceram;
- qualquer agente de IA deve verificar a visibilidade do repositório antes de persistir informação potencialmente sensível;
- tarefas futuras que precisem de detalhe interno podem ficar bloqueadas até existir contexto privado adequado.

## Não decidido aqui

- provedor definitivo de produção;
- política institucional final de classificação/retention;
- MFA final;
- regras multiusuário detalhadas;
- momento de importação de dados históricos.
