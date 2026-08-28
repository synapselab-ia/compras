# Security Baseline — Compras

**Versão:** 0.1  
**Status:** requisito estrutural

## 1. Princípio

Informações de contratações antes da publicação podem ser sensíveis. O produto adota `deny by default`.

Sem autorização explícita, o resultado esperado é nenhum dado interno.

## 2. Classificação de dados

### PUBLIC

Informação já pública por fonte oficial ou deliberadamente publicada.

Exemplos: dados de portais públicos, catálogos oficiais, contratações já publicadas.

### INTERNAL

Informação operacional não destinada à publicação aberta.

Exemplos: estado de trabalho, responsável, pendências, notas operacionais.

### SENSITIVE_PRE_PUBLICATION

Informação que pode afetar confidencialidade, integridade do procedimento, competição ou estratégia antes da publicação oficial.

Exemplos conceituais: itens/quantidades/estimativas ainda internas, pesquisa em elaboração e documentos preparatórios não públicos.

A classificação concreta deve ser refinada com governança institucional antes de produção.

## 3. Regra do repositório público

Enquanto este repositório estiver público, considerar qualquer commit permanentemente divulgável.

Não versionar dados `INTERNAL` reais nem `SENSITIVE_PRE_PUBLICATION`.

Tornar o repositório privado posteriormente não revoga clones, forks ou cópias feitas enquanto público.

## 4. Autenticação

- toda área operacional interna exige autenticação;
- não existe signup público como comportamento padrão;
- novos membros entram por mecanismo administrativo/convite controlado;
- MFA deve ser avaliada como requisito antes de uso institucional com dados sensíveis;
- sessões devem usar mecanismos seguros do provedor escolhido.

## 5. Autorização

Autorização deve existir no enforcement real:

- servidor;
- banco/RLS quando aplicável;
- funções/RPCs/gateways transacionais.

Nunca considerar `botão escondido` ou `rota não linkada` como controle de acesso.

Cenários adversariais mínimos para testes futuros:

- não autenticado;
- autenticado autorizado;
- autenticado sem membership;
- usuário conhecendo ID de registro fora de seu escopo;
- tentativa de forjar `user_id`, `organization_id` ou equivalente;
- tentativa de alterar ownership/escopo;
- acesso direto a endpoint sem passar pela UI.

## 6. RLS

Tabelas internas expostas por Data API devem nascer com RLS adequada.

Preferência de implantação:

1. tabela/constraints;
2. RLS habilitada;
3. políticas mínimas;
4. grants estritos;
5. testes owner/non-owner/anonymous;
6. somente então integração normal da UI.

Conta/role com `BYPASSRLS` é administrativa, não prova autorização do usuário normal.

## 7. Secrets

É proibido versionar ou expor em browser/logs/documentação:

- senhas;
- tokens;
- private keys;
- connection strings;
- credenciais privilegiadas;
- secrets de APIs.

Variáveis públicas precisam ser tecnicamente seguras para exposição. Prefixo público não torna segredo seguro.

## 8. URLs e metadados

Evitar conteúdo sensível em slugs/URLs, query strings e títulos de página quando um identificador opaco satisfizer a navegação.

UUID/ID opaco reduz vazamento acidental de metadados, mas nunca substitui autorização.

## 9. Logs e analytics

Logs devem ser minimizados e estruturados para operação/segurança.

Não registrar corpo completo de documentos ou payloads sensíveis sem necessidade explícita.

Ferramentas externas de analytics/session replay não entram por padrão em áreas internas. Qualquer adoção exige avaliação do que é coletado e enviado.

## 10. Ambientes

### Desenvolvimento

- dados fictícios;
- banco/branch separado;
- nenhum documento interno real para conveniência.

### Preview/Staging

- dados fictícios ou anonimizados;
- secrets próprios;
- nenhuma cópia informal de produção.

### Produção

- dados reais apenas após revisão formal de infraestrutura, autorização, backup, logs, retenção e conformidade.

## 11. Integrações externas e IA

Integrações com fontes públicas podem receber parâmetros mínimos necessários à consulta.

Conteúdo `SENSITIVE_PRE_PUBLICATION` não pode ser enviado a provedor externo de IA, analytics ou integração genérica sem:

- finalidade explícita;
- decisão documentada;
- avaliação de privacidade/retenção;
- minimização de dados;
- autorização compatível com a governança aplicável.

IA nunca é fonte canônica e não altera silenciosamente registros internos.

## 12. Auditoria

Alterações relevantes devem registrar ator, horário, tipo de evento e referência ao registro alterado.

Auditoria de leitura de dados sensíveis permanece questão aberta e deve considerar utilidade, custo, privacidade e retenção.

## 13. Exclusão e histórico

Para registros operacionais relevantes, preferir estados como arquivado/cancelado e eventos de reversão a exclusão física silenciosa.

Exclusão permanente, quando necessária, deve possuir regra explícita e não destruir evidência exigida por auditoria/negócio.

## 14. Falha segura

Se autorização, provedor externo ou estado da fonte não puder ser verificado com segurança, falhar fechado e informar indisponibilidade. Não ampliar acesso nem apresentar dado potencialmente incorreto apenas para manter a interface funcionando.
