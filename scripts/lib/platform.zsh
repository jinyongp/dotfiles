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
  DOTFILES_PLATFORM="$(dotfiles::detect_platform_id || true)"

  case "$DOTFILES_PLATFORM" in
    macos) DOTFILES_PLATFORM_LABEL="macOS" ;;
    wsl) DOTFILES_PLATFORM_LABEL="WSL" ;;
    linux) DOTFILES_PLATFORM_LABEL="Linux" ;;
    *)
      dotfiles::log_error "Unsupported platform: ${OSTYPE:-unknown}"
      exit 1
      ;;
  esac
}
