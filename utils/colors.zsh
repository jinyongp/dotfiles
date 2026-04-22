#!/usr/bin/env bash

if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    DOTFILES_ROOT="$(eval 'cd -- "$(dirname -- "${(%):-%x}")/.." && pwd')"
  fi
fi

# shellcheck disable=SC1090
source "$DOTFILES_ROOT/scripts/lib/style.sh"
