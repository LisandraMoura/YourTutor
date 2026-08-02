# Documento de Requisitos — Tutor de Inglês por WhatsApp

**Versão:** 0.2
**Data:** 31/07/2026
**Status:** em construção — ver §12 (decisões pendentes)

**Mudanças na 0.2:** áudio não é armazenado (§7.4); adicionada governança de contribuição open source (§14).

---

## 1. Visão geral

Um tutor de inglês conversacional acessível pelo WhatsApp, disponível 24/7. O usuário fala (áudio ou texto) e recebe de volta áudio + texto. O sistema mantém o estado de aprendizado da pessoa em banco e conduz um ciclo pedagógico contínuo:

```
diagnóstico → lista de conhecimento → conversação (1 item por vez)
     ↑                                          |
     └──────── lista concluída ─────────────────┘
```

**Objetivo do protótipo:** validar o loop pedagógico e a experiência no WhatsApp com o mínimo de infraestrutura. Não é objetivo, nesta versão, avaliar proficiência com rigor.

---

## 2. Escopo

### 2.1 Dentro do escopo (protótipo)

| # | Item |
|---|---|
| E1 | Recebimento de mensagens de texto e áudio via WPPConnect |
| E2 | Transcrição de áudio de entrada (STT) |
| E3 | Diagnóstico declarado: o usuário informa o nível (A1–C2), sem avaliação |
| E4 | Geração automática da lista de conhecimento do nível |
| E5 | Aula de conversação item a item, com limite de turnos |
| E6 | Correção pontual a cada mensagem do usuário |
| E7 | Fechamento de lição com análise + resumo conceitual |
| E8 | Progressão automática de nível ao concluir a lista |
| E9 | Envio de áudio (TTS) + texto de apoio nas lições |
| E10 | Subida completa com `docker compose` + `make` |
| E11 | Configuração integral via `.env` |

### 2.2 Fora do escopo (protótipo)

- Avaliação real de proficiência / prova de nível
- Múltiplos idiomas de estudo (só inglês)
- Painel web / dashboard de acompanhamento
- Pagamento, autenticação, multi-tenant
- Análise de pronúncia a partir do áudio (só o texto transcrito é avaliado)
- **Armazenamento de mídia** — nenhum áudio é persistido (ver §7.4)

---

## 3. Arquitetura

### 3.1 Componentes

```
WhatsApp
   │  (QR code / sessão)
   ▼
WPPConnect Server  ──webhook──►  API (orquestrador)  ──►  OpenAI
   ▲                                   │                  ├─ STT (Whisper)
   └──────── envio de msg ─────────────┤                  ├─ LLM (chat)
                                       ▼                  └─ TTS
                                   Postgres
                                   (estado, planos, histórico)
```

| Container | Responsabilidade |
|---|---|
| `wppconnect` | Conexão com o WhatsApp, pareamento por QR, envio/recebimento de mídia |
| `api` | Orquestração dos agentes, máquina de estados, chamadas à OpenAI, conversão de áudio (ffmpeg) |
| `postgres` | Persistência de usuários, planos, lições, mensagens e feedbacks |

### 3.2 Requisitos de infraestrutura

- **RI1** — Volume persistente para os tokens de sessão do WPPConnect (evitar reler QR a cada restart).
- **RI2** — Volume persistente para o banco.
- **RI3** — `ffmpeg` disponível na imagem da API (conversão de áudio, ver §7.3).
- **RI4** — Fila/lock por usuário: mensagens do mesmo número processadas em série, para não corromper o estado.
- **RI5** — Idempotência por `message_id` do WhatsApp (webhooks podem repetir).

---

## 4. Máquina de estados do usuário

| Estado | Entrada | Saída / próximo |
|---|---|---|
| `NEW` | Primeira mensagem de um número desconhecido | Saudação + pergunta do nível → `AWAITING_LEVEL` |
| `AWAITING_LEVEL` | Usuário informa o nível | Grava nível, gera plano, envia plano → `IDLE` |
| `IDLE` | Usuário aceita começar / pede lição | Seleciona próximo item, monta cenário → `IN_LESSON` |
| `IN_LESSON` | Turnos de conversa em inglês | Limite de turnos ou perguntas esgotadas → `LESSON_REVIEW` |
| `LESSON_REVIEW` | — | Análise + resumo + plano atualizado → `IDLE` |
| `IDLE` (lista concluída) | Último item marcado como `done` | Sobe de nível, regera plano → `IDLE` |

**RF1** — Qualquer mensagem fora do fluxo esperado é tratada pelo orquestrador, que reafirma o estado atual e reconvida à ação pendente.

---

## 5. Agentes

| Agente | Entrada | Saída | Idioma da saída |
|---|---|---|---|
| **Orquestrador** | Mensagem + estado do usuário | Roteamento para o agente correto | — |
| **Diagnóstico** | Resposta do usuário sobre o nível | Nível CEFR normalizado (A1…C2) | PT |
| **Planejador** | Nível CEFR | Lista ordenada de itens de conhecimento (JSON) | Título EN + descrição PT |
| **Designer de lição** | 1 item da lista | Cenário de conversa + até 6 perguntas-âncora (JSON) | EN |
| **Conversação** | Cenário + perguntas-âncora + histórico da lição | Próxima fala do tutor | EN |
| **Corretor** | Última mensagem do usuário + contexto | Correção + versão mais natural + explicação | EN (exemplos) + PT (explicação) |
| **Revisor** | Histórico completo da lição | Pontos positivos, pontos a melhorar, resumo conceitual | PT com termos em EN |

### 5.1 Regras dos agentes

- **RA1** — O Planejador retorna JSON estrito, sem markdown, para gravação direta no banco.
- **RA2** — O Designer de lição gera **no máximo 6** perguntas-âncora. O agente de Conversação as adapta ao rumo da conversa, mas não cria perguntas novas além do necessário para dar naturalidade.
- **RA3** — A lição encerra por **duas** condições, o que ocorrer primeiro: perguntas-âncora esgotadas **ou** `MAX_TURNS` atingido (o teto duro é o que protege contra o usuário desviar do roteiro).
- **RA4** — O Corretor roda a cada mensagem do usuário dentro da lição. Se não houver erro relevante, ele reforça o acerto em uma linha em vez de inventar correção.
- **RA5** — O agente de Conversação nunca corrige dentro da fala em inglês; correção é responsabilidade exclusiva do Corretor, em mensagem separada.

---

## 6. Regras de idioma e formato de saída

| Situação | Formato | Idioma |
|---|---|---|
| Saudação, diagnóstico, plano, progresso | Texto | PT (termos técnicos em EN) |
| Fala do tutor durante a lição | **Áudio + texto** | EN |
| Resposta do usuário na lição | Áudio ou texto | EN (esperado) |
| Correção pontual | Texto | Exemplo em EN + explicação em PT |
| Fechamento da lição | Texto | PT com conceitos em EN |

**RF2** — O texto que acompanha o áudio é sempre a transcrição literal do que foi falado, para servir de apoio quando o usuário não entender o áudio.

---

## 7. Áudio

### 7.1 Entrada
- **RF3** — Áudio recebido → download da mídia do WPPConnect → transcrição via **Whisper** (`whisper-1` ou `gpt-4o-transcribe`) → o texto segue o mesmo caminho de uma mensagem de texto.
- **RF4** — Transcrição salva junto à mensagem, para auditoria e para o Revisor.

### 7.2 Saída
- **RF5** — Texto da fala do tutor → modelo de **TTS** (`gpt-4o-mini-tts` ou `tts-1`) → áudio.

### 7.3 Formato
- **RF6** — WhatsApp espera **OGG/Opus** para mensagem de voz (PTT). A saída do TTS precisa ser convertida com `ffmpeg` antes do envio, senão o áudio chega como arquivo anexado em vez de mensagem de voz.

### 7.4 Não persistência de áudio

- **RF8** — **Nenhum áudio é armazenado.** O que persiste é sempre texto: a transcrição (entrada) ou o roteiro falado (saída).
- **RF9** — Áudio de entrada: baixado para diretório temporário → transcrito → **arquivo apagado na mesma requisição**, inclusive em caso de erro (bloco `finally`).
- **RF10** — Áudio de saída: gerado em memória/tmp → enviado ao WPPConnect → apagado imediatamente. Sem cache de TTS.
- **RF11** — O container da API não monta volume de mídia; o diretório temporário vive no filesystem efêmero do container.
- **RF12** — Limpeza de segurança: job/`make clean-tmp` que varre arquivos de mídia órfãos com mais de N minutos, para o caso de crash entre a geração e o descarte.
- **RF13** — Consequência aceita: reprocessamento de áudio é impossível. Se a transcrição sair ruim, o registro ruim é o que fica. Trocar o modelo de STT depois não permite reprocessar o histórico.

> Nota de custo: o driver de custo do áudio é a **chamada de API** (minutos de STT/TTS), não o armazenamento. Não persistir corta custo de disco e reduz superfície de privacidade, mas não reduz a conta da OpenAI — para isso, ver D4 (modo só texto).

---

## 8. Modelo de dados (Postgres)

```
users
  id, phone_e164 (unique), display_name, level_cefr,
  state, created_at, updated_at

knowledge_items          -- a "lista de conhecimento"
  id, user_id, level_cefr, order_index,
  title_en, description_pt,
  status (pending | in_progress | done),
  completed_at

lessons
  id, user_id, knowledge_item_id,
  scenario, anchor_questions (jsonb),
  turn_count, max_turns,
  status (active | finished | aborted),
  started_at, ended_at

messages
  id, user_id, lesson_id (null),
  wa_message_id (unique), direction (in | out),
  media_type (text | audio),   -- origem da mensagem, não indica mídia salva
  content_text,                -- texto digitado OU transcrição do áudio
  audio_seconds,               -- só para métrica de custo (RNF5)
  created_at

feedbacks
  id, lesson_id, message_id (null),
  kind (inline_correction | lesson_review),
  content, created_at
```

**RF7** — A progressão de nível ocorre quando todos os `knowledge_items` do nível corrente estão `done`; o sistema grava o novo nível em `users.level_cefr` e o Planejador gera a nova lista.

---

## 9. Configuração (`.env`)

```env
# WhatsApp
WPP_SESSION_NAME=
WPP_SERVER_URL=
WPP_SECRET_KEY=
WPP_WEBHOOK_URL=
BOT_PHONE_NUMBER=

# OpenAI
OPENAI_API_KEY=
OPENAI_MODEL_CHAT=
OPENAI_MODEL_STT=
OPENAI_MODEL_TTS=
OPENAI_TTS_VOICE=
OPENAI_TEMPERATURE=
OPENAI_MAX_TOKENS=
OPENAI_TIMEOUT_SECONDS=

# Pedagógico
DEFAULT_LEVEL=
MAX_TURNS_PER_LESSON=
MAX_ANCHOR_QUESTIONS=
ITEMS_PER_LEVEL=

# Banco
POSTGRES_HOST=
POSTGRES_PORT=
POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=

# Aplicação
API_PORT=
LOG_LEVEL=
```

---

## 10. Makefile (alvos mínimos)

| Alvo | Função |
|---|---|
| `make up` | Sobe todos os containers |
| `make down` | Derruba tudo |
| `make logs` | Logs agregados |
| `make qr` | Mostra o QR code para parear o WhatsApp |
| `make migrate` | Aplica migrações do banco |
| `make reset` | Limpa banco e sessão (recomeço do zero) |
| `make clean-tmp` | Remove arquivos de mídia temporários órfãos (RF12) |
| `make test` | Suíte de testes |
| `make lint` | Lint/format |
| `make setup` | Setup do ambiente de desenvolvimento (usado por contribuidores) |
| `make check` | Roda tudo que a CI roda — lint + tipos + testes (§14.4) |

---

## 11. Requisitos não funcionais

- **RNF1** — Tempo de resposta alvo: até 15s entre a mensagem do usuário e a primeira resposta (áudio incluso).
- **RNF2** — Nenhum segredo no repositório; tudo via `.env` (com `.env.example` versionado).
- **RNF3** — Todas as chamadas à OpenAI com retry e timeout; falha resulta em mensagem amigável ao usuário, não em silêncio.
- **RNF4** — Log estruturado por `user_id` + `lesson_id`, sem gravar a chave de API.
- **RNF5** — Custo por lição estimado e registrado (tokens + minutos de áudio), já que áudio em toda mensagem é o maior driver de custo.

---

## 12. Decisões pendentes

| # | Questão |
|---|---|
| D1 | Quantos itens por nível o Planejador deve gerar? (sugestão: 10–15 no A1) |
| D2 | `MAX_TURNS_PER_LESSON` — 8? 12? |
| D3 | Comandos explícitos do usuário (ex.: "próxima lição", "meu progresso", "recomeçar") ou tudo por linguagem natural? |
| D4 | O usuário pode escolher fazer a lição só em texto, sem áudio? (custo e acessibilidade) |
| D5 | O que acontece se o usuário responder em português dentro da lição — o tutor insiste em inglês, traduz, ou aceita? |
| D6 | Retomada: se o usuário sumir no meio de uma lição e voltar 3 dias depois, retoma ou reinicia o item? |
| D7 | O plano é enviado inteiro a cada atualização ou só o delta ("2 de 12 concluídos")? |
| D8 | ~~Licença: MIT (permissiva, adoção máxima) ou AGPL (garante que forks em SaaS voltem)?~~ **RESOLVIDA: Apache-2.0** (permissiva, com concessão explícita de patente). Ver `LICENSE`. |
| D9 | O histórico de mensagens em texto também tem retenção limitada, ou fica indefinidamente? O Revisor precisa dele só até o fim da lição |
| D10 | Aviso de privacidade ao usuário na primeira mensagem, já que a conversa passa pela OpenAI? |

---

## 13. Riscos

| # | Risco | Mitigação |
|---|---|---|
| R1 | Progressão de nível sem avaliação infla o progresso do usuário | Aceito no protótipo; prever avaliação leve em versão futura |
| R2 | Sessão do WPPConnect cai e exige novo QR | Volume persistente + alerta no log |
| R3 | Custo de áudio em toda mensagem | Métrica de custo por lição (RNF5) + D4 |
| R4 | Usuário desvia do roteiro e a lição não termina | Teto duro de turnos (RA3) |
| R5 | WPPConnect é solução não oficial — risco de bloqueio do número | Usar número dedicado, volume de mensagens baixo no protótipo |
| R6 | Contribuidor vaza chave de API ou número real em commit | Secret scanning + pre-commit hook + `.env` no `.gitignore` (§14.5) |
| R7 | Volume de PRs/issues maior que a capacidade de moderação | Escopo declarado no README, `good first issue`, resposta padrão de triagem (§14.6) |
| R8 | Contribuição depende de chave da OpenAI para testar — barreira de entrada | Camada de LLM abstraída + fixtures/mocks nos testes (§14.4) |

---

## 14. Governança e contribuição (open source)

**Modelo:** repositório público, contribuição aberta a qualquer pessoa, **merge exclusivo da mantenedora**. Ninguém escreve direto na `main`.

### 14.1 Fluxo de contribuição

```
fork → branch → PR para develop → CI verde → review da mantenedora → merge
```

- **RG1** — `main` e `develop` protegidas: sem push direto, PR obrigatório, CI obrigatória, review obrigatório.
- **RG2** — `CODEOWNERS` apontando a mantenedora como revisora obrigatória de todo o repositório.
- **RG3** — Contribuidores externos trabalham por fork; ninguém recebe permissão de escrita por padrão.
- **RG4** — Squash merge, para manter o histórico da `develop` legível.

### 14.2 Arquivos obrigatórios na raiz

| Arquivo | Conteúdo |
|---|---|
| `README.md` | O que é, como subir em 3 comandos, escopo e não-escopo |
| `LICENSE` | Apache-2.0 (D8 resolvida) |
| `CONTRIBUTING.md` | Fluxo acima, padrão de commit, como rodar testes, o que é aceito |
| `CODE_OF_CONDUCT.md` | Contributor Covenant + canal de contato |
| `SECURITY.md` | Como reportar vulnerabilidade em privado |
| `.env.example` | Todas as chaves de §9, sem valores |
| `.github/PULL_REQUEST_TEMPLATE.md` | Checklist: testes, docs, sem segredo, issue vinculada |
| `.github/ISSUE_TEMPLATE/` | Bug report, feature request, question |

### 14.3 Padrões de código

- **RG5** — Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`…), o que permite CHANGELOG automático.
- **RG6** — Um PR = uma issue = um propósito. PR sem issue vinculada é fechado com pedido de abertura de issue antes.
- **RG7** — Formatação e lint automatizados; nenhum PR entra em discussão de estilo, a ferramenta decide.
- **RG8** — Prompts dos agentes ficam em arquivos versionados (`prompts/`), não hardcoded — é a parte que mais vai receber contribuição da comunidade.

### 14.4 CI (obrigatória em todo PR)

1. Lint + formatação
2. Checagem de tipos
3. Testes unitários e de integração
4. Secret scanning
5. Build da imagem Docker

- **RG9** — A suíte de testes roda **sem chave da OpenAI**: a camada de LLM/STT/TTS é uma interface com implementação `fake` para os testes. Sem isso, contribuição externa fica inviável (R8).
- **RG10** — `make check` reproduz localmente exatamente o que a CI roda.

### 14.5 Segredos

- **RG11** — `.env`, tokens de sessão do WPPConnect e qualquer número de telefone real ficam no `.gitignore`.
- **RG12** — Pre-commit hook com detecção de segredos.
- **RG13** — Nenhum workflow de CI expõe secrets do repositório a PRs vindos de fork.

### 14.6 Moderação

- **RG14** — Labels de triagem: `good first issue`, `help wanted`, `needs discussion`, `wontfix`, `blocked`.
- **RG15** — Mudanças de arquitetura ou de comportamento pedagógico exigem issue com discussão **antes** do código; PR de arquitetura sem discussão prévia é recusado.
- **RG16** — Expectativa pública de tempo de resposta declarada no `CONTRIBUTING.md` (ex.: triagem em até 7 dias) — evita frustração e cobrança.
- **RG17** — GitHub Discussions habilitado para dúvidas e ideias, mantendo as issues limpas para trabalho acionável.