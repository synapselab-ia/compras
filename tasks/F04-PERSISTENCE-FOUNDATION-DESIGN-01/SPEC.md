# F04-PERSISTENCE-FOUNDATION-DESIGN-01 — Fundação de persistência segura

**Classe:** T2 — banco/segurança/design  
**Estado:** READY  
**Dependência:** F03-CONTRATACAO-DETAIL-PROTOTYPE-01 concluída  
**Classificação dos dados permitidos:** PUBLIC / SANITIZED DESIGN ONLY

## 1. Problema

As jornadas principais de leitura já existem como protótipo, mas o produto ainda usa dados estáticos. Criar migrations ou conectar um provedor antes de definir o contrato mínimo de persistência aumentaria o risco de congelar taxonomias abertas, acoplar segurança à UI ou criar schema guiado por conveniência técnica em vez do domínio.

A próxima incerteza é estrutural: quais dados precisam persistir para sustentar Central, detalhe, responsabilidade operacional e histórico sem resolver prematuramente questões ainda abertas.

## 2. Resultado esperado

Produzir o desenho canônico da primeira persistência operacional, sem provisionar infraestrutura externa.

Criar `docs/architecture/DATABASE.md` cobrindo no mínimo:

- entidades/tabelas candidatas do núcleo;
- chaves internas estáveis;
- cardinalidades e foreign keys;
- constraints/invariantes que já são sustentadas pelas fontes;
- estratégia para etapa/status enquanto Q-001/Q-002 estiverem abertas;
- múltiplos identificadores relacionados sem fechar Q-003;
- usuário versus membership/autorização;
- responsável interno, aguardando, próxima ação e timestamps relevantes;
- eventos/timeline e preservação de histórico;
- arquivamento/cancelamento sem exclusão silenciosa;
- índices necessários às consultas da Central e detalhe;
- estratégia inicial de RLS/deny-by-default;
- padrão de migrations e testes de banco;
- dados/classificações proibidos em logs e fixtures públicas.

Se uma decisão estrutural relevante for fechada, registrar ADR apropriado. Se a evidência não permitir decidir, manter como open question ou decisão adiada explicitamente.

## 3. Fontes obrigatórias

Ler diretamente:

- `docs/product/PROJECT_DESIGN.md`;
- `docs/product/DOMAIN_MODEL.md`;
- `docs/product/OPEN_QUESTIONS.md`;
- `docs/architecture/ARCHITECTURE.md`;
- `docs/architecture/SECURITY.md`;
- `docs/qa/DEFINITION_OF_DONE.md`;
- código das jornadas Central/detalhe apenas na medida necessária para validar consultas e campos efetivamente usados.

Como é tarefa T2, segurança é parte do desenho, não revisão posterior.

## 4. Regras de modelagem

- `Contratação` permanece a raiz operacional, não um número de processo isolado;
- uma contratação pode possuir múltiplos identificadores relacionados;
- `responsável_interno`, `aguardando` e `proxima_acao` são conceitos distintos;
- fatos históricos não podem depender apenas do estado atual da linha;
- mudança relevante deve ser representável em timeline/auditoria;
- IDs internos não devem depender de números administrativos externos;
- não usar enum físico irreversível para taxonomias ainda abertas sem justificativa forte;
- não exigir exclusão física para arquivamento/cancelamento;
- autorização deve ser aplicável no banco/servidor e negar por padrão;
- o piloto individual não autoriza schema acoplado a um único usuário;
- RLS futura deve conseguir diferenciar usuário autenticado de membership autorizado;
- evitar `jsonb` genérico como substituto do modelo relacional para o núcleo;
- evitar tabelas/abstrações futuras sem consulta ou invariantes concretos que as justifiquem.

## 5. Segurança

Enquanto o repositório estiver público:

- nenhum dado real, nome real, processo real, valor, documento, CNPJ, caminho interno ou secret;
- exemplos de SQL/documentação usam somente IDs artificiais como UUIDs fictícios ou `DEMO-*`;
- nenhum token/JWT real em testes ou documentação;
- logs de auditoria devem ser desenhados para registrar ação/metadado necessário sem duplicar conteúdo sensível;
- leituras adversariais devem fazer parte do plano de teste futuro: anônimo, autenticado sem membership, membro autorizado e tentativa com ID conhecido de outro escopo.

## 6. Relação com provedores externos

Não selecionar comportamento de Neon/Auth/Data API por memória.

Se o desenho depender de detalhe específico de um provedor, consultar documentação oficial atual e distinguir claramente:

- requisito do produto/PostgreSQL;
- decisão arquitetural nossa;
- comportamento específico do provedor.

Não provisionar conta, projeto, banco, branch ou secret nesta work unit.

## 7. Open Questions preservadas

Não fechar por conveniência:

- Q-001 — taxonomia final de etapas;
- Q-002 — taxonomia final de status;
- Q-003 — semântica final dos tipos de processos/identificadores relacionados;
- Q-004 — regra de ±25%;
- Q-005 — limites de inatividade;
- Q-006 — quando próxima ação vira Pendência;
- Q-009 — política final de permissões multiusuário;
- Q-010 — necessidade/retenção de auditoria de leitura.

O schema pode reservar caminhos evolutivos, mas não fingir que essas respostas já existem.

## 8. Fora do escopo

- migrations aplicadas;
- banco hospedado;
- conexão externa;
- Auth real;
- secrets;
- CRUD persistente;
- importação de planilhas;
- dados reais;
- pesquisa de preços;
- documentos;
- deploy.

## 9. Red-team obrigatório

Antes de concluir:

- procurar relações 1:1 indevidamente impostas onde o domínio exige cardinalidade maior;
- procurar perda de histórico por sobrescrita destrutiva;
- procurar autorização dependente apenas da UI;
- procurar possibilidade de acesso por usuário autenticado sem membership;
- procurar taxonomias abertas congeladas por enum/schema prematuro;
- procurar uso de texto livre onde referência estruturada já é invariável;
- procurar duplicação desnecessária entre estado atual e eventos;
- procurar `jsonb` usado para evitar decisões relacionais já suportadas pelas fontes;
- procurar acoplamento a provedor sem necessidade;
- procurar exemplos que possam ter aparência de dado real/sensível.

## 10. Verificação

Esta work unit é primariamente documental/arquitetural.

Obrigatório:

- coerência cruzada com produto, domínio, segurança e open questions: PASS;
- red-team estrutural e de segurança: PASS;
- `CONTEXT_MANIFEST` atualizado se qualquer input estável for alterado;
- lint/typecheck/test/build somente se código/configuração executável for alterado; caso contrário registrar `SKIPPED` honestamente;
- deixar exatamente uma `NEXT_ACTION` para a primeira implementação de banco/migrations/testes.
