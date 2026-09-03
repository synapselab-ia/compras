# Next Action — Compras

## F19-AUTH-PORTABILITY-DESIGN-01 — Desenhar Better Auth self-hosted para remover dependência do signup controlado pelo Neon

**Classe:** `T5 — arquitetura` com impacto de `T2 — segurança` e `T3 — integração externa`  
**Estado:** READY  
**Objetivo:** decidir, com documentação oficial atual e prova local/efêmera, se o preview privado deve substituir o Managed Better Auth bloqueado por Better Auth self-hosted em PostgreSQL controlado, com signup fechado por configuração versionada.

Esta é a única `NEXT_ACTION` canônica.

## Por que esta ação agora

A F17 foi movida para `ON HOLD`: a sessão autenticada real provou que a superfície Managed Better Auth disponível nesta conta/região não permite WRITE + READBACK de `disable_sign_up=true`. Repetir a mesma tentativa não produz progresso.

A F18 abriu uma faixa independente de demonstração hospedada e concluiu um deployment Preview Next.js `READY` com dados exclusivamente fictícios, sem Auth, banco ou secrets. O preview demo permanece atrás da Vercel Authentication e Git auto-deploy voltou a ficar desabilitado.

O próximo problema útil é remover a dependência arquitetural da capacidade ausente do Managed Neon Auth sem enfraquecer a admissão privada.

## Hipótese a testar

A documentação oficial atual do Better Auth expõe diretamente:

- PostgreSQL como backend;
- `emailAndPassword.enabled=true`;
- `emailAndPassword.disableSignUp=true`;
- `trustedOrigins` explícitos;
- social providers somente quando configurados;
- plugins somente quando adicionados;
- geração/migration do schema Auth.

A F19 deve provar se isso permite manter ou melhorar a fronteira F14/F08: sign-in email/senha por Server Action, sign-out, sessão server-side, catch-all Auth deny-all, identidade derivada no servidor e autorização final por `app_users` + membership + RLS.

## Execução obrigatória

1. recuperar estado/contexto e validar manifest;
2. revalidar documentação oficial atual do Better Auth/Next.js/PostgreSQL;
3. inspecionar `@neondatabase/auth` atual e a interface consumida por F14;
4. desenhar schema/role/connection boundary para Auth separado do domínio Compras;
5. definir signup fechado, trusted origins, ausência de OAuth/plugins e bootstrap administrativo do primeiro usuário fictício;
6. executar prova local/efêmera suficiente para verificar que signup é negado por configuração real;
7. red-team de endpoints laterais, privilégios de banco, sessão, migrations, secrets e compatibilidade com Vercel;
8. registrar decisão em nova ADR: `ADOPT`, `REJECT` ou `BLOCKED` com evidência;
9. atualizar checkpoint deixando exatamente uma nova NEXT_ACTION.

## Invariantes

- `REAL_DATA_ALLOWED = NO`;
- nenhum secret em Git/chat/log/artifact público;
- nenhum usuário real;
- nenhuma autorização derivada do browser;
- autenticar não cria automaticamente `app_users` ou memberships;
- não habilitar social provider/plugin por conveniência;
- não usar role PostgreSQL privilegiada como runtime normal;
- F17 permanece documentada como evidência do blocker do Managed Neon Auth, mas deixa de ser frente ativa enquanto estiver ON HOLD.

## Fonte da tarefa

Executar `tasks/F19-AUTH-PORTABILITY-DESIGN-01/SPEC.md`, ADR-006, ADR-007, ADR-008, `docs/architecture/SECURITY.md` e `docs/architecture/DATABASE.md`.

## Critério de encerramento

A F19 termina somente com uma decisão arquitetural verificável e uma estratégia de enforcement que mantenha signup fechado por construção, preserve a identidade server-side/RLS e não dependa de capacidade indisponível do provider atual.
