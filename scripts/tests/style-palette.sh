#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1090
source "$DOTFILES_ROOT/scripts/lib/style.sh"

style_test::assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'not ok %s\n' "$name" >&2
    printf 'expected: %q\n' "$expected" >&2
    printf 'actual:   %q\n' "$actual" >&2
    exit 1
  fi

  printf 'ok %s\n' "$name"
}

style_test::background() (
  unset DOTFILES_COLOR_SCHEME COLORFGBG
  [[ "$1" == "-" ]] || export DOTFILES_COLOR_SCHEME="$1"
  [[ "$2" == "-" ]] || export COLORFGBG="$2"
  dotfiles_terminal_background
)

style_test::render() (
  local scheme="$1"
  local function_name="$2"

  unset DOTFILES_COLOR_SCHEME COLORFGBG NO_COLOR TERM CLICOLOR FORCE_COLOR CLICOLOR_FORCE
  export DOTFILES_FORCE_COLOR=1
  [[ "$scheme" == "-" ]] || export DOTFILES_COLOR_SCHEME="$scheme"

  "$function_name" "x"
)

style_test::render_with_env() (
  local mode="$1"

  unset DOTFILES_COLOR_SCHEME COLORFGBG NO_COLOR TERM CLICOLOR DOTFILES_FORCE_COLOR FORCE_COLOR CLICOLOR_FORCE

  case "$mode" in
    no_color) export NO_COLOR=1 ;;
    term_dumb) export TERM=dumb ;;
    clicolor_off) export CLICOLOR=0 ;;
    dotfiles_force_over_no_color)
      export NO_COLOR=1
      export DOTFILES_FORCE_COLOR=1
      ;;
    force_color_over_term_dumb)
      export TERM=dumb
      export FORCE_COLOR=1
      ;;
    clicolor_force_over_clicolor_off)
      export CLICOLOR=0
      export CLICOLOR_FORCE=1
      ;;
  esac

  dotfiles_accent "x"
)

style_test::test_background_detection() {
  style_test::assert_eq "override_light_wins" "light" "$(style_test::background light "15;0")"
  style_test::assert_eq "override_dark_wins" "dark" "$(style_test::background dark "0;15")"
  style_test::assert_eq "colorfgbg_light" "light" "$(style_test::background - "0;15")"
  style_test::assert_eq "colorfgbg_dark" "dark" "$(style_test::background - "15;0")"
  style_test::assert_eq "colorfgbg_uses_last_field" "dark" "$(style_test::background - "1;2;3")"
  style_test::assert_eq "colorfgbg_unset_unknown" "unknown" "$(style_test::background - -)"
  style_test::assert_eq "colorfgbg_malformed_unknown" "unknown" "$(style_test::background - "light")"
  style_test::assert_eq "colorfgbg_out_of_range_unknown" "unknown" "$(style_test::background - "0;16")"
  style_test::assert_eq "invalid_override_ignored" "light" "$(style_test::background auto "0;15")"
}

style_test::test_palette_tokens() {
  style_test::assert_eq "accent_dark" $'\033[1;96mx\033[0m' "$(style_test::render dark dotfiles_accent)"
  style_test::assert_eq "accent_light" $'\033[1;34mx\033[0m' "$(style_test::render light dotfiles_accent)"
  style_test::assert_eq "accent_unknown" $'\033[1;34mx\033[0m' "$(style_test::render - dotfiles_accent)"

  style_test::assert_eq "success_dark" $'\033[1;92mx\033[0m' "$(style_test::render dark dotfiles_success)"
  style_test::assert_eq "success_light" $'\033[1;32mx\033[0m' "$(style_test::render light dotfiles_success)"
  style_test::assert_eq "warning_dark" $'\033[1;93mx\033[0m' "$(style_test::render dark dotfiles_warning)"
  style_test::assert_eq "warning_light" $'\033[1;35mx\033[0m' "$(style_test::render light dotfiles_warning)"
  style_test::assert_eq "error_dark" $'\033[1;91mx\033[0m' "$(style_test::render dark dotfiles_error)"
  style_test::assert_eq "error_light" $'\033[1;31mx\033[0m' "$(style_test::render light dotfiles_error)"

  style_test::assert_eq "body_default_foreground" $'\033[39mx\033[0m' "$(style_test::render - dotfiles_body)"
  style_test::assert_eq "frame_default_foreground" $'\033[2;39mx\033[0m' "$(style_test::render - dotfiles_frame)"
  style_test::assert_eq "description_default_foreground" $'\033[2;39mx\033[0m' "$(style_test::render - dotfiles_description)"
}

style_test::test_ansi_enablement() {
  style_test::assert_eq "no_color_disables_ansi" "x" "$(style_test::render_with_env no_color)"
  style_test::assert_eq "term_dumb_disables_ansi" "x" "$(style_test::render_with_env term_dumb)"
  style_test::assert_eq "clicolor_zero_disables_ansi" "x" "$(style_test::render_with_env clicolor_off)"
  style_test::assert_eq "dotfiles_force_overrides_no_color" $'\033[1;34mx\033[0m' "$(style_test::render_with_env dotfiles_force_over_no_color)"
  style_test::assert_eq "force_color_overrides_term_dumb" $'\033[1;34mx\033[0m' "$(style_test::render_with_env force_color_over_term_dumb)"
  style_test::assert_eq "clicolor_force_overrides_clicolor_zero" $'\033[1;34mx\033[0m' "$(style_test::render_with_env clicolor_force_over_clicolor_off)"
}

style_test::test_background_detection
style_test::test_palette_tokens
style_test::test_ansi_enablement

printf 'all style palette tests passed\n'
