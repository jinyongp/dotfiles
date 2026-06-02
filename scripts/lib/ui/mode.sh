#!/usr/bin/env bash

if [[ -z "${UI_MODE_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    UI_MODE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    UI_MODE_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if ! typeset -f ui::env_mode >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$UI_MODE_LIB_DIR/environment.sh"
fi

ui::mode() {
  ui::env_mode
}

ui::is_json() {
  [[ "$(ui::mode)" == "json" ]]
}

ui::is_plain() {
  ui::env_plain_symbols_enabled
}

ui::terminal_lines() {
  local lines=""
  local stty_size=""

  if command -v tput >/dev/null 2>&1; then
    lines="$(tput lines 2>/dev/null || true)"
  fi

  if [[ ! "$lines" =~ ^[0-9]+$ ]] || [[ "$lines" -le 0 ]]; then
    stty_size="$(stty size 2>/dev/null || true)"
    if [[ "$stty_size" =~ ^[0-9]+[[:space:]][0-9]+$ ]]; then
      lines="${stty_size%% *}"
    fi
  fi

  if [[ ! "$lines" =~ ^[0-9]+$ ]] || [[ "$lines" -le 0 ]]; then
    lines=24
  fi

  printf '%s' "$lines"
}

ui::terminal_columns() {
  local columns=""
  local stty_size=""

  if command -v tput >/dev/null 2>&1; then
    columns="$(tput cols 2>/dev/null || true)"
  fi

  if [[ ! "$columns" =~ ^[0-9]+$ ]] || [[ "$columns" -le 0 ]]; then
    stty_size="$(stty size 2>/dev/null || true)"
    if [[ "$stty_size" =~ ^[0-9]+[[:space:]][0-9]+$ ]]; then
      columns="${stty_size##* }"
    fi
  fi

  if [[ ! "$columns" =~ ^[0-9]+$ ]] || [[ "$columns" -le 0 ]]; then
    columns=80
  fi

  printf '%s' "$columns"
}

ui::terminal_background() {
  ui::env_terminal_background
}

ui::symbol() {
  local name="$1"
  local plain=0

  ui::is_plain && plain=1

  if [[ "$plain" -eq 1 ]]; then
    case "$name" in
      question) printf '>' ;;
      completed) printf '=' ;;
      select_current) printf '*' ;;
      select_idle) printf 'o' ;;
      checkbox_on) printf '[x]' ;;
      checkbox_off) printf '[ ]' ;;
      cursor) printf '>' ;;
      bullet) printf '-' ;;
      more_up) printf '^' ;;
      more_down) printf 'v' ;;
      status_separator) printf ' ' ;;
      *) printf '%s' "$name" ;;
    esac
    return 0
  fi

  case "$name" in
    question) printf '◆' ;;
    completed) printf '◇' ;;
    select_current) printf '●' ;;
    select_idle) printf '○' ;;
    checkbox_on) printf '◼' ;;
    checkbox_off) printf '◻' ;;
    cursor) printf '›' ;;
    bullet) printf '•' ;;
    more_up) printf '↑' ;;
    more_down) printf '↓' ;;
    status_separator) printf ' ' ;;
    *) printf '%s' "$name" ;;
  esac
}
