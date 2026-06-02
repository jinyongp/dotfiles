#!/usr/bin/env bash

if [[ -z "${UI_TOKENS_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    UI_TOKENS_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    UI_TOKENS_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

ui::__source() {
  local file_name="$1"
  local file_path=""

  if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ui/$file_name" ]]; then
    file_path="$DOTFILES_ROOT/scripts/lib/ui/$file_name"
  else
    file_path="$UI_TOKENS_LIB_DIR/$file_name"
  fi

  # shellcheck disable=SC1090
  source "$file_path"
}

if ! typeset -f ui::apply >/dev/null 2>&1; then
  ui::__source ansi.sh
fi

if ! typeset -f ui::terminal_background >/dev/null 2>&1; then
  ui::__source mode.sh
fi

ui::__palette_accent_token() {
  case "$(ui::terminal_background)" in
    dark) printf 'bright-green' ;;
    *) printf 'green' ;;
  esac
}

ui::__palette_success_token() {
  case "$(ui::terminal_background)" in
    dark) printf 'bright-green' ;;
    *) printf 'green' ;;
  esac
}

ui::__palette_warning_token() {
  case "$(ui::terminal_background)" in
    dark) printf 'bright-yellow' ;;
    *) printf 'magenta' ;;
  esac
}

ui::__palette_error_token() {
  case "$(ui::terminal_background)" in
    dark) printf 'bright-red' ;;
    *) printf 'red' ;;
  esac
}

ui::__palette_link_token() {
  case "$(ui::terminal_background)" in
    dark) printf 'green' ;;
    *) printf 'green' ;;
  esac
}

ui::__palette_code_token() {
  case "$(ui::terminal_background)" in
    dark) printf 'bright-green' ;;
    *) printf 'green' ;;
  esac
}

ui::style() {
  local token="$1"
  local text="$2"
  shift 2 || true

  case "$token" in
    heading) ui::apply "$text" bold default ;;
    body) printf '%s' "$text" ;;
    muted) ui::apply "$text" dim default ;;
    subtle) printf '%s' "$text" ;;
    accent) ui::apply "$text" bold "$(ui::__palette_accent_token)" ;;
    success) ui::apply "$text" bold "$(ui::__palette_success_token)" ;;
    warning) ui::apply "$text" bold "$(ui::__palette_warning_token)" ;;
    error) ui::apply "$text" bold "$(ui::__palette_error_token)" ;;
    code) ui::apply "$text" "$(ui::__palette_code_token)" ;;
    path) ui::apply "$text" underline default ;;
    link)
      ui::link "$text" "${1:-$text}"
      ;;
    table_header) ui::apply "$text" dim underline default ;;
    frame) ui::apply "$text" dim default ;;
    hint) ui::apply "$text" dim italic default ;;
    description) ui::apply "$text" dim default ;;
    disabled) ui::apply "$text" dim default ;;
    active) printf '%s' "$text" ;;
    selected) ui::apply "$text" "$(ui::__palette_success_token)" ;;
    selected_active) ui::apply "$text" "$(ui::__palette_success_token)" ;;
    value) ui::apply "$text" bold default ;;
    *) ui::apply "$text" "$token" "$@" ;;
  esac
}

ui::heading() { ui::style heading "$1"; }
ui::body() { ui::style body "$1"; }
ui::muted() { ui::style muted "$1"; }
ui::subtle() { ui::style subtle "$1"; }
ui::accent() { ui::style accent "$1"; }
ui::success() { ui::style success "$1"; }
ui::warning() { ui::style warning "$1"; }
ui::error() { ui::style error "$1"; }
ui::code() { ui::style code "$1"; }
ui::path() { ui::style path "$1"; }
ui::link_text() { ui::style link "$1" "${2:-$1}"; }
ui::hint() { ui::style hint "$1"; }
ui::description() { ui::style description "$1"; }
ui::disabled() { ui::style disabled "$1"; }
ui::active() { ui::style active "$1"; }
ui::selected() { ui::style selected "$1"; }

dotfiles_color_enabled() { ui::ansi_enabled; }
dotfiles_link_enabled() { ui::link_enabled; }
dotfiles_terminal_background() { ui::terminal_background; }
dotfiles_style() { ui::apply "$@"; }
dotfiles_link() { ui::style link "$1" "${2:-$1}"; }
dotfiles_muted() { ui::muted "$1"; }
dotfiles_subtle() { ui::subtle "$1"; }
dotfiles_accent() { ui::accent "$1"; }
dotfiles_success() { ui::success "$1"; }
dotfiles_warning() { ui::warning "$1"; }
dotfiles_error() { ui::error "$1"; }
dotfiles_code() { ui::code "$1"; }
dotfiles_path() { ui::path "$1"; }
dotfiles_heading() { ui::heading "$1"; }
dotfiles_body() { ui::body "$1"; }
dotfiles_value() { ui::style value "$1"; }
dotfiles_frame() { ui::style frame "$1"; }
dotfiles_hint() { ui::hint "$1"; }
dotfiles_description() { ui::description "$1"; }
dotfiles_disabled() { ui::disabled "$1"; }
dotfiles_active() { ui::active "$1"; }
dotfiles_selected() { ui::selected "$1"; }
dotfiles_selected_active() { ui::style selected_active "$1"; }
