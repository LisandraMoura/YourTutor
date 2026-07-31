# CLAUDE.md

Instruções para agentes Claude que trabalham neste repositório. Leia antes de qualquer alteração.

---

## O que é este projeto

Tutor de inglês conversacional que roda dentro do WhatsApp. O usuário manda texto ou áudio, o tutor responde com áudio + texto e conduz um ciclo pedagógico contínuo:

```
diagnóstico → lista de conhecimento → lição de conversação (1 item por vez)
     ↑                                            |
     └────────────── lista concluída ─────────────┘
```

A especificação completa está em `docs/requisitos.md`. **Em caso de conflito entre este arquivo e a especificação, a especificação vence** — e avise sobre a divergência em vez de escolher silenciosamente.

---

## Stack

| Camada | Tecnologia |
|---|---|
| Linguagem | Python + `uv` |
| Lint/format | `ruff` |
| Testes | `pytest` |
| WhatsApp | WPPConnect (não oficial, pareamento por QR) |
| LLM / STT / TTS | API da OpenAI, **exclusivamente** |
| Banco | Postgres |
| Orquestração | Docker Compose + Makefile |

---

## Comandos

Use sempre o `make`, nunca comandos soltos de docker/uv:

```bash
make up          # sobe todos os containers
make down        # derruba tudo
make logs        # logs agregados
make qr          # exibe o QR code para parear o WhatsApp
make migrate     # aplica migrações
make reset       # zera banco e sessão
make test        # suíte de testes
make lint        # lint + formatação
make check       # reproduz localmente exatamente o que a CI roda
```

Antes de considerar qualquer tarefa concluída: `make check` precisa passar.

---

## Mapa do repositório

```
app/
├── config.py          # carregamento do .env — TODA configuração passa por aqui
├── webhook/           # recebimento de mensagens do WPPConnect
├── orchestrator/      # máquina de estados do usuário (§4 da spec)
├── agents/            # um módulo por agente (§5 da spec)
├── prompts/           # prompts em arquivos versionados, NUNCA no código
├── llm/               # interface + implementação OpenAI + implementação fake
├── whatsapp/          # cliente WPPConnect (envio, download de mídia)
├── audio/             # STT, TTS, conversão ffmpeg, ciclo de vida do arquivo temporário
└── db/                # modelos, migrações, repositórios
tests/
docs/requisitos.md     # especificação — fonte da verdade
```

**Onde mexer para cada tipo de mudança:**

| Mudança | Lugar |
|---|---|
| Comportamento pedagógico de um agente | `app/prompts/` (não o código) |
| Novo estado ou transição do usuário | `app/orchestrator/` + migração |
| Novo campo persistido | `app/db/` + migração + spec §8 |
| Nova configuração | `app/config.py` + `.env.example` + spec §9 |
| Formato de áudio, conversão | `app/audio/` |

---

## Regras invioláveis

1. **Nunca faça commit nem push.** Prepare a alteração e o texto do PR; a decisão de commitar é da mantenedora.
2. **Nunca armazene áudio.** Áudio de entrada é baixado, transcrito e apagado na mesma requisição (bloco `finally`, inclusive em erro). Áudio de saída é gerado, enviado e apagado. Sem cache de TTS, sem volume de mídia. O que persiste é sempre texto.
3. **Nunca hardcode prompt.** Todo prompt vive em `app/prompts/`, versionado. É a parte que mais recebe contribuição da comunidade.
4. **Os testes rodam sem chave da OpenAI.** A camada `llm/` é uma interface com implementação `fake`. Qualquer teste novo que exija chave real está errado — quebra a contribuição externa.
5. **Nenhum segredo no repositório.** Nem chave, nem token de sessão, nem número de telefone real. `.env` está no `.gitignore`; atualize sempre o `.env.example`.
6. **Nenhuma configuração hardcoded.** Modelo, temperatura, número, limites de turno — tudo vem do `.env` via `config.py`.
7. **Nenhuma dependência nova sem perguntar antes.** O projeto é deliberadamente enxuto.
8. **Não use outro provedor de LLM.** A decisão de ficar só na OpenAI é do projeto, não uma limitação temporária.
9. **Escopo:** implemente apenas o que a issue pede. Melhoria fora do escopo vira issue nova, não entra no PR.

---

## Convenções

- **Commits:** Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`).
- **Branches:** a partir de `develop`, nomeadas `<tipo>/<numero-issue>-<slug>`. `main` e `develop` são protegidas.
- **PR:** um PR = uma issue = um propósito. PR sem issue vinculada é recusado.
- **Idioma:** código, nomes de variáveis e docstrings em **inglês**; documentação de usuário e issues em **português**.
- **Estilo:** não discuta formatação — `ruff` decide.

---

## Glossário do domínio

Use estes termos com precisão; eles têm significado específico aqui.

| Termo | Significado |
|---|---|
| **Item de conhecimento** | Uma unidade da lista de estudo do nível (ex.: "Verbo To Be"). Tem status `pending`/`in_progress`/`done`. |
| **Lista de conhecimento** (plano) | O conjunto ordenado de itens do nível atual do usuário. Gerada pelo agente Planejador. |
| **Lição** | Uma conversa completa sobre **um** item de conhecimento. |
| **Perguntas-âncora** | Até 6 perguntas pré-definidas pelo Designer de lição; o agente de Conversação as adapta ao contexto, mas não as multiplica. |
| **Turno** | Um par mensagem-do-tutor / mensagem-do-usuário. Limitado por `MAX_TURNS_PER_LESSON`. |
| **Correção pontual** | Feedback em texto após cada mensagem do usuário, separado da fala do tutor. |
| **Fechamento** | Análise final da lição: pontos positivos, pontos a melhorar e resumo conceitual. |

---

## Regras de idioma do produto

Não confunda com o idioma do código. Dentro da conversa com o usuário:

| Situação | Formato | Idioma |
|---|---|---|
| Saudação, diagnóstico, plano, progresso | Texto | Português |
| Fala do tutor durante a lição | **Áudio + texto** | Inglês |
| Correção pontual | Texto | Exemplo em inglês + explicação em português |
| Fechamento da lição | Texto | Português, com os conceitos em inglês |

O texto que acompanha o áudio é a transcrição **literal** do que foi falado — ele existe para quando o usuário não entende o áudio.

---

## Armadilhas conhecidas

- **Whisper é STT, não TTS.** Entrada de áudio → Whisper. Saída de texto → modelo de TTS. São chamadas diferentes.
- **Áudio do WhatsApp precisa ser OGG/Opus** para virar mensagem de voz (PTT). A saída do TTS da OpenAI precisa passar por `ffmpeg`, senão chega como arquivo anexado.
- **Webhooks repetem.** Toda mensagem recebida é idempotente por `wa_message_id`.
- **Mensagens do mesmo usuário são processadas em série.** Processamento concorrente corrompe a máquina de estados.
- **O agente de Conversação nunca corrige dentro da fala em inglês.** Correção é do agente Corretor, em mensagem separada.
- **A sessão do WPPConnect vive em volume persistente.** Apagar o volume força novo QR code.

---

## Antes de abrir um PR

- [ ] `make check` passa
- [ ] Nenhum segredo, número real ou áudio versionado
- [ ] `.env.example` atualizado se houve nova configuração
- [ ] `docs/requisitos.md` atualizado se o comportamento mudou
- [ ] Testes rodam sem chave da OpenAI
- [ ] Issue vinculada e escopo respeitado