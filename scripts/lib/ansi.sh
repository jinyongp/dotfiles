#!/usr/bin/env bash

dotfiles_ansi_reset=$'\033[0m'
# shellcheck disable=SC2034
dotfiles_color_reset="$dotfiles_ansi_reset"
# shellcheck disable=SC2034
reset="$dotfiles_ansi_reset"

dotfiles_ansi_enabled() {
  if [[ "${DOTFILES_FORCE_COLOR:-0}" == "1" || "${FORCE_COLOR:-0}" != "0" || "${CLICOLOR_FORCE:-0}" != "0" ]]; then
    return 0
  fi

  if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" || "${CLICOLOR:-1}" == "0" ]]; then
    return 1
  fi

  [[ -t 1 ]]
}

dotfiles_ansi_link_enabled() {
  dotfiles_ansi_enabled && [[ "${DOTFILES_DISABLE_OSC8:-0}" != "1" ]]
}

dotfiles_ansi_code() {
  case "$1" in
    default|default-fg|fg-default|foreground) printf '39' ;;
    default-bg|bg-default|background) printf '49' ;;
    bold) printf '1' ;;
    dim) printf '2' ;;
    italic) printf '3' ;;
    underline) printf '4' ;;
    curly-underline) printf '4:3' ;;
    blink) printf '5' ;;
    reverse) printf '7' ;;
    strikethrough) printf '9' ;;
    black) printf '30' ;;
    red) printf '31' ;;
    green) printf '32' ;;
    yellow) printf '33' ;;
    blue) printf '34' ;;
    purple|magenta) printf '35' ;;
    cyan) printf '36' ;;
    white) printf '37' ;;
    bright-black|gray|grey) printf '90' ;;
    bright-red) printf '91' ;;
    bright-green) printf '92' ;;
    bright-yellow) printf '93' ;;
    bright-blue) printf '94' ;;
    bright-purple|bright-magenta) printf '95' ;;
    bright-cyan) printf '96' ;;
    bright-white) printf '97' ;;
    bg-black) printf '40' ;;
    bg-red) printf '41' ;;
    bg-green) printf '42' ;;
    bg-yellow) printf '43' ;;
    bg-blue) printf '44' ;;
    bg-purple|bg-magenta) printf '45' ;;
    bg-cyan) printf '46' ;;
    bg-white) printf '47' ;;
    bg-bright-black|bg-gray|bg-grey) printf '100' ;;
    bg-bright-red) printf '101' ;;
    bg-bright-green) printf '102' ;;
    bg-bright-yellow) printf '103' ;;
    bg-bright-blue) printf '104' ;;
    bg-bright-purple|bg-bright-magenta) printf '105' ;;
    bg-bright-cyan) printf '106' ;;
    bg-bright-white) printf '107' ;;
    fg=*) printf '38;5;%s' "${1#fg=}" ;;
    bg=*) printf '48;5;%s' "${1#bg=}" ;;
    *) return 1 ;;
  esac
}

dotfiles_ansi_apply() {
  local text="$1"
  shift || true

  local token="" code="" sgr=""

  if ! dotfiles_ansi_enabled || [[ "$#" -eq 0 ]]; then
    printf '%s' "$text"
    return 0
  fi

  for token in "$@"; do
    code="$(dotfiles_ansi_code "$token" || true)"
    [[ -n "$code" ]] || continue
    if [[ -n "$sgr" ]]; then
      sgr="${sgr};${code}"
    else
      sgr="$code"
    fi
  done

  if [[ -z "$sgr" ]]; then
    printf '%s' "$text"
    return 0
  fi

  printf '\033[%sm%s%s' "$sgr" "$text" "$dotfiles_ansi_reset"
}

dotfiles_ansi_link() {
  local text="$1"
  local target="${2:-$1}"
  local osc8_open=$'\033]8;;'
  local osc8_close=$'\033]8;;\033\\'
  local osc8_st=$'\033\\'

  if ! dotfiles_ansi_link_enabled; then
    dotfiles_ansi_apply "$text" underline cyan
    return 0
  fi

  printf '%s%s%s%s%s' "$osc8_open" "$target" "$osc8_st" "$text" "$osc8_close"
}
