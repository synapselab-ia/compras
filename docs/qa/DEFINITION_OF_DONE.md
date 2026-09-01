# Definition of Done — Compras

Uma tarefa não está concluída porque o código foi escrito ou a tela renderizou.

## 1. Engineering Done

Quando aplicável, a entrega precisa demonstrar:

- critérios de aceite atendidos;
- regras de negócio afetadas documentadas;
- tipos/validações implementados;
- autorização considerada no enforcement real;
- migrations versionadas para alterações persistentes;
- constraints/índices necessários;
- testes relevantes criados ou atualizados;
- lint PASS;
- typecheck PASS;
- testes PASS;
- build PASS;
- nenhuma credencial ou dado real indevido no diff;
- documentação/ADR atualizados quando a semântica mudou.

Se algum gate não existir ou não puder ser executado, registrar `SKIPPED` e motivo. Nunca converter ausência de evidência em PASS.

## 2. Security Done

Tarefas que tocam autenticação, autorização, dados internos, banco ou endpoints exigem, conforme o escopo:

- não autenticado negado;
- usuário autorizado permitido;
- usuário não autorizado negado mesmo conhecendo ID válido;
- ownership/escopo não pode ser forjado pelo cliente;
- privilégios não dependem da UI;
- secrets não chegam ao browser;
- RLS/policies/grants testados quando aplicáveis;
- logs não vazam payload sensível desnecessário;
- fluxo externo de dados revisado.

Segurança não pode ser reduzida para destravar a feature.

## 3. Product Done

Pergunta obrigatória:

> Uma pessoa autorizada consegue executar corretamente a necessidade operacional pela aplicação, sem conhecer detalhes de implementação nem recorrer a um controle paralelo não documentado?

Para UI/UX, considerar:

- objetivo da jornada claro;
- linguagem operacional;
- loading/empty/error/success;
- feedback de ações;
- confirmação/contexto para ações destrutivas;
- teclado e acessibilidade básica;
- desktop/mobile conforme criticidade;
- tabelas densas com estratégia mobile deliberada;
- navegação `lista → detalhe → ação` quando reduzir complexidade;
- URLs estáveis para entidades persistentes quando útil;
- IDs e jargão técnico não expostos sem necessidade.

## 4. Data/History Done

Quando a tarefa altera estado operacional:

- mudanças relevantes são rastreáveis;
- cancelamento/arquivamento não apaga fatos silenciosamente;
- dados externos não sobrescrevem dados internos sem regra;
- snapshots/evidências mantêm proveniência quando exigidos.

## 5. AI Continuity Done

Antes de encerrar uma work unit relevante:

- diff integral revisado;
- `CURRENT_STATE.md` coerente com o Git real;
- exatamente uma `NEXT_ACTION` executável;
- decisões novas registradas na fonte adequada;
- perguntas abertas preservadas sem respostas inventadas;
- limitações e verificações reais registradas;
- próximo chat consegue continuar sem depender da conversa anterior.

## 6. Proibição de falsa conclusão

Não declarar uma feature concluída quando:

- existe somente backend sem jornada utilizável prevista;
- autorização foi testada apenas escondendo botões;
- teste foi imaginado, mas não executado;
- dados fictícios mascaram integração ausente apresentada como real;
- browser não foi verificado e a conclusão depende de comportamento visual não comprovado;
- regra de negócio necessária permanece uma `OPEN QUESTION` bloqueante.
