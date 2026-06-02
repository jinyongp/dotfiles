#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ui-rendering.XXXXXX")"

trap 'rm -rf "$WORK_DIR"' EXIT

source "$DOTFILES_ROOT/scripts/lib/ui/ansi.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/mode.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/tokens.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/format.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/message.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/help.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"

ui_rendering_test::fail() {
  printf 'ui-rendering: %s\n' "$1" >&2
  exit 1
}

ui_rendering_test::assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" == *"$needle"* ]] || ui_rendering_test::fail "$message"
}

ui_rendering_test::assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" != *"$needle"* ]] || ui_rendering_test::fail "$message"
}

ui_rendering_test::strip_ansi() {
  perl -0pe 's/\e\][^\a]*(?:\a|\e\\\\)//g; s/\e\[[0-?]*[ -\/]*[@-~]//g; s/\r//g'
}

ui_rendering_test::assert_color_controls() {
  local output=""

  output="$(NO_COLOR= CLICOLOR=1 TERM=xterm-256color FORCE_COLOR=1 ui::accent "accent" | sed -n l)"
  ui_rendering_test::assert_contains "$output" "\\033[" "FORCE_COLOR should force ANSI"

  output="$(CLICOLOR=1 TERM=xterm-256color FORCE_COLOR=1 NO_COLOR=1 ui::accent "accent" | sed -n l)"
  ui_rendering_test::assert_not_contains "$output" "\\033[" "NO_COLOR should override FORCE_COLOR"

  output="$(NO_COLOR= CLICOLOR=1 TERM=dumb FORCE_COLOR=1 ui::symbol question)"
  [[ "$output" == ">" ]] || ui_rendering_test::fail "TERM=dumb should use plain symbol"

  output="$(NO_COLOR= CLICOLOR=1 TERM=xterm-256color FORCE_COLOR=1 DOTFILES_DISABLE_OSC8=1 ui::link "label" "https://example.test" | sed -n l)"
  ui_rendering_test::assert_not_contains "$output" "\\033]8" "DOTFILES_DISABLE_OSC8 should disable OSC8"

  printf 'ok color_controls\n'
}

ui_rendering_test::assert_modes_and_symbols() {
  local output=""

  output="$(DOTFILES_INSTALL_UI_MODE=invalid ui::mode)"
  [[ "$output" == "auto" ]] || ui_rendering_test::fail "invalid mode should fall back to auto"

  output="$(NO_COLOR= CLICOLOR=1 TERM=xterm-256color DOTFILES_INSTALL_UI_MODE=auto ui::symbol question)"
  [[ "$output" == "◆" ]] || ui_rendering_test::fail "auto mode should use rich symbol when terminal supports it"

  output="$(DOTFILES_INSTALL_UI_MODE=plain ui::symbol question)"
  [[ "$output" == ">" ]] || ui_rendering_test::fail "plain mode should use ASCII symbol"

  printf 'ok modes_and_symbols\n'
}

ui_rendering_test::assert_json_and_errors() {
  local json_file="$WORK_DIR/error.json"
  local plain=""

  DOTFILES_INSTALL_UI_MODE=json ui::validation_error "invalid input" \
    $'input\tbad' \
    $'expected\tgood' 2>"$json_file"
  python3 - "$json_file" <<'PY'
import json
import sys

event = json.load(open(sys.argv[1], encoding="utf-8"))
assert event["schema"] == "dotfiles.ui.v1"
assert event["type"] == "validation_error"
assert event["data"]["fields"] == {"input": "bad", "expected": "good"}
PY

  DOTFILES_INSTALL_UI_MODE=json ui::validation_error "invalid input" \
    $'input\tbad\001value' 2>"$json_file"
  python3 - "$json_file" <<'PY'
import json
import sys

event = json.load(open(sys.argv[1], encoding="utf-8"))
assert event["data"]["fields"] == {"input": "bad\x01value"}
PY

  plain="$(DOTFILES_INSTALL_UI_MODE=plain ui::validation_error "invalid input" $'input\tbad' $'expected\tgood' 2>&1 | ui_rendering_test::strip_ansi)"
  ui_rendering_test::assert_contains "$plain" "Error: invalid input" "plain validation should include message"
  ui_rendering_test::assert_contains "$plain" "input: bad" "plain validation should preserve field order"
  ui_rendering_test::assert_contains "$plain" "expected: good" "plain validation should preserve expected field"

  printf 'ok json_and_errors\n'
}

ui_rendering_test::assert_help_and_reports() {
  local output=""

  output="$({ ui::help_start "Tool" "Summary."; ui::help_usage "tool run"; ui::help_commands $'run\trun\tRun it.'; ui::help_options; ui::help_examples "tool run"; } | ui_rendering_test::strip_ansi)"
  ui_rendering_test::assert_contains "$output" "Tool" "help should include title"
  ui_rendering_test::assert_contains "$output" "Usage:" "help should include usage"
  ui_rendering_test::assert_contains "$output" "Commands:" "help should include commands"
  ui_rendering_test::assert_not_contains "$output" "Options:" "empty options should be omitted"

  output="$({ ui::report_section "Empty"; ui::report_section "Filled" "one"; } | ui_rendering_test::strip_ansi)"
  ui_rendering_test::assert_not_contains "$output" "Empty" "empty report section should be omitted"
  ui_rendering_test::assert_contains "$output" "Filled" "non-empty report section should render"

  printf 'ok help_and_reports\n'
}

ui_rendering_test::assert_status_alignment() {
  local output=""

  output="$(ui::status installed "done" | ui_rendering_test::strip_ansi)"
  ui_rendering_test::assert_contains "$output" "installed  done" "status label should be padded"

  output="$(ui::status warning "check" | ui_rendering_test::strip_ansi)"
  ui_rendering_test::assert_contains "$output" "warning    check" "warning label should be padded"

  printf 'ok status_alignment\n'
}

ui_rendering_test::main() {
  ui_rendering_test::assert_color_controls
  ui_rendering_test::assert_modes_and_symbols
  ui_rendering_test::assert_json_and_errors
  ui_rendering_test::assert_help_and_reports
  ui_rendering_test::assert_status_alignment
  printf 'all ui rendering tests passed\n'
}

ui_rendering_test::main "$@"
