# F05-DB-CORE-SCHEMA-01 — Primeira migration do núcleo e RLS default-deny

**Classe:** T2 — banco/segurança  
**Estado:** READY  
**Dependência:** F04-PERSISTENCE-FOUNDATION-DESIGN-01 concluída  
**Classificação dos dados permitidos:** PUBLIC / FICTITIOUS ONLY

## 1. Problema

O contrato de persistência está desenhado, mas ainda não existe schema executável. A próxima slice deve transformar apenas o núcleo aprovado em migration reproduzível e testes de banco, sem conectar a aplicação a provedor externo ou abrir acesso antes de existir identidade confiável.

## 2. Resultado esperado

Criar a primeira fundação executável de PostgreSQL em:

```text
database/
├── migrations/
│   └── 0001_core_foundation.sql
└── tests/
    └── ...
```

A migration deve implementar, de forma coerente com `docs/architecture/DATABASE.md` e ADR-002:

- `teams`;
- `app_users` com identidade externa composta por issuer + subject, sem email como chave de segurança;
- `memberships`;
- `contractings`;
- `related_identifiers`;
- `contracting_items`;
- `contracting_events`;
- UUIDs/chaves/constraints/FKs compostas de mesmo escopo;
- índices mínimos justificados pelas consultas atuais;
- timestamps de arquivamento/revogação/desvínculo/retirada previstos no desenho;
- RLS habilitada/default-deny nas tabelas internas previstas para acesso operacional;
- papel criado somente nos testes para exercitar RLS sem privilégios administrativos;
- imutabilidade operacional de eventos por grants/policies compatíveis com a fundação.

## 3. Testes obrigatórios

Usar PostgreSQL descartável em CI, sem Neon/Supabase/Vercel e sem dados reais.

A suíte deve provar ao menos:

- schema cria do zero;
- migrations rodam em banco vazio;
- membership de outra equipe não pode ser usada como responsável de uma contratação;
- cardinalidade N de identificadores relacionados funciona;
- ordinal duplicado dentro da mesma contratação é rejeitado;
- FK de equipe/contratação impede item/identificador/evento cruzado entre equipes;
- evento não consegue apontar item ou identificador de outra contratação/equipe;
- papel operacional de teste, mesmo recebendo grants necessários para exercitar a policy, não consegue ler linhas internas sem policy permissiva, ainda que conheça UUID válido;
- o mesmo papel não consegue inserir/alterar/excluir linhas pela ausência de policy permissiva;
- eventos não podem ser alterados/excluídos pelo papel operacional;
- dados de teste são exclusivamente artificiais.

Não criar assertions de quantidade positiva, faixa ou precisão máxima sem regra de negócio aprovada.

Preferir SQL reproduzível e simples. Não adicionar framework de banco se assertions SQL/psql forem suficientes.

## 4. CI

Integrar a verificação de banco à CI atual de forma independente da aplicação.

Requisitos:

- PostgreSQL efêmero/service container ou mecanismo equivalente gratuito do runner;
- aplicar migration a partir do repositório;
- executar testes SQL;
- não usar secrets externos;
- não publicar dumps/artifacts com dados operacionais;
- manter os gates existentes de `npm ci`, lint, typecheck, testes e build.

## 5. Regras obrigatórias

- não provisionar banco hospedado;
- não conectar UI ao banco;
- não implementar Auth real;
- não criar política permissiva baseada em `user_id`/`team_id` fornecido pelo cliente;
- não criar `role` de membership enquanto Q-009 estiver aberta;
- não usar PostgreSQL `ENUM` para etapa/status/tipos abertos;
- não criar catálogos finais de workflow;
- não adicionar Pendência, pesquisa de preços, documentos ou módulos futuros;
- não usar `jsonb` genérico no núcleo;
- não adicionar constraint quantitativa de item sem fonte aprovada;
- não adicionar dados/números/nomes reais;
- migration aplicada nesta work unit passa a ser história imutável; correções posteriores usam nova migration.

## 6. Decisões técnicas permitidas

A slice pode escolher defaults PostgreSQL pequenos e portáveis necessários à execução, desde que não mudem semântica de produto.

Se geração de UUID exigir extensão específica, preferir manter IDs sem default e inserir UUIDs artificiais pela aplicação/testes a acoplar o schema a uma extensão sem necessidade.

Exato mecanismo de identidade corrente para policies permissivas permanece fora do escopo.

O papel de migration/owner deve permanecer distinto do papel usado para testar acesso operacional; owner/BYPASSRLS não pode ser usado como prova de segurança.

## 7. Open Questions preservadas

Não fechar:

- Q-001 etapas;
- Q-002 status;
- Q-003 tipos de identificadores/processos;
- Q-004 regra ±25%;
- Q-005 inatividade;
- Q-006 Pendência;
- Q-009 permissões multiusuário;
- Q-010 auditoria de leitura.

## 8. Red-team obrigatório

Antes de promover:

- tentar relações cross-team por todas as FKs relevantes;
- tentar evento referenciando subentidade de outra contratação;
- tentar acesso com UUID conhecido usando o papel operacional de teste;
- procurar `GRANT` de produção amplo ou policy `USING (true)` indevida;
- procurar tabela interna sem RLS quando o desenho exigir proteção;
- confirmar que policy inexistente resulta em deny real de RLS, não apenas em ausência de grant;
- confirmar que owner/admin usado para migration não é usado como prova de autorização;
- procurar enum/lista fechada que resolva open question;
- procurar regra quantitativa inventada;
- procurar DELETE destrutivo como fluxo normal;
- revisar fixtures/logs por aparência de dado real;
- revisar migration completa e CI.

## 9. Gates

Obrigatórios:

- migration aplicada em PostgreSQL descartável: PASS;
- testes de banco: PASS;
- `npm ci`: PASS;
- `npm run lint`: PASS;
- `npm run typecheck`: PASS;
- `npm test`: PASS;
- `npm run build`: PASS;
- CI: PASS;
- red-team: PASS;
- nenhum dado real/secret no diff.

## 10. Fora do escopo

- Auth/claims/JWT reais;
- policy de leitura para membership autorizada;
- CRUD da aplicação;
- servidor/RPC de mutação;
- banco hospedado;
- migrations de pesquisa de preços;
- importação;
- deploy.

## 11. Critério de encerramento

A tarefa termina quando a primeira migration e testes estiverem reproduzíveis em CI, o banco estiver seguro por default sem identidade permissiva improvisada, o diff tiver sido red-teamado e existir exatamente uma nova `NEXT_ACTION` para integrar identidade/autorização ou outra menor decisão bloqueante descoberta pela implementação.
