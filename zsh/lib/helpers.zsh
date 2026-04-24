source "$DOTFILES/scripts/lib/runtime-shared.zsh"

dotfiles_has_command() {
  (( $+commands[$1] ))
}

dotfiles_source_if_exists() {
  [[ -f "$1" ]] || return 0
  source "$1"
}

dotfiles_prepend_path() {
  local path_entry="$1"

  [[ -d "$path_entry" ]] || return 0

  case ":$PATH:" in
    *":$path_entry:"*) ;;
    *) export PATH="$path_entry:$PATH" ;;
  esac
}

dotfiles_configure_npm_global_path() {
  dotfiles_prepend_path "$(dotfiles::npm_global_bin_dir)"
}

dotfiles_configure_pnpm_home() {
  if [[ -z "${PNPM_HOME:-}" ]]; then
    export PNPM_HOME="$(dotfiles::pnpm_home)"
  fi

  dotfiles_prepend_path "$PNPM_HOME"
}

dotfiles_fnm_install_dir() {
  dotfiles::fnm_install_dir
}

dotfiles_fnm_runtime_dir() {
  dotfiles::fnm_runtime_dir
}

dotfiles_activate_fnm() {
  local mode="${1:-base}"
  local runtime_dir fnm_env
  local -a fnm_args

  dotfiles_prepend_path "$(dotfiles_fnm_install_dir)"

  if ! dotfiles_has_command fnm; then
    return 0
  fi

  runtime_dir="$(dotfiles_fnm_runtime_dir)" || return 0
  fnm_args=(env --shell zsh --version-file-strategy=recursive)

  if [[ "$mode" == "interactive" ]]; then
    fnm_args+=(--use-on-cd)
  fi

  fnm_env="$(XDG_RUNTIME_DIR="$runtime_dir" fnm "${fnm_args[@]}" 2>/dev/null)" || return 0
  [[ -n "$fnm_env" ]] || return 0
  eval "$fnm_env"

  if [[ "$mode" != "interactive" ]]; then
    XDG_RUNTIME_DIR="$runtime_dir" fnm use --silent-if-unchanged --version-file-strategy=recursive >/dev/null 2>&1 || true
  fi
}

dotfiles_configure_base_toolchain() {
  dotfiles_apply_brew_shellenv
  dotfiles_configure_npm_global_path
  dotfiles_activate_fnm base
  dotfiles_configure_pnpm_home
}

dotfiles_ensure_writable_dir() {
  local dir_path="$1"

  [[ -n "$dir_path" ]] || return 1
  mkdir -p "$dir_path" 2>/dev/null || return 1
  [[ -d "$dir_path" && -w "$dir_path" ]]
}

dotfiles_resolve_writable_dir() {
  local preferred_dir="$1"
  local fallback_dir="${2:-}"

  if [[ -n "$preferred_dir" ]] && dotfiles_ensure_writable_dir "$preferred_dir"; then
    print -r -- "$preferred_dir"
    return 0
  fi

  if [[ -n "$fallback_dir" ]] && dotfiles_ensure_writable_dir "$fallback_dir"; then
    print -r -- "$fallback_dir"
    return 0
  fi

  return 1
}

dotfiles_should_disable_background_updates() {
  [[ -n "${DISABLE_BACKGROUND_UPDATES:-}" ]] && return 0
  [[ -n "${AGENT_SHELL:-}" ]] && return 0
  [[ -n "${AUTOMATION_SHELL:-}" ]] && return 0
  [[ -n "${CI:-}" ]] && return 0
  [[ -n "${CODEX_CI:-}" || -n "${CODEX_SANDBOX:-}" || -n "${CODEX_THREAD_ID:-}" ]]
}

dotfiles_has_terminal_ui() {
  [[ -t 1 ]] || return 1
  [[ "${TERM:-}" != "dumb" ]]
}

dotfiles_configure_cache_home() {
  local preferred_cache_home fallback_cache_home
  local resolved_cache_home=""

  preferred_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
  fallback_cache_home="${${TMPDIR:-/tmp}%/}/dotfiles-cache-${UID}"

  if resolved_cache_home="$(dotfiles_resolve_writable_dir "$preferred_cache_home" "$fallback_cache_home" 2>/dev/null)"; then
    export XDG_CACHE_HOME="$resolved_cache_home"
    return 0
  fi

  export XDG_CACHE_HOME="$preferred_cache_home"
}

dotfiles_configure_state_home() {
  local preferred_state_home fallback_state_home
  local resolved_state_home=""

  preferred_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  fallback_state_home="${${TMPDIR:-/tmp}%/}/dotfiles-state-${UID}"

  if resolved_state_home="$(dotfiles_resolve_writable_dir "$preferred_state_home" "$fallback_state_home" 2>/dev/null)"; then
    export XDG_STATE_HOME="$resolved_state_home"
    return 0
  fi

  export XDG_STATE_HOME="$preferred_state_home"
}

dotfiles_brew_bin() {
  dotfiles::brew_bin_path
}

dotfiles_brew_prefix() {
  local formula_name="$1"
  local brew_bin

  brew_bin="$(dotfiles_brew_bin 2>/dev/null)" || return 1
  "$brew_bin" --prefix "$formula_name"
}

dotfiles_apply_brew_shellenv() {
  dotfiles::activate_brew_shellenv
}

dotfiles_load_install_env() {
  export DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-$(dotfiles::config_dir)}"
  export DOTFILES_INSTALL_ENV="${DOTFILES_INSTALL_ENV:-$(dotfiles::install_env_path)}"
  export DOTFILES_ENV_ZSH="${DOTFILES_ENV_ZSH:-$(dotfiles::env_zsh_path)}"
  export DOTFILES_PROFILE_ZSH="${DOTFILES_PROFILE_ZSH:-$(dotfiles::profile_zsh_path)}"
  export DOTFILES_LOCAL_ZSH="${DOTFILES_LOCAL_ZSH:-$(dotfiles::local_zsh_path)}"

  if [[ -f "$DOTFILES_INSTALL_ENV" ]]; then
    source "$DOTFILES_INSTALL_ENV"
  fi

  if [[ -n "${DOTFILES_ROOT:-}" ]]; then
    export DOTFILES="$DOTFILES_ROOT"
  fi

  export DOTFILES_THEME="${DOTFILES_THEME:-starship}"
}

dotfiles_detect_platform() {
  export DOTFILES_PLATFORM="$(dotfiles::detect_platform_id || true)"
  [[ -n "$DOTFILES_PLATFORM" ]]
}

dotfiles_configure_oh_my_zsh() {
  local resolved_zsh_cache_dir resolved_zsh_compdump_dir resolved_starship_cache_dir

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
  resolved_starship_cache_dir="$(
    dotfiles_resolve_writable_dir \
      "${STARSHIP_CACHE:-$XDG_CACHE_HOME/starship}" \
      "${${TMPDIR:-/tmp}%/}/dotfiles-cache-${UID}/starship" 2>/dev/null || true
  )"
  if [[ -n "$resolved_starship_cache_dir" ]]; then
    export STARSHIP_CACHE="$resolved_starship_cache_dir"
  fi

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
