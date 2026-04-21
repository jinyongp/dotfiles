dotfiles_has_command() {
  (( $+commands[$1] ))
}

dotfiles_source_if_exists() {
  [[ -f "$1" ]] && source "$1"
}

dotfiles_prepend_path() {
  local path_entry="$1"

  [[ -d "$path_entry" ]] || return 0

  case ":$PATH:" in
    *":$path_entry:"*) ;;
    *) export PATH="$path_entry:$PATH" ;;
  esac
}

dotfiles_brew_bin() {
  if dotfiles_has_command brew; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
    return 0
  fi

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    echo /home/linuxbrew/.linuxbrew/bin/brew
    return 0
  fi

  if [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    echo "$HOME/.linuxbrew/bin/brew"
    return 0
  fi

  return 1
}

dotfiles_brew_prefix() {
  local formula_name="$1"
  local brew_bin

  brew_bin="$(dotfiles_brew_bin 2>/dev/null)" || return 1
  "$brew_bin" --prefix "$formula_name"
}

dotfiles_apply_brew_shellenv() {
  local brew_bin

  brew_bin="$(dotfiles_brew_bin 2>/dev/null)" || return 0
  eval "$("$brew_bin" shellenv)"
}

dotfiles_load_install_env() {
  if [[ -f "$DOTFILES_INSTALL_ENV" ]]; then
    source "$DOTFILES_INSTALL_ENV"
  fi

  if [[ -n "${DOTFILES_ROOT:-}" ]]; then
    export DOTFILES="$DOTFILES_ROOT"
  fi

  export DOTFILES_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
  export DOTFILES_INSTALL_ENV="$DOTFILES_CONFIG_DIR/install.env"
  export DOTFILES_LOCAL_ZSH="$DOTFILES_CONFIG_DIR/local.zsh"
  export DOTFILES_THEME="${DOTFILES_THEME:-starship}"
}

dotfiles_detect_platform() {
  if [[ "$OSTYPE" == darwin* ]]; then
    export DOTFILES_PLATFORM="macos"
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    export DOTFILES_PLATFORM="wsl"
    return 0
  fi

  if [[ "$OSTYPE" == linux* ]]; then
    export DOTFILES_PLATFORM="linux"
    return 0
  fi
}

dotfiles_configure_oh_my_zsh() {
  export ZSH="$HOME/.oh-my-zsh"
  export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZSH/cache}"
  export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

  if [[ -z "${DOTFILES_ENABLE_OH_MY_ZSH:-}" ]]; then
    if [[ -d "$ZSH" ]]; then
      export DOTFILES_ENABLE_OH_MY_ZSH="1"
    else
      export DOTFILES_ENABLE_OH_MY_ZSH="0"
    fi
  fi
}
