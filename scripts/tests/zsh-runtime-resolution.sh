#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zsh-runtime-resolution.XXXXXX")"
FAKE_ZSH="$WORK_DIR/homebrew/bin/zsh"
TEST_BIN="$WORK_DIR/bin"
INVOCATION_LOG="$WORK_DIR/zsh-invocation.log"

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$(dirname -- "$FAKE_ZSH")" "$WORK_DIR/home" "$TEST_BIN"
ln -s "$(command -v bash)" "$TEST_BIN/bash"
ln -s "$(command -v dirname)" "$TEST_BIN/dirname"
printf '%s\n' \
  '#!/bin/sh' \
  'printf "%s\\n" "$@" > "$ZSH_INVOCATION_LOG"' \
  >"$FAKE_ZSH"
chmod +x "$FAKE_ZSH"

env -i \
  HOME="$WORK_DIR/home" \
  PATH="$TEST_BIN" \
  SHELL="$FAKE_ZSH" \
  ZSH_INVOCATION_LOG="$INVOCATION_LOG" \
  "$DOTFILES_ROOT/cmd/dotfiles" agents sync

expected="$(printf '%s\n' "$DOTFILES_ROOT/scripts/run-agent-skills.zsh" sync)"
actual="$(cat "$INVOCATION_LOG")"

if [[ "$actual" != "$expected" ]]; then
  printf 'zsh-runtime-resolution: unexpected invocation\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
fi

if grep -R -n --include='*.zsh' '^#!/bin/zsh$' "$DOTFILES_ROOT/scripts"; then
  printf 'zsh-runtime-resolution: hard-coded /bin/zsh shebang found\n' >&2
  exit 1
fi

printf 'all zsh runtime resolution tests passed\n'
