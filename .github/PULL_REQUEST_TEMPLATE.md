## Descrição

<!-- O que este PR faz, em 1-2 linhas. -->

**Arquivos modificados**

<!-- Um por linha: `caminho/do/arquivo` — propósito em até 100 caracteres. -->
-

## Issue relacionada

<!-- OBRIGATÓRIO. Um PR = uma issue = um propósito; PR sem issue vinculada é fechado (RG6). -->
Closes #

## Tipo de mudança

<!-- Marque o que se aplica. Deve bater com o prefixo do commit (Conventional Commits). -->
- [ ] `feat` — nova funcionalidade
- [ ] `fix` — correção de bug
- [ ] `refactor` — mudança de código sem mudar comportamento
- [ ] `test` — apenas testes
- [ ] `docs` — apenas documentação
- [ ] `chore` — build, CI, tooling, governança

## Checklist

<!-- Da seção "Antes de abrir um PR" do CLAUDE.md. -->
- [ ] `make check` passa
- [ ] Nenhum segredo, número real ou áudio versionado
- [ ] `.env.example` atualizado se houve nova configuração
- [ ] `docs/requisitos.md` atualizado se o comportamento mudou
- [ ] Testes rodam sem chave da OpenAI
- [ ] Issue vinculada e escopo respeitado

<!-- Regras invioláveis do CLAUDE.md que o PR não pode violar. -->
- [ ] Prompts em `app/prompts/`, nenhum prompt hardcoded
- [ ] Nenhuma configuração hardcoded — tudo pelo `.env` via `app/config.py`
- [ ] Nenhum áudio persistido (entrada e saída são apagadas na mesma requisição)
- [ ] Nenhum outro provedor de LLM além da OpenAI
- [ ] Nenhuma dependência nova (ou a inclusão foi acordada na issue)

<!-- Marque só o que foi de fato cumprido. Item que não se aplica: deixe desmarcado e explique. -->

## Evidências

<!-- Cole a saída do `make check`, logs ou prints que demonstrem a mudança funcionando. -->

```
```

---

<!-- Lembretes: a base é `develop`, nunca `main`. O merge é da mantenedora. -->
