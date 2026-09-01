# F01-BOOTSTRAP-01 — Fundação Executável

## Problema

A Foundation-00 define produto, segurança, arquitetura e protocolo de trabalho, mas o repositório ainda não possui aplicação executável nem gates técnicos reais. A próxima slice deve criar somente a fundação mínima necessária para desenvolvimento incremental confiável.

## Resultado esperado

Uma aplicação web mínima, reproduzível e sem dados reais, apta a receber as próximas slices do produto.

## Comportamento/escopo

A tarefa deve:

1. verificar a documentação oficial atual do framework e tooling antes de escolher versões/comandos;
2. inicializar Next.js com App Router, React e TypeScript estrito conforme a arquitetura vigente;
3. adotar a solução de styling mínima compatível com a Foundation-00, evitando design system prematuro;
4. estabelecer organização inicial de código que permita separar UI, aplicação/domínio e adapters sem criar abstrações vazias em excesso;
5. criar uma página/shell inicial neutro, sem representar fluxo de negócio como se já estivesse implementado;
6. configurar scripts reais para lint, typecheck, test e build;
7. criar ao menos um teste executável que prove o funcionamento da infraestrutura de testes escolhida;
8. configurar GitHub Actions para executar os gates em contexto público seguro;
9. documentar instalação e execução local;
10. atualizar checkpoint e deixar exatamente uma nova `NEXT_ACTION`.

## Critérios de aceite

- instalação limpa das dependências é reproduzível a partir do lockfile;
- TypeScript está em modo estrito;
- `lint`: PASS;
- `typecheck`: PASS;
- `test`: PASS;
- `build`: PASS;
- CI correspondente está versionada e não utiliza dado interno real;
- nenhum secret está presente no diff, logs configurados ou exemplos;
- nenhuma dependência de banco/Auth/hosting é necessária para executar e validar a aplicação local;
- a página inicial não contém dados ou exemplos derivados de contratação real;
- README/startup técnico explica os comandos existentes, sem prometer funcionalidade ainda não entregue;
- `CURRENT_STATE` registra exatamente o que foi validado;
- uma única `NEXT_ACTION` fica pronta.

## Fora do escopo

- Neon/PostgreSQL;
- migrations;
- autenticação;
- RLS;
- Vercel;
- dados reais;
- importação de planilhas;
- entidades persistentes de contratação;
- pesquisa de preços;
- integração PNCP/Compras.gov;
- workflow funcional;
- dashboards/indicadores reais;
- resolução de regras de negócio abertas.

## Invariantes

- GitHub permanece fonte canônica;
- repositório público permanece livre de `INTERNAL` real e `SENSITIVE_PRE_PUBLICATION`;
- não inventar semântica de produto para preencher a tela inicial;
- não adicionar framework/dependência estrutural sem necessidade demonstrável;
- não usar deploy como substituto de build/test local/CI;
- a fundação deve poder evoluir para banco/autorização sem mover regra crítica para componentes React.

## Impacto em dados

Nenhum dado persistente de negócio deve ser criado. Fixtures, quando necessárias, são estritamente fictícias e genéricas.

## Impacto em segurança

O risco principal desta slice é exposição acidental pelo repositório/CI público. Revisar:

- arquivos versionados;
- `.env*` e exemplos;
- workflow YAML;
- comandos que possam ecoar ambiente;
- logs/summaries/artifacts;
- dependências introduzidas.

Nenhum secret é necessário para esta task.

## Verificação obrigatória

Executar e registrar os comandos reais definidos pelo projeto, equivalentes a:

```text
install clean
lint
typecheck
test
build
```

Também verificar:

- diff completo;
- ausência de segredo/dado sensível;
- execução da CI quando o conector/ambiente permitir observar o run;
- carregamento básico da aplicação em browser se ferramenta adequada estiver disponível; se não, registrar `SKIPPED` sem transformar em PASS.
