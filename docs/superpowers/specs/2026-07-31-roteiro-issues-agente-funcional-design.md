# Design — Roteiro de issues até o agente funcional

**Data:** 2026-07-31
**Status:** aprovado para virar plano/script

## Contexto

O repositório `LisandraMoura/YourTutor` hoje só tem `README.md`, `CLAUDE.md` e
`docs/requisitos/requisitos-tutor-ingles.md`. Nenhum código, `Makefile`, CI ou
arquivo de governança existe ainda. Este design quebra a especificação em um
roteiro de issues do GitHub, do zero até o agente funcionar ponta a ponta
(diagnóstico → plano → lição → correção → fechamento → progressão de nível),
seguindo o modelo do script de exemplo (`create_issues_2026-07-03.sh` do
projeto AI-Brasil).

O script final roda contra a API REST do GitHub (`POST /repos/{repo}/issues`)
e cria labels + issues, um `create_issue` por item do roteiro abaixo.

## Decisões desta rodada

- **Escopo:** técnico (E1–E11) **e** governança open source (§14) — CI,
  `LICENSE`, `CONTRIBUTING.md`, templates de PR/issue, `CODEOWNERS`, proteção
  de branch.
- **Decisões pendentes (§12, D1–D10):** cada issue afetada assume um valor
  padrão razoável e sinaliza a suposição na descrição, sem travar o roteiro
  numa issue de discussão à parte. Suposições assumidas:
  - D1: `ITEMS_PER_LEVEL=12`
  - D2: `MAX_TURNS_PER_LESSON=10`
  - D3: só linguagem natural nesta fase; comandos explícitos ficam de fora do protótipo
  - D4: sem modo só-texto no protótipo; sempre áudio + texto (revisitar depois por custo)
  - D5: se o usuário responder em português na lição, o tutor reforça a resposta em inglês sem bloquear a conversa
  - D6: se o usuário sumir e voltar, a lição é retomada de onde parou (não reinicia o item)
  - D7: primeiro envio do plano é completo; atualizações seguintes são delta ("2 de 12 concluídos")
  - D8: licença MIT
  - D9: histórico de mensagens retido indefinidamente nesta fase (sem job de expurgo)
  - D10: aviso fixo de privacidade enviado no estado `NEW` (conversa passa pela OpenAI, nenhum áudio é armazenado)
- **Granularidade:** uma issue por módulo/pasta do mapa do `CLAUDE.md`
  (RG6/regra 9: uma issue = um propósito). Sem trilhas por pessoa — só labels
  de onda e esforço.

## Labels

| Label | Cor | Descrição |
|---|---|---|
| `onda-0` | `5319e7` | Fundação do repositório |
| `onda-1` | `1d76db` | Infra de dados e integração externa |
| `onda-2` | `d93f0b` | Orquestração e agentes pedagógicos |
| `onda-3` | `0e8a16` | Integração ponta a ponta e polimento |
| `esforco-xs` | `c2e0c6` | Esforço XS |
| `esforco-s` | `bfdadc` | Esforço S |
| `esforco-m` | `fef2c0` | Esforço M |
| `esforco-l` | `f9d0c4` | Esforço L |
| `governanca` | `ededed` | Arquivos/processo de governança OSS |
| `task` | `ededed` | Task de desenvolvimento (label padrão do exemplo) |

## Roteiro (23 issues)

### Onda 0 — Fundação do repositório

1. **[SETUP] Scaffolding do projeto Python (uv, ruff, pytest)** — S
   `pyproject.toml`, estrutura `app/`/`tests/`, config de `ruff`, dependências
   mínimas.
2. **[SETUP] docker-compose + Dockerfile da API (ffmpeg) + Postgres + WPPConnect** — M
   RI1–RI3.
3. **[SETUP] Makefile com os alvos mínimos (§10)** — S
   `up down logs qr migrate reset clean-tmp test lint check setup`.
4. **[CONFIG] `config.py` + `.env.example` com todas as chaves da §9** — S
   Regra inviolável 6: nenhuma config hardcoded.
5. **[GOVERNANCA] Arquivos obrigatórios de OSS (§14.2)** — S
   `LICENSE` (MIT, D8), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
   `SECURITY.md`, `CODEOWNERS`.
6. **[GOVERNANCA] Templates de PR e issue (§14.2)** — XS
   `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/` (bug,
   feature, question).
7. **[CI] Pipeline de CI + pre-commit + proteção de branch (§14.4, §14.5, RG1)** — M
   Lint, checagem de tipos, testes, secret scanning, build da imagem; `make
   check` reproduz local; branch protection em `main`/`develop`.

### Onda 1 — Infraestrutura de dados e integração

8. **[DB] Modelo de dados Postgres + migrações (§8)** — M
   `users, knowledge_items, lessons, messages, feedbacks`.
9. **[LLM] Interface `llm/` + implementação fake** — M
   Regra inviolável 4/RG9: testes rodam sem chave da OpenAI.
10. **[LLM] Implementação OpenAI da interface `llm/`** — M
    Chat, STT (Whisper), TTS, com retry/timeout (RNF3).
11. **[WHATSAPP] Cliente WPPConnect** — M
    Envio de texto/áudio, download de mídia.
12. **[WEBHOOK] Recebimento de mensagens** — M
    Idempotência por `wa_message_id` (RI5), fila/lock por usuário (RI4).
13. **[AUDIO] STT/TTS + conversão ffmpeg (OGG/Opus) + não persistência** — L
    RF3–RF13 completos, incluindo `make clean-tmp`.

### Onda 2 — Orquestração e agentes pedagógicos

14. **[ORCH] Máquina de estados do usuário (§4)** — M
    `NEW → AWAITING_LEVEL → IDLE → IN_LESSON → LESSON_REVIEW`, RF1.
15. **[AGENTE] Diagnóstico** — S
16. **[AGENTE] Planejador** — M — RA1 (JSON estrito)
17. **[AGENTE] Designer de lição** — M — RA2 (máx. 6 perguntas-âncora)
18. **[AGENTE] Conversação** — M — RA5 (nunca corrige)
19. **[AGENTE] Corretor** — M — RA4
20. **[AGENTE] Revisor** — S

Cada issue de agente cobre: prompt versionado em `app/prompts/` (regra 3),
módulo em `app/agents/`, testes com LLM fake.

### Onda 3 — Integração ponta a ponta e polimento

21. **[INTEGRACAO] Loop pedagógico completo + progressão de nível** — L
    RF7, liga todos os agentes através do orquestrador.
22. **[OBSERVABILIDADE] Log estruturado + custo por lição** — S
    RNF4, RNF5.
23. **[TESTE] Suíte e2e do ciclo completo com LLM fake** — M
    Valida o loop sem chave da OpenAI (RG9/R8).

## Dependências entre issues

Onda 0 é pré-requisito de tudo. Dentro da onda 1, DB/LLM/WhatsApp/Audio são
paralelizáveis entre si mas o Webhook depende do cliente WhatsApp. Onda 2
depende da onda 1 completa (precisa de LLM fake + DB). Onda 3 depende da onda
2 completa. Cada issue declara sua dependência no corpo, como no exemplo.

## Fora de escopo desta rodada

- Issues de discussão dedicadas para D1–D10 (assumidos inline, ver acima).
- Qualquer coisa de `docs/requisitos.md` §2.2 (fora de escopo do protótipo).

## Entregável

Um script `scripts/issues/create_issues_2026-07-31.sh`, no mesmo formato do
exemplo do AI-Brasil (`create_label`/`create_issue` via `curl` + `python3`),
criando as labels da tabela acima e as 23 issues do roteiro, com `REPO`
default `LisandraMoura/YourTutor`.
