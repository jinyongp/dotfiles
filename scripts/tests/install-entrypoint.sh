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

install_entrypoint_test::run_install_with_mode() {
  local mode="$1"
  local name="$2"
  shift 2 || true

  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_INSTALL_UI_MODE="$mode" \
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

install_entrypoint_test::run_dotfiles_command_json() {
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
    DOTFILES_INSTALL_UI_MODE="json" \
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
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "Agent skills:"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "planning"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "internal; available"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "gate"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "external; not installed"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "humanize-korean"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list.out" "codex/skills/humanize-korean"
  install_entrypoint_test::assert_no_stderr "dotfiles_agents_list"

  install_entrypoint_test::run_dotfiles_command_json "dotfiles_agents_list_json" agents list
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"id": "gate"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"id": "planning"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"kind": "internal"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"adapterTargets":'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"status": "not_installed"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"adapters": ["codex","claude"]'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"id": "humanize-korean"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json.out" '"copyPolicy": "materialize_repo_symlinks"'
  install_entrypoint_test::assert_no_stderr "dotfiles_agents_list_json"

  if install_entrypoint_test::run_dotfiles_command_json "dotfiles_agents_list_json_flag" agents list --json; then
    install_entrypoint_test::fail "agents list --json unexpectedly succeeded"
  fi
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json_flag.err" '"type":"validation_error"'
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_agents_list_json_flag.err" '"input":"--json"'

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

  install_entrypoint_test::assert_contains "$error_file" "Error: unknown install target"
  install_entrypoint_test::assert_contains "$error_file" "input: definitely-not-a-target"
  install_entrypoint_test::assert_contains "$error_file" "expected: dotfiles, packages, agents, oh_my_zsh, neovim, fonts, desktop_apps, macos_defaults, theme"
  install_entrypoint_test::assert_contains "$error_file" "usage: $DOTFILES_ROOT/install <module> [item...]"
  install_entrypoint_test::assert_contains "$error_file" "next: $DOTFILES_ROOT/install list"
  printf 'ok invalid_target\n'
}

install_entrypoint_test::assert_structured_direct_errors() {
  local output_file error_file

  output_file="$WORK_DIR/invalid_item.out"
  error_file="$WORK_DIR/invalid_item.err"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" agents not-an-agent >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "invalid direct item unexpectedly succeeded"
  fi
  install_entrypoint_test::assert_contains "$error_file" "Error: unknown item for install target"
  install_entrypoint_test::assert_contains "$error_file" "target: agents"
  install_entrypoint_test::assert_contains "$error_file" "input: not-an-agent"

  output_file="$WORK_DIR/extra_item.out"
  error_file="$WORK_DIR/extra_item.err"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" dotfiles extra >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "extra direct item unexpectedly succeeded"
  fi
  install_entrypoint_test::assert_contains "$error_file" "Error: module does not accept item arguments"
  install_entrypoint_test::assert_contains "$error_file" "target: dotfiles"

  output_file="$WORK_DIR/non_tty.out"
  error_file="$WORK_DIR/non_tty.err"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "non-TTY install unexpectedly succeeded"
  fi
  install_entrypoint_test::assert_contains "$error_file" "Error: interactive terminal required"
  install_entrypoint_test::assert_contains "$error_file" "input: stdin is not a TTY"

  printf 'ok structured_direct_errors\n'
}

install_entrypoint_test::assert_modes() {
  install_entrypoint_test::run_install_with_mode plain "plain_list" list
  if grep -q '[◆◇●○◻◼›↑↓•]' "$WORK_DIR/plain_list.out"; then
    install_entrypoint_test::fail "plain install list should not contain Unicode UI symbols"
  fi

  install_entrypoint_test::run_install_with_mode json "json_list" list
  python3 -m json.tool "$WORK_DIR/json_list.out" >/dev/null
  install_entrypoint_test::assert_contains "$WORK_DIR/json_list.out" '"id":"dotfiles"'
  install_entrypoint_test::assert_no_stderr "json_list"

  output_file="$WORK_DIR/json_invalid.out"
  error_file="$WORK_DIR/json_invalid.err"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" definitely-not-a-target >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON invalid target unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"type":"validation_error"'

  output_file="$WORK_DIR/json_missing_stdin.out"
  error_file="$WORK_DIR/json_missing_stdin.err"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON missing stdin unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"type":"input_required"'

  output_file="$WORK_DIR/json_bad_items_key.out"
  error_file="$WORK_DIR/json_bad_items_key.err"
  marker_file="$WORK_DIR/json_eval_marker"
  json_request='{"schema":"dotfiles.install.request.v1","profile":"custom","modules":["dotfiles"],"items":{"bad$(touch '"$marker_file"')":["x"]},"summaryAction":"cancel"}'
  if printf '%s' "$json_request" | env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON invalid items key unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"type":"validation_error"'
  install_entrypoint_test::assert_contains "$error_file" '"field":"items"'
  [[ ! -e "$marker_file" ]] || install_entrypoint_test::fail "JSON items key reached shell evaluation"

  output_file="$WORK_DIR/json_unselected_items.out"
  error_file="$WORK_DIR/json_unselected_items.err"
  json_request='{"schema":"dotfiles.install.request.v1","profile":"custom","modules":["dotfiles"],"items":{"packages":["jq"]},"summaryAction":"cancel"}'
  if printf '%s' "$json_request" | env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON unselected items unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"type":"validation_error"'
  install_entrypoint_test::assert_contains "$error_file" '"field":"items.packages"'

  output_file="$WORK_DIR/json_multi_profile.out"
  error_file="$WORK_DIR/json_multi_profile.err"
  json_request='{"schema":"dotfiles.install.request.v1","profile":"minimal recommended","summaryAction":"cancel"}'
  if printf '%s' "$json_request" | env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON multi-token profile unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"field":"profile"'

  output_file="$WORK_DIR/json_multi_theme.out"
  error_file="$WORK_DIR/json_multi_theme.err"
  json_request='{"schema":"dotfiles.install.request.v1","profile":"custom","modules":["dotfiles"],"theme":"starship default","summaryAction":"cancel"}'
  if printf '%s' "$json_request" | env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON multi-token theme unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"field":"theme"'

  output_file="$WORK_DIR/json_macos_apt.out"
  error_file="$WORK_DIR/json_macos_apt.err"
  json_request='{"schema":"dotfiles.install.request.v1","profile":"custom","modules":["packages"],"packageManager":"apt","summaryAction":"cancel"}'
  if printf '%s' "$json_request" | env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json DOTFILES_PLATFORM=macos PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "JSON macOS apt package manager unexpectedly succeeded"
  fi
  python3 -m json.tool "$error_file" >/dev/null
  install_entrypoint_test::assert_contains "$error_file" '"field":"packageManager"'
  install_entrypoint_test::assert_contains "$error_file" '"platform":"macos"'

  printf 'ok modes\n'
}

install_entrypoint_test::assert_install_remote_json_dirty_repo() {
  local repo_dir="$WORK_DIR/dirty-repo"
  local output_file="$WORK_DIR/install_remote_dirty.out"
  local error_file="$WORK_DIR/install_remote_dirty.err"

  mkdir -p "$repo_dir"
  git -C "$repo_dir" init >/dev/null 2>&1
  printf 'dirty\n' >"$repo_dir/dirty.txt"

  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" DOTFILES_INSTALL_UI_MODE=json DOTFILES_DIR="$repo_dir" PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/scripts/install-remote.bash" >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "install-remote dirty repo unexpectedly succeeded"
  fi

  python3 - "$error_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    events = [json.loads(line) for line in handle if line.strip()]

assert len(events) == 1
assert events[0]["type"] == "validation_error"
assert "dirty.txt" in events[0]["data"]["fields"]["status"]
PY

  printf 'ok install_remote_json_dirty_repo\n'
}

install_entrypoint_test::main() {
  install_entrypoint_test::setup_fixture
  install_entrypoint_test::assert_syntax
  install_entrypoint_test::assert_help
  install_entrypoint_test::assert_list
  install_entrypoint_test::assert_dotfiles_command
  install_entrypoint_test::assert_invalid_target
  install_entrypoint_test::assert_structured_direct_errors
  install_entrypoint_test::assert_modes
  install_entrypoint_test::assert_install_remote_json_dirty_repo
}

install_entrypoint_test::main "$@"
