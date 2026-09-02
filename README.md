# Compras

Sistema em desenvolvimento para organizar fluxos de contratações públicas, centralizar acompanhamento operacional e reduzir controles fragmentados.

## Estado atual

As work units de fundação, protótipo, persistência, RLS, fronteira server-side e primeira leitura persistente da Central foram concluídas até a **F09 — First Persistent Read**.

A aplicação possui uma Central do Setor com modo demonstrativo e um caminho persistente server-side opt-in. O modo persistente usa sessão validada, identidade externa mínima (`issuer + subject`), contexto PostgreSQL local à transação e RLS para autorizar a leitura. Ele permanece desabilitado por padrão e não possui infraestrutura/credenciais reais neste repositório.

O detalhe da contratação continua demonstrativo. A próxima frente é **F10 — Team Directory / RLS Design**, porque as policies atuais permitem autorizar contratações da equipe, mas ainda não fornecem uma projeção segura com nomes de outros membros responsáveis.

Ainda não existe deploy operacional, banco/Auth hospedado provisionado, login/signup exposto, escrita persistente ou dados reais.

## Requisitos locais

- Node.js 24 LTS ou versão compatível com o `engines` do projeto;
- npm.

## Instalação

```bash
npm ci
```

## Comandos

```bash
npm run dev
npm run lint
npm run typecheck
npm test
npm run build
npm start
```

`typecheck` executa `next typegen` antes do TypeScript para manter os tipos de rotas/framework atualizados.

## Stack atual

- Next.js App Router;
- React;
- TypeScript estrito;
- PostgreSQL relacional com RLS/default-deny;
- Neon Auth SDK server-side e Neon Serverless Driver, sem recurso hospedado provisionado;
- CSS global mínimo, sem design system prematuro;
- ESLint com `eslint-config-next`;
- Vitest para testes unitários;
- PostgreSQL descartável na CI para migrations/RLS/red-team;
- GitHub Actions com instalação reproduzível por `npm ci`.

## Leitura persistente

A Central usa dados demonstrativos enquanto `COMPRAS_PERSISTENT_READ_ENABLED` estiver ausente ou igual a `false`.

O valor exato `true` seleciona o caminho persistente. Esse modo exige, em runtime, configuração server-only válida de Auth e banco. Falhas não fazem fallback para dados demo; a página apresenta estado indisponível genérico.

Nenhuma variável de segredo usa prefixo público e nenhuma credencial real deve ser versionada.

## Segurança desta fase

O repositório permanece público. Não use dados reais, documentos internos ou informações pré-publicação em código, fixtures, Issues, PRs, logs ou artifacts.

A existência do caminho persistente em código **não autoriza dados operacionais reais**. Antes disso ainda são necessárias decisões/provisionamento controlado de infraestrutura, autenticação/admissão e revisão explícita da política de dados.

A autorização não depende da UI: identidade é resolvida server-side e o banco aplica RLS. Roles owner, superuser, `neondb_owner` ou `BYPASSRLS` não são caminho operacional normal.

## Continuidade por IA

Uma nova sessão deve começar por `AGENTS.md` e `docs/00-START-HERE.md`, recuperar o estado real do GitHub e executar `docs/ai/NEXT_ACTION.md` conforme `docs/ai/WORK_PROTOCOL.md`.
