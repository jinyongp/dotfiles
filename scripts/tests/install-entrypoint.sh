#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

install_entrypoint_test::fail() {
  printf 'install-entrypoint: %s\n' "$1" >&2
  exit 1
}

install_entrypoint_test::setup_fixture() {
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-entrypoint.XXXXXX")"
  HOME_DIR="$WORK_DIR/home"
  CONFIG_DIR="$WORK_DIR/config"

  mkdir -p "$HOME_DIR" "$CONFIG_DIR"
}

install_entrypoint_test::run_install() {
  local name="$1"
  shift || true

  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    bash "$DOTFILES_ROOT/install" "$@" >"$output_file" 2>"$error_file"
}

install_entrypoint_test::assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    sed -n '1,120p' "$file" >&2
    install_entrypoint_test::fail "expected '$expected' in $file"
  fi
}

install_entrypoint_test::assert_no_stderr() {
  local name="$1"
  local error_file="$WORK_DIR/${name}.err"

  if [[ -s "$error_file" ]]; then
    sed -n '1,120p' "$error_file" >&2
    install_entrypoint_test::fail "unexpected stderr for $name"
  fi
}

install_entrypoint_test::assert_syntax() {
  local file

  bash -n "$DOTFILES_ROOT/install"
  for file in "$DOTFILES_ROOT"/scripts/lib/install/*.bash; do
    bash -n "$file"
  done

  printf 'ok syntax\n'
}

install_entrypoint_test::assert_help() {
  install_entrypoint_test::run_install "help" --help
  install_entrypoint_test::assert_contains "$WORK_DIR/help.out" "Usage:"
  install_entrypoint_test::assert_contains "$WORK_DIR/help.out" "$DOTFILES_ROOT/install <module>"
  install_entrypoint_test::assert_no_stderr "help"
  printf 'ok help\n'
}

install_entrypoint_test::assert_list() {
  install_entrypoint_test::run_install "list" list
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "Available direct install targets:"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "dotfiles:"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "theme:"
  install_entrypoint_test::assert_no_stderr "list"
  printf 'ok list\n'
}

install_entrypoint_test::assert_invalid_target() {
  local output_file="$WORK_DIR/invalid.out"
  local error_file="$WORK_DIR/invalid.err"

  if env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    bash "$DOTFILES_ROOT/install" definitely-not-a-target >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "invalid direct target unexpectedly succeeded"
  fi

  install_entrypoint_test::assert_contains "$error_file" "Unknown install target: definitely-not-a-target"
  install_entrypoint_test::assert_contains "$error_file" "Available direct install targets:"
  printf 'ok invalid_target\n'
}

install_entrypoint_test::main() {
  install_entrypoint_test::setup_fixture
  install_entrypoint_test::assert_syntax
  install_entrypoint_test::assert_help
  install_entrypoint_test::assert_list
  install_entrypoint_test::assert_invalid_target
}

install_entrypoint_test::main "$@"
