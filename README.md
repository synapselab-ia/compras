# Compras

Sistema em desenvolvimento para organizar fluxos de contratações públicas, centralizar acompanhamento operacional e reduzir controles fragmentados.

## Estado atual

O projeto está na fase **F01 — Fundação Executável**.

A aplicação desta fase é deliberadamente neutra: não possui banco, autenticação, integração externa ou dados operacionais reais. O repositório continua público e somente conteúdo sanitizado pode ser publicado.

## Requisitos locais

- Node.js 24 LTS ou superior suportado pelo projeto;
- npm.

## Instalação

Após a inclusão do lockfile canônico:

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

## Stack da fundação

- Next.js App Router;
- React;
- TypeScript estrito;
- CSS global mínimo, sem design system prematuro;
- ESLint com `eslint-config-next`;
- Vitest para testes unitários;
- GitHub Actions para CI.

## Segurança desta fase

Nenhum secret é necessário para instalar, testar ou compilar a aplicação. Não use dados reais, documentos internos ou informações pré-publicação em código, fixtures, Issues, PRs, logs ou artifacts enquanto o repositório estiver público.

## Continuidade por IA

Uma nova sessão deve começar por `AGENTS.md` e `docs/00-START-HERE.md`, recuperar o estado real do GitHub e executar `docs/ai/NEXT_ACTION.md` conforme `docs/ai/WORK_PROTOCOL.md`.
