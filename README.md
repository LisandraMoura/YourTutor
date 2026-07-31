# Tutor de Inglês no WhatsApp

Um tutor de inglês conversacional que vive dentro do WhatsApp. Você manda uma mensagem — de texto ou de voz — e conversa em inglês com um agente disponível a qualquer hora, que corrige seus erros e acompanha sua evolução.

> **Status:** protótipo em desenvolvimento. Ainda não é utilizável em produção.

---

## Por que existe

Aprender inglês trava na hora de conversar. Aula tem hora marcada, professor tem agenda, e a maioria das pessoas não tem com quem praticar sem constrangimento. A proposta aqui é simples: um interlocutor que está sempre disponível, no aplicativo que você já usa todo dia, que não julga e que corrige de forma didática — explicando **em português** por que aquilo soou errado em inglês.

Não é um chatbot genérico com um prompt de "seja um professor de inglês". O sistema mantém um plano de estudo por pessoa, trabalha um tópico por vez e só avança quando o tópico é praticado.

---

## Como funciona

```
diagnóstico → lista de conhecimento → lição de conversação (1 item por vez)
     ↑                                            |
     └────────────── lista concluída ─────────────┘
```

1. **Diagnóstico.** No primeiro contato, o tutor pergunta seu nível (A1 a C2) e registra.
2. **Lista de conhecimento.** A partir do nível, é gerada uma lista ordenada do que você precisa dominar — por exemplo, "Verbo To Be", "Present Simple", "Countable vs Uncountable".
3. **Lição.** O tutor pega **um** item e monta uma conversa real sobre ele. "Verbo To Be" vira uma conversa de apresentação pessoal. As perguntas vêm em inglês, por áudio e texto; você responde por áudio ou texto.
4. **Correção.** A cada resposta sua, chega uma mensagem em texto com o que saiu errado e como soaria mais natural — o exemplo em inglês, a explicação em português.
5. **Fechamento.** No fim da lição: pontos positivos, pontos a melhorar e um resumo do que foi estudado. O item é marcado como concluído e o plano atualizado chega para você acompanhar o progresso.
6. **Nível seguinte.** Quando a lista termina, o nível sobe e uma nova lista é gerada.

---

## Privacidade

**Nenhum áudio é armazenado.** O áudio que você envia é transcrito e o arquivo é apagado na mesma requisição. O áudio que o tutor envia é gerado, entregue e descartado. O que fica registrado é apenas texto — a transcrição e o histórico da conversa — necessário para o tutor lembrar do seu progresso.

O conteúdo das conversas é processado pela API da OpenAI.

---

## Subindo o projeto

**Pré-requisitos:** Docker, Docker Compose, `make` e uma chave de API da OpenAI.

```bash
cp .env.example .env      # preencha OPENAI_API_KEY e as demais variáveis
make up                   # sobe API, WPPConnect e Postgres
make qr                   # escaneie o QR code com o WhatsApp
```

Pronto. Mande uma mensagem para o número pareado.

Use um **número dedicado**, não o seu pessoal — a integração é não oficial e existe risco de bloqueio (ver [Limitações](#limitações)).

### Comandos disponíveis

| Comando | O que faz |
|---|---|
| `make up` / `make down` | Sobe / derruba os containers |
| `make logs` | Logs agregados |
| `make qr` | QR code para parear o WhatsApp |
| `make migrate` | Aplica migrações do banco |
| `make reset` | Zera banco e sessão |
| `make test` | Roda os testes |
| `make lint` | Lint e formatação |
| `make check` | Roda tudo que a CI roda |

---

## Configuração

Tudo é configurável pelo `.env` — modelo, temperatura, voz do TTS, número, limites da lição, credenciais do banco. Veja o `.env.example` para a lista completa.

Os prompts dos agentes ficam em `app/prompts/`, em arquivos versionados. Se você quer mudar o comportamento pedagógico do tutor, é lá — não precisa tocar em código.

---

## Arquitetura

```
WhatsApp
   │
   ▼
WPPConnect ──webhook──►  API  ──►  OpenAI (LLM · Whisper · TTS)
   ▲                      │
   └──── envio ───────────┤
                          ▼
                      Postgres
```

Três containers: `wppconnect` (conexão com o WhatsApp), `api` (orquestração dos agentes) e `postgres` (estado, planos e histórico).

Sete agentes dividem o trabalho: Orquestrador, Diagnóstico, Planejador, Designer de lição, Conversação, Corretor e Revisor. A especificação completa está em [`docs/requisitos.md`](docs/requisitos.md).

---

## Limitações

- **Não avalia proficiência.** O nível é declarado por você, e a progressão acontece ao concluir a lista — sem prova. É uma escolha consciente do protótipo.
- **Não analisa pronúncia.** O áudio é transcrito e só o texto é avaliado.
- **WPPConnect é uma integração não oficial** com o WhatsApp. Existe risco de bloqueio do número. Use um número dedicado.
- **Custo.** Cada mensagem envolve chamadas de STT, LLM e TTS. Em uso intenso, a conta da OpenAI cresce rápido.
- **Só inglês**, e só português como idioma de explicação.

---

## Contribuindo

Contribuições são bem-vindas de qualquer pessoa. O fluxo:

```
fork → branch → PR para develop → CI verde → review → merge
```

Todo merge passa pela revisão da mantenedora. `main` e `develop` são protegidas.

Os testes rodam **sem chave da OpenAI** — a camada de LLM tem uma implementação `fake` para testes. Você não precisa gastar dinheiro para contribuir.

Antes de abrir um PR, leia o [`CONTRIBUTING.md`](CONTRIBUTING.md). Mudanças de arquitetura ou de comportamento pedagógico precisam de uma issue com discussão antes do código.

Boas portas de entrada: melhorar os prompts em `app/prompts/`, aumentar a cobertura de testes, ou pegar uma issue marcada como `good first issue`.

---

## Licença

_A definir._