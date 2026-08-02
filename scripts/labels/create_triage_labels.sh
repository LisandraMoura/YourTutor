#!/usr/bin/env bash
# Cria as labels de triagem do repositório (RG14, §14.6 da especificação).
#
# Uso:
#   bash scripts/labels/create_triage_labels.sh            # simulação (dry-run) — não escreve nada
#   bash scripts/labels/create_triage_labels.sh --apply    # cria de fato as labels que faltam
#   bash scripts/labels/create_triage_labels.sh --help
#
# Requisitos: `gh` instalado e autenticado (`gh auth status`). Nenhum token precisa
# ser exportado no ambiente — o script não lê nem grava segredo algum.
#
# Comportamento:
#   - Dry-run é o padrão. Sem `--apply`, o script apenas mostra o que faria.
#   - Idempotente: label que já existe é PULADA, sem alteração de cor nem de descrição.
#   - Nunca apaga nem renomeia label. Nada destrutivo.
#   - Falha de rede em uma label não interrompe as demais; o script sai com código != 0
#     e pode ser executado de novo com segurança.

set -euo pipefail

REPO="${REPO:-LisandraMoura/YourTutor}"
APPLY=0

# name|color|description — labels de triagem exigidas pela RG14.
TRIAGE_LABELS=(
  "good first issue|7057ff|Boa porta de entrada para quem está chegando"
  "help wanted|008672|Contribuição externa bem-vinda nesta issue"
  "needs discussion|d4c5f9|Precisa de acordo antes do código (RG15)"
  "blocked|b60205|Bloqueada por outra issue ou por decisão pendente"
  "wontfix|ffffff|Fora do escopo do projeto; não será feito"
)

usage() {
  # Imprime o bloco de comentários do topo do arquivo, sem o shebang.
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

for arg in "$@"; do
  case "$arg" in
    --apply)
      APPLY=1
      ;;
    --dry-run)
      APPLY=0
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Argumento desconhecido: $arg" >&2
      echo "Use --apply, --dry-run ou --help." >&2
      exit 2
      ;;
  esac
done

if ! command -v gh > /dev/null 2>&1; then
  echo "ERRO: o GitHub CLI (gh) não está instalado. Veja https://cli.github.com" >&2
  exit 1
fi

if ! gh auth status > /dev/null 2>&1; then
  echo "ERRO: gh não está autenticado. Rode 'gh auth status' e 'gh auth login'." >&2
  exit 1
fi

echo "Repositório: ${REPO}"
if [ "$APPLY" -eq 1 ]; then
  echo "Modo: APLICAR (as labels que faltam serão criadas)"
else
  echo "Modo: SIMULAÇÃO (nada será alterado — use --apply para criar de fato)"
fi
echo ""

# Lista as labels existentes uma única vez. Falha aqui (rede, 403) aborta antes de
# qualquer escrita — não faz sentido tentar criar sem saber o que já existe.
if ! existing=$(gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name' 2>&1); then
  echo "ERRO: não foi possível listar as labels de ${REPO}." >&2
  echo "      Verifique a conexão e a permissão de escrita no repositório ('gh auth status')." >&2
  echo "      Detalhe: ${existing}" >&2
  exit 1
fi

label_exists() {
  local needle="$1"
  local name
  while IFS= read -r name; do
    [ "$name" = "$needle" ] && return 0
  done <<< "$existing"
  return 1
}

created=0
skipped=0
failed=0

for entry in "${TRIAGE_LABELS[@]}"; do
  IFS='|' read -r name color description <<< "$entry"

  if label_exists "$name"; then
    echo "  = ${name} — já existe, nada a fazer"
    skipped=$((skipped + 1))
    continue
  fi

  if [ "$APPLY" -eq 0 ]; then
    echo "  + ${name} — SERIA CRIADA (cor #${color}, \"${description}\")"
    created=$((created + 1))
    continue
  fi

  if output=$(gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$description" 2>&1); then
    echo "  + ${name} — criada (cor #${color})"
    created=$((created + 1))
  else
    echo "  ! ${name} — FALHOU: ${output}" >&2
    failed=$((failed + 1))
  fi
done

echo ""
if [ "$APPLY" -eq 1 ]; then
  echo "Resumo: ${created} criada(s) · ${skipped} já existente(s) · ${failed} falha(s)"
else
  echo "Resumo: ${created} seria(m) criada(s) · ${skipped} já existente(s)"
  echo "Nada foi alterado. Rode de novo com --apply para criar."
fi

if [ "$failed" -gt 0 ]; then
  echo "Alguma label falhou. O script é idempotente: corrija o problema e rode de novo." >&2
  exit 1
fi
