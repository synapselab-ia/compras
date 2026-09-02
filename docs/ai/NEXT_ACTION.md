# Next Action — Compras

## F15-HOSTED-PREVIEW-PROVISION-01 — Provisionar e provar o primeiro preview hospedado privado fictício

**Classe:** `T3 — integração externa` com impacto de `T2 — segurança`  
**Estado:** READY  
**Objetivo:** materializar, em ambiente descartável e exclusivamente fictício, a fronteira definida nas ADR-006/ADR-007, provisionando o primeiro preview hospedado privado somente se Deployment Protection, Auth sem signup, separação de papéis PostgreSQL, migrations, secrets, smoke adversarial e deprovisionamento puderem ser provados sem enfraquecer os invariantes existentes.

## Fonte da tarefa

Executar conforme `tasks/F15-HOSTED-PREVIEW-PROVISION-01/SPEC.md`, ADR-003, ADR-005, ADR-006, ADR-007, `docs/architecture/SECURITY.md` e as fronteiras F08/F11/F14.

## Resultado esperado

Ao final, deve existir um preview hospedado **não produtivo, privado, descartável e com dados somente fictícios**, ou um blocker explícito e seguro caso o provider/plano/conector não permita cumprir a fronteira.

O encerramento bem-sucedido deve provar, no mínimo:

- proteção externa efetiva do deployment antes de qualquer uso operacional;
- nenhuma production surface pública contendo a aplicação/configuração privada;
- secrets server-only e limitados à branch/ambiente de Preview necessário;
- Neon/PostgreSQL com principal runtime não privilegiado e distinto de bootstrap/migration;
- migrations canônicas `0001`–`0003` aplicadas pelo caminho administrativo apropriado;
- Managed Better Auth com email/senha e `disable_sign_up=true` confirmado provider-side;
- métodos adicionais de signup/autocriação desabilitados;
- usuário de teste exclusivamente fictício admitido por caminho administrativo controlado;
- `app_user`/membership fictícios criados separadamente no banco do produto, sem auto-provisionamento por login;
- `COMPRAS_PERSISTENT_READ_ENABLED=true` somente depois de Auth, banco e proteção estarem prontos;
- smoke adversarial de sessão, signup, RLS/cross-team, sign-out e fail-closed;
- plano de rollback/deprovisionamento executável e testado quando aplicável;
- nenhum dado real, interno ou pré-publicação em provider, logs, GitHub ou artifacts.

## Regras obrigatórias

- revalidar documentação/capacidades atuais de Vercel e Neon imediatamente antes de qualquer provisionamento;
- usar os conectores oficiais disponíveis quando a ação for sobre recursos da conta, em vez de inferir estado pelo web público;
- não criar ou anexar secret antes de provar a proteção externa necessária;
- não aceitar URL obscura como proteção;
- não usar Shareable Links, Deployment Protection Exceptions ou query-string bypass;
- se qualquer production domain/deployment servir a aplicação, ele deve possuir proteção compatível com `All Deployments`; sem isso, bloquear antes dos secrets;
- limitar variáveis de Preview à branch hospedada dedicada sempre que o provider suportar esse escopo;
- runtime PostgreSQL não pode ser owner, superuser, `BYPASSRLS`, `CREATEROLE`, `neondb_owner` ou a capability `compras_team_directory_view_owner`;
- runtime e capability devem ser criados/validados por SQL, não por caminho de control plane que lhes conceda `neon_superuser`;
- migration principal e runtime devem usar credenciais distintas;
- schema hospedado deve vir das migrations Git canônicas, nunca de edição manual de tabelas/policies no painel;
- seed fictício deve ser separado das migrations e possuir guard explícito contra ambiente errado;
- provider Auth deve ter `disable_sign_up=true` confirmado antes de exposição;
- OAuth, magic link, OTP, reset, MFA e outros métodos permanecem desabilitados nesta primeira prova;
- nenhum secret, token, connection string, cookie ou credencial pode ser persistido em GitHub público, chat, log ou artifact;
- preservar F08: browser não define issuer, subject, `app_user_id`, membership ou `team_id`;
- preservar F11/RLS e todas as regressões existentes;
- `REAL_DATA_ALLOWED = NO` durante toda a work unit;
- não resolver Q-009/Q-010 ou outras taxonomias abertas.

## Sequência de segurança

A ordem é parte do requisito:

1. revalidar provider/plano/conectores;
2. provisionar superfície descartável sem dados reais;
3. ativar e provar Deployment Protection;
4. criar/configurar Postgres/Auth e papéis administrativos necessários;
5. aplicar migrations canônicas;
6. configurar Auth com signup desabilitado e métodos adicionais desligados;
7. criar somente identidade e dados fictícios necessários ao smoke;
8. anexar secrets server-only ao Preview protegido;
9. habilitar leitura persistente;
10. executar smoke funcional e adversarial;
11. registrar evidência sanitizada;
12. provar rollback/deprovisionamento ou remover recursos temporários que não devam permanecer.

Se qualquer etapa crítica falhar, não avançar para a seguinte quando isso ampliar exposição.

## Red-team mínimo

Atacar deliberadamente:

- URL de deployment em navegador anônimo/incógnito;
- production URL gerada automaticamente;
- preview sem Deployment Protection;
- signup direto pela superfície da aplicação;
- signup direto no endpoint gerenciado do provider;
- OAuth/OTP/reset ou método lateral habilitado por default;
- secret propagado para PR/branch não autorizada;
- runtime usando role control-plane/owner/`neon_superuser`/`BYPASSRLS`;
- capability contaminada por membership privilegiada;
- mesma credencial usada para migration e runtime;
- seed executado em ambiente ou branch indevida;
- sessão inexistente/expirada tentando alcançar dados;
- identidade provider válida sem `app_user`/membership interna;
- UUID conhecido de outra equipe;
- membership revogada/usuário interno desabilitado;
- sign-out seguido de tentativa de reutilizar acesso;
- falha de Auth/DB virando demo silencioso;
- logs, URLs, erro de build ou artifacts contendo secrets/claims/connection strings;
- preview/branch/deployment órfão após rollback.

## Verificação obrigatória

- capacidades atuais dos providers: REVALIDADAS;
- proteção anônima do deployment: PROVADA;
- ausência de production surface pública desprotegida: PROVADA;
- `disable_sign_up=true` provider-side: PROVADO;
- métodos adicionais desabilitados: PROVADOS;
- papéis PostgreSQL e memberships técnicas: INSPECIONADOS;
- migrations `0001`–`0003`: APLICADAS E VERIFICADAS;
- seed: SOMENTE FICTÍCIO E COM ESCOPO CORRETO;
- smoke de sign-in/sign-out: PASS;
- smoke de RLS/cross-team/identidade não autorizada: PASS;
- `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`: PASS quando código/config versionada for alterado;
- CI GitHub: PASS para qualquer mudança versionada;
- diff/repo/logs públicos sem secret/dado real: PASS;
- rollback/deprovisionamento: PROVADO ou estado residual explicitamente justificado como preview privado descartável;
- exatamente uma nova `NEXT_ACTION` executável ao encerrar F15.

## Condição de bloqueio

Marcar F15 como **BLOCKED**, sem relaxar segurança, se qualquer uma destas condições ocorrer:

- plano/capacidade Vercel não consegue impedir superfície pública relevante;
- conector/provider não permite confirmar ou configurar `disable_sign_up`/métodos de Auth necessários;
- não é possível separar de forma segura bootstrap/migration/runtime;
- única credencial disponível ao runtime é owner/superuser/`BYPASSRLS`/`neon_superuser`;
- secret só pode ser anexado a escopo Git excessivamente amplo;
- não há forma confiável de executar ou desfazer o preview sem risco de dados reais;
- qualquer requisito crítico depender de ação manual não observável que não possa ser verificada.

## Fora do escopo

Não:

- usar dado real, interno ou pré-publicação;
- criar usuário real;
- tornar o preview produção;
- liberar production domain público;
- adicionar analytics/session replay externa;
- implementar mutations/CRUD de contratação;
- definir perfis funcionais da Q-009;
- implementar auditoria de leitura da Q-010;
- OAuth, magic link, OTP, reset, MFA;
- migrar/copyar futura base produtiva para Preview.

## Critério de encerramento

A tarefa termina quando existe evidência verificável de um preview hospedado privado, fictício e descartável que preserva Deployment Protection + Auth privado + F08 + PostgreSQL/RLS, sem signup público e sem credencial runtime privilegiada, ou quando um blocker real é documentado sem enfraquecer a fronteira. Em ambos os casos deve restar exatamente uma próxima work unit canônica coerente com o estado real.
