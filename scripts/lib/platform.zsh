#!/bin/zsh

platform::is_macos() {
  [[ "$DOTFILES_PLATFORM" == "macos" ]]
}

platform::is_linux() {
  [[ "$DOTFILES_PLATFORM" == "linux" || "$DOTFILES_PLATFORM" == "wsl" ]]
}

platform::is_wsl() {
  [[ "$DOTFILES_PLATFORM" == "wsl" ]]
}

platform::detect() {
  if [[ "$OSTYPE" == darwin* ]]; then
    DOTFILES_PLATFORM="macos"
    DOTFILES_PLATFORM_LABEL="macOS"
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    DOTFILES_PLATFORM="wsl"
    DOTFILES_PLATFORM_LABEL="WSL"
    return 0
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    DOTFILES_PLATFORM="wsl"
    DOTFILES_PLATFORM_LABEL="WSL"
    return 0
  fi

  if [[ "$OSTYPE" == linux* ]]; then
    DOTFILES_PLATFORM="linux"
    DOTFILES_PLATFORM_LABEL="Linux"
    return 0
  fi

  dotfiles::log_error "Unsupported platform: ${OSTYPE:-unknown}"
  exit 1
}
