# ADR-008 — Faixa hospedada de demonstração com conteúdo público/fictício enquanto o preview privado está bloqueado

**Status:** Accepted  
**Data:** 2026-09-03  
**Escopo:** hospedagem somente de UI/dados fictícios já públicos; não altera a fronteira do preview privado definida nas ADR-006/007  
**Classificação permitida:** PUBLIC / FICTITIOUS ONLY

## Contexto

A F17 provou a parte Vercel da fronteira privada, mas ficou `ON HOLD` por capacidade externa do Neon: a superfície observada não permite aplicar e ler de volta `disable_sign_up=true` antes de expor Managed Better Auth.

O protocolo canônico determina que uma frente `ON HOLD` não deve impedir uma work unit independente. O usuário também determinou explicitamente que o projeto deve continuar avançando sem depender de nova sessão Work.

A aplicação já possui um modo demo seguro e explícito: quando `COMPRAS_PERSISTENT_READ_ENABLED` está ausente ou `false`, a Central usa somente fixtures fictícias versionadas no repositório público e exibe o aviso `Protótipo com dados fictícios`. Nenhum banco ou sessão Auth é necessário nesse modo.

## Decisão

Criar uma faixa hospedada **DEMO / PUBLIC DATA** independente da futura hospedagem privada/persistente.

A classificação `PUBLIC` descreve o conteúdo permitido, não obriga a remover Deployment Protection. Se a Vercel Authentication já proteger a URL de Preview, ela deve permanecer ativa. A faixa existe apenas para permitir inspeção/evolução da interface com dados artificiais e não é ambiente operacional, não prova F17 e não satisfaz a F15.

### Invariantes obrigatórias

1. `REAL_DATA_ALLOWED = NO` continua absoluto.
2. Nenhum `DATABASE_URL`, `NEON_AUTH_BASE_URL`, `NEON_AUTH_COOKIE_SECRET`, token de provider ou outro secret é anexado ao deployment demo.
3. `COMPRAS_PERSISTENT_READ_ENABLED` permanece ausente; o runtime deve cair no modo `demo` por construção.
4. Somente fixtures claramente fictícias já publicáveis podem aparecer.
5. Nenhum Neon project/Auth/user/migration/seed é criado para esta faixa.
6. Nenhum signup, login operacional, RLS hospedado ou persistência é alegado como funcional.
7. Vercel Authentication/Standard Protection não é removida para facilitar a demonstração.
8. A aplicação deve continuar identificando visualmente que está em demonstração e que persistência está desabilitada.
9. Auto-deploy Git deve voltar a `false` após o deployment deliberado, para commits posteriores não criarem publicações por acidente.
10. Se a Vercel classificar acidentalmente um deployment como `production`, nenhum secret/dado interno pode existir; a tentativa deve ser tratada fail-closed e corrigida antes de nova publicação deliberada.

## Relação com ADR-006 e ADR-007

ADR-006/007 continuam integralmente válidas para qualquer ambiente que use Auth, banco, secrets, sessão ou dados não públicos.

Em particular:

- o preview privado continua exigindo defesa provider-side contra signup;
- a aplicação deny-all não substitui `disable_sign_up=true` no ambiente privado;
- nenhum dado real ou pré-publicação pode entrar nesta faixa demo;
- nenhum secret pode ser promovido para esta faixa;
- a proteção Vercel existente continua sendo defesa adicional, mesmo que o conteúdo demo seja publicável.

Portanto, esta ADR cria uma **faixa paralela de demonstração**, e não uma exceção à segurança do produto real.

## Implementação F18

A F18 deve:

1. reutilizar o projeto Vercel já criado, sem criar outro projeto apenas por nomenclatura;
2. configurar no código o preset `framework: "nextjs"`, pois o projeto foi criado inicialmente com preset `Other` e uma tentativa de build falhou procurando diretório `public`;
3. habilitar Git deployment apenas no commit deliberado da branch F18;
4. observar o build e confirmar que nenhum env/secret é necessário;
5. confirmar que o deployment deliberado é Preview (`target` ausente/null) e permanece atrás da Vercel Authentication já provada;
6. verificar a lógica hospedada pelo build e, quando o canal autenticado permitir, fazer smoke da página sem criar Shareable Link persistente;
7. retornar `git.deploymentEnabled` para `false` depois da prova;
8. registrar o deployment como DEMO/PUBLIC DATA, jamais como preview privado/persistente.

Um acesso autenticado usado somente para smoke pode ser temporário e não deve ser persistido em Git, logs de checkpoint ou documentação. Nenhum bypass é requisito de disponibilidade do produto.

## Red-team obrigatório

Antes de promover F18:

- confirmar que não existe env var operacional residual;
- confirmar que nenhum dado das tabelas reais ou de processo foi incluído nas fixtures;
- confirmar que a ausência de Auth/DB não causa fallback silencioso de modo persistente para demo; o demo só é válido porque o ambiente foi deliberadamente criado sem habilitar persistência;
- confirmar que o deployment não é descrito como produção operacional ou ambiente apto a dados reais;
- confirmar que Vercel Authentication continua sendo a barreira externa observada na URL de Preview;
- confirmar que Git auto-deploy foi novamente desabilitado após a publicação deliberada.

## Consequências

### Positivas

- UI hospedada pode ser inspecionada sem esperar o Neon;
- nenhuma credencial de banco/Auth ou sessão Work é necessária para publicar o build;
- desenvolvimento visual/produto pode continuar sobre dados artificiais;
- a barreira de segurança do ambiente privado permanece intacta.

### Limites

- login, banco, persistência e RLS hospedados continuam bloqueados pela F17;
- o nome provisório do projeto Vercel pode ser alterado posteriormente sem exigir recriação do recurso;
- a URL Preview pode exigir login Vercel por causa da proteção já existente;
- deployments de tentativa que falhem devem ser registrados, mas não justificam anexar secrets para “fazer funcionar”.
