#!/usr/bin/env bash

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/jinyongp/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REF="${DOTFILES_REF:-main}"

install_remote::require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'dotfiles install: required command not found: %s\n' "$1" >&2
    return 1
  fi
}

install_remote::ensure_clean_worktree() {
  local status=""

  status="$(git -C "$DOTFILES_DIR" status --porcelain)"
  if [[ -n "$status" ]]; then
    printf 'dotfiles install: local changes found in %s; refusing to update.\n' "$DOTFILES_DIR" >&2
    printf '%s\n' "$status" >&2
    return 1
  fi
}

install_remote::clone_or_update_repo() {
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  elif [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    printf 'dotfiles install: path exists but is not a git repo: %s\n' "$DOTFILES_DIR" >&2
    return 1
  fi

  install_remote::ensure_clean_worktree

  git -C "$DOTFILES_DIR" fetch --prune origin
  git -C "$DOTFILES_DIR" checkout "$DOTFILES_REF"
  git -C "$DOTFILES_DIR" pull --ff-only origin "$DOTFILES_REF"
}

install_remote::main() {
  install_remote::require_command git
  install_remote::require_command bash

  install_remote::clone_or_update_repo
  exec "$DOTFILES_DIR/install" "$@"
}

install_remote::main "$@"
