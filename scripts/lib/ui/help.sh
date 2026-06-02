#!/usr/bin/env bash

if [[ -z "${UI_HELP_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    UI_HELP_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    UI_HELP_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if ! typeset -f ui::report_section >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$UI_HELP_LIB_DIR/message.sh"
fi

ui::help_start() {
  local title="$1"
  local summary="${2:-}"

  printf '%s\n' "$(ui::heading "$title")"
  if [[ -n "$summary" ]]; then
    printf '%s\n' "$(ui::body "$summary")"
  fi
}

ui::help_usage() {
  ui::report_section "Usage:" "$@"
}

ui::help_records() {
  local title="$1"
  shift || true
  local record id label description line
  local -a lines=()

  for record in "$@"; do
    IFS=$'\t' read -r id label description <<<"$record"
    [[ -n "$id" ]] || continue
    if [[ -n "$description" ]]; then
      line="$(ui::align_pair "$(ui::code "$id")" "$description" 18)"
    elif [[ -n "$label" ]]; then
      line="$(ui::align_pair "$(ui::code "$id")" "$label" 18)"
    else
      line="$(ui::code "$id")"
    fi
    lines+=("$line")
  done

  if (( ${#lines[@]} == 0 )); then
    return 0
  fi

  ui::report_section "$title" "${lines[@]}"
}

ui::help_commands() {
  ui::help_records "Commands:" "$@"
}

ui::help_options() {
  ui::help_records "Options:" "$@"
}

ui::help_examples() {
  ui::report_section "Examples:" "$@"
}

ui::help_environment() {
  ui::help_records "Environment:" "$@"
}

ui::help_render() {
  return 0
}
