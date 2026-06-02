#!/usr/bin/env bash

if [[ -z "${UI_FORMAT_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    UI_FORMAT_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    UI_FORMAT_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if ! typeset -f ui::style >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$UI_FORMAT_LIB_DIR/tokens.sh"
fi

ui::line() {
  printf '   %s' "$1"
}

ui::blank() {
  printf ''
}

ui::section() {
  ui::heading "$1"
}

ui::title() {
  local title="$1"
  local summary="${2:-}"

  printf '%s\n' "$(ui::heading "$title")"
  if [[ -n "$summary" ]]; then
    printf '%s\n' "$(ui::description "$summary")"
  fi
}

ui::list_item() {
  printf '  %s %s' "$(ui::muted "$(ui::symbol bullet)")" "$1"
}

ui::row() {
  local left="$1"
  local right="${2:-}"
  local width="${3:-18}"

  ui::align_pair "$left" "$right" "$width"
}

ui::kv() {
  local label="$1"
  local value="$2"

  printf '%s %s' "$(ui::muted "${label}:")" "$(ui::body "$value")"
}

ui::field() {
  local label="$1"
  local value="$2"
  local kind="${3:-body}"
  local rendered_value=""

  case "$kind" in
    code|command) rendered_value="$(ui::code "$value")" ;;
    path) rendered_value="$(ui::path "$value")" ;;
    value) rendered_value="$(ui::style value "$value")" ;;
    muted|description) rendered_value="$(ui::description "$value")" ;;
    *) rendered_value="$(ui::body "$value")" ;;
  esac

  printf '%s %s' "$(ui::muted "${label}:")" "$rendered_value"
}

ui::command() {
  ui::code "$1"
}

ui::path_value() {
  ui::path "$1"
}

ui::status_label() {
  local state="$1"
  local label=""
  local padded=""

  case "$state" in
    starting) label="starting" ;;
    checking) label="checking" ;;
    installing) label="installing" ;;
    installed) label="installed" ;;
    reused) label="reused" ;;
    skipped) label="skipped" ;;
    completed) label="completed" ;;
    warning) label="warning" ;;
    failed) label="failed" ;;
    note) label="note" ;;
    *) label="$state" ;;
  esac

  printf -v padded '%-10s' "$label"

  case "$state" in
    starting|checking|installing|reused) ui::accent "$padded" ;;
    installed|completed) ui::success "$padded" ;;
    skipped|note) ui::muted "$padded" ;;
    warning) ui::warning "$padded" ;;
    failed) ui::error "$padded" ;;
    *) ui::body "$padded" ;;
  esac
}

ui::status() {
  local state="$1"
  local message="$2"

  ui::line "$(ui::status_label "$state") $message"
}

ui::badge() {
  local text="$1"
  local badge_text="[$text]"

  case "$text" in
    current) ui::subtle "$badge_text" ;;
    installed) ui::disabled "$badge_text" ;;
    *) ui::muted "$badge_text" ;;
  esac
}

ui::align_pair() {
  local left="$1"
  local right="$2"
  local width="${3:-0}"
  local visible_left padding_width padding=""

  visible_left="$(ui::strip_ansi "$left")"
  if [[ "$width" -le 0 ]]; then
    printf '%s %s' "$left" "$right"
    return 0
  fi

  padding_width=$((width - ${#visible_left} + 1))
  if [[ "$padding_width" -lt 1 ]]; then
    padding_width=1
  fi
  printf -v padding '%*s' "$padding_width" ''
  printf '%s%s%s' "$left" "$padding" "$right"
}
