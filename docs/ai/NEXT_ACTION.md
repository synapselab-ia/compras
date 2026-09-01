# Next Action — Compras

## F01-BOOTSTRAP-01 — Inicializar Fundação Executável

**Classe:** `T5 — arquitetura/fundação`  
**Estado:** READY  
**Objetivo:** transformar a baseline documental aprovada em uma aplicação mínima executável, testável e validável, sem introduzir ainda dados internos, banco, autenticação, deploy ou regras de negócio não resolvidas.

## Fonte da tarefa

Executar conforme `tasks/F01-BOOTSTRAP-01/SPEC.md`.

## Resultado esperado

Ao final, o repositório deve conter uma aplicação web mínima que:

- possa ser instalada de forma reproduzível;
- compile em TypeScript estrito;
- possua scripts reais de lint, typecheck, test e build;
- tenha uma página inicial neutra, sem dados reais;
- possua CI no GitHub executando os gates aplicáveis com dados exclusivamente fictícios/sanitizados;
- preserve a arquitetura modular e os guardrails da Foundation-00;
- não dependa de Neon, Vercel, Auth ou qualquer banco para funcionar localmente.

## Regras obrigatórias

Antes de implementar:

- verificar documentação oficial atual do Next.js e ferramentas externas adotadas;
- inspecionar a branch `main` e evitar sobrescrever trabalho concorrente;
- tratar o repositório como público em todos os writes, logs e artifacts;
- registrar decisão arquitetural somente se surgir escolha estrutural material não coberta pela Foundation-00.

## Fora do escopo

Não:

- provisionar Neon;
- criar schema/migrations de negócio;
- implementar autenticação/RLS;
- configurar Vercel;
- importar planilhas ou dados reais;
- cadastrar contratação real;
- integrar PNCP/Compras.gov;
- resolver Q-001 a Q-012 por conveniência;
- implementar telas funcionais da Central do Setor além de um shell neutro necessário à fundação.

## Critério de encerramento

A tarefa só pode ser promovida quando os gates definidos no SPEC tiverem sido realmente executados e registrados, o diff público estiver livre de dados sensíveis e `CURRENT_STATE`/`NEXT_ACTION` refletirem o Git real.
