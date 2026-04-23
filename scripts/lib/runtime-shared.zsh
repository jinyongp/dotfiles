#!/bin/zsh

dotfiles::__printf_line() {
  printf '%s\n' "$1"
}

dotfiles::__tmp_root() {
  local tmp_root="${TMPDIR:-/tmp}"

  tmp_root="${tmp_root%/}"
  dotfiles::__printf_line "$tmp_root"
}

dotfiles::__platform_for_paths() {
  if [[ -n "${DOTFILES_PLATFORM:-}" ]]; then
    dotfiles::__printf_line "$DOTFILES_PLATFORM"
    return 0
  fi

  dotfiles::detect_platform_id || return 1
}

dotfiles::__config_home() {
  dotfiles::__printf_line "${XDG_CONFIG_HOME:-$HOME/.config}"
}

dotfiles::__data_home() {
  dotfiles::__printf_line "${XDG_DATA_HOME:-$HOME/.local/share}"
}

dotfiles::__current_uid() {
  if [[ -n "${UID:-}" ]]; then
    dotfiles::__printf_line "$UID"
    return 0
  fi

  id -u
}

dotfiles::brew_bin_path() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    dotfiles::__printf_line "/opt/homebrew/bin/brew"
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    dotfiles::__printf_line "/usr/local/bin/brew"
    return 0
  fi

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    dotfiles::__printf_line "/home/linuxbrew/.linuxbrew/bin/brew"
    return 0
  fi

  if [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    dotfiles::__printf_line "$HOME/.linuxbrew/bin/brew"
    return 0
  fi

  return 1
}

dotfiles::detect_platform_id() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    dotfiles::__printf_line "macos"
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    dotfiles::__printf_line "wsl"
    return 0
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    dotfiles::__printf_line "wsl"
    return 0
  fi

  if [[ "${OSTYPE:-}" == linux* ]]; then
    dotfiles::__printf_line "linux"
    return 0
  fi

  return 1
}

dotfiles::config_dir() {
  if [[ -n "${DOTFILES_CONFIG_DIR:-}" ]]; then
    dotfiles::__printf_line "$DOTFILES_CONFIG_DIR"
    return 0
  fi

  dotfiles::__printf_line "$(dotfiles::__config_home)/dotfiles"
}

dotfiles::install_env_path() {
  if [[ -n "${DOTFILES_INSTALL_ENV:-}" ]]; then
    dotfiles::__printf_line "$DOTFILES_INSTALL_ENV"
    return 0
  fi

  dotfiles::__printf_line "$(dotfiles::config_dir)/install.env"
}

dotfiles::env_zsh_path() {
  if [[ -n "${DOTFILES_ENV_ZSH:-}" ]]; then
    dotfiles::__printf_line "$DOTFILES_ENV_ZSH"
    return 0
  fi

  dotfiles::__printf_line "$(dotfiles::config_dir)/env.zsh"
}

dotfiles::profile_zsh_path() {
  if [[ -n "${DOTFILES_PROFILE_ZSH:-}" ]]; then
    dotfiles::__printf_line "$DOTFILES_PROFILE_ZSH"
    return 0
  fi

  dotfiles::__printf_line "$(dotfiles::config_dir)/profile.zsh"
}

dotfiles::local_zsh_path() {
  if [[ -n "${DOTFILES_LOCAL_ZSH:-}" ]]; then
    dotfiles::__printf_line "$DOTFILES_LOCAL_ZSH"
    return 0
  fi

  dotfiles::__printf_line "$(dotfiles::config_dir)/local.zsh"
}

dotfiles::npm_global_prefix() {
  local platform_id=""

  platform_id="$(dotfiles::__platform_for_paths || true)"

  if [[ -n "${XDG_DATA_HOME:-}" ]]; then
    dotfiles::__printf_line "$XDG_DATA_HOME/npm-global"
    return 0
  fi

  case "$platform_id" in
    macos) dotfiles::__printf_line "$HOME/Library/Application Support/npm-global" ;;
    *) dotfiles::__printf_line "$HOME/.local/share/npm-global" ;;
  esac
}

dotfiles::npm_global_bin_dir() {
  dotfiles::__printf_line "$(dotfiles::npm_global_prefix)/bin"
}

dotfiles::pnpm_home() {
  local platform_id=""

  if [[ -n "${PNPM_HOME:-}" ]]; then
    dotfiles::__printf_line "$PNPM_HOME"
    return 0
  fi

  platform_id="$(dotfiles::__platform_for_paths || true)"

  case "$platform_id" in
    macos) dotfiles::__printf_line "$HOME/Library/pnpm" ;;
    *) dotfiles::__printf_line "$(dotfiles::__data_home)/pnpm" ;;
  esac
}

dotfiles::fnm_install_dir() {
  local platform_id=""

  if [[ -n "${FNM_DIR:-}" ]]; then
    dotfiles::__printf_line "$FNM_DIR"
    return 0
  fi

  platform_id="$(dotfiles::__platform_for_paths || true)"

  if [[ -n "${XDG_DATA_HOME:-}" ]]; then
    dotfiles::__printf_line "$XDG_DATA_HOME/fnm"
    return 0
  fi

  case "$platform_id" in
    macos) dotfiles::__printf_line "$HOME/Library/Application Support/fnm" ;;
    *) dotfiles::__printf_line "$HOME/.local/share/fnm" ;;
  esac
}

dotfiles::fnm_runtime_dir() {
  local runtime_dir="${XDG_RUNTIME_DIR:-}"
  local fallback_dir=""
  local current_uid=""

  if [[ -n "$runtime_dir" && -d "$runtime_dir" && -w "$runtime_dir" ]]; then
    dotfiles::__printf_line "$runtime_dir"
    return 0
  fi

  current_uid="$(dotfiles::__current_uid)"
  fallback_dir="$(dotfiles::__tmp_root)/fnm-runtime-${current_uid}"

  mkdir -p "$fallback_dir" 2>/dev/null || return 1
  chmod 700 "$fallback_dir" 2>/dev/null || true
  dotfiles::__printf_line "$fallback_dir"
}

dotfiles::activate_brew_shellenv() {
  local brew_bin=""

  brew_bin="$(dotfiles::brew_bin_path 2>/dev/null)" || return 0
  eval "$("$brew_bin" shellenv)"
}
