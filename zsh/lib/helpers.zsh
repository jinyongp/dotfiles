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

dotfiles_ensure_writable_dir() {
  local dir_path="$1"

  [[ -n "$dir_path" ]] || return 1
  mkdir -p "$dir_path" 2>/dev/null || return 1
  [[ -d "$dir_path" && -w "$dir_path" ]]
}

dotfiles_should_disable_background_updates() {
  [[ -n "${DISABLE_BACKGROUND_UPDATES:-}" ]] && return 0
  [[ -n "${AGENT_SHELL:-}" ]] && return 0
  [[ -n "${AUTOMATION_SHELL:-}" ]] && return 0
  [[ -n "${CI:-}" ]] && return 0
  [[ -n "${CODEX_CI:-}" || -n "${CODEX_SANDBOX:-}" || -n "${CODEX_THREAD_ID:-}" ]]
}

dotfiles_configure_cache_home() {
  local preferred_cache_home fallback_cache_home

  preferred_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  fallback_cache_home="${${TMPDIR:-/tmp}%/}/dotfiles-cache-${UID}"

  if dotfiles_ensure_writable_dir "$preferred_cache_home"; then
    export XDG_CACHE_HOME="$preferred_cache_home"
    return 0
  fi

  if dotfiles_ensure_writable_dir "$fallback_cache_home"; then
    export XDG_CACHE_HOME="$fallback_cache_home"
    return 0
  fi

  export XDG_CACHE_HOME="$preferred_cache_home"
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
  local resolved_zsh_cache_dir resolved_zsh_compdump_dir

  dotfiles_configure_cache_home

  export ZSH="$HOME/.oh-my-zsh"
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

  resolved_zsh_cache_dir="${ZSH_CACHE_DIR:-}"
  if [[ -z "$resolved_zsh_cache_dir" ]] || ! dotfiles_ensure_writable_dir "$resolved_zsh_cache_dir"; then
    resolved_zsh_cache_dir="$XDG_CACHE_HOME/oh-my-zsh"
    dotfiles_ensure_writable_dir "$resolved_zsh_cache_dir" || true
  fi

  resolved_zsh_compdump_dir="${ZSH_COMPDUMP:-}"
  if [[ -n "$resolved_zsh_compdump_dir" ]]; then
    resolved_zsh_compdump_dir="${resolved_zsh_compdump_dir:h}"
  fi

  if [[ -z "${ZSH_COMPDUMP:-}" ]] || [[ -z "$resolved_zsh_compdump_dir" ]] || ! dotfiles_ensure_writable_dir "$resolved_zsh_compdump_dir"; then
    export ZSH_COMPDUMP="$resolved_zsh_cache_dir/.zcompdump"
  fi

  export ZSH_CACHE_DIR="$resolved_zsh_cache_dir"

  dotfiles_ensure_writable_dir "$ZSH_CACHE_DIR/completions" || true
  dotfiles_ensure_writable_dir "$XDG_CACHE_HOME/starship" || true

  if dotfiles_should_disable_background_updates; then
    export DISABLE_AUTO_UPDATE=true
    zstyle ':omz:update' mode disabled
    zstyle ':omz:update' verbose silent
    export ZSH_CUSTOM_AUTOUPDATE_QUIET=true
  fi

  if [[ -z "${DOTFILES_ENABLE_OH_MY_ZSH:-}" ]]; then
    if [[ -d "$ZSH" ]]; then
      export DOTFILES_ENABLE_OH_MY_ZSH="1"
    else
      export DOTFILES_ENABLE_OH_MY_ZSH="0"
    fi
  fi
}
