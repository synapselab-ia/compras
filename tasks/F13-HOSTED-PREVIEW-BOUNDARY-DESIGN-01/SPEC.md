# F13-HOSTED-PREVIEW-BOUNDARY-DESIGN-01 — Desenhar a fronteira do primeiro preview hospedado privado

**Classe:** T5 — arquitetura, com impacto de T2 — segurança e T3 — integração externa  
**Estado:** READY após conclusão de F12  
**Dependências:** F08, F09, F11, F12, ADR-003, ADR-004, ADR-005 e migrations `0001`–`0003`  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

F12 completou em código e CI a jornada persistente de leitura `Central → detalhe → Central`, mas ela ainda é provada somente contra PostgreSQL efêmero e identidades artificiais de teste.

A arquitetura de referência indica PostgreSQL/Neon e Vercel como candidatos iniciais, porém declara explicitamente que a stack externa deve ser revalidada no momento da implementação e que nenhum ambiente está provisionado.

F13 deve eliminar as ambiguidades de hospedagem, identidade, papéis de banco, configuração, migrations, observabilidade e rollback antes de qualquer provisionamento.

## 2. Resultado esperado

Produzir uma decisão arquitetural sanitizada, preferencialmente `docs/decisions/ADR-006-hosted-preview-boundary.md`, baseada em documentação oficial atual, que defina o caminho seguro para uma futura work unit de provisionamento.

A decisão deve cobrir:

1. hosting do preview e mecanismo de acesso privado;
2. PostgreSQL e identidade necessários ao caminho F08;
3. isolamento entre local/CI, preview e produção futura;
4. admissão privada sem signup público;
5. separação de papéis de migration e runtime;
6. gestão de configuração sensível fora do Git;
7. aplicação das migrations canônicas;
8. seed e smoke test somente fictícios;
9. logging/analytics/URLs;
10. rollback e deprovisionamento;
11. blockers de plano, termos ou capacidade, se houver.

## 3. Revalidação externa obrigatória

Consultar fontes oficiais atuais somente para as capacidades necessárias à decisão.

Para o hosting considerado, confirmar:

- proteção de acesso a preview/deployment;
- configuração por ambiente/branch;
- separação entre configuração server-side e client-side;
- logs/analytics relevantes;
- integração com GitHub e comportamento de previews de PR;
- limites de plano que afetem a proteção escolhida.

Para o PostgreSQL/Auth considerado, confirmar:

- conexão server-side compatível com F08;
- suporte ao modelo de identidade necessário;
- gerenciamento de roles, ownership e RLS;
- execução de migrations por principal separado do runtime;
- branches/databases de preview, se relevantes;
- limites de plano que afetem o desenho.

Registrar incertezas em vez de inferir capacidade não confirmada.

## 4. Invariantes a preservar

O desenho não pode contrariar:

- browser nunca define identidade ou escopo confiável;
- Auth externa identifica; membership/RLS autoriza;
- runtime nunca usa owner, superuser, `BYPASSRLS`, `neondb_owner` ou capability role;
- `withTrustedDatabaseContext()` continua sendo a fronteira de leitura persistente;
- migrations versionadas no Git continuam sendo a fonte canônica do schema;
- capability `team_member_directory` continua técnica e não assumível pela aplicação;
- falha persistente não cai silenciosamente para demo;
- repositório público não recebe dado interno, identidade operacional ou configuração sensível;
- `REAL_DATA_ALLOWED = NO` durante e após F13.

## 5. Ambientes

Definir ao menos:

### Local/CI

- dados artificiais;
- banco efêmero ou local;
- testes adversariais continuam sendo gate.

### Preview hospedado

- não-produção;
- somente dados fictícios/sanitizados;
- acesso privado/autenticado por controle efetivo, não apenas URL obscura;
- runtime sujeito a RLS;
- configuração sensível injetada fora do Git;
- seed explicitamente fictício;
- possibilidade de destruição/recriação sem perda operacional.

### Produção futura

- fora do escopo de F13;
- exige nova avaliação antes de aceitar dados reais.

## 6. Papéis de banco e migrations

O ADR deve separar claramente:

- principal de migration/administração, usado somente para operações administrativas autorizadas;
- principal runtime, não-owner e sem privilégios que contornem RLS;
- capability roles `NOLOGIN`, que não são credenciais operacionais;
- identidade do usuário, validada no servidor e transportada ao PostgreSQL apenas pelo contrato F08.

A futura implantação deve poder provar que uma configuração runtime privilegiada falha fechada pelas validações existentes.

## 7. Seed e smoke test

Definir um cenário totalmente fictício capaz de comprovar em preview:

```text
identidade de teste autorizada
→ Central persistente
→ contratação fictícia visível
→ detalhe persistente correspondente
→ retorno à Central
```

E cenários negativos que provem que acesso não autorizado não revela dados, UUID de outra equipe permanece indistinguível de inexistente e falha persistente não cai para demo.

F13 apenas desenha os cenários; não cria conta, banco ou seed hospedado.

## 8. Red-team obrigatório

Atacar o desenho contra:

- preview acessível anonimamente por URL descoberta;
- proteção existente somente na UI;
- signup público ativado por padrão;
- configuração sensível propagada a previews indevidos;
- valor server-side exposto ao client bundle;
- runtime com privilégio administrativo;
- mesma credencial usada para migration e runtime contínuo;
- seed fictício aplicado no ambiente errado;
- logs/analytics coletando metadados internos desnecessários;
- recursos de preview abandonados sem deprovisionamento;
- desenho dependente de capacidade não confirmada do plano atual.

Cada risco material deve resultar em controle, blocker ou decisão explícita.

## 9. Verificação

F13 só pode ser concluída se:

- fontes oficiais atuais forem revalidadas;
- a decisão registrar premissas verificadas e pontos condicionais;
- SECURITY, DATABASE e ADR-003/004/005 continuarem coerentes;
- nenhuma migration, runtime ou infraestrutura for alterada;
- nenhum dado real ou identidade operacional for publicado;
- diff e CI passarem;
- o checkpoint deixar exatamente uma nova `NEXT_ACTION` executável.

## 10. Fora do escopo

Não:

- provisionar Vercel, Neon ou outro provider;
- criar projeto/database/Auth hospedado;
- inserir configuração operacional real;
- criar usuário ou convite real;
- aplicar migrations externamente;
- executar seed hospedado;
- deploy;
- domínio customizado;
- dados reais;
- mutation ou escrita persistente;
- resolver Q-009/Q-010;
- fechar taxonomias abertas;
- transformar preview em produção.

## 11. Critério de encerramento

F13 termina quando existe um ADR suficientemente preciso para que a próxima sessão possa provisionar ou rejeitar o preview sem tomar decisões silenciosas de segurança/provedor, com critérios de aceite, rollback e superfícies públicas explícitas.
