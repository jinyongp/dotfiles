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
  if declare -F ui::style >/dev/null 2>&1; then
    ui::style frame "$1"
    return 0
  fi

  if declare -F dotfiles_frame >/dev/null 2>&1; then
    dotfiles_frame "$1"
  else
    prompt::style "$1" dim fg=245
  fi
}

prompt::title() {
  if declare -F ui::heading >/dev/null 2>&1; then
    ui::heading "$1"
    return 0
  fi

  if declare -F dotfiles_heading >/dev/null 2>&1; then
    dotfiles_heading "$1"
  else
    prompt::style "$1" bold bright-white
  fi
}

prompt::intro_meta() {
  if prompt::is_plain_mode; then
    if declare -F ui::muted >/dev/null 2>&1; then
      ui::muted "$1"
    else
      if declare -F dotfiles_muted >/dev/null 2>&1; then
        dotfiles_muted "$1"
      else
        prompt::style "$1" dim default
      fi
    fi
    return 0
  fi

  if declare -F ui::subtle >/dev/null 2>&1; then
    ui::subtle "$1"
    return 0
  fi

  if prompt::is_plain_mode; then
    if declare -F dotfiles_muted >/dev/null 2>&1; then
      dotfiles_muted "$1"
    else
      prompt::style "$1" dim default
    fi
    return 0
  fi

  if declare -F dotfiles_subtle >/dev/null 2>&1; then
    dotfiles_subtle "$1"
  else
    prompt::style "$1" italic blue
  fi
}

prompt::body() {
  if declare -F ui::body >/dev/null 2>&1; then
    ui::body "$1"
    return 0
  fi

  if declare -F dotfiles_body >/dev/null 2>&1; then
    dotfiles_body "$1"
  else
    prompt::style "$1" bright-white
  fi
}

prompt::value() {
  if declare -F ui::style >/dev/null 2>&1; then
    ui::style value "$1"
    return 0
  fi

  if declare -F dotfiles_value >/dev/null 2>&1; then
    dotfiles_value "$1"
  else
    prompt::style "$1" bold bright-cyan
  fi
}

prompt::accent() {
  if declare -F ui::accent >/dev/null 2>&1; then
    ui::accent "$1"
    return 0
  fi

  if declare -F dotfiles_accent >/dev/null 2>&1; then
    dotfiles_accent "$1"
  else
    prompt::style "$1" bold blue
  fi
}

prompt::success() {
  if declare -F ui::success >/dev/null 2>&1; then
    ui::success "$1"
    return 0
  fi

  if declare -F dotfiles_success >/dev/null 2>&1; then
    dotfiles_success "$1"
  else
    prompt::style "$1" bold green
  fi
}

prompt::warning() {
  if declare -F ui::warning >/dev/null 2>&1; then
    ui::warning "$1"
    return 0
  fi

  if declare -F dotfiles_warning >/dev/null 2>&1; then
    dotfiles_warning "$1"
  else
    prompt::style "$1" bold magenta
  fi
}

prompt::danger() {
  if declare -F ui::error >/dev/null 2>&1; then
    ui::error "$1"
    return 0
  fi

  if declare -F dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$1"
  else
    prompt::style "$1" bold red
  fi
}

prompt::muted() {
  if declare -F ui::muted >/dev/null 2>&1; then
    ui::muted "$1"
    return 0
  fi

  if declare -F dotfiles_muted >/dev/null 2>&1; then
    dotfiles_muted "$1"
  else
    prompt::style "$1" dim fg=245
  fi
}

prompt::subtle() {
  if declare -F ui::subtle >/dev/null 2>&1; then
    ui::subtle "$1"
    return 0
  fi

  if declare -F dotfiles_subtle >/dev/null 2>&1; then
    dotfiles_subtle "$1"
  else
    prompt::style "$1" fg=246
  fi
}

prompt::hint() {
  if prompt::is_plain_mode; then
    if declare -F ui::muted >/dev/null 2>&1; then
      ui::muted "$1"
    else
      if declare -F dotfiles_muted >/dev/null 2>&1; then
        dotfiles_muted "$1"
      else
        prompt::style "$1" dim default
      fi
    fi
    return 0
  fi

  if declare -F ui::hint >/dev/null 2>&1; then
    ui::hint "$1"
    return 0
  fi

  if prompt::is_plain_mode; then
    if declare -F dotfiles_muted >/dev/null 2>&1; then
      dotfiles_muted "$1"
    else
      prompt::style "$1" dim default
    fi
    return 0
  fi

  if declare -F dotfiles_hint >/dev/null 2>&1; then
    dotfiles_hint "$1"
  else
    prompt::style "$1" dim italic fg=245
  fi
}

prompt::description() {
  if declare -F ui::description >/dev/null 2>&1; then
    ui::description "$1"
    return 0
  fi

  if declare -F dotfiles_description >/dev/null 2>&1; then
    dotfiles_description "$1"
  else
    prompt::style "$1" fg=248
  fi
}

prompt::disabled() {
  if declare -F ui::disabled >/dev/null 2>&1; then
    ui::disabled "$1"
    return 0
  fi

  if declare -F dotfiles_disabled >/dev/null 2>&1; then
    dotfiles_disabled "$1"
  else
    prompt::style "$1" dim fg=242
  fi
}

prompt::active_label() {
  if prompt::is_plain_mode; then
    if declare -F ui::style >/dev/null 2>&1; then
      ui::style active "$1"
      return 0
    fi

    if declare -F dotfiles_style >/dev/null 2>&1; then
      dotfiles_style "$1" bold default
    else
      prompt::style "$1" bold bright-white
    fi
    return 0
  fi

  if declare -F dotfiles_active >/dev/null 2>&1; then
    dotfiles_active "$1"
  else
    prompt::style "$1" bold underline bright-white
  fi
}

prompt::selected_label() {
  if declare -F ui::selected >/dev/null 2>&1; then
    ui::selected "$1"
    return 0
  fi

  if declare -F dotfiles_selected >/dev/null 2>&1; then
    dotfiles_selected "$1"
  else
    prompt::style "$1" bold bright-green
  fi
}

prompt::selected_active_label() {
  if prompt::is_plain_mode; then
    if declare -F ui::style >/dev/null 2>&1; then
      ui::style selected_active "$1"
      return 0
    fi

    if declare -F dotfiles_selected >/dev/null 2>&1; then
      dotfiles_selected "$1"
    else
      prompt::style "$1" bold green
    fi
    return 0
  fi

  if declare -F dotfiles_selected_active >/dev/null 2>&1; then
    dotfiles_selected_active "$1"
  else
    prompt::style "$1" bold underline green
  fi
}

prompt::keycap() {
  if declare -F ui::code >/dev/null 2>&1; then
    ui::code "$1"
    return 0
  fi

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

  if declare -F ui::badge >/dev/null 2>&1; then
    ui::badge "$text"
    return 0
  fi

  badge_text="$(prompt::badge_text "$text")"

  case "$text" in
    current) prompt::subtle "$badge_text" ;;
    installed) prompt::disabled "$badge_text" ;;
    *) prompt::muted "$badge_text" ;;
  esac
}
