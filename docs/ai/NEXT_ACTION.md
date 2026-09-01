# Next Action — Compras

## F04-PERSISTENCE-FOUNDATION-DESIGN-01 — Desenhar fundação de persistência segura

**Classe:** `T2 — banco/segurança/design`  
**Estado:** READY  
**Objetivo:** transformar as jornadas já prototipadas em um contrato de persistência mínimo, portátil e seguro antes de criar banco externo, migrations definitivas ou autenticação real.

## Fonte da tarefa

Executar conforme `tasks/F04-PERSISTENCE-FOUNDATION-DESIGN-01/SPEC.md`.

## Resultado esperado

Ao final, o repositório deve possuir um desenho executável para a primeira slice persistente, incluindo:

- `docs/architecture/DATABASE.md` com entidades/tabelas candidatas, chaves, relacionamentos, invariantes, índices e estratégia de auditoria necessários ao núcleo atual;
- fronteiras claras entre identidade autenticada, membership/autorização e dados da contratação;
- estratégia deny-by-default/RLS para futura implementação;
- contrato de migrations e testes de banco;
- decisão explícita sobre o que pode ser modelado já e o que permanece dependente de open questions;
- uma work unit seguinte pequena o suficiente para implementar a primeira migration/testes sem improvisar arquitetura.

## Regras obrigatórias

- não provisionar Neon, Vercel, banco externo, Auth ou secrets nesta slice;
- revalidar documentação oficial atual dos componentes externos apenas quando uma decisão depender deles;
- preservar portabilidade PostgreSQL e evitar acoplamento gratuito a um provedor;
- não fechar Q-001, Q-002, Q-003 ou Q-009 por conveniência de schema;
- modelar etapa/status de modo que taxonomias ainda abertas possam evoluir sem migration destrutiva prematura;
- contratação continua sendo a entidade operacional central;
- múltiplos identificadores relacionados continuam suportados conceitualmente;
- responsável e aguardando quem continuam conceitos distintos;
- histórico relevante deve ser preservável e auditável;
- segurança deve existir no contrato do banco, não somente na aplicação;
- nenhuma credencial ou dado real pode ser introduzido enquanto o repositório estiver público.

## Fora do escopo

Não:

- criar banco hospedado;
- aplicar migration real;
- implementar login;
- criar RLS em ambiente externo;
- importar planilhas;
- usar processos/dados reais;
- implementar pesquisa de preços;
- implementar regra de ±25%;
- definir política definitiva de permissões multiusuário;
- deploy de produção.

## Critério de encerramento

A tarefa termina quando o desenho de persistência estiver coerente com produto, domínio, segurança e protótipos atuais, tiver sido red-teamado contra perda de histórico/vazamento/acoplamento prematuro, o `CONTEXT_MANIFEST` tiver sido reconciliado caso fontes estáveis mudem e existir exatamente uma nova `NEXT_ACTION` para a primeira implementação de banco.
