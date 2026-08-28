# Architecture — Compras

**Versão:** 0.1  
**Status:** arquitetura de referência, não provisionada

## 1. Objetivo arquitetural

Permitir evolução rápida com baixo custo, segurança por padrão, domínio desacoplado de provedor e integração controlada com fontes públicas oficiais.

## 2. Stack de referência inicial

Para protótipo e primeira versão:

- Next.js App Router;
- React;
- TypeScript em modo estrito;
- CSS/Tailwind ou design system definido na slice de fundação executável;
- PostgreSQL;
- Neon como provedor de referência para Postgres/Auth/Data API, sujeito a verificação oficial no momento da implementação;
- Vercel como alvo de protótipo/preview quando compatível com termos e finalidade;
- GitHub como fonte de verdade e CI.

A stack externa deve ser revalidada em documentação oficial antes de implementação porque planos, APIs e limites mudam.

## 3. Forma do sistema

Monólito modular web.

Separação lógica esperada:

```text
UI / rotas
    ↓
application services / use cases
    ↓
domain
    ↓
repositories / adapters
    ↓
PostgreSQL / APIs externas
```

Regras críticas não devem depender de componentes React.

## 4. Módulos iniciais previstos

- identidade e acesso;
- contratações;
- processos relacionados;
- itens;
- workflow/estado operacional;
- timeline/auditoria;
- busca;
- alertas;
- pesquisa de preços;
- integrações públicas;
- documentos, futuramente.

## 5. Banco

Estratégia desejada:

```text
database/
├── migrations/
└── tests/
```

Git registra a história do schema.

Toda alteração persistente usa migration versionada. Banco não é modelado exclusivamente por painel administrativo.

## 6. Autenticação e autorização

A aplicação é privada por natureza.

Camadas:

```text
Browser
  ↓ sessão autenticada
Servidor / Data API
  ↓ autorização
PostgreSQL + RLS
```

A UI pode ocultar ações não permitidas, mas não constitui a fronteira autoritativa.

V0.1 pode autorizar um único usuário/membership sem abandonar o modelo multiusuário.

## 7. Dados públicos versus operação interna

Separar dois contextos:

### Public Intelligence

- catálogos públicos;
- APIs de compras públicas;
- preços e resultados já públicos;
- cache descartável/expirável.

### Internal Operations

- contratações internas;
- estado operacional;
- itens e quantidades ainda não publicados;
- pesquisa em elaboração;
- responsáveis;
- timeline;
- documentos e pendências.

Integração pública não recebe acesso irrestrito ao contexto interno.

## 8. Estratégia para APIs públicas

Não espelhar grandes bases por padrão.

Fluxo desejado:

```text
consulta do usuário
→ descoberta/normalização de catálogo quando necessária
→ chamadas server-side a fontes oficiais
→ merge/deduplicação
→ ranking determinístico
→ exibição
→ persistência somente das referências escolhidas
```

Cache efêmero pode existir no navegador ou camada de aplicação. Persistência permanente deve ter motivo operacional.

## 9. Pesquisa e ranking

Primeira versão deve preferir regras determinísticas e explicáveis a IA opaca.

Compatibilidade pode considerar, conforme especificação futura:

- termos relevantes;
- números e medidas;
- unidade;
- marca/modelo quando legitimamente pertinente;
- localidade;
- recência;
- quantidade;
- fonte;
- divergências explícitas.

O produto deve explicar por que um resultado foi priorizado ou rejeitado.

## 10. Auditoria

Mudanças relevantes produzem eventos de domínio/auditoria suficientes para reconstruir o histórico operacional.

Evitar logar conteúdo sensível desnecessário.

## 11. Ambientes

Enquanto o repositório for público:

- somente dados fictícios/sanitizados;
- nenhuma credencial real versionada;
- nenhum processo interno real em fixtures.

Antes de uso com dados sensíveis reais, revisar:

- visibilidade do repositório;
- hospedagem autorizada;
- identidade/MFA;
- RLS e testes adversariais;
- backups;
- logging;
- analytics;
- política de dados e LGPD;
- termos do provedor de hosting.

## 12. Princípio de portabilidade

Next.js, domínio e migrations devem evitar acoplamento desnecessário ao provedor hospedado.

Trocar provedor de Postgres/hosting no futuro não deve exigir reescrever regras de negócio.
