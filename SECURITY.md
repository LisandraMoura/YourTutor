# Política de Segurança

Obrigada por ajudar a manter este projeto seguro. Este documento explica como reportar uma vulnerabilidade **em privado**.

---

## Versões suportadas

Este projeto é um **protótipo em desenvolvimento** e ainda não tem release publicada. Não há versões antigas com suporte.

| Versão | Suporte |
|---|---|
| Último estado da branch `develop` | Sim |
| Qualquer outro commit, fork ou branch | Não |

---

## Como reportar

**Nunca abra uma issue pública para relatar uma vulnerabilidade.** Uma issue pública expõe a falha para todo mundo antes que exista correção.

Use o canal privado do próprio GitHub:

1. Acesse a aba **Security** do repositório.
2. Clique em **Report a vulnerability**.
3. Preencha o formulário.

O relato fica visível apenas para você e para a mantenedora, e permanece privado até que a correção esteja publicada.

> Se o botão **Report a vulnerability** não aparecer, o reporte privado ainda não foi habilitado nas configurações do repositório. Nesse caso, **não descreva a falha publicamente**: abra uma issue apenas dizendo que precisa de um canal privado para um assunto de segurança, sem nenhum detalhe técnico, e aguarde o contato.

---

## O que incluir no relato

- Descrição da vulnerabilidade e do impacto (o que uma pessoa mal-intencionada consegue fazer).
- Passos para reproduzir, ou uma prova de conceito.
- Commit, branch ou versão em que você observou o problema.
- Ambiente relevante (sistema operacional, versão do Docker, configuração fora do padrão).

### O que **nunca** incluir

Este é um projeto que lida com chaves de API, sessão de WhatsApp e conversas de pessoas reais. No relato, **jamais** inclua:

- Chave da OpenAI (`OPENAI_API_KEY`) ou qualquer outra credencial, sua ou de terceiros.
- Token ou arquivo de sessão do WPPConnect.
- Número de telefone real.
- Conteúdo de conversa de usuário real, transcrição ou áudio.

Se precisar demonstrar a falha com dados, **use dados fictícios**. Se a vulnerabilidade envolver um segredo que já vazou, diga apenas **onde** o segredo está exposto — não cole o valor dele.

---

## Prazos

- **Confirmação de recebimento:** até 7 dias, mesmo que seja só para avisar que a análise vai demorar.
- **Avaliação e correção:** conforme a severidade. Falha crítica tem prioridade sobre qualquer outra coisa do projeto.
- **Divulgação:** coordenada. A falha é tornada pública depois que a correção estiver disponível, com crédito para quem reportou — a menos que você prefira permanecer anônimo.

O projeto é mantido por uma pessoa; os prazos são o melhor esforço, não um SLA contratual.

---

## Escopo de interesse

Vale especialmente a pena reportar:

- Vazamento ou exposição de `OPENAI_API_KEY` ou de qualquer variável do `.env`.
- Vazamento do token ou da sessão do WPPConnect, que dá acesso à conta de WhatsApp pareada.
- Acesso indevido a dados de conversa, plano de estudo ou histórico de outro usuário.
- Áudio persistido em disco, cache ou volume — o projeto garante que nenhum áudio é armazenado; qualquer resíduo é uma falha de privacidade.
- Injeção de prompt que leve o sistema a expor configuração, segredo ou dados de outro usuário.
- Execução de código, path traversal ou escrita arbitrária de arquivo através do webhook ou do download de mídia.
- Segredo, número de telefone real ou dado pessoal encontrado no histórico do repositório.

### Fora de escopo

- O fato de a integração com o WhatsApp ser **não oficial** (WPPConnect) e o número pareado correr risco de bloqueio. Isso é uma limitação conhecida e declarada no `README.md`, não uma vulnerabilidade.
- O fato de o conteúdo das conversas ser processado pela API da OpenAI. Também é declarado, e é o desenho do produto.
- Vulnerabilidades em dependências de terceiros sem impacto demonstrável neste projeto — reporte-as ao projeto de origem.
- Resultado bruto de scanner automático, sem análise de impacto.

---

## Sem programa de recompensa

Não há **bug bounty** e não há pagamento por relatos. Este é um projeto pessoal e open source. O que oferecemos é resposta séria, correção e crédito público.
