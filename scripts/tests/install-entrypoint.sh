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
  REPO_HOME_DIR="$(cd -- "$DOTFILES_ROOT/.." && pwd)"

  mkdir -p "$HOME_DIR" "$CONFIG_DIR"
}

install_entrypoint_test::run_install() {
  local name="$1"
  shift || true
  install_entrypoint_test::run_install_with_home "$HOME_DIR" "$name" "$@"
}

install_entrypoint_test::run_install_with_home() {
  local home_dir="$1"
  local name="$2"
  shift 2 || true

  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"

  env -i \
    HOME="$home_dir" \
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
  bash -n "$DOTFILES_ROOT/cmd/dotfiles"
  bash -n "$DOTFILES_ROOT/scripts/install-remote.bash"
  for file in "$DOTFILES_ROOT"/scripts/lib/install/*.bash; do
    bash -n "$file"
  done

  printf 'ok syntax\n'
}

install_entrypoint_test::run_dotfiles_command() {
  local name="$1"
  shift || true

  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_PLATFORM="macos" \
    PATH="$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    dotfiles "$@" >"$output_file" 2>"$error_file"
}

install_entrypoint_test::assert_help() {
  install_entrypoint_test::run_install "help" --help
  install_entrypoint_test::assert_contains "$WORK_DIR/help.out" "Usage:"
  install_entrypoint_test::assert_contains "$WORK_DIR/help.out" "$DOTFILES_ROOT/install <module>"
  install_entrypoint_test::assert_no_stderr "help"

  install_entrypoint_test::run_install_with_home "$REPO_HOME_DIR" "help_home" help
  install_entrypoint_test::assert_contains "$WORK_DIR/help_home.out" "~/.dotfiles/install <module>"
  install_entrypoint_test::assert_no_stderr "help_home"
  printf 'ok help\n'
}

install_entrypoint_test::assert_list() {
  install_entrypoint_test::run_install "list" list
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "Available direct install targets:"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "dotfiles:"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "agents:"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "theme:"
  install_entrypoint_test::assert_no_stderr "list"
  printf 'ok list\n'
}

install_entrypoint_test::assert_dotfiles_command() {
  install_entrypoint_test::run_dotfiles_command "dotfiles_path" path
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_path.out" "$DOTFILES_ROOT"
  install_entrypoint_test::assert_no_stderr "dotfiles_path"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_commands" complete commands
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_commands.out" "install:run the interactive installer or direct install target"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_commands"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_targets" complete targets
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_targets.out" "neovim:Neovim"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_targets"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_items" complete items packages
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_items.out" "taskwarrior:Taskwarrior"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_items"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_external_skills" complete external-skills
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_external_skills.out" "gate:gate (gate)"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_external_skills.out" "humanize-korean:humanize-korean (im-not-ai)"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_external_skills"

  install_entrypoint_test::run_dotfiles_command "dotfiles_agents_list" agents list
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "gate  not installed"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "  install: gate -> codex, claude"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "humanize-korean  not installed"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "  policy:  materialize_repo_symlinks"
  install_entrypoint_test::assert_no_stderr "dotfiles_agents_list"

  install_entrypoint_test::run_dotfiles_command "dotfiles_agents_list_json" agents list --json
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"id": "gate"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"status": "not_installed"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"adapters": ["codex","claude"]'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"id": "humanize-korean"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"copyPolicy": "materialize_repo_symlinks"'
  install_entrypoint_test::assert_no_stderr "dotfiles_agents_list_json"

  printf 'ok dotfiles_command\n'
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
  install_entrypoint_test::assert_dotfiles_command
  install_entrypoint_test::assert_invalid_target
}

install_entrypoint_test::main "$@"
