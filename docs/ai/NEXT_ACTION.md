# Next Action — Compras

## F00-REVIEW-01 — Revisar e aprovar a Foundation-00

**Classe:** `T0 — descoberta/produto`  
**Estado:** READY  
**Objetivo:** validar se a fundação documental representa corretamente o produto antes de inicializar código ou infraestrutura.

## Escopo

Revisar com o usuário:

- missão e limites do produto;
- entidade central `Contratação`;
- Central do Setor como experiência principal;
- separação entre etapa, status, responsável, aguardando e próxima ação;
- workflow sanitizado inicial;
- modelo de domínio;
- questões abertas que realmente bloqueiam implementação;
- política de segurança e restrições do repositório público;
- arquitetura de referência;
- protocolo FLOW-IA.

## Critérios de aceite

A tarefa termina quando:

- erros conceituais apontados pelo usuário forem corrigidos;
- nenhuma informação interna sensível for adicionada ao repositório público;
- as questões ainda desconhecidas permanecerem explicitamente abertas;
- não houver conflito material entre Project Design, Domain Model, Workflow, Security e Source of Truth;
- o usuário aprovar a fundação como baseline suficiente para começar a implementação;
- `CURRENT_STATE` for atualizado;
- uma única próxima ação técnica for promovida.

## Fora do escopo

Não:

- inicializar Next.js;
- provisionar Neon;
- configurar Vercel;
- criar dados reais;
- importar planilhas;
- implementar autenticação;
- implementar banco;
- integrar PNCP/Compras.gov;
- publicar informação interna para completar documentação.

## Próxima ação esperada após aprovação

Promover uma work unit de **Fundação Executável** que inicialize a aplicação mínima, validações locais e estrutura técnica sem ainda carregar dados internos reais.

A especificação dessa work unit deve ser criada somente após a revisão, para refletir eventuais correções arquiteturais da Foundation-00.
