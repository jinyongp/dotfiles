# Semantic prompt styling helpers.

prompt::style() {
  local text="$1"
  shift || true

  if declare -F dotfiles_style >/dev/null 2>&1; then
    dotfiles_style "$text" "$@"
  else
    printf '%s' "$text"
  fi
}

prompt::frame() {
  if declare -F dotfiles_frame >/dev/null 2>&1; then
    dotfiles_frame "$1"
  else
    prompt::style "$1" dim fg=245
  fi
}

prompt::title() {
  if declare -F dotfiles_heading >/dev/null 2>&1; then
    dotfiles_heading "$1"
  else
    prompt::style "$1" bold bright-white
  fi
}

prompt::body() {
  if declare -F dotfiles_body >/dev/null 2>&1; then
    dotfiles_body "$1"
  else
    prompt::style "$1" bright-white
  fi
}

prompt::value() {
  if declare -F dotfiles_value >/dev/null 2>&1; then
    dotfiles_value "$1"
  else
    prompt::style "$1" bold bright-cyan
  fi
}

prompt::accent() {
  if declare -F dotfiles_accent >/dev/null 2>&1; then
    dotfiles_accent "$1"
  else
    prompt::style "$1" bold blue
  fi
}

prompt::success() {
  if declare -F dotfiles_success >/dev/null 2>&1; then
    dotfiles_success "$1"
  else
    prompt::style "$1" bold green
  fi
}

prompt::warning() {
  if declare -F dotfiles_warning >/dev/null 2>&1; then
    dotfiles_warning "$1"
  else
    prompt::style "$1" bold magenta
  fi
}

prompt::danger() {
  if declare -F dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$1"
  else
    prompt::style "$1" bold red
  fi
}

prompt::muted() {
  if declare -F dotfiles_muted >/dev/null 2>&1; then
    dotfiles_muted "$1"
  else
    prompt::style "$1" dim fg=245
  fi
}

prompt::subtle() {
  if declare -F dotfiles_subtle >/dev/null 2>&1; then
    dotfiles_subtle "$1"
  else
    prompt::style "$1" fg=246
  fi
}

prompt::hint() {
  if declare -F dotfiles_hint >/dev/null 2>&1; then
    dotfiles_hint "$1"
  else
    prompt::style "$1" dim italic fg=245
  fi
}

prompt::description() {
  if declare -F dotfiles_description >/dev/null 2>&1; then
    dotfiles_description "$1"
  else
    prompt::style "$1" fg=248
  fi
}

prompt::disabled() {
  if declare -F dotfiles_disabled >/dev/null 2>&1; then
    dotfiles_disabled "$1"
  else
    prompt::style "$1" dim fg=242
  fi
}

prompt::active_label() {
  if declare -F dotfiles_active >/dev/null 2>&1; then
    dotfiles_active "$1"
  else
    prompt::style "$1" bold underline bright-white
  fi
}

prompt::selected_label() {
  if declare -F dotfiles_selected >/dev/null 2>&1; then
    dotfiles_selected "$1"
  else
    prompt::style "$1" bold bright-green
  fi
}

prompt::selected_active_label() {
  if declare -F dotfiles_selected_active >/dev/null 2>&1; then
    dotfiles_selected_active "$1"
  else
    prompt::style "$1" bold underline green
  fi
}

prompt::keycap() {
  if declare -F dotfiles_code >/dev/null 2>&1; then
    dotfiles_code "$1"
  else
    prompt::accent "$1"
  fi
}

prompt::badge_text() {
  printf '[%s]' "$1"
}

prompt::badge() {
  local text="$1"
  local badge_text=""

  badge_text="$(prompt::badge_text "$text")"

  case "$text" in
    current) prompt::accent "$badge_text" ;;
    installed) prompt::disabled "$badge_text" ;;
    *) prompt::warning "$badge_text" ;;
  esac
}
