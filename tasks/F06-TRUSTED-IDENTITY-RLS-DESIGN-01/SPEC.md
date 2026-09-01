# F06-TRUSTED-IDENTITY-RLS-DESIGN-01 — SPEC

## Classe

`T3 — integração externa`, com impacto direto de `T2 — segurança`.

## Problema

A F05 estabeleceu o núcleo relacional e RLS `default-deny`, mas deliberadamente não abriu nenhuma policy porque ainda não existe identidade autenticada confiável integrada ao PostgreSQL.

A arquitetura usa Neon como provedor de referência para Postgres/Auth/Data API, sujeito a revalidação oficial. Como essas capacidades são externas e mutáveis, não é seguro implementar claims, função de identidade ou policy com base em memória, exemplo antigo ou suposição sobre o produto atual.

## Resultado esperado

Produzir um desenho técnico pequeno e implementável para a próxima slice, baseado em documentação oficial atual, cobrindo:

1. caminho de autenticação/sessão oferecido pela stack Neon de referência no momento da execução;
2. claims ou identificadores que podem ser considerados verificados server-side;
3. mapeamento confiável de identidade externa para `app_users(auth_issuer, auth_subject)`;
4. resolução de membership ativa por `user_id` interno;
5. mecanismo proposto para derivar o usuário corrente no PostgreSQL/servidor sem aceitar identidade fornecida pelo cliente;
6. policies mínimas futuras de `SELECT` por equipe/membership;
7. testes adversariais necessários antes de qualquer policy permissiva;
8. efeitos de custo, privacidade, retenção, API ou lock-in que alterem materialmente a arquitetura de referência.

## Inspeção obrigatória

Antes de decidir:

- ler `docs/architecture/ARCHITECTURE.md`;
- ler `docs/architecture/SECURITY.md`;
- ler `docs/architecture/DATABASE.md`;
- ler `docs/decisions/ADR-002-persistence-foundation.md`;
- ler `docs/product/OPEN_QUESTIONS.md`, especialmente Q-009 e Q-010;
- revisar `database/migrations/0001_core_foundation.sql` e testes atuais;
- consultar documentação oficial atual do Neon para Postgres, Auth e Data API/integração equivalente que esteja realmente disponível;
- usar outras fontes somente como apoio, nunca como autoridade para comportamento de segurança do provedor.

## Comportamento / decisões que o desenho deve fixar

### Identidade

A identidade autorizadora deve nascer de sessão/credencial validada, não de `user_id`, `membership_id`, `team_id`, `issuer` ou `subject` enviados livremente pelo browser.

O desenho deve indicar onde ocorre a validação e qual informação verificada chega ao servidor/PostgreSQL.

### Mapeamento

Persistir a separação já aprovada:

`identidade autenticada verificada → issuer + subject → app_user → membership ativa → team_id autorizado`.

Conhecer UUID ou identificador administrativo não concede acesso.

### Leitura

A futura policy de leitura deve ser mínima e baseada em membership ativa. Não criar `role` em `memberships` e não antecipar Q-009.

A F06 especifica a policy e testes; não a aplica.

### Falha segura

Sessão ausente, inválida, claim não verificável, app_user inexistente, membership ausente/revogada ou falha na resolução deve resultar em nenhum acesso interno.

## Critérios de aceite

- [ ] documentação oficial atual consultada e registrada com links/data quando relevante;
- [ ] capacidades atuais do Neon de referência separadas de suposições históricas;
- [ ] fronteira de confiança desenhada sem ID de autorização escolhido pelo cliente;
- [ ] `issuer + subject` preservados como chave externa composta;
- [ ] membership ativa usada como base de escopo de leitura;
- [ ] Q-009 permanece aberta e nenhum `role` é inventado;
- [ ] nenhum `BYPASSRLS`/owner é usado como caminho normal;
- [ ] nenhuma chave privilegiada é planejada para o browser;
- [ ] casos sem membership, membership revogada e UUID conhecido de outra equipe aparecem no plano de teste;
- [ ] falha de sessão/validação é `fail-closed`;
- [ ] decisão registrada em ADR ou documentação canônica adequada;
- [ ] diff integral revisado contra `SECURITY.md` e repositório público;
- [ ] gates de aplicação existentes continuam PASS se arquivos executáveis forem tocados;
- [ ] nenhuma infraestrutura externa é provisionada.

## Fora do escopo

- provisionar projeto Neon ou qualquer banco hospedado;
- criar usuário real, secret, JWT, connection string ou credencial;
- implementar login/signup;
- aplicar policy permissiva;
- conectar a Central/detalhe ao banco;
- escrever RPC/serviço de mutação;
- resolver Q-009;
- adicionar dados reais ou fixtures internas;
- deploy.

## Invariantes

- repositório público continua aceitando somente dados fictícios/sanitizados;
- RLS atual permanece sem policy permissiva até a identidade confiável existir;
- `app_users` e `memberships` continuam entidades distintas;
- autorização nunca depende apenas de UI;
- provider externo não se torna fonte canônica do domínio;
- portabilidade de PostgreSQL e do domínio deve ser preservada quando tecnicamente razoável.

## Impacto em dados

Nenhuma migration é esperada nesta slice, salvo se a pesquisa revelar requisito estrutural indispensável e compatível com as decisões já aprovadas; nesse caso, a F06 deve parar no desenho e promover uma slice própria em vez de misturar implementação.

## Impacto em segurança

Alto. Uma decisão incorreta aqui pode transformar RLS em controle aparente. Toda hipótese sobre sessão, claims, chaves ou Data API deve ser confrontada com documentação oficial atual e cenários adversariais.

## Verificação obrigatória

- revisão de fontes oficiais atuais;
- threat/red-team do fluxo de identidade;
- coerência com `SECURITY.md`, `DATABASE.md` e ADR-002;
- confirmação de que nenhuma policy permissiva, secret ou recurso externo foi criado;
- atualização de checkpoint ao final com exatamente uma ação executável seguinte.
