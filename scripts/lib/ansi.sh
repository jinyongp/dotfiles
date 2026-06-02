#!/usr/bin/env bash

if [[ -z "${DOTFILES_ANSI_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    DOTFILES_ANSI_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    DOTFILES_ANSI_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ui/ansi.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/ui/ansi.sh"
else
  # shellcheck disable=SC1090
  source "$DOTFILES_ANSI_LIB_DIR/ui/ansi.sh"
fi
