#!/usr/bin/env bash

if [[ -z "${UI_MESSAGE_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    UI_MESSAGE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    UI_MESSAGE_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if ! typeset -f ui::status >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$UI_MESSAGE_LIB_DIR/format.sh"
fi

ui::json_escape() {
  local value="$1"

  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$value" | python3 -c 'import json, sys; sys.stdout.write(json.dumps(sys.stdin.read(), ensure_ascii=False)[1:-1])'
    return 0
  fi

  if command -v perl >/dev/null 2>&1; then
    printf '%s' "$value" | perl -CS -0pe 's/\\/\\\\/g; s/"/\\"/g; s/\x08/\\b/g; s/\x0c/\\f/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g; s/([\x00-\x07\x0b\x0e-\x1f])/sprintf("\\u%04x", ord($1))/eg'
    return 0
  fi

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

ui::json_string() {
  printf '"%s"' "$(ui::json_escape "$1")"
}

ui::json_event() {
  local type="$1"
  local surface="${2:-cli}"
  local data="${3-}"

  if [[ -z "$data" ]]; then
    data="{}"
  fi

  printf '{"schema":"dotfiles.ui.v1","type":'
  ui::json_string "$type"
  printf ',"surface":'
  ui::json_string "$surface"
  printf ',"mode":"json","data":%s}\n' "$data"
}

ui::write() {
  local stream="${1:-stdout}"
  local text="${2:-}"

  if [[ "$stream" == "stderr" ]]; then
    printf '%s\n' "$text" >&2
  else
    printf '%s\n' "$text"
  fi
}

ui::info() {
  ui::write stdout "$(ui::muted "$1")"
}

ui::note() {
  ui::write stdout "$(ui::status note "$1")"
}

ui::warn() {
  ui::write stderr "$(ui::status warning "$1")"
}

ui::fail() {
  ui::write stderr "$(ui::status failed "$1")"
}

ui::step() {
  printf '\n'
  ui::write stdout "$(ui::accent "$(ui::symbol question)")  $(ui::heading "$1")"
}

ui::report_section() {
  local title="$1"
  shift || true
  local line
  local -a lines=()

  for line in "$@"; do
    [[ -n "$line" ]] || continue
    lines+=("$line")
  done

  if (( ${#lines[@]} == 0 )); then
    return 0
  fi

  printf '\n%s\n' "$(ui::section "$title")"
  for line in "${lines[@]}"; do
    printf '%s\n' "$(ui::list_item "$line")"
  done
}

ui::record_section() {
  ui::report_section "$@"
}
