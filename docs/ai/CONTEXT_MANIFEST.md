# Context Manifest — Compras

`CONTEXT_SCHEMA = 1`

## 1. Propósito

Este arquivo compila o contexto estável necessário para retomada rápida por IA.

Ele não substitui as fontes detalhadas. Seu fast path é válido somente enquanto os blobs listados em `INPUT_MANIFEST` continuarem iguais.

`AGENTS.md`, `docs/00-START-HERE.md`, `CURRENT_STATE.md` e `NEXT_ACTION.md` são lidos ao vivo e não fazem parte do cache estável.

## 2. INPUT_MANIFEST

| Fonte canônica | Blob esperado |
|---|---|
| `docs/product/PROJECT_DESIGN.md` | `9f28a371e04ecdce8f2689a6c06b00beeaa25859` |
| `docs/product/DOMAIN_MODEL.md` | `13d7352cffb68273a26d142bee1165557d7eb864` |
| `docs/product/BUSINESS_WORKFLOW.md` | `f8fc35aaf8cdd5334591c2402921e6776afd2f4b` |
| `docs/product/OPEN_QUESTIONS.md` | `145ef9fe301d5c35ad9455d04be5740dbba36a13` |
| `docs/architecture/ARCHITECTURE.md` | `a7544848c1eefcc54ec4537d3951e6b3559619d7` |
| `docs/architecture/SECURITY.md` | `d8e65b514f53772af854be87c08f79e037432ade` |
| `docs/qa/DEFINITION_OF_DONE.md` | `cd0e3d1f01333c418d4fb622940f908df2b87a57` |
| `docs/ai/SOURCE_OF_TRUTH.md` | `dca5ef489d0fd32e70f3e157550c6b1eaed5e476` |
| `docs/ai/WORK_PROTOCOL.md` | `c53df5afa42297a1501fbb7b666f0539f91af918` |

## 3. Validação

Antes de edição substantiva:

1. obter os blobs atuais dos inputs acima;
2. comparar com o manifest;
3. se todos coincidirem: `CONTEXT_STATUS = VALID`;
4. se houver divergência: `CONTEXT_STATUS = INVALID`;
5. abrir somente os inputs divergentes e dependências necessárias;
6. reconciliar e recompilar este manifest antes de continuar.

## 4. Digest estável

### Produto

- sistema operacional para acompanhar contratações públicas, não substituto de sistemas oficiais;
- `Contratação` é a entidade central;
- Central do Setor deve responder quem está fazendo o quê e o que precisa acontecer agora;
- etapa, status, responsável, aguardando e próxima ação são conceitos distintos;
- timeline preserva fatos relevantes;
- primeira versão prioriza substituir controles fragmentados antes de automações avançadas.

### Domínio

- uma contratação pode relacionar múltiplos processos/identificadores;
- itens pertencem à contratação e podem possuir pesquisa própria;
- usuário autenticado e membership/autorização são separados conceitualmente;
- mudança relevante deve ser rastreável;
- arquivamento/cancelamento não apaga histórico;
- evidência de preço escolhida deve preservar proveniência e snapshot histórico.

### Pesquisa pública

- preferir consulta federada a APIs oficiais a espelhamento integral de grandes bases;
- cache externo pode ser efêmero;
- persistir principalmente referências efetivamente selecionadas;
- ranking inicial deve ser determinístico e explicável;
- resultado externo não vira automaticamente verdade interna.

### Segurança

- dados internos privados por padrão;
- classificação `PUBLIC`, `INTERNAL`, `SENSITIVE_PRE_PUBLICATION`;
- enquanto o repo for público, não versionar dados internos reais nem sensíveis;
- autenticação obrigatória para operação interna;
- sem signup público por padrão;
- autorização server/database, não apenas UI;
- RLS para dados internos expostos por Data API;
- secrets nunca no repositório/browser;
- conteúdo sensível não sai para serviço externo sem decisão explícita;
- desenvolvimento usa dados fictícios/sanitizados.

### Desenvolvimento por IA

- GitHub canônico; chat descartável;
- uma `NEXT_ACTION` por sessão;
- ciclo `RECOVER → CLASSIFY → INSPECT → BOUND → IMPLEMENT → RED TEAM → VERIFY → PROMOTE → CHECKPOINT → REPORT`;
- não inventar requisitos;
- dúvida real vira open question/decisão necessária;
- uma work unit pequena e verificável por vez;
- segurança não é enfraquecida para passar teste;
- conclusão exige evidência real e continuidade documentada.

## 5. Classes de tarefa

- `T0`: descoberta/produto;
- `T1`: feature normal;
- `T2`: banco/segurança;
- `T3`: integração externa;
- `T4`: bug;
- `T5`: arquitetura/refatoração;
- `T6`: consulta/status read-only.

## 6. Regra de incerteza

Manifest válido reduz releitura redundante, não a investigação necessária.

Conflito, ambiguidade, mudança de fonte, questão de segurança ou necessidade de detalhe exato expande o conjunto de leitura.
