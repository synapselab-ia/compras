# Next Action — Compras

## F14-PRIVATE-AUTH-ADMISSION-01 — Implementar autenticação privada sem signup público

**Classe:** `T1 — feature` com impacto de `T2 — segurança` e `T3 — integração externa`  
**Estado:** READY  
**Objetivo:** implementar no repositório a jornada mínima de autenticação necessária ao futuro preview privado, permitindo apenas sign-in de identidades previamente admitidas, sem signup público, sem provisionar Vercel/Neon e sem alterar as regras de autorização/RLS já validadas.

## Fonte da tarefa

Executar conforme `tasks/F14-PRIVATE-AUTH-ADMISSION-01/SPEC.md`, ADR-003, ADR-006, `docs/architecture/SECURITY.md` e a fronteira F08 existente.

## Resultado esperado

Ao final, o repositório deve possuir:

- uma jornada explícita de sign-in para Managed Better Auth compatível com o SDK atual;
- nenhuma UI de signup;
- uma fronteira server-side que não exponha livremente operações de signup apenas porque o SDK/provider as oferece;
- proteção das rotas operacionais contra uso anônimo no modo persistente, com estado de sessão claro e fail-closed;
- sign-out funcional;
- identidade do usuário derivada exclusivamente da sessão validada, mantendo `issuer + subject` como única identidade externa aceita por F08;
- nenhuma criação automática de `app_users` ou memberships a partir de login;
- configuração inválida/falha do Auth resultando em indisponibilidade genérica, sem fallback demo em modo persistente;
- contrato documentado para o futuro provisionamento exigir `disable_sign_up=true` no Managed Better Auth antes de anexar secrets/URL hospedada;
- testes adversariais cobrindo tentativa direta de signup, sessão ausente/inválida, identidade desconhecida e retorno seguro para sign-in.

## Regras obrigatórias

- revalidar a documentação oficial atual do SDK/Managed Better Auth necessária à implementação antes de alterar integração externa;
- reutilizar `@neondatabase/auth` e o adaptador de identidade atual; não introduzir segundo provedor de Auth sem decisão arquitetural;
- não aceitar issuer, subject, `app_user_id`, membership ou `team_id` do browser;
- não transformar email em identidade/autorização interna;
- não auto-provisionar domínio Compras no primeiro login;
- não habilitar signup público, OAuth, magic link ou outro método que possa criar usuário implicitamente;
- se o handler genérico do SDK expuser endpoints além do necessário, restringir a superfície da aplicação de forma testável em vez de confiar que a UI não os chama;
- o provider hospedado futuro continua obrigado a usar `disable_sign_up=true`; bloqueio na aplicação é defesa adicional, não substituição do controle provider-side;
- `NEON_AUTH_COOKIE_SECRET`, `DATABASE_URL` e qualquer credencial permanecem server-only;
- `NEON_AUTH_BASE_URL` não é derivada da request;
- manter `COMPRAS_PERSISTENT_READ_ENABLED` com a semântica atual;
- nenhuma policy/migration de escrita e nenhuma infraestrutura hospedada nesta work unit;
- somente fixtures fictícias/sanitizadas;
- manter `REAL_DATA_ALLOWED = NO`;
- não resolver Q-009/Q-010 ou taxonomias abertas.

## Comportamento mínimo

### Sem sessão

Em caminho operacional persistente, o usuário deve ser direcionado para a experiência de sign-in ou receber estado autenticável equivalente, sem executar leitura protegida como se fosse uma falha de banco.

### Sign-in válido

Uma identidade previamente existente no provider pode estabelecer sessão. A sessão validada produz somente `issuer + subject`; autorização continua dependendo de `app_users` ativo + membership ativa no PostgreSQL.

### Identidade autenticada sem autorização interna

Não recebe dados de contratação. Não é criada membership automaticamente e não ganha erro que revele escopo de outra equipe.

### Signup

Tentativa pela UI não existe. Tentativa direta contra a superfície HTTP da aplicação deve ser rejeitada. A futura configuração hospedada deve bloquear também signup diretamente no endpoint gerenciado do provider.

### Sign-out

Invalida/encerra a sessão pelo mecanismo oficial do SDK e retorna ao estado não autenticado sem preservar acesso persistente.

### Auth indisponível/configuração inválida

Falha fechada. Não serializar provider error, cookie, endpoint interno ou secret. Em modo persistente, não cair para demo.

## Red-team mínimo

Atacar deliberadamente:

- chamada direta a endpoint `sign-up` sem passar pela UI;
- rota operacional acessada sem sessão;
- sessão inválida/expirada;
- issuer/subject forjados em query/body/header;
- email conhecido tentando substituir subject;
- usuário autenticado no provider mas desconhecido em `app_users`;
- usuário desabilitado/membership revogada;
- configuração `NEON_AUTH_BASE_URL` ou cookie secret ausente/inválida;
- redirect aberto por `callbackURL`/parâmetro fornecido pelo cliente;
- erro do provider vazando detalhes;
- fallback demo mascarando Auth indisponível;
- endpoint adicional do handler permitindo OAuth/signup implícito;
- client bundle recebendo cookie secret ou `DATABASE_URL`.

## Verificação obrigatória

- documentação oficial atual de Managed Better Auth/Next.js SDK: REVALIDADA;
- lint: PASS;
- typecheck: PASS;
- testes existentes: PASS;
- novos testes de Auth/admissão: PASS;
- build: PASS;
- regressões F08/F09/F12: PASS;
- nenhum endpoint de signup utilizável pela aplicação: PROVADO;
- ausência de auto-provisionamento de `app_users`/membership: PROVADA;
- diff integral sem secret/dado real/infra: PASS;
- CI: PASS;
- exatamente uma nova `NEXT_ACTION` executável ao encerrar F14.

## Fora do escopo

Não:

- criar projeto Neon/Vercel;
- adicionar secrets reais;
- habilitar Managed Better Auth hospedado;
- criar usuário real ou fictício hospedado;
- configurar `disable_sign_up` em recurso real;
- aplicar migrations hospedadas;
- deploy;
- dados reais;
- mutation/CRUD de contratação;
- perfis funcionais Q-009;
- auditoria de leitura Q-010;
- recuperação de senha, OAuth ou MFA nesta primeira jornada;
- tornar o preview produção.

## Critério de encerramento

A tarefa termina quando a aplicação possui uma fronteira de autenticação privada testada, capaz de consumir somente identidades previamente admitidas e de rejeitar signup na sua própria superfície, preservando F08/RLS, e deixa exatamente uma próxima work unit para provisionar e provar o preview hospedado fictício conforme ADR-006.
