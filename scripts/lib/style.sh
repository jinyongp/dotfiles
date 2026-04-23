#!/usr/bin/env bash

if [[ -z "${DOTFILES_STYLE_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    DOTFILES_STYLE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    DOTFILES_STYLE_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

dotfiles__style_lib_dir() {
  [[ -n "${DOTFILES_STYLE_LIB_DIR:-}" ]] || return 1
  printf '%s' "$DOTFILES_STYLE_LIB_DIR"
}

dotfiles__style_source_ansi() {
  local ansi_path=""
  local style_lib_dir=""

  if typeset -f dotfiles_ansi_apply >/dev/null 2>&1; then
    return 0
  fi

  if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ansi.sh" ]]; then
    ansi_path="$DOTFILES_ROOT/scripts/lib/ansi.sh"
  else
    style_lib_dir="$(dotfiles__style_lib_dir)" || return 1
    ansi_path="$style_lib_dir/ansi.sh"
  fi

  # shellcheck disable=SC1090
  source "$ansi_path"
}

dotfiles__style_source_ansi || return 1

dotfiles_color_enabled() {
  dotfiles_ansi_enabled
}

dotfiles_link_enabled() {
  dotfiles_ansi_link_enabled
}

dotfiles_terminal_background() {
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

dotfiles__palette_accent_token() {
  case "$(dotfiles_terminal_background)" in
    dark) printf 'bright-cyan' ;;
    *) printf 'blue' ;;
  esac
}

dotfiles__palette_success_token() {
  case "$(dotfiles_terminal_background)" in
    dark) printf 'bright-green' ;;
    *) printf 'green' ;;
  esac
}

dotfiles__palette_warning_token() {
  case "$(dotfiles_terminal_background)" in
    dark) printf 'bright-yellow' ;;
    *) printf 'magenta' ;;
  esac
}

dotfiles__palette_error_token() {
  case "$(dotfiles_terminal_background)" in
    dark) printf 'bright-red' ;;
    *) printf 'red' ;;
  esac
}

dotfiles__palette_link_token() {
  case "$(dotfiles_terminal_background)" in
    dark) printf 'cyan' ;;
    *) printf 'blue' ;;
  esac
}

dotfiles__palette_code_token() {
  case "$(dotfiles_terminal_background)" in
    dark) printf 'bright-blue' ;;
    *) printf 'blue' ;;
  esac
}

dotfiles_style() {
  dotfiles_ansi_apply "$@"
}

dotfiles_link() {
  local text="$1"
  local target="${2:-$1}"

  if dotfiles_link_enabled; then
    dotfiles_ansi_link "$text" "$target"
    return 0
  fi

  dotfiles_style "$text" underline "$(dotfiles__palette_link_token)"
}

dotfiles_muted() {
  dotfiles_style "$1" dim default
}

dotfiles_subtle() {
  dotfiles_style "$1" default
}

dotfiles_accent() {
  dotfiles_style "$1" bold "$(dotfiles__palette_accent_token)"
}

dotfiles_success() {
  dotfiles_style "$1" bold "$(dotfiles__palette_success_token)"
}

dotfiles_warning() {
  dotfiles_style "$1" bold "$(dotfiles__palette_warning_token)"
}

dotfiles_error() {
  dotfiles_style "$1" bold "$(dotfiles__palette_error_token)"
}

dotfiles_code() {
  dotfiles_style "$1" bold "$(dotfiles__palette_code_token)"
}

dotfiles_path() {
  dotfiles_style "$1" underline default
}

dotfiles_heading() {
  dotfiles_style "$1" bold default
}

dotfiles_body() {
  dotfiles_style "$1" default
}

dotfiles_value() {
  dotfiles_style "$1" bold default
}

dotfiles_frame() {
  dotfiles_style "$1" dim default
}

dotfiles_hint() {
  dotfiles_style "$1" dim italic default
}

dotfiles_description() {
  dotfiles_style "$1" dim default
}

dotfiles_disabled() {
  dotfiles_style "$1" dim default
}

dotfiles_active() {
  dotfiles_style "$1" default
}

dotfiles_selected() {
  dotfiles_style "$1" "$(dotfiles__palette_success_token)"
}

dotfiles_selected_active() {
  dotfiles_style "$1" "$(dotfiles__palette_success_token)"
}

while read -r color_name style_tokens; do
  [[ -n "$color_name" ]] || continue
  eval "${color_name}() { dotfiles_style \"\$*\" ${style_tokens}; }"
done <<'EOF'
black black
red red
green green
yellow yellow
blue blue
purple purple
cyan cyan
white white
b_black bold black
b_red bold red
b_green bold green
b_yellow bold yellow
b_blue bold blue
b_purple bold purple
b_cyan bold cyan
b_white bold white
t_black dim black
t_red dim red
t_green dim green
t_yellow dim yellow
t_blue dim blue
t_purple dim purple
t_cyan dim cyan
t_white dim white
i_black italic black
i_red italic red
i_green italic green
i_yellow italic yellow
i_blue italic blue
i_purple italic purple
i_cyan italic cyan
i_white italic white
u_black underline black
u_red underline red
u_green underline green
u_yellow underline yellow
u_blue underline blue
u_purple underline purple
u_cyan underline cyan
u_white underline white
bg_black bg-black
bg_red bg-red
bg_green bg-green
bg_yellow bg-yellow
bg_blue bg-blue
bg_purple bg-purple
bg_cyan bg-cyan
bg_white bg-white
EOF
