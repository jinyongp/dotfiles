#!/bin/zsh

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

install_execution_test::assert_successful_progress() {
  local output_file="$WORK_DIR/success.out"
  local output=""
  local expected_link_line=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=compact

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
  DOTFILES_INSTALL_UI_MODE=compact

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

install_execution_test::assert_rich_spacing() {
  local compact_file="$WORK_DIR/compact-spacing.out"
  local rich_file="$WORK_DIR/rich-spacing.out"
  local compact_output=""
  local rich_output=""

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=compact
  {
    dotfiles::execution_run_step prompt "Prompt" install_execution_test::simple_step
  } >"$compact_file" 2>&1

  install_execution_test::reset_state
  DOTFILES_INSTALL_UI_MODE=rich
  {
    dotfiles::execution_run_step prompt "Prompt" install_execution_test::simple_step
  } >"$rich_file" 2>&1

  compact_output="$(install_execution_test::normalize_file "$compact_file")"
  rich_output="$(install_execution_test::normalize_file "$rich_file")"

  print -r -- "$compact_output" | perl -0ne 'exit(!/reused\s+starship prompt binary\n   completed/s)' \
    || install_execution_test::fail "compact mode should stay dense"
  print -r -- "$rich_output" | perl -0ne 'exit(!/reused\s+starship prompt binary\n\n   completed/s)' \
    || install_execution_test::fail "rich mode should keep stronger separation"
  print -- "ok rich_spacing"
}

install_execution_test::main() {
  install_execution_test::assert_successful_progress
  install_execution_test::assert_failure_progress
  install_execution_test::assert_failure_progress_under_errexit
  install_execution_test::assert_plain_mode
  install_execution_test::assert_rich_spacing
  print -- "all install execution progress tests passed"
}

install_execution_test::main "$@"
