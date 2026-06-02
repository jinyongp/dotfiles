#!/usr/bin/env bash

if [[ -z "${UI_ERRORS_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    UI_ERRORS_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    UI_ERRORS_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if ! typeset -f ui::json_event >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$UI_ERRORS_LIB_DIR/message.sh"
fi

ui::error_start() {
  printf '%s\n' "$(ui::error "Error: $1")" >&2
}

ui::error_field() {
  local label="$1"
  local value="$2"

  [[ -n "$value" ]] || return 0
  printf '%s\n' "$(ui::line "$(ui::kv "$label" "$value")")" >&2
}

ui::error_usage() {
  ui::error_field usage "$1"
}

ui::error_next() {
  ui::error_field next "$1"
}

ui::error_render() {
  return 0
}

ui::validation_error() {
  local message="$1"
  shift || true
  local record label value json_fields="" escaped_label escaped_value

  if ui::is_json; then
    for record in "$@"; do
      IFS=$'\t' read -r label value <<<"$record"
      [[ -n "$label" ]] || continue
      escaped_label="$(ui::json_escape "$label")"
      escaped_value="$(ui::json_escape "$value")"
      json_fields="${json_fields}${json_fields:+,}\"$escaped_label\":\"$escaped_value\""
    done
    ui::json_event validation_error cli "{\"message\":\"$(ui::json_escape "$message")\",\"fields\":{${json_fields}}}" >&2
    return 0
  fi

  ui::error_start "$message"
  for record in "$@"; do
    IFS=$'\t' read -r label value <<<"$record"
    case "$label" in
      usage) ui::error_usage "$value" ;;
      next) ui::error_next "$value" ;;
      *) ui::error_field "$label" "$value" ;;
    esac
  done
}

ui::input_required() {
  local message="$1"
  shift || true
  local record label value json_fields="" escaped_label escaped_value

  if ui::is_json; then
    for record in "$@"; do
      IFS=$'\t' read -r label value <<<"$record"
      [[ -n "$label" ]] || continue
      escaped_label="$(ui::json_escape "$label")"
      escaped_value="$(ui::json_escape "$value")"
      json_fields="${json_fields}${json_fields:+,}\"$escaped_label\":\"$escaped_value\""
    done
    ui::json_event input_required cli "{\"message\":\"$(ui::json_escape "$message")\",\"fields\":{${json_fields}}}" >&2
    return 0
  fi

  ui::error_start "$message"
  for record in "$@"; do
    IFS=$'\t' read -r label value <<<"$record"
    case "$label" in
      usage) ui::error_usage "$value" ;;
      next) ui::error_next "$value" ;;
      *) ui::error_field "$label" "$value" ;;
    esac
  done
}
