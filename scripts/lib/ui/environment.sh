#!/usr/bin/env bash

if [[ -z "${UI_ENV_STDOUT_IS_TTY:-}" ]]; then
  if [[ -t 1 ]]; then
    UI_ENV_STDOUT_IS_TTY=1
  else
    UI_ENV_STDOUT_IS_TTY=0
  fi
fi

ui::env_mode() {
  case "${DOTFILES_INSTALL_UI_MODE:-auto}" in
    auto|plain|json)
      printf '%s' "${DOTFILES_INSTALL_UI_MODE:-auto}"
      ;;
    *)
      printf 'auto'
      ;;
  esac
}

ui::env_color_enabled() {
  case "$(ui::env_mode)" in
    plain|json) return 1 ;;
  esac

  if [[ -n "${NO_COLOR:-}" ]]; then
    return 1
  fi

  if [[ "${FORCE_COLOR:-0}" != "0" || "${CLICOLOR_FORCE:-0}" != "0" ]]; then
    return 0
  fi

  if [[ "${CLICOLOR:-1}" == "0" || "${TERM:-}" == "dumb" ]]; then
    return 1
  fi

  if [[ "${DOTFILES_COLOR_OUTPUT_IS_TTY:-0}" == "1" ]]; then
    return 0
  fi

  [[ "${UI_ENV_STDOUT_IS_TTY:-0}" == "1" ]]
}

ui::env_osc8_enabled() {
  ui::env_color_enabled && [[ "${DOTFILES_DISABLE_OSC8:-0}" != "1" ]]
}

ui::env_plain_symbols_enabled() {
  [[ "$(ui::env_mode)" == "plain" || "${TERM:-}" == "dumb" ]]
}

ui::env_terminal_background() {
  local override="${DOTFILES_COLOR_SCHEME:-}"
  local colorfgbg="${COLORFGBG:-}"
  local background_code=""

  case "$override" in
    light|dark)
      printf '%s' "$override"
      return 0
      ;;
  esac

  if [[ "$colorfgbg" == *";"* ]]; then
    background_code="${colorfgbg##*;}"
    if [[ "$background_code" =~ ^[0-9]+$ ]]; then
      if (( background_code >= 0 && background_code <= 6 )); then
        printf 'dark'
        return 0
      fi
      if (( background_code >= 7 && background_code <= 15 )); then
        printf 'light'
        return 0
      fi
    fi
  fi

  printf 'unknown'
}
