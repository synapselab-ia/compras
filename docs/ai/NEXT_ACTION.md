# Next Action — Compras

## F05-DB-CORE-SCHEMA-01 — Primeira migration do núcleo e RLS default-deny

**Classe:** `T2 — banco/segurança`  
**Estado:** READY  
**Objetivo:** transformar o desenho aprovado de persistência em schema PostgreSQL reproduzível e testes adversariais, mantendo o sistema sem banco hospedado, sem Auth real e sem policy permissiva improvisada.

## Fonte da tarefa

Executar conforme `tasks/F05-DB-CORE-SCHEMA-01/SPEC.md`.

## Resultado esperado

Ao final, o repositório deve possuir:

- `database/migrations/0001_core_foundation.sql`;
- testes SQL reproduzíveis em PostgreSQL descartável;
- tabelas `teams`, `app_users`, `memberships`, `contractings`, `related_identifiers`, `contracting_items` e `contracting_events` conforme `DATABASE.md`;
- FKs/constraints compostas que impeçam relações cross-team/cross-contracting relevantes;
- índices mínimos para Central/detalhe;
- RLS habilitada em default-deny, sem policy permissiva dependente de Auth inexistente;
- CI capaz de subir PostgreSQL efêmero, aplicar migration e executar os testes de banco;
- gates atuais da aplicação continuando PASS.

## Regras obrigatórias

- não provisionar Neon, Supabase, Vercel ou qualquer banco externo;
- não introduzir secret, JWT ou conexão real;
- não conectar a UI ao banco nesta slice;
- não implementar Auth real nem aceitar `user_id`/`team_id` fornecido pelo cliente como identidade;
- não criar `role` de membership enquanto Q-009 estiver aberta;
- não criar PostgreSQL `ENUM` para etapa/status/tipos abertos;
- não inventar constraint quantitativa de item;
- não adicionar Pendência, pesquisa de preços, documentos, importação ou módulos futuros;
- usar apenas dados artificiais e sanitizados;
- owner/BYPASSRLS não pode ser usado como prova de autorização;
- migration aplicada passa a ser história imutável; correções futuras usam nova migration.

## Segurança mínima a provar

- papel operacional de teste sem policy permissiva não lê linha interna mesmo conhecendo UUID válido;
- o mesmo papel não insere/altera/exclui por ausência de policy permissiva;
- responsável de outra equipe é rejeitado pela integridade referencial;
- item/identificador/evento não pode ser ligado a contratação de outro escopo;
- evento não pode apontar subentidade pertencente a outra contratação/equipe;
- eventos permanecem imutáveis para o papel operacional.

## Fora do escopo

Não:

- policy de leitura para membro autorizado;
- claims/JWT/provider Auth;
- CRUD persistente da aplicação;
- RPC/serviço de mutação;
- banco hospedado;
- dados reais;
- pesquisa de preços;
- deploy.

## Critério de encerramento

A tarefa termina quando migration + testes de banco passam em PostgreSQL descartável e CI, o diff passa red-team de integridade/RLS/dados públicos, e o checkpoint deixa exatamente uma nova `NEXT_ACTION` pequena e executável.
