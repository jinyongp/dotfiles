#!/bin/zsh

dotfiles::brew_bin_path() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    print -r -- /opt/homebrew/bin/brew
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    print -r -- /usr/local/bin/brew
    return 0
  fi

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    print -r -- /home/linuxbrew/.linuxbrew/bin/brew
    return 0
  fi

  if [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    print -r -- "$HOME/.linuxbrew/bin/brew"
    return 0
  fi

  return 1
}

dotfiles::detect_platform_id() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    print -r -- "macos"
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    print -r -- "wsl"
    return 0
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    print -r -- "wsl"
    return 0
  fi

  if [[ "${OSTYPE:-}" == linux* ]]; then
    print -r -- "linux"
    return 0
  fi

  return 1
}
