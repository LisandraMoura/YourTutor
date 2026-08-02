# Contribuindo

Obrigada pelo interesse em contribuir. Este é um projeto público, aberto a contribuição de qualquer pessoa, com **merge exclusivo da mantenedora**. Este documento explica como contribuir de um jeito que dê certo desde o primeiro PR.

Antes de qualquer coisa, leia o [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md). Participar do projeto significa concordar com ele.

---

## O que o projeto aceita

Boas portas de entrada:

- **Prompts dos agentes** (`app/prompts/`) — é a parte que mais se beneficia de contribuição da comunidade e não exige mexer em código.
- **Testes** — aumentar cobertura, cobrir caminho de erro, cobrir caso de borda.
- **Documentação** — corrigir, esclarecer, completar.
- **Issues marcadas com `good first issue` ou `help wanted`.**

O que **não** entra sem discussão prévia:

- **Mudança de arquitetura ou de comportamento pedagógico** exige uma issue com discussão **antes** do código. PR de arquitetura que chega sem discussão prévia é recusado — não por rigidez, mas porque a discussão depois do código feito desperdiça o seu trabalho.
- **Dependência nova.** O projeto é deliberadamente enxuto. Pergunte numa issue antes.
- **Outro provedor de LLM.** Ficar apenas na API da OpenAI é uma decisão do projeto, não uma limitação temporária.

Dúvidas e ideias vão para **GitHub Discussions**. As issues ficam reservadas para trabalho acionável.

---

## Fluxo de contribuição

```
fork → branch → PR para develop → CI verde → review da mantenedora → merge
```

1. Faça **fork** do repositório. Contribuidores externos trabalham por fork; ninguém recebe permissão de escrita por padrão.
2. Crie a **branch** a partir da `develop`.
3. Abra o **PR apontando para `develop`** — nunca para `main`.
4. A **CI precisa passar** (lint, checagem de tipos, testes, secret scanning, build da imagem).
5. A **mantenedora revisa** e faz o merge. O merge é **squash**, para manter o histórico da `develop` legível.

`main` e `develop` são branches protegidas: sem push direto, PR obrigatório, CI obrigatória e review obrigatório.

---

## Branch e commit

**Branch:** `<tipo>/<numero-issue>-<slug>`, em kebab-case.

```
fix/712-idempotencia-wppconnect
docs/5-arquivos-oss-obrigatorios
```

**Commit:** [Conventional Commits](https://www.conventionalcommits.org/pt-br/).

| Tipo | Quando usar |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `docs` | Apenas documentação |
| `refactor` | Muda o código sem mudar o comportamento |
| `test` | Adiciona ou ajusta testes |
| `chore` | Build, dependências, configuração |

**Um PR = uma issue = um propósito.** PR sem issue vinculada é recusado com pedido de abrir a issue primeiro. Melhoria que você notou de passagem vira issue nova, não entra no PR.

---

## Rodando os testes sem chave da OpenAI

**Você não precisa de uma chave da OpenAI para contribuir, e não precisa gastar dinheiro para rodar os testes.**

A camada `app/llm/` é uma interface com duas implementações: a real (OpenAI) e uma **`fake`**, usada nos testes. O mesmo vale para STT e TTS. A suíte inteira roda contra a implementação `fake`.

```bash
cp .env.example .env   # pode deixar OPENAI_API_KEY vazia para rodar os testes
make test              # suíte de testes
make lint              # lint + formatação
make check             # reproduz localmente exatamente o que a CI roda
```

Use sempre os alvos do `make`, nunca comandos soltos de `docker` ou `uv`.

> **Regra que não se negocia:** qualquer teste novo que exija uma chave real da OpenAI está errado — ele quebra a contribuição externa. Se o seu teste precisa de uma resposta do LLM, use a implementação `fake`; se ela ainda não cobre o seu caso, estenda-a.

Antes de abrir o PR, `make check` precisa passar.

---

## O que faz um PR ser recusado

Vale conferir esta lista antes de abrir o PR — são as recusas mais comuns:

- **Segredo, número de telefone real ou áudio versionado.** Nem chave de API, nem token de sessão do WPPConnect. Toda configuração vive no `.env`, que está no `.gitignore`; o que vai para o repositório é o `.env.example`, sem valores.
- **Prompt hardcoded no código.** Todo prompt vive em `app/prompts/`, versionado.
- **Configuração hardcoded.** Modelo, temperatura, número, limites de turno — tudo vem do `.env` através de `app/config.py`.
- **Áudio persistido.** Áudio de entrada é baixado, transcrito e apagado na mesma requisição (inclusive em caso de erro). Áudio de saída é gerado, enviado e apagado. Sem cache de TTS, sem volume de mídia. O que persiste é sempre texto.
- **Dependência nova sem perguntar antes.**
- **Escopo inflado.** Só o que a issue pede.

---

## Estilo e idioma

Formatação não se discute: **o `ruff` decide**. Rode `make lint` e siga o que a ferramenta disser — nenhum PR entra em debate de estilo.

Idioma:

- **Código, nomes de variáveis e docstrings:** inglês.
- **Documentação de usuário, issues e PRs:** português.

(Isso é sobre o repositório. O idioma que o tutor usa na conversa com o usuário é outro assunto — está na especificação.)

---

## Antes de abrir o PR

- [ ] `make check` passa
- [ ] Nenhum segredo, número real ou áudio versionado
- [ ] `.env.example` atualizado, se houve nova configuração
- [ ] Especificação atualizada, se o comportamento mudou
- [ ] Testes rodam sem chave da OpenAI
- [ ] Issue vinculada e escopo respeitado

O PR usa o template de [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md), que é preenchido automaticamente ao abrir o PR. Preencha o checklist com honestidade: item não cumprido fica desmarcado com uma explicação — isso acelera a review em vez de atrasá-la.

---

## Triagem e tempo de resposta

Este projeto é mantido por uma pessoa. Para você não ficar no escuro:

- **Triagem em até 7 dias.** Toda issue e todo PR recebem um primeiro retorno nesse prazo — nem que seja para dizer que vai demorar.
- Depois da triagem, a issue recebe uma label:

| Label | Significado |
|---|---|
| `good first issue` | Boa para quem está chegando |
| `help wanted` | A mantenedora gostaria de ajuda aqui |
| `needs discussion` | Precisa de decisão antes de virar código |
| `blocked` | Depende de outra coisa para andar |
| `wontfix` | Decidido que não será feito (com o motivo) |

Se passar dos 7 dias sem retorno, pode comentar na própria issue — é lembrete legítimo, não insistência.

---

## Licença das contribuições

O projeto é licenciado sob a **[Apache License 2.0](LICENSE)**.

- **A sua contribuição entra sob a mesma licença.** Pela Seção 5 da Apache-2.0, toda contribuição enviada intencionalmente para inclusão no projeto é licenciada sob os termos da Apache-2.0, sem termos adicionais. É o modelo *inbound = outbound*: ao abrir um PR, você concorda com isso. **Não há CLA para assinar** — a própria licença já resolve.
- **Concessão de patente.** Pela Seção 3 da Apache-2.0, ao contribuir você concede uma licença de patente sobre aquilo que contribuiu, permitindo que o projeto e quem o usa não sejam processados por patentes que cubram a sua contribuição.
- **Aviso de arquivos modificados.** Pela Seção 4(b), quem redistribui uma versão modificada precisa marcar de forma visível os arquivos alterados. Para PRs feitos aqui no repositório, o histórico do git já cumpre esse papel; se você **forkar e redistribuir** o projeto por fora, essa marcação é responsabilidade sua.

Você continua sendo autor da sua contribuição — a Apache-2.0 não transfere a titularidade dos direitos autorais.

---

## Segurança

**Não abra issue pública para vulnerabilidade.** O procedimento de reporte privado está no [`SECURITY.md`](SECURITY.md).
