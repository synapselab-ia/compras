# Next Action — Compras

## F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01 — Desenhar a fronteira do primeiro preview hospedado privado

**Classe:** `T5 — arquitetura` com impacto de `T2 — segurança` e `T3 — integração externa`  
**Estado:** READY  
**Objetivo:** revalidar nas fontes oficiais atuais as capacidades e limites dos provedores de referência e definir, sem ainda provisionar recursos, o desenho mínimo seguro para um primeiro preview hospedado privado da jornada persistente de leitura, usando exclusivamente dados fictícios/sanitizados.

## Fonte da tarefa

Executar conforme `tasks/F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01/SPEC.md`, `docs/architecture/ARCHITECTURE.md`, `docs/architecture/SECURITY.md`, `docs/architecture/DATABASE.md`, ADR-003, ADR-004 e ADR-005.

## Resultado esperado

Ao final, o repositório deve possuir uma decisão arquitetural verificável que estabeleça, no mínimo:

- se Neon continua adequado como referência para PostgreSQL/identidade necessários ao preview e quais capacidades atuais serão realmente usadas;
- se Vercel continua adequado como alvo do preview e qual mecanismo atual impede acesso público não autenticado à aplicação;
- separação explícita entre ambiente local/CI, preview hospedado e eventual produção futura;
- estratégia de admissão privada sem signup público;
- papéis de banco separados para migration/administração e runtime, preservando F08/RLS e impedindo owner/superuser/`BYPASSRLS` no aplicativo;
- categorias de secrets e onde cada uma pode existir, sem registrar valores reais no GitHub;
- caminho de aplicação das migrations `0001`–`0003` em banco hospedado sem depender de painel como fonte canônica;
- estratégia de seed/smoke test exclusivamente fictícia para provar `Central → detalhe → Central` persistente;
- política mínima de logs, analytics e URLs para evitar exposição de metadados internos;
- plano de rollback/deprovisionamento do preview;
- critérios objetivos para uma futura work unit de provisionamento, ou blocker explícito caso algum provedor/plano não satisfaça a fronteira.

## Regras obrigatórias

- revalidar documentação oficial atual dos provedores antes de fechar qualquer decisão; não confiar apenas na arquitetura de referência histórica;
- preferir documentação oficial e registrar links/versões/datas suficientes para auditoria da decisão;
- não provisionar projeto, banco, Auth, domínio ou deploy nesta work unit;
- não criar usuário operacional real nem publicar identificadores de conta/projeto;
- não criar ou versionar secret, token, connection string, cookie, issuer/subject real ou credencial de provider;
- não habilitar signup público;
- não aceitar proteção apenas na UI como controle de acesso ao preview;
- preservar o contrato F08: sessão validada no servidor, contexto LOCAL e runtime não privilegiado sujeito a RLS;
- preservar migrations como fonte canônica do schema;
- dados usados em exemplos, testes e documentação devem ser artificiais;
- manter `REAL_DATA_ALLOWED = NO`;
- não resolver Q-009, Q-010 ou taxonomias abertas por inferência;
- se a capacidade necessária depender de plano, setting ou limitação não confirmada, registrar a incerteza em vez de assumir.

## Red-team mínimo

O desenho deve ser atacado contra, no mínimo:

- preview acessível anonimamente por URL descoberta;
- signup/admissão aberta por configuração padrão;
- runtime usando owner, superuser, `BYPASSRLS`, `neondb_owner` ou capability role;
- migrations executadas com credencial runtime ou credencial administrativa usada pela aplicação;
- secrets chegando ao browser, GitHub público, Actions log, artifact ou URL;
- branch/preview de PR recebendo secrets ou dados além do necessário;
- seed fictício sendo confundido com dado real ou sendo aplicado em ambiente errado;
- fallback demo mascarando falha de leitura persistente hospedada;
- logs/analytics capturando IDs, claims ou conteúdo operacional desnecessário;
- provider lock-in desnecessário contrariando a portabilidade definida na arquitetura;
- ausência de rollback/deprovisionamento.

## Verificação obrigatória

- documentação oficial atual dos provedores relevantes: REVALIDADA;
- matriz de capacidades/limitações e riscos: DOCUMENTADA;
- ADR da fronteira do preview: COMPLETA;
- compatibilidade com SECURITY/DATABASE/ADR-003/004/005: PASS;
- nenhuma mudança de runtime, migration ou infraestrutura: CONFIRMADA;
- diff integral sem secret, dado real, account/project ID ou URL privada: PASS;
- lint/test/build aplicáveis à documentação: PASS/NOT APPLICABLE conforme CI;
- CI: PASS;
- exatamente uma nova `NEXT_ACTION` executável ao encerrar F13.

## Fora do escopo

Não:

- criar projeto Vercel/Neon ou qualquer outro recurso externo;
- adicionar secrets a Vercel, GitHub ou provider;
- aplicar migrations em banco hospedado;
- criar identidade operacional real;
- convidar usuário;
- deploy ou domínio;
- habilitar `COMPRAS_PERSISTENT_READ_ENABLED` em ambiente hospedado;
- mutations, CRUD ou policy de escrita;
- decidir perfis funcionais da Q-009;
- decidir auditoria de leitura da Q-010;
- usar dados reais;
- tornar o repositório privado como efeito colateral;
- pesquisa de preços.

## Critério de encerramento

A tarefa termina quando existe uma decisão arquitetural atualizada, baseada em fontes oficiais, que permita provisionar um preview privado fictício sem adivinhações de segurança/provedor, com riscos e rollback explícitos, e quando o checkpoint deixa exatamente uma próxima work unit pequena e executável.
