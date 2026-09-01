# AGENTS.md — Compras

Este arquivo define regras obrigatórias para qualquer agente de IA ou novo chat trabalhando neste repositório.

## 1. Startup obrigatório

Antes de qualquer alteração substantiva:

1. localizar o estado canônico atual do projeto; se os documentos de operação ainda não estiverem na branch default, localizar a PR/branch ativa que os contém;
2. ler `docs/00-START-HERE.md`;
3. ler `docs/ai/CURRENT_STATE.md`;
4. ler `docs/ai/NEXT_ACTION.md`;
5. ler `docs/ai/WORK_PROTOCOL.md`;
6. validar `docs/ai/CONTEXT_MANIFEST.md` conforme o protocolo;
7. verificar branch, commit, Issue/PR e estado real do repositório;
8. abrir somente a documentação e o código exigidos pela tarefa ativa.

O histórico do chat não substitui o repositório.

## 2. Regra de escopo

- executar somente a `NEXT_ACTION`, salvo instrução explícita do usuário ou bloqueio real;
- não antecipar funcionalidades futuras;
- não refatorar áreas não relacionadas sem evidência de necessidade;
- não inventar regra de negócio;
- dúvidas reais devem virar `OPEN QUESTION` ou `DECISÃO NECESSÁRIA`;
- alterações arquiteturais relevantes exigem ADR.

## 3. Regra especial enquanto o repositório for público

Tratar toda superfície pública do GitHub como potencialmente permanente e divulgável, não apenas arquivos versionados.

É proibido publicar dados internos reais ou `SENSITIVE_PRE_PUBLICATION` em:

- commits e arquivos;
- Issues, Pull Requests, descrições e comentários de review;
- GitHub Actions inputs, nomes de jobs, logs, summaries, artifacts ou outputs;
- releases, snippets, exemplos, fixtures, dumps ou relatórios gerados;
- qualquer outra superfície pública associada ao repositório.

Também é proibido versionar ou publicar:

- processos reais ainda não públicos;
- números, objetos, quantidades ou valores de contratações sensíveis;
- documentos internos;
- nomes ou dados pessoais desnecessários;
- empresas consultadas em pesquisas ainda internas;
- caminhos de rede ou estrutura interna sensível;
- credenciais, tokens, chaves, connection strings ou secrets;
- dumps, logs ou fixtures com dados reais.

Somente documentação sanitizada, código genérico e dados fictícios são permitidos até que o projeto seja privado e a política de dados seja revisada. Tornar o repositório privado depois não revoga cópias, logs, forks ou divulgações ocorridas enquanto público.

## 4. Segurança

Segurança nunca deve ser enfraquecida para fazer uma tarefa passar.

- autorização crítica deve ser imposta no servidor e/ou banco, nunca apenas pela UI;
- RLS é obrigatória para tabelas de dados internos expostas por Data API;
- negar por padrão;
- não criar signup público por conveniência;
- não expor segredo em bundle de navegador;
- não usar identidade privilegiada para CRUD normal;
- dados classificados como `SENSITIVE_PRE_PUBLICATION` não podem ser enviados a serviços externos sem decisão explícita e documentada.

## 5. Banco

- toda mudança estrutural persistente deve ser migration versionada;
- migration aplicada não é reescrita para alterar a história;
- correções usam nova migration;
- constraints, índices, autorização, auditoria e testes fazem parte do desenho da feature;
- testes destrutivos devem usar ambiente/branch descartável, nunca produção para prova.

## 6. Qualidade e conclusão

Quando aplicável, uma tarefa exige evidência real de:

- validação de entrada;
- regras de negócio;
- autorização;
- estados loading/empty/error/success;
- responsividade e acessibilidade básica;
- testes relevantes;
- lint;
- typecheck;
- build;
- revisão de segurança;
- documentação atualizada.

Nunca declarar PASS para verificação não executada.

## 7. Encerramento

Ao concluir trabalho relevante:

1. revisar o diff integral;
2. executar gates aplicáveis;
3. atualizar documentação sem duplicação desnecessária;
4. atualizar `CURRENT_STATE.md`;
5. deixar exatamente uma `NEXT_ACTION` executável;
6. registrar limitações, bloqueios e verificações reais;
7. preservar um `LAST_GOOD_COMMIT` quando houver estado executável validado.
