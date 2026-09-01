# Compras

Sistema em desenvolvimento para organizar fluxos de contratações públicas, centralizar acompanhamento operacional e reduzir controles fragmentados.

## Estado atual

A **F01 — Fundação Executável** foi concluída e validada. O projeto está agora em **F02 — Central do Setor Prototype**.

A aplicação possui uma base mínima executável e reproduzível, mas ainda não possui banco, autenticação, integração externa, deploy operacional ou dados reais. O repositório continua público e somente conteúdo sanitizado/fictício pode ser publicado.

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
- CSS global mínimo, sem design system prematuro;
- ESLint com `eslint-config-next`;
- Vitest para testes unitários;
- GitHub Actions com instalação reproduzível por `npm ci`.

## Segurança desta fase

Nenhum secret é necessário para instalar, testar ou compilar a aplicação. Não use dados reais, documentos internos ou informações pré-publicação em código, fixtures, Issues, PRs, logs ou artifacts enquanto o repositório estiver público.

A ausência de autenticação nesta fase significa que **nenhum dado operacional real é permitido**. O próximo protótipo usa apenas registros artificiais e explicitamente demonstrativos.

## Continuidade por IA

Uma nova sessão deve começar por `AGENTS.md` e `docs/00-START-HERE.md`, recuperar o estado real do GitHub e executar `docs/ai/NEXT_ACTION.md` conforme `docs/ai/WORK_PROTOCOL.md`.
