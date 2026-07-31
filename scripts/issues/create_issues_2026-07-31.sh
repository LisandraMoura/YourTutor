#!/usr/bin/env bash
# Cria as issues do roteiro "do zero ao agente funcional" no GitHub via API REST.
# Gerado por: issue-planner skill (roteiro de 2026-07-31)
# Design: docs/superpowers/specs/2026-07-31-roteiro-issues-agente-funcional-design.md
#
# Uso:   GITHUB_TOKEN=<seu_token_classico> bash scripts/issues/create_issues_2026-07-31.sh
# Repo:  LisandraMoura/YourTutor
# Token: precisa de permissão issues:write (classic PAT) ou "Issues: write" (fine-grained)

set -euo pipefail

REPO="${REPO:-LisandraMoura/YourTutor}"
API="https://api.github.com/repos/${REPO}/issues"
LABELS_API="https://api.github.com/repos/${REPO}/labels"

TOKEN="${GITHUB_TOKEN:?'Defina GITHUB_TOKEN no ambiente (token com permissão issues:write)'}"

create_issue() {
  local title="$1"
  local body="$2"
  shift 2
  local payload
  payload=$(python3 -c "
import json, sys
title = sys.argv[1]
body = sys.argv[2]
labels = list(sys.argv[3:]) + ['task']
print(json.dumps({'title': title, 'body': body, 'labels': labels}))
" "$title" "$body" "$@")

  result=$(curl -s -X POST "$API" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$payload")

  number=$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('number','ERR'))" <<< "$result")
  url=$(python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('html_url',''))" <<< "$result")
  echo "  #${number} — ${title}"
  echo "         ${url}"
}

create_label() {
  local name="$1" color="$2" desc="$3"
  local payload
  payload=$(python3 -c "
import json, sys
print(json.dumps({'name': sys.argv[1], 'color': sys.argv[2], 'description': sys.argv[3]}))
" "$name" "$color" "$desc")
  curl -s -X POST "$LABELS_API" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null
  echo "  Label: ${name}"
}

echo "=== Repo: ${REPO} ==="
echo ""

# ── Labels ────────────────────────────────────────────────────────────────────
echo "=== Labels ==="
create_label "onda-0"     "5319e7" "Fundação do repositório" || true
create_label "onda-1"     "1d76db" "Infra de dados e integração externa" || true
create_label "onda-2"     "d93f0b" "Orquestração e agentes pedagógicos" || true
create_label "onda-3"     "0e8a16" "Integração ponta a ponta e polimento" || true
create_label "esforco-xs" "c2e0c6" "Esforço XS" || true
create_label "esforco-s"  "bfdadc" "Esforço S" || true
create_label "esforco-m"  "fef2c0" "Esforço M" || true
create_label "esforco-l"  "f9d0c4" "Esforço L" || true
create_label "governanca" "ededed" "Arquivos/processo de governança OSS" || true
create_label "task"       "ededed" "Task de desenvolvimento" || true

echo ""
echo "=== Issues ==="
echo ""
echo "--- Onda 0 — Fundação do repositório ---"

# ── ISSUE 1 ───────────────────────────────────────────────────────────────────
title="[SETUP] Scaffolding do projeto Python (uv, ruff, pytest) · fundação"
body=$(cat <<'BODY'
## Contexto

O repositório só tem `README.md`, `CLAUDE.md` e `docs/requisitos/`. Nenhum
código existe ainda. Esta é a primeira issue do roteiro — todas as outras
dependem dela.

## Objetivo

Criar o esqueleto do projeto Python gerenciado por `uv`, com lint/format via
`ruff` e testes via `pytest`, seguindo o mapa de pastas do `CLAUDE.md`.

## Escopo

1. `pyproject.toml` (uv) com as dependências mínimas do protótipo
2. Estrutura de pastas: `app/{config.py, webhook/, orchestrator/, agents/, prompts/, llm/, whatsapp/, audio/, db/}`, `tests/`
3. Configuração do `ruff` (lint + format)
4. `pytest` configurado, com um teste de exemplo passando

## Critérios de Aceitação

- [ ] `uv sync` funciona
- [ ] `ruff check` / `ruff format --check` rodam sem erro
- [ ] `pytest` roda (mesmo com 1 teste trivial) sem chave da OpenAI
- [ ] Estrutura de pastas corresponde ao mapa do `CLAUDE.md`

## Esforço / Onda

S · Onda 0

## Depende de

Nenhuma — primeira issue do roteiro.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-s"

# ── ISSUE 2 ───────────────────────────────────────────────────────────────────
title="[SETUP] docker-compose + Dockerfile da API (ffmpeg) + Postgres + WPPConnect · fundação"
body=$(cat <<'BODY'
## Contexto

RI1–RI3 exigem volumes persistentes (sessão do WhatsApp e banco) e `ffmpeg`
disponível na imagem da API. Arquitetura completa em §3 da spec.

## Objetivo

Subir os três containers (`wppconnect`, `api`, `postgres`) via
`docker compose`.

## Escopo

1. `Dockerfile` da API com `ffmpeg` + `uv`
2. `docker-compose.yml` com os 3 serviços
3. Volume persistente para a sessão do WPPConnect (RI1) e para o Postgres (RI2)
4. Rede interna entre os containers

## Critérios de Aceitação

- [ ] `docker compose up` sobe os 3 containers
- [ ] `ffmpeg` disponível dentro do container da API
- [ ] Volumes persistem entre restarts (sessão WPPConnect e dados do Postgres)

## Esforço / Onda

M · Onda 0

## Depende de

Issue [SETUP] Scaffolding do projeto Python.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-m"

# ── ISSUE 3 ───────────────────────────────────────────────────────────────────
title="[SETUP] Makefile com os alvos mínimos (§10) · fundação"
body=$(cat <<'BODY'
## Contexto

§10 da spec define os alvos mínimos de Makefile que a CLAUDE.md também exige
(regra: "use sempre o make, nunca comandos soltos de docker/uv").

## Objetivo

Implementar `make up down logs qr migrate reset clean-tmp test lint check setup`,
cada um delegando para `docker compose` / `uv` / `pytest` / `ruff` conforme o
caso.

## Escopo

1. Todos os alvos da tabela §10
2. `make check` precisa reproduzir localmente exatamente o que a CI roda (RG10) —
   a CI ainda não existe (ver issue [CI]), então por enquanto `make check` roda
   lint + testes; será atualizado quando a CI existir

## Critérios de Aceitação

- [ ] Todos os alvos da tabela §10 existem e funcionam
- [ ] `make check` roda lint + testes localmente

## Esforço / Onda

S · Onda 0

## Depende de

Issue [SETUP] docker-compose + Dockerfile da API.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-s"

# ── ISSUE 4 ───────────────────────────────────────────────────────────────────
title="[CONFIG] config.py + .env.example (§9) · fundação"
body=$(cat <<'BODY'
## Contexto

Regra inviolável do CLAUDE.md: nenhuma configuração hardcoded — modelo,
temperatura, número, limites de turno, tudo vem do `.env` via `config.py`.

## Objetivo

Centralizar toda configuração em `app/config.py`, carregada do `.env`, com
`.env.example` cobrindo todas as chaves de §9.

## Escopo

1. Loading e validação das chaves de §9 (WhatsApp, OpenAI, Pedagógico, Banco, Aplicação)
2. `.env.example` com todas as chaves, sem valores reais
3. Falha clara e cedo se uma chave obrigatória faltar

## Nota sobre decisões pendentes (§12)

A spec deixa `ITEMS_PER_LEVEL` (D1) e `MAX_TURNS_PER_LESSON` (D2) em aberto.
Esta issue assume, como default no `.env.example`, `ITEMS_PER_LEVEL=12` e
`MAX_TURNS_PER_LESSON=10` — suposições a validar com a mantenedora, não
decisões finais.

## Critérios de Aceitação

- [ ] Toda chave de §9 existe em `.env.example`
- [ ] `config.py` falha de forma clara se uma chave obrigatória faltar
- [ ] Nenhum valor de configuração hardcoded em outro lugar do código

## Esforço / Onda

S · Onda 0

## Depende de

Issue [SETUP] Scaffolding do projeto Python.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-s"

# ── ISSUE 5 ───────────────────────────────────────────────────────────────────
title="[GOVERNANCA] Arquivos obrigatórios de OSS: LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CODEOWNERS (§14.2)"
body=$(cat <<'BODY'
## Contexto

O projeto é público, com contribuição aberta e merge exclusivo da
mantenedora (§14). §14.2 lista os arquivos obrigatórios na raiz que ainda não
existem.

## Objetivo

Criar `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md` e
`CODEOWNERS`.

## Escopo

1. `LICENSE` — ver nota sobre D8 abaixo
2. `CONTRIBUTING.md`: fluxo fork → branch → PR para `develop` → CI verde →
   review → merge (§14.1); Conventional Commits (RG5); como rodar testes sem
   chave da OpenAI; expectativa de triagem em até 7 dias (RG16)
3. `CODE_OF_CONDUCT.md`: Contributor Covenant + canal de contato
4. `SECURITY.md`: como reportar vulnerabilidade em privado
5. `CODEOWNERS`: mantenedora como revisora obrigatória de todo o repositório (RG2)

## Nota sobre decisão pendente (D8)

A spec deixa a licença em aberto (MIT vs. AGPL). Esta issue assume **MIT**
(adoção máxima) — suposição a confirmar com a mantenedora antes do merge.

## Critérios de Aceitação

- [ ] Os 5 arquivos existem na raiz
- [ ] `CONTRIBUTING.md` cobre fluxo, padrão de commit e como rodar testes sem chave da OpenAI
- [ ] `SECURITY.md` explica como reportar vulnerabilidade em privado

## Esforço / Onda

S · Onda 0 · Governança

## Depende de

Nenhuma.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-s" "governanca"

# ── ISSUE 6 ───────────────────────────────────────────────────────────────────
title="[GOVERNANCA] Templates de PR e issue + labels de triagem (§14.2, §14.6)"
body=$(cat <<'BODY'
## Contexto

§14.2 exige templates de PR e issue; §14.6 exige labels de triagem para
moderação de contribuições externas.

## Objetivo

Criar `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/` (bug,
feature, question) e as labels de triagem.

## Escopo

1. PR template com checklist: testes, docs, sem segredo, issue vinculada
2. Issue templates: bug report, feature request, question
3. Labels: `good first issue`, `help wanted`, `needs discussion`, `wontfix`, `blocked` (RG14)

## Critérios de Aceitação

- [ ] Template de PR cobre o checklist "Antes de abrir um PR" do `CLAUDE.md`
- [ ] 3 templates de issue existem
- [ ] Labels de triagem criadas no repositório

## Esforço / Onda

XS · Onda 0 · Governança

## Depende de

Nenhuma.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-xs" "governanca"

# ── ISSUE 7 ───────────────────────────────────────────────────────────────────
title="[CI] Pipeline de CI + pre-commit + proteção de branch (§14.4, §14.5, RG1)"
body=$(cat <<'BODY'
## Contexto

R6 e R8 dos riscos (§13) só são mitigados se a CI existir e rodar sem chave
da OpenAI. `main` e `develop` precisam ficar protegidas (RG1).

## Objetivo

CI obrigatória em todo PR, pre-commit hook de detecção de segredos e
proteção de branch em `main`/`develop`.

## Escopo

1. Workflow de CI: lint, checagem de tipos, testes, secret scanning, build da imagem Docker (§14.4)
2. Garantir que nenhum secret do repositório é exposto a PRs vindos de fork (RG13)
3. Pre-commit hook de detecção de segredos (RG12)
4. Configurar proteção de branch em `main` e `develop` — passo de configuração
   do repositório (settings do GitHub), documentado aqui por não ser código

## Critérios de Aceitação

- [ ] CI roda em todo PR e falha se algum teste tentar exigir `OPENAI_API_KEY` real
- [ ] `make check` reproduz localmente exatamente o que a CI roda (RG10)
- [ ] `main` e `develop` exigem PR + CI verde + review obrigatório

## Esforço / Onda

M · Onda 0 · Governança

## Depende de

Issues [SETUP] Scaffolding do projeto Python, [SETUP] Makefile, [CONFIG] config.py.
BODY
)
create_issue "$title" "$body" "onda-0" "esforco-m" "governanca"

echo ""
echo "--- Onda 1 — Infraestrutura de dados e integração ---"

# ── ISSUE 8 ───────────────────────────────────────────────────────────────────
title="[DB] Modelo de dados Postgres + migrações (§8)"
body=$(cat <<'BODY'
## Contexto

§8 define o schema completo: `users`, `knowledge_items`, `lessons`,
`messages`, `feedbacks`.

## Objetivo

Implementar as 5 tabelas e a ferramenta de migração usada por `make migrate`.

## Escopo

1. Schema conforme §8, incluindo `wa_message_id` único e `phone_e164` único
2. Repositórios básicos de acesso em `app/db/`
3. RF7: progressão de nível grava o novo `users.level_cefr`

## Nota sobre decisão pendente (D9)

A spec deixa em aberto se o histórico de mensagens tem retenção limitada.
Esta issue assume retenção indefinida nesta fase (sem job de expurgo) —
suposição a revisitar depois; o Revisor só precisa do histórico até o fim da
lição.

## Critérios de Aceitação

- [ ] `make migrate` cria as 5 tabelas
- [ ] Constraints da §8 implementadas (unicidade, enums de status)
- [ ] Testes de repositório rodam sem chave da OpenAI

## Esforço / Onda

M · Onda 1

## Depende de

Issues [SETUP] docker-compose, [SETUP] Makefile.
BODY
)
create_issue "$title" "$body" "onda-1" "esforco-m"

# ── ISSUE 9 ───────────────────────────────────────────────────────────────────
title="[LLM] Interface llm/ + implementação fake"
body=$(cat <<'BODY'
## Contexto

Regra inviolável do `CLAUDE.md`: os testes rodam sem chave da OpenAI. A
camada `llm/` precisa ser uma interface com implementação `fake`, senão a
contribuição externa é inviável (R8, RG9).

## Objetivo

Definir a interface abstrata de chat/STT/TTS usada por todos os agentes, com
uma implementação `fake` determinística para testes.

## Escopo

1. Contrato único (chat, transcrição/STT, síntese/TTS) usado por todo o resto do projeto
2. Implementação `fake` com respostas configuráveis por teste

## Critérios de Aceitação

- [ ] Nenhum teste do repositório precisa de `OPENAI_API_KEY`
- [ ] A interface cobre chat, STT e TTS

## Esforço / Onda

M · Onda 1

## Depende de

Issue [CONFIG] config.py.
BODY
)
create_issue "$title" "$body" "onda-1" "esforco-m"

# ── ISSUE 10 ──────────────────────────────────────────────────────────────────
title="[LLM] Implementação OpenAI da interface llm/ (chat, STT, TTS)"
body=$(cat <<'BODY'
## Contexto

RF3 e RF5 exigem Whisper para STT e um modelo de TTS para a saída; RNF3
exige retry e timeout em toda chamada à OpenAI.

## Objetivo

Implementação real da interface da issue [LLM] Interface llm/ + implementação
fake, usando a API da OpenAI.

## Escopo

1. Chat via `OPENAI_MODEL_CHAT`, STT via `OPENAI_MODEL_STT` (Whisper), TTS via `OPENAI_MODEL_TTS`/`OPENAI_TTS_VOICE`
2. Retry + timeout configuráveis via `.env` (`OPENAI_TIMEOUT_SECONDS`)
3. Falha de API vira mensagem amigável ao usuário, nunca silêncio (RNF3)

## Critérios de Aceitação

- [ ] Implementação satisfaz a mesma interface da versão fake
- [ ] Retry e timeout configuráveis via `.env`
- [ ] Testes que dependem de rede/chave real são explicitamente marcados e pulados por padrão

## Esforço / Onda

M · Onda 1

## Depende de

Issue [LLM] Interface llm/ + implementação fake.
BODY
)
create_issue "$title" "$body" "onda-1" "esforco-m"

# ── ISSUE 11 ──────────────────────────────────────────────────────────────────
title="[WHATSAPP] Cliente WPPConnect (envio de texto/áudio, download de mídia)"
body=$(cat <<'BODY'
## Contexto

E1 e E9 do escopo do protótipo exigem recebimento e envio de texto/áudio via
WPPConnect.

## Objetivo

Cliente que encapsula a comunicação com o WPPConnect Server.

## Escopo

1. `app/whatsapp/`: download de mídia de uma mensagem recebida
2. Envio de mensagem de texto
3. Envio de mensagem de voz (PTT) a partir de um arquivo local já convertido

## Critérios de Aceitação

- [ ] Cliente baixa a mídia de uma mensagem recebida
- [ ] Cliente envia texto e áudio (arquivo local) para um número

## Esforço / Onda

M · Onda 1

## Depende de

Issues [SETUP] docker-compose, [CONFIG] config.py.
BODY
)
create_issue "$title" "$body" "onda-1" "esforco-m"

# ── ISSUE 12 ──────────────────────────────────────────────────────────────────
title="[WEBHOOK] Recebimento de mensagens (idempotência + fila por usuário)"
body=$(cat <<'BODY'
## Contexto

RI4 e RI5: webhooks do WhatsApp repetem, e mensagens do mesmo usuário
precisam ser processadas em série para não corromper a máquina de estados.

## Objetivo

Endpoint que recebe o webhook do WPPConnect com idempotência por
`wa_message_id` e fila/lock por usuário.

## Escopo

1. `app/webhook/`: recepção e validação do payload do WPPConnect
2. Idempotência por `wa_message_id` (RI5)
3. Fila/lock por usuário — mensagens do mesmo número em série (RI4)
4. Grava a mensagem recebida em `messages` (`media_type` text/audio)

## Critérios de Aceitação

- [ ] Reenvio do mesmo `wa_message_id` não duplica processamento
- [ ] Duas mensagens do mesmo usuário chegando em paralelo são processadas em série

## Esforço / Onda

M · Onda 1

## Depende de

Issues [DB] Modelo de dados Postgres, [WHATSAPP] Cliente WPPConnect.
BODY
)
create_issue "$title" "$body" "onda-1" "esforco-m"

# ── ISSUE 13 ──────────────────────────────────────────────────────────────────
title="[AUDIO] STT/TTS + conversão ffmpeg (OGG/Opus) + não persistência (§7)"
body=$(cat <<'BODY'
## Contexto

Regra inviolável do `CLAUDE.md`: nenhum áudio é armazenado. §7 detalha o
ciclo de vida completo (RF3–RF13): entrada baixada/transcrita/apagada na
mesma requisição, mesmo em erro; saída gerada/enviada/apagada, sem cache de
TTS.

## Objetivo

Pipeline de áudio completo, ponta a ponta, sem persistir nenhum arquivo de
mídia.

## Escopo

1. Entrada: download → transcrição via Whisper → apagar arquivo em bloco `finally`, inclusive em erro (RF3, RF9)
2. Saída: texto do tutor → TTS → conversão `ffmpeg` para OGG/Opus (PTT) → envio → apagar (RF5, RF6, RF10)
3. Container da API sem volume de mídia — diretório temporário efêmero (RF11)
4. `make clean-tmp`: varre arquivos de mídia órfãos com mais de N minutos (RF12), N vindo de config

## Nota sobre decisão pendente (D4)

A spec deixa em aberto se o usuário pode escolher fazer a lição só em texto
(custo/acessibilidade). Esta issue **não** implementa esse modo — o
protótipo sempre gera áudio + texto; um modo só-texto fica para uma issue
futura, se decidido.

## Critérios de Aceitação

- [ ] Nenhum arquivo de áudio sobrevive além da requisição, mesmo com uma falha simulada no meio do processamento
- [ ] Saída chega ao WhatsApp como mensagem de voz (PTT), não como anexo
- [ ] `make clean-tmp` remove órfãos com mais de N minutos configuráveis

## Esforço / Onda

L · Onda 1

## Depende de

Issues [LLM] Implementação OpenAI, [WHATSAPP] Cliente WPPConnect.
BODY
)
create_issue "$title" "$body" "onda-1" "esforco-l"

echo ""
echo "--- Onda 2 — Orquestração e agentes pedagógicos ---"

# ── ISSUE 14 ──────────────────────────────────────────────────────────────────
title="[ORCH] Máquina de estados do usuário (§4)"
body=$(cat <<'BODY'
## Contexto

§4 define as transições `NEW → AWAITING_LEVEL → IDLE → IN_LESSON →
LESSON_REVIEW → IDLE`. RF1 exige que qualquer mensagem fora do fluxo
esperado seja tratada sem quebrar o estado atual.

## Objetivo

Implementar a máquina de estados que roteia cada mensagem recebida para o
agente correto.

## Escopo

1. `app/orchestrator/`: as 5 transições da tabela §4
2. RF1: mensagem fora do fluxo esperado reafirma o estado atual e reconvida à ação pendente

## Nota sobre decisões pendentes (D3, D6, D10)

- **D3**: nesta fase só se aceita linguagem natural; comandos explícitos
  ("próxima lição", "meu progresso", "recomeçar") ficam fora do protótipo —
  suposição a validar.
- **D6**: se o usuário sumir durante `IN_LESSON` e voltar depois, a lição é
  **retomada** de onde parou, não reiniciada — suposição a validar.
- **D10**: no estado `NEW`, antes de perguntar o nível, o tutor envia um
  aviso fixo de privacidade informando que a conversa passa pela OpenAI e que
  nenhum áudio é armazenado.

## Critérios de Aceitação

- [ ] Cada transição da tabela §4 tem teste cobrindo entrada e saída
- [ ] Mensagem fora de fluxo não quebra o estado atual
- [ ] Aviso de privacidade é enviado no primeiro contato (`NEW`)

## Esforço / Onda

M · Onda 2

## Depende de

Issues [DB] Modelo de dados Postgres, [LLM] Interface llm/ + implementação fake.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-m"

# ── ISSUE 15 ──────────────────────────────────────────────────────────────────
title="[AGENTE] Diagnóstico"
body=$(cat <<'BODY'
## Contexto

E3 do escopo: diagnóstico declarado — o usuário informa o nível, sem
avaliação real.

## Objetivo

Normalizar a resposta livre do usuário sobre o próprio nível em um valor
CEFR válido (A1–C2).

## Escopo

1. Prompt versionado em `app/prompts/` (nunca hardcoded no código)
2. Módulo em `app/agents/`
3. Saída em português (§6)

## Critérios de Aceitação

- [ ] Entradas variadas ("iniciante", "intermediário", "acho que sou B1") normalizam para um nível CEFR válido
- [ ] Testes usam o LLM fake, sem chave da OpenAI

## Esforço / Onda

S · Onda 2

## Depende de

Issue [LLM] Interface llm/ + implementação fake.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-s"

# ── ISSUE 16 ──────────────────────────────────────────────────────────────────
title="[AGENTE] Planejador (geração da lista de conhecimento)"
body=$(cat <<'BODY'
## Contexto

RA1: o Planejador retorna JSON estrito, sem markdown, para gravação direta
no banco.

## Objetivo

Gerar a lista de conhecimento do nível do usuário e gravá-la em
`knowledge_items`.

## Escopo

1. Prompt em `app/prompts/`; saída título em inglês + descrição em português por item
2. JSON estrito, sem markdown (RA1)
3. Quantidade de itens por nível vem de `ITEMS_PER_LEVEL` (config.py, suposição D1 = 12)

## Critérios de Aceitação

- [ ] Saída é JSON válido, gravável direto no banco, sem parsing de markdown
- [ ] Quantidade de itens gerados respeita `ITEMS_PER_LEVEL`

## Esforço / Onda

M · Onda 2

## Depende de

Issues [DB] Modelo de dados Postgres, [AGENTE] Diagnóstico.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-m"

# ── ISSUE 17 ──────────────────────────────────────────────────────────────────
title="[AGENTE] Designer de lição (cenário + perguntas-âncora)"
body=$(cat <<'BODY'
## Contexto

RA2: o Designer de lição gera no máximo 6 perguntas-âncora; o agente de
Conversação as adapta ao rumo da conversa, mas não cria perguntas novas além
do necessário.

## Objetivo

A partir de 1 item da lista de conhecimento, gerar um cenário de conversa e
até 6 perguntas-âncora.

## Escopo

1. Prompt em `app/prompts/`; saída em inglês
2. JSON com `scenario` + `anchor_questions` (≤ `MAX_ANCHOR_QUESTIONS`)
3. Grava em `lessons` (`scenario`, `anchor_questions` jsonb)

## Critérios de Aceitação

- [ ] Nunca gera mais perguntas que `MAX_ANCHOR_QUESTIONS`
- [ ] Cenário é coerente com o `title_en` do item de conhecimento

## Esforço / Onda

M · Onda 2

## Depende de

Issue [AGENTE] Planejador.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-m"

# ── ISSUE 18 ──────────────────────────────────────────────────────────────────
title="[AGENTE] Conversação (fala do tutor em inglês)"
body=$(cat <<'BODY'
## Contexto

RA5: o agente de Conversação nunca corrige dentro da fala em inglês —
correção é responsabilidade exclusiva do Corretor, em mensagem separada. RA3:
a lição encerra por perguntas-âncora esgotadas ou `MAX_TURNS` atingido, o que
ocorrer primeiro.

## Objetivo

Gerar a próxima fala do tutor a partir do cenário, das perguntas-âncora e do
histórico da lição.

## Escopo

1. Prompt em `app/prompts/`; saída em inglês (áudio + texto, ver issue [AUDIO])
2. Adapta as perguntas-âncora ao rumo da conversa sem multiplicá-las (RA2)
3. Encerra a lição por perguntas esgotadas OU `MAX_TURNS_PER_LESSON` (RA3)

## Nota sobre decisão pendente (D5)

A spec deixa em aberto o que fazer se o usuário responder em português
dentro da lição. Esta issue assume que o tutor **reforça a resposta em
inglês sem bloquear** a conversa — suposição a validar.

## Critérios de Aceitação

- [ ] A fala do tutor nunca contém correção do usuário
- [ ] A lição encerra por perguntas esgotadas OU `MAX_TURNS_PER_LESSON`, o que vier primeiro

## Esforço / Onda

M · Onda 2

## Depende de

Issue [AGENTE] Designer de lição.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-m"

# ── ISSUE 19 ──────────────────────────────────────────────────────────────────
title="[AGENTE] Corretor (correção pontual)"
body=$(cat <<'BODY'
## Contexto

RA4: o Corretor roda a cada mensagem do usuário dentro da lição; se não
houver erro relevante, reforça o acerto em uma linha em vez de inventar
correção.

## Objetivo

Gerar a correção pontual — exemplo em inglês + explicação em português — a
cada resposta do usuário.

## Escopo

1. Prompt em `app/prompts/`
2. Roda logo após cada turno do usuário, em mensagem separada da fala do tutor (RA5)
3. Grava em `feedbacks` (`kind = inline_correction`)

## Critérios de Aceitação

- [ ] Mensagem sem erro relevante gera reforço de uma linha, não correção inventada
- [ ] Correção sempre chega em mensagem separada da fala do tutor

## Esforço / Onda

M · Onda 2

## Depende de

Issue [AGENTE] Conversação.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-m"

# ── ISSUE 20 ──────────────────────────────────────────────────────────────────
title="[AGENTE] Revisor (fechamento da lição)"
body=$(cat <<'BODY'
## Contexto

E7 do escopo: fechamento de lição com análise + resumo conceitual. §6 define
o idioma: português com os conceitos em inglês.

## Objetivo

Gerar o fechamento da lição a partir do histórico completo: pontos
positivos, pontos a melhorar e resumo conceitual.

## Escopo

1. Prompt em `app/prompts/`
2. Entrada: histórico completo da lição (mensagens + correções)
3. Grava em `feedbacks` (`kind = lesson_review`)

## Critérios de Aceitação

- [ ] Fechamento cobre as 3 partes exigidas: pontos positivos, pontos a melhorar, resumo conceitual
- [ ] Saída em português, com os conceitos em inglês (§6)

## Esforço / Onda

S · Onda 2

## Depende de

Issue [AGENTE] Corretor.
BODY
)
create_issue "$title" "$body" "onda-2" "esforco-s"

echo ""
echo "--- Onda 3 — Integração ponta a ponta e polimento ---"

# ── ISSUE 21 ──────────────────────────────────────────────────────────────────
title="[INTEGRACAO] Loop pedagógico completo + progressão automática de nível"
body=$(cat <<'BODY'
## Contexto

Esta é a issue que fecha o objetivo do protótipo: validar o loop pedagógico
ponta a ponta (diagnóstico → lista de conhecimento → lição item a item →
lista concluída → próximo nível). RF7 exige progressão automática de nível.

## Objetivo

Ligar o orquestrador a todos os agentes num fluxo real, incluindo a
progressão automática de nível ao concluir a lista.

## Escopo

1. `diagnóstico → plano → lição (Designer + Conversação + Corretor) → Revisor → knowledge_items.status`
2. Quando todos os itens do nível estão `done`: sobe `users.level_cefr` e o Planejador regera a lista (RF7)
3. Cada handoff entre agentes respeita o idioma da §6

## Nota sobre decisão pendente (D7)

A spec deixa em aberto se o plano é enviado inteiro a cada atualização ou só
o delta. Esta issue assume: **primeiro envio completo**, atualizações
seguintes mostram só o delta (ex.: "2 de 12 concluídos") — suposição a
validar.

## Critérios de Aceitação

- [ ] Um usuário fictício completa uma lista inteira de itens via mensagens simuladas (LLM fake) e o nível sobe
- [ ] Atualização de progresso após o primeiro envio mostra só o delta

## Esforço / Onda

L · Onda 3

## Depende de

Issues [WEBHOOK] Recebimento de mensagens, [AUDIO] STT/TTS + conversão ffmpeg,
[ORCH] Máquina de estados, e todos os agentes (Diagnóstico, Planejador,
Designer de lição, Conversação, Corretor, Revisor).
BODY
)
create_issue "$title" "$body" "onda-3" "esforco-l"

# ── ISSUE 22 ──────────────────────────────────────────────────────────────────
title="[OBSERVABILIDADE] Log estruturado + custo por lição"
body=$(cat <<'BODY'
## Contexto

RNF4 exige log estruturado por `user_id` + `lesson_id`, sem gravar a chave de
API. RNF5 exige custo por lição estimado e registrado, já que áudio em toda
mensagem é o maior driver de custo (R3).

## Objetivo

Log estruturado em toda a aplicação e cálculo de custo por lição.

## Escopo

1. Log estruturado por `user_id` + `lesson_id`, nunca com a chave de API (RNF4)
2. Custo por lição em tokens + minutos de áudio (RNF5), usando `messages.audio_seconds`

## Critérios de Aceitação

- [ ] Log de qualquer chamada à OpenAI nunca contém a chave de API
- [ ] Custo por lição é calculável a partir dos dados gravados

## Esforço / Onda

S · Onda 3

## Depende de

Issues [LLM] Implementação OpenAI, [AUDIO] STT/TTS, [INTEGRACAO] Loop pedagógico completo.
BODY
)
create_issue "$title" "$body" "onda-3" "esforco-s"

# ── ISSUE 23 ──────────────────────────────────────────────────────────────────
title="[TESTE] Suíte end-to-end do ciclo completo com LLM fake"
body=$(cat <<'BODY'
## Contexto

RG9/R8: a suíte de testes roda sem chave da OpenAI, senão a contribuição
externa fica inviável. Esta issue fecha o objetivo do protótipo (E1–E11):
validar o loop pedagógico com o mínimo de infraestrutura.

## Objetivo

Teste de integração cobrindo diagnóstico → plano → lição → fechamento →
progressão de nível, do início ao fim, sem chave da OpenAI.

## Escopo

1. Teste roda em `make test` e na CI
2. Cobre pelo menos 1 ciclo completo de progressão de nível, usando o LLM fake

## Critérios de Aceitação

- [ ] Teste roda na CI sem `OPENAI_API_KEY`
- [ ] Cobre pelo menos 1 ciclo completo (diagnóstico até progressão de nível)

## Esforço / Onda

M · Onda 3

## Depende de

Issue [INTEGRACAO] Loop pedagógico completo + progressão automática de nível.
BODY
)
create_issue "$title" "$body" "onda-3" "esforco-m"

echo ""
echo "=== Concluído! ==="
