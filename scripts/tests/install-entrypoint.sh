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

  if ! grep -Fq -- "$expected" "$file"; then
    sed -n '1,120p' "$file" >&2
    install_entrypoint_test::fail "expected '$expected' in $file"
  fi
}

install_entrypoint_test::assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq -- "$unexpected" "$file"; then
    sed -n '1,120p' "$file" >&2
    install_entrypoint_test::fail "did not expect '$unexpected' in $file"
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

install_entrypoint_test::run_with_pty() {
  local output_file="$1"
  shift || true

  python3 - "$output_file" "$@" <<'PY'
import errno
import os
import pty
import sys

output_file = sys.argv[1]
command = sys.argv[2:]
pid, fd = pty.fork()

if pid == 0:
    os.execvp(command[0], command)

chunks = []
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError as error:
        if error.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    chunks.append(chunk)

_, status = os.waitpid(pid, 0)
with open(output_file, "wb") as handle:
    handle.write(b"".join(chunks))

if os.WIFEXITED(status):
    raise SystemExit(os.WEXITSTATUS(status))
raise SystemExit(128 + os.WTERMSIG(status))
PY
}

install_entrypoint_test::assert_syntax() {
  local file

  bash -n "$DOTFILES_ROOT/install"
  for file in "$DOTFILES_ROOT"/cmd/bin/* "$DOTFILES_ROOT"/cmd/*/main.sh; do
    bash -n "$file"
  done
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
    PATH="$DOTFILES_ROOT/cmd/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
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
    PATH="$DOTFILES_ROOT/cmd/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    dotfiles "$@" >"$output_file" 2>"$error_file"
}

install_entrypoint_test::assert_help() {
  install_entrypoint_test::run_install "help" --help
  install_entrypoint_test::assert_contains "$WORK_DIR/help.out" "COMMANDS"
  install_entrypoint_test::assert_contains "$WORK_DIR/help.out" "EXAMPLES"
  install_entrypoint_test::assert_not_contains "$WORK_DIR/help.out" "Usage:"
  install_entrypoint_test::assert_no_stderr "help"

  install_entrypoint_test::run_install_with_home "$REPO_HOME_DIR" "help_home" help
  install_entrypoint_test::assert_contains "$WORK_DIR/help_home.out" "~/${DOTFILES_ROOT##*/}/install neovim"
  install_entrypoint_test::assert_not_contains "$WORK_DIR/help_home.out" "Usage:"
  install_entrypoint_test::assert_no_stderr "help_home"
  printf 'ok help\n'
}

install_entrypoint_test::assert_list() {
  install_entrypoint_test::run_install "list" list
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "Install targets"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "usage: dfx install <target> [item...]"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "target"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "installs"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "example"
  install_entrypoint_test::assert_contains "$WORK_DIR/list.out" "dotfiles          shell, Git, Vim, Neovim links"
  install_entrypoint_test::assert_not_contains "$WORK_DIR/list.out" "theme             current shell theme deps"
  install_entrypoint_test::assert_not_contains "$WORK_DIR/list.out" "dfx install theme"
  install_entrypoint_test::assert_no_stderr "list"
  printf 'ok list\n'
}

install_entrypoint_test::assert_dotfiles_command() {
  install_entrypoint_test::run_dotfiles_command "dotfiles_path" path
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_path.out" "$DOTFILES_ROOT"
  install_entrypoint_test::assert_no_stderr "dotfiles_path"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_commands" complete commands
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_commands.out" "install:run the interactive installer or direct install target"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_commands.out" "list:list direct install targets"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_commands"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_targets" complete targets
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_targets.out" "neovim:Neovim"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_targets"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_items" complete items packages
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_items.out" "taskwarrior:Taskwarrior"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_items"

  install_entrypoint_test::run_dotfiles_command "dotfiles_complete_theme_items" complete items themes
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_theme_items.out" "starship:starship"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_complete_theme_items.out" "none:none"
  install_entrypoint_test::assert_no_stderr "dotfiles_complete_theme_items"

  install_entrypoint_test::run_dotfiles_command "dotfiles_themes_help" themes
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_themes_help.out" "COMMANDS"
  install_entrypoint_test::assert_no_stderr "dotfiles_themes_help"

  install_entrypoint_test::run_dotfiles_command "dotfiles_themes_list" themes list
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_themes_list.out" "Shell themes"
  install_entrypoint_test::assert_contains "$WORK_DIR/dotfiles_themes_list.out" "starship"
  install_entrypoint_test::assert_no_stderr "dotfiles_themes_list"

  printf 'ok dotfiles_command\n'
}

install_entrypoint_test::assert_invalid_target() {
  local output_file="$WORK_DIR/invalid.out"
  local error_file="$WORK_DIR/invalid.err"
  local expected_targets="dotfiles, packages, oh_my_zsh, neovim"

  if [[ "${OSTYPE:-}" == darwin* ]]; then
    expected_targets+=", fonts, desktop_apps, macos_defaults"
  fi
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
  install_entrypoint_test::assert_contains "$error_file" "expected: $expected_targets"
  install_entrypoint_test::assert_contains "$error_file" "usage: $DOTFILES_ROOT/install <module> [item...]"
  install_entrypoint_test::assert_contains "$error_file" "next: $DOTFILES_ROOT/install list"
  printf 'ok invalid_target\n'
}

install_entrypoint_test::assert_structured_direct_errors() {
  local output_file error_file

  output_file="$WORK_DIR/invalid_item.out"
  error_file="$WORK_DIR/invalid_item.err"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" packages not-a-package >"$output_file" 2>"$error_file"; then
    install_entrypoint_test::fail "invalid direct item unexpectedly succeeded"
  fi
  install_entrypoint_test::assert_contains "$error_file" "Error: unknown item for install target"
  install_entrypoint_test::assert_contains "$error_file" "target: packages"
  install_entrypoint_test::assert_contains "$error_file" "input: not-a-package"

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
  if printf '%s' "$json_request" | env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_INSTALL_UI_MODE=json OSTYPE=darwin PATH="/usr/bin:/bin:/usr/sbin:/sbin" TERM="xterm-256color" bash "$DOTFILES_ROOT/install" >"$output_file" 2>"$error_file"; then
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

install_entrypoint_test::assert_install_remote_piped_tty() {
  local source_repo="$WORK_DIR/install-remote-source"
  local checkout_dir="$WORK_DIR/install-remote-checkout"
  local runner_file="$WORK_DIR/install-remote-piped-runner.bash"
  local output_file="$WORK_DIR/install-remote-piped.out"

  mkdir -p "$source_repo"
  git -C "$source_repo" init -q
  git -C "$source_repo" symbolic-ref HEAD refs/heads/main
  git -C "$source_repo" config user.name "Dotfiles Test"
  git -C "$source_repo" config user.email "dotfiles@example.invalid"

  cat >"$source_repo/install" <<'BASH'
#!/usr/bin/env bash

set -euo pipefail

if [[ ! -t 0 ]]; then
  printf 'fake installer stdin is not a TTY\n' >&2
  exit 1
fi

printf 'remote installer received TTY\n'
BASH
  chmod +x "$source_repo/install"
  git -C "$source_repo" add install
  git -C "$source_repo" commit -q -m "test: add fake installer"

  cat >"$runner_file" <<'BASH'
#!/usr/bin/env bash

set -euo pipefail

cat "$BOOTSTRAP_PATH" | bash
BASH
  chmod +x "$runner_file"

  install_entrypoint_test::run_with_pty "$output_file" \
    env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    DOTFILES_REPO="$source_repo" \
    DOTFILES_DIR="$checkout_dir" \
    DOTFILES_REF=main \
    BOOTSTRAP_PATH="$DOTFILES_ROOT/scripts/install-remote.bash" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    bash "$runner_file"

  install_entrypoint_test::assert_contains "$output_file" "remote installer received TTY"
  install_entrypoint_test::assert_not_contains "$output_file" "fake installer stdin is not a TTY"
  printf 'ok install_remote_piped_tty\n'
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
  install_entrypoint_test::assert_install_remote_piped_tty
}

install_entrypoint_test::main "$@"
