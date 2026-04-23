#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
SNAPSHOT_DIR="$SCRIPT_DIR/prompt-snapshots"

prompt_test::fail() {
  printf 'prompt-rendering: %s\n' "$1" >&2
  exit 1
}

prompt_test::normalize_file() {
  local input_file="$1"

  perl -0pe '
    s/\e\][^\a]*(?:\a|\e\\\\)//g;
    s/\e\[[0-?]*[ -\/]*[@-~]//g;
    s/\r//g;
    s/\n+\z/\n/;
  ' "$input_file"
}

prompt_test::case_names() {
  printf '%s\n' \
    "intro_with_meta" \
    "summary_basic" \
    "text_basic" \
    "text_validation_retry" \
    "select_basic" \
    "select_with_disabled_and_status" \
    "multiselect_basic" \
    "multiselect_with_scroll_indicators" \
    "multiselect_with_disabled_rows"
}

prompt_test::mode_names() {
  printf '%s\n' \
    "compact" \
    "plain" \
    "rich"
}

prompt_test::write_case_input() {
  local case_name="$1"

  case "$case_name" in
    text_basic)
      printf '\n'
      ;;
    text_validation_retry)
      printf 'bad slug\nvalid-slug\n'
      ;;
  esac
}

prompt_test::run_case_to_file() {
  local case_name="$1"
  local mode="$2"
  local output_file="$3"

  prompt_test::write_case_input "$case_name" \
    | DOTFILES_ROOT="$DOTFILES_ROOT" DOTFILES_INSTALL_UI_MODE="$mode" bash "$0" --case "$case_name" --mode "$mode" \
    >"$output_file"
}

prompt_test::assert_compact_expectations() {
  local case_name="$1"
  local actual_file="$2"

  case "$case_name" in
    select_basic)
      perl -0ne 'exit(!/Cross-platform prompt using the Starship binary\.\n   ● starship/s)' "$actual_file" \
        || prompt_test::fail "compact select_basic should keep dense spacing"
      ;;
    select_with_disabled_and_status)
      grep -Fq "starship [current]" "$actual_file" \
        || prompt_test::fail "compact select_with_disabled_and_status should render inline current status"
      grep -Fq "powerlevel10k [installed]" "$actual_file" \
        || prompt_test::fail "compact select_with_disabled_and_status should render inline installed status"
      ;;
  esac
}

prompt_test::assert_plain_expectations() {
  local case_name="$1"
  local raw_file="$2"
  local actual_file="$3"

  if grep -q '[◆◇●○◻◼›↑↓]' "$actual_file"; then
    prompt_test::fail "plain mode should not render Unicode prompt markers"
  fi

  perl -ne 'if (/\e\[(?:[0-9]+;)*(?:3|4)(?:;[0-9]+)*m/) { exit 1 } END { exit 0 }' "$raw_file" \
    || prompt_test::fail "plain mode should not emit italic or underline ANSI sequences"

  case "$case_name" in
    select_basic|select_with_disabled_and_status|multiselect_basic|multiselect_with_scroll_indicators|multiselect_with_disabled_rows)
      grep -Fq "Up/Down" "$actual_file" \
        || prompt_test::fail "plain mode should render ASCII navigation hints"
      ;;
  esac
}

prompt_test::assert_rich_expectations() {
  local case_name="$1"
  local actual_file="$2"

  case "$case_name" in
    select_basic)
      perl -0ne 'exit(!/Cross-platform prompt using the Starship binary\.\n\n   ● starship/s)' "$actual_file" \
        || prompt_test::fail "rich select_basic should keep spaced layout"
      ;;
    select_with_disabled_and_status)
      grep -Eq 'starship[[:space:]]{2,}\[current\]' "$actual_file" \
        || prompt_test::fail "rich select_with_disabled_and_status should keep aligned badges"
      ;;
  esac
}

prompt_test::assert_mode_expectations() {
  local mode="$1"
  local case_name="$2"
  local raw_file="$3"
  local actual_file="$4"

  case "$mode" in
    compact) prompt_test::assert_compact_expectations "$case_name" "$actual_file" ;;
    plain) prompt_test::assert_plain_expectations "$case_name" "$raw_file" "$actual_file" ;;
    rich) prompt_test::assert_rich_expectations "$case_name" "$actual_file" ;;
  esac
}

prompt_test::compare_case() {
  local mode="$1"
  local case_name="$2"
  local work_dir="$3"
  local raw_file="$work_dir/${mode}_${case_name}.raw"
  local actual_file="$work_dir/${mode}_${case_name}.txt"
  local expected_file="$SNAPSHOT_DIR/$mode/${case_name}.txt"

  prompt_test::run_case_to_file "$case_name" "$mode" "$raw_file"
  prompt_test::normalize_file "$raw_file" >"$actual_file"
  prompt_test::assert_mode_expectations "$mode" "$case_name" "$raw_file" "$actual_file"

  if [[ "${UPDATE:-0}" == "1" ]]; then
    mkdir -p "$SNAPSHOT_DIR/$mode"
    cp "$actual_file" "$expected_file"
    printf 'updated %s/%s\n' "$mode" "$case_name"
    return 0
  fi

  if [[ ! -f "$expected_file" ]]; then
    printf 'missing snapshot: %s\n' "$expected_file" >&2
    return 1
  fi

  if ! diff -u "$expected_file" "$actual_file"; then
    printf 'snapshot mismatch: %s\n' "$case_name" >&2
    return 1
  fi

  printf 'ok %s/%s\n' "$mode" "$case_name"
}

prompt_test::record() {
  printf '%s\t%s\t%s\t%s\t%s\t%s' \
    "$1" \
    "$2" \
    "${3:-}" \
    "${4:-0}" \
    "${5:-0}" \
    "${6:-}"
}

prompt_test::set_keys() {
  local key

  : >"$PROMPT_TEST__KEY_FILE"
  for key in "$@"; do
    printf '%s\n' "$key" >>"$PROMPT_TEST__KEY_FILE"
  done
}

prompt_test::install_overrides() {
  PROMPT_TEST__RENDER_COUNT=0
  PROMPT_TEST_COLUMNS="${PROMPT_TEST_COLUMNS:-80}"
  PROMPT_TEST_LINES="${PROMPT_TEST_LINES:-24}"

  prompt::enter_raw_mode() {
    PROMPT__RAW_MODE=1
  }

  prompt::leave_raw_mode() {
    PROMPT__RAW_MODE=0
  }

  prompt::read_key() {
    local key=""
    local remaining_file=""

    if [[ ! -s "$PROMPT_TEST__KEY_FILE" ]]; then
      printf 'enter'
      return 0
    fi

    key="$(sed -n '1p' "$PROMPT_TEST__KEY_FILE")"
    remaining_file="${PROMPT_TEST__KEY_FILE}.remaining"
    sed '1d' "$PROMPT_TEST__KEY_FILE" >"$remaining_file"
    mv "$remaining_file" "$PROMPT_TEST__KEY_FILE"

    printf '%s' "$key"
  }

  prompt::clear_rendered_block() {
    if [[ "${PROMPT__RENDERED_LINES:-0}" -gt 0 ]]; then
      printf '\n'
    fi

    PROMPT__RENDERED_LINES=0
  }

  prompt::render_block() {
    local line

    prompt::clear_rendered_block
    PROMPT_TEST__RENDER_COUNT=$((PROMPT_TEST__RENDER_COUNT + 1))

    printf '[[ render %s ]]\n' "$PROMPT_TEST__RENDER_COUNT"
    for line in "$@"; do
      printf '%s\n' "$line"
    done

    PROMPT__RENDERED_LINES=$#
  }

  prompt::terminal_columns() {
    printf '%s' "$PROMPT_TEST_COLUMNS"
  }

  prompt::terminal_lines() {
    printf '%s' "$PROMPT_TEST_LINES"
  }
}

prompt_test::case_summary_basic() {
  prompt::summary \
    "Installation plan" \
    "Platform: macOS" \
    "Modules: Dotfiles, Neovim" \
    "Auto: oh-my-zsh included for theme support" \
    "Reuse: ~/.oh-my-zsh" \
    "Skip: Fonts"
}

prompt_test::case_intro_with_meta() {
  PROMPT_TEST_COLUMNS=40

  prompt::intro "Dotfiles Installer" "macOS"
  prompt::outro "Done."
}

prompt_test::case_text_basic() {
  local answer=""

  prompt::text \
    answer \
    "Enter your Git email." \
    "jinyong@example.com" \
    "no" \
    "Used for your Git commits."

  printf '[[ value ]]\n%s\n' "$answer"
}

prompt_test::slug_validator() {
  [[ "$1" =~ ^[a-z0-9-]+$ ]]
}

prompt_test::case_text_validation_retry() {
  local machine_name=""

  prompt::text \
    machine_name \
    "Choose a machine name." \
    "" \
    "no" \
    prompt_test::slug_validator \
    "Use lowercase letters, numbers, and hyphens only." \
    "Used for local bootstrap labels."

  printf '[[ value ]]\n%s\n' "$machine_name"
}

prompt_test::case_select_basic() {
  local result=""
  local records=()

  records[0]="$(prompt_test::record "starship" "starship" "Cross-platform prompt using the Starship binary." "1" "0")"
  records[1]="$(prompt_test::record "powerlevel10k" "powerlevel10k" "Feature-rich prompt for zsh with instant prompt support." "0" "0")"
  records[2]="$(prompt_test::record "default" "default" "Keep the default shell prompt styling." "0" "0")"

  prompt_test::set_keys "enter"
  prompt::select result "Select a shell theme." "Use ↑/↓ to choose, Enter to confirm." "${records[@]}"

  printf '[[ value ]]\n%s\n' "$result"
}

prompt_test::case_select_with_disabled_and_status() {
  local result=""
  local records=()

  PROMPT_TEST_COLUMNS=36
  records[0]="$(prompt_test::record "starship" "starship" "Currently active shell theme." "1" "0" "current")"
  records[1]="$(prompt_test::record "powerlevel10k" "powerlevel10k" "Installed already, but unavailable until oh-my-zsh is enabled." "0" "1" "installed")"
  records[2]="$(prompt_test::record "default" "default" "Use the default shell prompt styling." "0" "0")"

  prompt_test::set_keys "down" "enter"
  prompt::select result "Select a shell theme." "Use ↑/↓ to choose, Enter to confirm." "${records[@]}"

  printf '[[ value ]]\n%s\n' "$result"
}

prompt_test::case_multiselect_basic() {
  local result=""
  local records=()

  records[0]="$(prompt_test::record "git" "git" "Required for cloning and repo workflows." "0" "0")"
  records[1]="$(prompt_test::record "fnm" "fnm" "Fast Node.js version manager." "0" "0")"
  records[2]="$(prompt_test::record "eza" "eza" "Modern replacement for ls." "0" "0")"

  prompt_test::set_keys "space" "down" "down" "space" "enter"
  prompt::multiselect result "Select base CLI packages." "Use ↑/↓ to move, Space to toggle, Enter to confirm." "${records[@]}"

  printf '[[ value ]]\n%s\n' "$result"
}

prompt_test::case_multiselect_with_scroll_indicators() {
  local result=""
  local records=()

  PROMPT_TEST_LINES=12
  records[0]="$(prompt_test::record "git" "git" "Required for cloning and repo workflows." "0" "0")"
  records[1]="$(prompt_test::record "fnm" "fnm" "Fast Node.js version manager." "0" "0")"
  records[2]="$(prompt_test::record "eza" "eza" "Modern replacement for ls." "0" "0")"
  records[3]="$(prompt_test::record "fd" "fd" "Simple and fast alternative to find." "0" "0")"
  records[4]="$(prompt_test::record "ripgrep" "ripgrep" "Fast recursive search tool." "0" "0")"
  records[5]="$(prompt_test::record "bat" "bat" "Cat clone with syntax highlighting." "0" "0")"
  records[6]="$(prompt_test::record "zoxide" "zoxide" "Smarter cd with frecency." "0" "0")"
  records[7]="$(prompt_test::record "starship" "starship" "Cross-platform prompt binary." "0" "0")"

  prompt_test::set_keys "down" "down" "down" "enter"
  prompt::multiselect result "Select base CLI packages." "Use ↑/↓ to move, Space to toggle, Enter to confirm." "${records[@]}"

  printf '[[ value ]]\n%s\n' "${result:-}"
}

prompt_test::case_multiselect_with_disabled_rows() {
  local result=""
  local records=()

  PROMPT_TEST_COLUMNS=20
  records[0]="$(prompt_test::record "git" "git" "Required for cloning and repo workflows." "0" "0")"
  records[1]="$(prompt_test::record "corepack" "corepack" "Managed by the current Node.js runtime." "0" "1" "installed")"
  records[2]="$(prompt_test::record "zoxide" "zoxide" "Smarter cd with frecency." "1" "0")"
  records[3]="$(prompt_test::record "starship" "starship" "Already active in the current shell." "0" "1" "current")"
  records[4]="$(prompt_test::record "eza" "eza" "Modern replacement for ls." "0" "0")"

  prompt_test::set_keys "down" "space" "enter"
  prompt::multiselect result "Select base CLI packages." "Use ↑/↓ to move, Space to toggle, Enter to confirm." "${records[@]}"

  printf '[[ value ]]\n%s\n' "$result"
}

prompt_test::run_case() {
  local case_name="$1"
  local mode="$2"

  export DOTFILES_ROOT
  export DOTFILES_FORCE_COLOR=1
  export DOTFILES_COLOR_SCHEME=light
  export DOTFILES_INSTALL_UI_MODE="$mode"
  PROMPT_TEST__KEY_FILE="$(mktemp "${TMPDIR:-/tmp}/prompt-rendering-keys.XXXXXX")"
  trap 'rm -f "$PROMPT_TEST__KEY_FILE"' EXIT

  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/prompt.bash"
  prompt_test::install_overrides

  case "$case_name" in
    intro_with_meta)
      prompt_test::case_intro_with_meta
      ;;
    summary_basic)
      prompt_test::case_summary_basic
      ;;
    text_basic)
      prompt_test::case_text_basic
      ;;
    text_validation_retry)
      prompt_test::case_text_validation_retry
      ;;
    select_basic)
      prompt_test::case_select_basic
      ;;
    select_with_disabled_and_status)
      prompt_test::case_select_with_disabled_and_status
      ;;
    multiselect_basic)
      prompt_test::case_multiselect_basic
      ;;
    multiselect_with_scroll_indicators)
      prompt_test::case_multiselect_with_scroll_indicators
      ;;
    multiselect_with_disabled_rows)
      prompt_test::case_multiselect_with_disabled_rows
      ;;
    *)
      prompt_test::fail "unknown case: $case_name"
      ;;
  esac
}

prompt_test::main() {
  local work_dir=""
  local mode=""
  local case_name=""
  local failures=0

  if [[ "${1:-}" == "--case" ]]; then
    [[ $# -eq 4 && "${3:-}" == "--mode" ]] || prompt_test::fail "usage: $0 --case <name> --mode <mode>"
    prompt_test::run_case "$2" "$4"
    return 0
  fi

  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/prompt-rendering.XXXXXX")"
  trap '[[ -n "${work_dir:-}" ]] && rm -rf "$work_dir"' EXIT

  while IFS= read -r mode; do
    while IFS= read -r case_name; do
      if ! prompt_test::compare_case "$mode" "$case_name" "$work_dir"; then
        failures=$((failures + 1))
      fi
    done < <(prompt_test::case_names)
  done < <(prompt_test::mode_names)

  if [[ "$failures" -gt 0 ]]; then
    prompt_test::fail "$failures case(s) failed"
  fi

  if [[ "${UPDATE:-0}" == "1" ]]; then
    printf 'updated %s snapshot(s)\n' "$(( $(prompt_test::case_names | wc -l | tr -d ' ') * $(prompt_test::mode_names | wc -l | tr -d ' ') ))"
  else
    printf 'all prompt rendering snapshots passed\n'
  fi
}

prompt_test::main "$@"
