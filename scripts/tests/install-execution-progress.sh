#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-execution-progress.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$HOME/.config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"
DOTFILES_EXECUTION_LOG_DIR="$WORK_DIR/logs"

export DOTFILES_ROOT HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR DOTFILES_EXECUTION_LOG_DIR

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR" "$DOTFILES_EXECUTION_LOG_DIR"

source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/execution-progress.zsh"

install_execution_test::fail() {
  print -u2 -- "install-execution-progress: $1"
  exit 1
}

install_execution_test::assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  print -r -- "$haystack" | grep -Fq -- "$needle" || install_execution_test::fail "$message"
}

install_execution_test::assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if print -r -- "$haystack" | grep -Fq -- "$needle"; then
    install_execution_test::fail "$message"
  fi
}

install_execution_test::normalize_file() {
  perl -0pe '
    s/\e\][^\a]*(?:\a|\e\\\\)//g;
    s/\e\[[0-?]*[ -\/]*[@-~]//g;
    s/\r//g;
    s/\n+\z/\n/;
  ' "$1"
}

install_execution_test::reset_state() {
  DOTFILES_RESULT_INSTALLED_ITEMS=()
  DOTFILES_RESULT_REUSED_ITEMS=()
  DOTFILES_RESULT_SKIPPED_ITEMS=()
  DOTFILES_RESULT_CREATED_FILES=()
  DOTFILES_RESULT_UPDATED_FILES=()
  DOTFILES_RESULT_LINKED_FILES=()
  DOTFILES_RESULT_BACKED_UP_FILES=()
  DOTFILES_RESULT_COMPLETED_WORK=()
  DOTFILES_RESULT_NOTES=()
  DOTFILES_RESULT_WARNINGS=()

  DOTFILES_EXECUTION_TTY_FD=""
  DOTFILES_EXECUTION_TTY_ERR_FD=""
  DOTFILES_EXECUTION_STEP_ID=""
  DOTFILES_EXECUTION_STEP_LABEL=""
  DOTFILES_EXECUTION_STEP_LOG_FILE=""
  DOTFILES_EXECUTION_STEP_ACTIVE=0
  DOTFILES_EXECUTION_STEP_INDEX=0
  DOTFILES_EXECUTION_STEP_INSTALLED_COUNT=0
  DOTFILES_EXECUTION_STEP_REUSED_COUNT=0
  DOTFILES_EXECUTION_STEP_SKIPPED_COUNT=0
  DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT=0
  DOTFILES_EXECUTION_STEP_EXTRA_COUNT=0
  DOTFILES_EXECUTION_STEP_WARNING_COUNT=0

  rm -rf "$DOTFILES_EXECUTION_LOG_DIR"
  mkdir -p "$DOTFILES_EXECUTION_LOG_DIR"
}

install_execution_test::successful_step() {
  print -r -- "hidden stdout"
  print -u2 -- "hidden stderr"
  dotfiles::execution_record_event installing "git via Homebrew"
  dotfiles::record_installed "git via Homebrew"
  dotfiles::record_reused "jq command"
  dotfiles::record_skipped "TypeScript editor tooling"
  dotfiles::record_file_linked "$HOME/.zshrc" "$DOTFILES_ROOT/zsh/.zshrc"
  dotfiles::record_completed_work "Linked repo-managed Neovim config"
  dotfiles::log_warn "Prompt cache needs refresh."
}

install_execution_test::failing_step() {
  print -r -- "before failure stdout"
  print -u2 -- "before failure stderr"
  dotfiles::execution_record_event installing "powerlevel10k theme"
  return 17
}

install_execution_test::simple_step() {
  dotfiles::record_reused "starship prompt binary"
}

install_execution_test::quiet_step() {
  dotfiles::record_reused_quiet "Managed link already in place: ~/.zshrc"
  dotfiles::record_skipped_quiet "Optional editor tooling"
}

install_execution_test::foreground_step() {
  print -u2 -- "hidden before foreground command"
  dotfiles::execution_run_foreground /bin/sh -c \
    'printf "%s\n" "visible foreground stdout"; printf "%s\n" "visible foreground stderr" >&2'
  print -u2 -- "hidden after foreground command"
}

install_execution_test::assert_successful_progress() {
  local output_file="$WORK_DIR/success.out"
  local output=""
  local expected_link_line=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=auto
  TERM=xterm-256color

  {
    dotfiles::execution_run_step demo "Demo Module" install_execution_test::successful_step
  } >"$output_file" 2>&1

  output="$(install_execution_test::normalize_file "$output_file")"
  expected_link_line="completed  Linked ~/.zshrc -> $(dotfiles::display_path "$DOTFILES_ROOT/zsh/.zshrc")"

  install_execution_test::assert_contains "$output" "◆  Demo Module" "missing module header"
  install_execution_test::assert_contains "$output" "installing git via Homebrew" "missing installing status"
  install_execution_test::assert_contains "$output" "installed  git via Homebrew" "missing installed status"
  install_execution_test::assert_contains "$output" "reused     jq command" "missing reused status"
  install_execution_test::assert_contains "$output" "skipped    TypeScript editor tooling" "missing skipped status"
  install_execution_test::assert_contains "$output" "$expected_link_line" "missing file change status"
  install_execution_test::assert_contains "$output" "completed  Linked repo-managed Neovim config" "missing completed work status"
  install_execution_test::assert_contains "$output" "warning    Prompt cache needs refresh." "missing inline warning"
  install_execution_test::assert_contains "$output" "completed  1 installed, 1 reused, 1 skipped, 1 file changes, 1 extra actions, 1 warnings" "missing completion summary"
  install_execution_test::assert_not_contains "$output" "hidden stdout" "raw stdout should be hidden on success"
  install_execution_test::assert_not_contains "$output" "hidden stderr" "raw stderr should be hidden on success"

  [[ -z "$(find "$DOTFILES_EXECUTION_LOG_DIR" -type f -print -quit)" ]] || install_execution_test::fail "successful step should not leave raw logs"
  print -- "ok successful_progress"
}

install_execution_test::assert_failure_progress() {
  local output_file="$WORK_DIR/failure.out"
  local output=""
  local raw_log=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=auto
  TERM=xterm-256color

  if {
    dotfiles::execution_run_step theme "Theme dependencies" install_execution_test::failing_step
  } >"$output_file" 2>&1; then
    install_execution_test::fail "failing step unexpectedly succeeded"
  fi

  output="$(install_execution_test::normalize_file "$output_file")"

  install_execution_test::assert_contains "$output" "failed     exited with status 17" "missing failure status"
  install_execution_test::assert_contains "$output" "failed     raw log:" "missing raw log path"

  raw_log="$(print -r -- "$output" | sed -n 's/^   failed     raw log: //p' | tail -n 1)"
  [[ -n "$raw_log" ]] || install_execution_test::fail "failed run did not expose raw log path"
  [[ -f "$raw_log" ]] || install_execution_test::fail "expected retained raw log file"

  install_execution_test::assert_contains "$(cat "$raw_log")" "before failure stdout" "raw log should keep stdout"
  install_execution_test::assert_contains "$(cat "$raw_log")" "before failure stderr" "raw log should keep stderr"
  print -- "ok failure_progress"
}

install_execution_test::assert_failure_progress_under_errexit() {
  local output_file="$WORK_DIR/failure-errexit.out"
  local output=""

  install_execution_test::reset_state

  if zsh -lc '
    set -e
    source "$DOTFILES_ROOT/scripts/lib/style.sh"
    source "$DOTFILES_ROOT/scripts/lib/common.zsh"
    source "$DOTFILES_ROOT/scripts/lib/execution-progress.zsh"
    DOTFILES_EXECUTION_LOG_DIR="$DOTFILES_EXECUTION_LOG_DIR"
    fail_step() {
      print -r -- "before failure stdout"
      print -u2 -- "before failure stderr"
      dotfiles::execution_record_event installing "powerlevel10k theme"
      return 17
    }
    dotfiles::execution_run_step theme "Theme dependencies" fail_step
  ' >"$output_file" 2>&1; then
    install_execution_test::fail "set -e failure run unexpectedly succeeded"
  fi

  output="$(install_execution_test::normalize_file "$output_file")"
  install_execution_test::assert_contains "$output" "failed     exited with status 17" "failure block should survive errexit"
  install_execution_test::assert_contains "$output" "failed     raw log:" "raw log path should survive errexit"
  print -- "ok failure_progress_under_errexit"
}

install_execution_test::assert_plain_mode() {
  local output_file="$WORK_DIR/plain.out"
  local output=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=plain

  {
    dotfiles::execution_run_step prompt "Prompt" install_execution_test::simple_step
  } >"$output_file" 2>&1

  output="$(install_execution_test::normalize_file "$output_file")"

  install_execution_test::assert_contains "$output" ">  Prompt" "plain mode should use ASCII header marker"
  install_execution_test::assert_not_contains "$output" "◆" "plain mode should avoid Unicode execution markers"
  print -- "ok plain_mode"
}

install_execution_test::assert_quiet_events() {
  local output_file="$WORK_DIR/quiet.out"
  local output=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=auto
  TERM=xterm-256color

  {
    dotfiles::execution_run_step dotfiles "Dotfiles" install_execution_test::quiet_step
  } >"$output_file" 2>&1

  output="$(install_execution_test::normalize_file "$output_file")"

  install_execution_test::assert_contains "$output" "◆  Dotfiles" "missing quiet-event module header"
  install_execution_test::assert_contains "$output" "completed  1 reused, 1 skipped" "quiet events should still affect summary counts"
  install_execution_test::assert_not_contains "$output" "Managed link already in place" "quiet reused event should not be printed inline"
  install_execution_test::assert_not_contains "$output" "Optional editor tooling" "quiet skipped event should not be printed inline"
  print -- "ok quiet_events"
}

install_execution_test::assert_foreground_command_output() {
  local output_file="$WORK_DIR/foreground.out"
  local output=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=auto
  TERM=xterm-256color

  {
    dotfiles::execution_run_step shell "Shell" install_execution_test::foreground_step
  } >"$output_file" 2>&1

  output="$(install_execution_test::normalize_file "$output_file")"

  install_execution_test::assert_contains "$output" "visible foreground stdout" "foreground stdout should bypass the step log"
  install_execution_test::assert_contains "$output" "visible foreground stderr" "foreground stderr should bypass the step log"
  install_execution_test::assert_not_contains "$output" "hidden before foreground command" "ordinary stderr should remain hidden before a foreground command"
  install_execution_test::assert_not_contains "$output" "hidden after foreground command" "ordinary stderr should remain hidden after a foreground command"
  print -- "ok foreground_command_output"
}

install_execution_test::assert_invalid_mode_falls_back_to_auto() {
  local output_file="$WORK_DIR/invalid-mode.out"
  local output=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=invalid
  TERM=xterm-256color
  {
    dotfiles::execution_run_step prompt "Prompt" install_execution_test::simple_step
  } >"$output_file" 2>&1

  output="$(install_execution_test::normalize_file "$output_file")"

  install_execution_test::assert_contains "$output" "◆  Prompt" "invalid UI mode should fall back to auto marker"
  install_execution_test::assert_contains "$output" "reused     starship prompt binary" "invalid UI mode should still render progress"
  print -- "ok invalid_mode_falls_back_to_auto"
}

install_execution_test::assert_json_mode() {
  local output_file="$WORK_DIR/json.out"
  local output=""
  local type_list=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=json
  {
    dotfiles::execution_run_step demo "Demo Module" install_execution_test::successful_step
  } >"$output_file" 2>&1

  output="$(cat "$output_file")"
  type_list="$(python3 - "$output_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    events = [json.loads(line) for line in handle if line.strip()]

print(",".join(event["type"] for event in events))

assert events[0]["schema"] == "dotfiles.ui.v1"
assert events[0]["type"] == "progress_start"
assert events[0]["surface"] == "install"
assert events[0]["mode"] == "json"
assert events[0]["data"]["stepId"] == "demo"
assert events[0]["data"]["label"] == "Demo Module"

assert any(event["type"] == "progress_event" and event["data"]["kind"] == "installed" for event in events)
assert any(event["type"] == "progress_event" and event["data"]["kind"] == "warning" for event in events)

finish = events[-1]
assert finish["type"] == "progress_finish"
assert finish["data"]["status"] == "completed"
assert finish["data"]["counts"]["installed"] == 1
assert finish["data"]["counts"]["reused"] == 1
assert finish["data"]["counts"]["skipped"] == 1
assert finish["data"]["counts"]["fileChanges"] == 1
assert finish["data"]["counts"]["extraActions"] == 1
assert finish["data"]["counts"]["warnings"] == 1
PY
)"

  install_execution_test::assert_contains "$type_list" "progress_start" "json mode should emit start event"
  install_execution_test::assert_contains "$type_list" "progress_event" "json mode should emit progress events"
  install_execution_test::assert_contains "$type_list" "progress_finish" "json mode should emit finish event"
  install_execution_test::assert_not_contains "$output" "◆  Demo Module" "json mode should not render human header"
  install_execution_test::assert_not_contains "$output" "hidden stdout" "json success should hide raw stdout"
  install_execution_test::assert_not_contains "$output" "hidden stderr" "json success should hide raw stderr"
  print -- "ok json_mode"
}

install_execution_test::assert_json_failure_mode() {
  local output_file="$WORK_DIR/json-failure.out"
  local output=""
  local raw_log=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=json
  if {
    dotfiles::execution_run_step theme "Theme dependencies" install_execution_test::failing_step
  } >"$output_file" 2>&1; then
    install_execution_test::fail "json failing step unexpectedly succeeded"
  fi

  output="$(cat "$output_file")"
  raw_log="$(python3 - "$output_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    events = [json.loads(line) for line in handle if line.strip()]

finish = events[-1]
assert finish["type"] == "progress_finish"
assert finish["data"]["status"] == "failed"
assert finish["data"]["exitStatus"] == 17
print(finish["data"]["rawLog"])
PY
)"

  [[ -n "$raw_log" ]] || install_execution_test::fail "json failure did not expose raw log path"
  [[ -f "$raw_log" ]] || install_execution_test::fail "json failure should retain raw log file"
  install_execution_test::assert_contains "$(cat "$raw_log")" "before failure stdout" "json raw log should keep stdout"
  install_execution_test::assert_contains "$(cat "$raw_log")" "before failure stderr" "json raw log should keep stderr"
  install_execution_test::assert_not_contains "$output" "failed     raw log:" "json failure should not render human raw log line"
  print -- "ok json_failure_mode"
}

install_execution_test::assert_runner_json_completion() {
  local plan_file="$WORK_DIR/empty-plan.env"
  local output_file="$WORK_DIR/runner-json.out"
  local error_file="$WORK_DIR/runner-json.err"

  cat >"$plan_file" <<EOF
DOTFILES_INSTALL_UI_MODE=json
DOTFILES_PLATFORM=macos
DOTFILES_PACKAGE_MANAGER=brew
DOTFILES_THEME=starship
DOTFILES_ENABLE_OH_MY_ZSH=0
DOTFILES_RUN_THEME_INSTALL=0
DOTFILES_ALLOW_AUTO_LAUNCH_ZSH=0
DOTFILES_SELECTED_MODULES=''
DOTFILES_BOOTSTRAP_ZSH_STATUS=none
DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER=''
DOTFILES_CONFIG_DIR='$DOTFILES_CONFIG_DIR'
EOF

  env -i HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" DOTFILES_CONFIG_DIR="$DOTFILES_CONFIG_DIR" PATH="$PATH" zsh -f "$DOTFILES_ROOT/scripts/run-install-plan.zsh" "$plan_file" >"$output_file" 2>"$error_file"
  python3 - "$output_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    events = [json.loads(line) for line in handle if line.strip()]

assert events
assert events[-1]["type"] == "install_complete"
assert all(event["schema"] == "dotfiles.ui.v1" for event in events)
PY

  if grep -Fq "Post-install Report" "$output_file"; then
    install_execution_test::fail "runner json mode should not print human install report"
  fi
  [[ ! -s "$error_file" ]] || install_execution_test::fail "runner json mode should not write stderr for empty plan"
  print -- "ok runner_json_completion"
}

install_execution_test::main() {
  install_execution_test::assert_successful_progress
  install_execution_test::assert_failure_progress
  install_execution_test::assert_failure_progress_under_errexit
  install_execution_test::assert_plain_mode
  install_execution_test::assert_quiet_events
  install_execution_test::assert_foreground_command_output
  install_execution_test::assert_invalid_mode_falls_back_to_auto
  install_execution_test::assert_json_mode
  install_execution_test::assert_json_failure_mode
  install_execution_test::assert_runner_json_completion
  print -- "all install execution progress tests passed"
}

install_execution_test::main "$@"
