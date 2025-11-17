#!/usr/bin/env bash

if [[ -z "${LINUX_SOS_ROOT:-}" ]]; then
  echo "[linux-sos] LINUX_SOS_ROOT não definido." >&2
  exit 1
fi

if [[ -z "${BASH_VERSINFO:-}" || ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo "[linux-sos] Bash 4+ é necessário." >&2
  exit 1
fi

# Global registries ---------------------------------------------------------
declare -a SOS_CHECK_ORDER=()
declare -A SOS_CHECK_CATEGORY=()
declare -A SOS_CHECK_PRIORITY=()
declare -A SOS_CHECK_DESCRIPTION=()
declare -A SOS_CHECK_FUNC=()
declare -A SOS_CHECK_FIX_ID=()

declare -A SOS_FIX_FUNC=()
declare -A SOS_FIX_DESCRIPTION=()

declare -A SOS_DSL_CHECK_BLOCKS=()
declare -A SOS_DSL_FIX_BLOCKS=()

declare -A SOS_LOADED_FILES=()

# Runtime flags -------------------------------------------------------------
SOS_OUTPUT_JSON=0
SOS_FILTER_CATEGORY=""
SOS_ENABLE_FIX_PROMPTS=0
SOS_ASSUME_YES=0
SOS_REQUESTED_CHECK=""
SOS_LIST_ONLY=0

# Result scratchpad ---------------------------------------------------------
SOS_RESULT_STATUS=""
SOS_RESULT_PROB=""
SOS_RESULT_MESSAGE=""
declare -a SOS_RESULT_SUGGESTIONS=()

LINUX_SOS_DISTRO_ID="unknown"
LINUX_SOS_DISTRO_FAMILY="unknown"

# CLI entry -----------------------------------------------------------------
sos_main() {
  __sos_init_state
  __sos_parse_args "$@"
  sos_detect_distro
  sos_load_modules

  if (( SOS_LIST_ONLY )); then
    sos_print_registered_checks
    return 0
  fi

  sos_run_checks
}

__sos_init_state() {
  SOS_CHECK_ORDER=()
  SOS_CHECK_CATEGORY=()
  SOS_CHECK_PRIORITY=()
  SOS_CHECK_DESCRIPTION=()
  SOS_CHECK_FUNC=()
  SOS_CHECK_FIX_ID=()
  SOS_FIX_FUNC=()
  SOS_FIX_DESCRIPTION=()
  SOS_DSL_CHECK_BLOCKS=()
  SOS_DSL_FIX_BLOCKS=()
  SOS_LOADED_FILES=()
}

__sos_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json)
        SOS_OUTPUT_JSON=1
        ;;
      --category)
        shift
        SOS_FILTER_CATEGORY="${1:-}"
        ;;
      --check)
        shift
        SOS_REQUESTED_CHECK="${1:-}"
        ;;
      --apply)
        SOS_ENABLE_FIX_PROMPTS=1
        ;;
      --yes|-y)
        SOS_ASSUME_YES=1
        ;;
      --list-checks)
        SOS_LIST_ONLY=1
        ;;
      --help|-h)
        sos_print_help
        exit 0
        ;;
      *)
        echo "Opção desconhecida: $1" >&2
        sos_print_help >&2
        exit 1
        ;;
    esac
    shift || true
  done
}

sos_print_help() {
  cat <<'EOF'
Linux SOS - diagnósticos iniciais para Linux
Uso: linux-sos [opções]

  --category <nome>   Executa apenas checks dessa categoria.
  --check <id>        Executa apenas o check informado.
  --json              Saída JSON simples.
  --apply             Oferece correções quando disponíveis.
  --yes               Responde "sim" automaticamente para correções.
  --list-checks       Lista checks registrados e sai.
  --help              Mostra esta mensagem.
EOF
}

sos_print_registered_checks() {
  if [[ ${#SOS_CHECK_ORDER[@]} -eq 0 ]]; then
    echo "Nenhum check carregado."
    return
  fi

  printf "%-20s %-10s %-10s %s\n" "ID" "Categoria" "Prioridade" "Descrição"
  printf '%s\n' "--------------------------------------------------------------------------------"
  local id
  for id in "${SOS_CHECK_ORDER[@]}"; do
    printf "%-20s %-10s %-10s %s\n" \
      "$id" \
      "${SOS_CHECK_CATEGORY[$id]}" \
      "${SOS_CHECK_PRIORITY[$id]}" \
      "${SOS_CHECK_DESCRIPTION[$id]}"
  done
}

# Distro detection -----------------------------------------------------------
sos_detect_distro() {
  local os_release="/etc/os-release"
  if [[ -r "$os_release" ]]; then
    # shellcheck disable=SC1091
    source "$os_release"
    LINUX_SOS_DISTRO_ID="${ID:-unknown}"
    LINUX_SOS_DISTRO_FAMILY="$(__sos_map_family "${ID_LIKE:-}" "${ID:-}")"
  fi

  if [[ "$LINUX_SOS_DISTRO_FAMILY" == "unknown" ]]; then
    LINUX_SOS_DISTRO_FAMILY="generic"
  fi

  export LINUX_SOS_DISTRO_ID
  export LINUX_SOS_DISTRO_FAMILY
}

__sos_map_family() {
  local like="$1"
  local id="$2"
  local tokens="$like $id"
  for token in $tokens; do
    case "$token" in
      *debian*|debian|ubuntu|linuxmint|pop|elementary)
        echo "debian"
        return
        ;;
      *arch*|arch|manjaro|endeavouros)
        echo "arch"
        return
        ;;
      fedora|rhel|centos|rocky|alma|suse|opensuse|mageia)
        echo "rpm"
        return
        ;;
    esac
  done
  echo "generic"
}

# Module loader --------------------------------------------------------------
sos_load_modules() {
  local modules_dir="${LINUX_SOS_ROOT}/modules"
  if [[ ! -d "$modules_dir" ]]; then
    return
  fi

  local category_dir
  for category_dir in "$modules_dir"/*; do
    [[ -d "$category_dir" ]] || continue
    local category="$(basename "$category_dir")"

    __sos_source_module "$category" "$category_dir/common.sh"
    __sos_source_module "$category" "$category_dir/${LINUX_SOS_DISTRO_FAMILY}.sh"
    __sos_source_module "$category" "$category_dir/${LINUX_SOS_DISTRO_ID}.sh"
  done
}

__sos_source_module() {
  local category="$1"
  local file="$2"
  if [[ -f "$file" && -z "${SOS_LOADED_FILES[$file]:-}" ]]; then
    SOS_LOADED_FILES[$file]=1
    LINUX_SOS_CURRENT_CATEGORY="$category"
    # shellcheck disable=SC1090
    source "$file"
    unset LINUX_SOS_CURRENT_CATEGORY
  fi
}

# Registration API -----------------------------------------------------------
sos_register_check() {
  local id="$1" category="$2" priority="$3" description="$4" func="$5" fix_id="${6:-}"
  if [[ -z "$id" || -z "$func" ]]; then
    echo "[linux-sos] Check inválido: id ou função vazios." >&2
    return 1
  fi
  if [[ -n "${SOS_CHECK_FUNC[$id]:-}" ]]; then
    echo "[linux-sos] Check '$id' já registrado, substituindo." >&2
    __sos_remove_check_from_order "$id"
  fi

  SOS_CHECK_CATEGORY[$id]="$category"
  SOS_CHECK_PRIORITY[$id]="$priority"
  SOS_CHECK_DESCRIPTION[$id]="$description"
  SOS_CHECK_FUNC[$id]="$func"
  SOS_CHECK_FIX_ID[$id]="$fix_id"

  SOS_CHECK_ORDER+=("$id")
}

__sos_remove_check_from_order() {
  local remove_id="$1"
  local -a rebuilt=()
  local existing
  for existing in "${SOS_CHECK_ORDER[@]}"; do
    [[ "$existing" == "$remove_id" ]] && continue
    rebuilt+=("$existing")
  done
  if ((${#rebuilt[@]})); then
    SOS_CHECK_ORDER=("${rebuilt[@]}")
  else
    SOS_CHECK_ORDER=()
  fi
}

sos_register_fix() {
  local id="$1" func="$2" description="${3:-}" block="${4:-}"
  if [[ -z "$id" || -z "$func" ]]; then
    echo "[linux-sos] Fix inválido." >&2
    return 1
  fi
  SOS_FIX_FUNC[$id]="$func"
  SOS_FIX_DESCRIPTION[$id]="$description"
  [[ -n "$block" ]] && SOS_DSL_FIX_BLOCKS[$id]="$block"
}

# Result helpers -------------------------------------------------------------
sos_reset_result() {
  SOS_RESULT_STATUS=""
  SOS_RESULT_PROB=""
  SOS_RESULT_MESSAGE=""
  SOS_RESULT_SUGGESTIONS=()
}

sos_set_result() {
  SOS_RESULT_STATUS="$1"
  SOS_RESULT_PROB="$2"
  SOS_RESULT_MESSAGE="$3"
  shift 3 || true
  SOS_RESULT_SUGGESTIONS=("$@")
}

sos_add_suggestion() {
  SOS_RESULT_SUGGESTIONS+=("$1")
}

# Runner ---------------------------------------------------------------------
sos_run_checks() {
  if [[ ${#SOS_CHECK_ORDER[@]} -eq 0 ]]; then
    echo "Nenhum check disponível."
    return 1
  fi

  local -a json_entries=()
  local executed=0
  local id
  for id in "${SOS_CHECK_ORDER[@]}"; do
    if [[ -n "$SOS_FILTER_CATEGORY" && "${SOS_CHECK_CATEGORY[$id]}" != "$SOS_FILTER_CATEGORY" ]]; then
      continue
    fi
    if [[ -n "$SOS_REQUESTED_CHECK" && "$id" != "$SOS_REQUESTED_CHECK" ]]; then
      continue
    fi

    __sos_run_single_check "$id"
    executed=$((executed + 1))

    json_entries+=("$(__sos_result_to_json "$id")")
    if (( SOS_OUTPUT_JSON )); then
      continue
    fi
    __sos_print_human_result "$id"
    __sos_maybe_offer_fix "$id"
  done

  if (( SOS_OUTPUT_JSON )); then
    local joined=""
    if ((${#json_entries[@]})); then
      joined="$(IFS=','; echo "${json_entries[*]}")"
    fi
    printf '[%s]\n' "$joined"
  elif (( executed == 0 )); then
    echo "Nenhum check corresponde aos filtros."
  fi
}

__sos_run_single_check() {
  local id="$1"
  local func="${SOS_CHECK_FUNC[$id]}"
  sos_reset_result
  local success=0
  local had_errexit=0
  if [[ $- == *e* ]]; then
    had_errexit=1
    set +e
  fi
  "$func" "$id"
  success=$?
  if (( had_errexit )); then
    set -e
  fi

  if [[ -z "$SOS_RESULT_STATUS" ]]; then
    if (( success == 0 )); then
      sos_set_result "ok" "baixa" "Check concluiu sem detalhes"
    else
      sos_set_result "fail" "alta" "Check retornou código $success"
    fi
  fi
}

__sos_print_human_result() {
  local id="$1"
  local category="${SOS_CHECK_CATEGORY[$id]}"
  local priority="${SOS_CHECK_PRIORITY[$id]}"
  printf '[%s][%s][%s] %s (%s)\n' \
    "$category" "$priority" "$id" "$SOS_RESULT_STATUS" "$SOS_RESULT_PROB"
  printf '  %s\n' "$SOS_RESULT_MESSAGE"
  if ((${#SOS_RESULT_SUGGESTIONS[@]})); then
    local suggestion
    printf '  Sugestões:\n'
    for suggestion in "${SOS_RESULT_SUGGESTIONS[@]}"; do
      printf '    - %s\n' "$suggestion"
    done
  fi
}

__sos_result_to_json() {
  local id="$1"
  local category="${SOS_CHECK_CATEGORY[$id]}"
  local priority="${SOS_CHECK_PRIORITY[$id]}"
  local description="${SOS_CHECK_DESCRIPTION[$id]}"
  local suggestions_json="[]"
  if ((${#SOS_RESULT_SUGGESTIONS[@]})); then
    local escaped
    local -a entries=()
    for suggestion in "${SOS_RESULT_SUGGESTIONS[@]}"; do
      escaped="$(__sos_json_escape "$suggestion")"
      entries+=("\"$escaped\"")
    done
    local joined="$(IFS=','; echo "${entries[*]}")"
    suggestions_json="[$joined]"
  fi
  printf '{"id":"%s","categoria":"%s","prioridade":"%s","descricao":"%s","status":"%s","probabilidade":"%s","mensagem":"%s","sugestoes":%s}' \
    "$(__sos_json_escape "$id")" \
    "$(__sos_json_escape "$category")" \
    "$(__sos_json_escape "$priority")" \
    "$(__sos_json_escape "$description")" \
    "$(__sos_json_escape "$SOS_RESULT_STATUS")" \
    "$(__sos_json_escape "$SOS_RESULT_PROB")" \
    "$(__sos_json_escape "$SOS_RESULT_MESSAGE")" \
    "$suggestions_json"
}

__sos_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

__sos_maybe_offer_fix() {
  local id="$1"
  local fix_id="${SOS_CHECK_FIX_ID[$id]}"
  local status="$SOS_RESULT_STATUS"

  if [[ -z "$fix_id" || -z "${SOS_FIX_FUNC[$fix_id]:-}" ]]; then
    return
  fi
  if [[ "$status" == "ok" ]]; then
    return
  fi
  if (( ! SOS_ENABLE_FIX_PROMPTS )) || (( SOS_OUTPUT_JSON )); then
    printf '  Correção disponível: %s\n' "$fix_id"
    return
  fi
  local prompt="Aplicar correção %s (%s)? [s/N]: "
  printf "$prompt" "$fix_id" "${SOS_FIX_DESCRIPTION[$fix_id]:-sem descrição}"
  local reply
  if (( SOS_ASSUME_YES )); then
    reply="s"
    printf 's (auto)\n'
  else
    read -r reply
  fi
  if [[ "$reply" =~ ^([sSyY])$ ]]; then
    __sos_run_fix "$fix_id"
  else
    printf '  Correção ignorada.\n'
  fi
}

__sos_run_fix() {
  local id="$1"
  local func="${SOS_FIX_FUNC[$id]}"
  if [[ -z "$func" ]]; then
    printf '  Fix %s indisponível.\n' "$id"
    return 1
  fi
  printf '  Executando fix %s...\n' "$id"
  local had_errexit=0
  if [[ $- == *e* ]]; then
    had_errexit=1
    set +e
  fi
  "$func" "$id"
  local rc=$?
  if (( had_errexit )); then
    set -e
  fi
  if (( rc == 0 )); then
    printf '  Correção aplicada com sucesso.\n'
  else
    printf '  Correção falhou (código %d).\n' "$rc"
  fi
}

# Mini DSL ------------------------------------------------------------------
sos_check() {
  local id="$1"
  local payload
  payload="$(cat)"
  declare -A data=()
  __sos_parse_block data "$payload"
  local category="${data[category]:-${LINUX_SOS_CURRENT_CATEGORY:-general}}"
  local priority="${data[priority]:-medium}"
  local description="${data[description]:-${data[fail_message]:-"Check $id"}}"
  local fix_id="${data[fix]:-}"
  SOS_DSL_CHECK_BLOCKS[$id]="$payload"
  sos_register_check "$id" "$category" "$priority" "$description" "__sos_run_dsl_check" "$fix_id"
}

sos_fix() {
  local id="$1"
  local payload
  payload="$(cat)"
  SOS_DSL_FIX_BLOCKS[$id]="$payload"
  declare -A data=()
  __sos_parse_block data "$payload"
  sos_register_fix "$id" "__sos_run_dsl_fix" "${data[description]:-Fix $id}" "$payload"
}

__sos_run_dsl_check() {
  local id="${1:-}"
  local payload="${SOS_DSL_CHECK_BLOCKS[$id]}"
  if [[ -z "$id" || -z "$payload" ]]; then
    sos_set_result "fail" "alta" "Check DSL '$id' não encontrado."
    return 1
  fi
  declare -A data=()
  __sos_parse_block data "$payload"
  local exec_cmd="${data[exec]:-}"
  local expect_exit="${data[expect_exit_code]:-0}"
  local expect_nonempty="${data[expect_nonempty]:-false}"
  local probability="${data[probability]:-media}"
  local success_msg="${data[success_message]:-Tudo certo.}"
  local fail_msg="${data[fail_message]:-Falha ao executar ${id}.}"
  local warn_msg="${data[warn_message]:-}"

  local output=""
  local exit_code=0
  if [[ -z "$exec_cmd" ]]; then
    sos_set_result "fail" "alta" "Check '${id}' não definiu comando."
    return 1
  fi

  local had_errexit=0
  if [[ $- == *e* ]]; then
    had_errexit=1
    set +e
  fi
  output="$(eval "$exec_cmd" 2>&1)"
  exit_code=$?
  if (( had_errexit )); then
    set -e
  fi

  local trimmed="$(echo -n "$output" | sed -e 's/^\s*//' -e 's/\s*$//')"

  local status="ok"
  local message="$success_msg"
  if (( exit_code != expect_exit )); then
    status="fail"
    message="$fail_msg (código $exit_code)"
  elif __sos_is_truthy "$expect_nonempty" && [[ -z "$trimmed" ]]; then
    status="fail"
    message="$fail_msg"
  elif [[ -n "$warn_msg" && -z "$trimmed" ]]; then
    status="warn"
    message="$warn_msg"
  fi

  local -a suggestions=()
  if [[ -n "${data[suggestions]:-}" ]]; then
    while IFS= read -r suggestion || [[ -n "$suggestion" ]]; do
      [[ -z "$suggestion" ]] && continue
      suggestions+=("$suggestion")
    done <<< "${data[suggestions]}"
  fi

  sos_set_result "$status" "$probability" "$message" "${suggestions[@]}"
}

__sos_run_dsl_fix() {
  local id="${1:-}"
  local payload="${SOS_DSL_FIX_BLOCKS[$id]}"
  if [[ -z "$id" || -z "$payload" ]]; then
    echo "Fix DSL '$id' não encontrado" >&2
    return 1
  fi
  declare -A data=()
  __sos_parse_block data "$payload"
  local exec_cmd="${data[exec]:-}"
  if [[ -z "$exec_cmd" ]]; then
    echo "Fix '${id}' não definiu exec" >&2
    return 1
  fi
  eval "$exec_cmd"
}

__sos_parse_block() {
  local -n target="$1"
  local payload="$2"
  local current_key=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(printf '%s\n' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" =~ ^([A-Za-z0-9_]+):[[:space:]]*(.*)$ ]]; then
      current_key="${BASH_REMATCH[1]}"
      target[$current_key]="${BASH_REMATCH[2]}"
      continue
    fi
    if [[ "$line" =~ ^-[[:space:]]*(.*)$ && -n "$current_key" ]]; then
      if [[ -n "${target[$current_key]:-}" ]]; then
        target[$current_key]+=$'\n'"${BASH_REMATCH[1]}"
      else
        target[$current_key]="${BASH_REMATCH[1]}"
      fi
    fi
  done <<< "$payload"
}

__sos_is_truthy() {
  local value="${1,,}"
  case "$value" in
    1|true|yes|on|y|s|sim)
      return 0
      ;;
  esac
  return 1
}
