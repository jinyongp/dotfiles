#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RUNNER="$DOTFILES_ROOT/scripts/run-install-plan.zsh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-simplified.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$WORK_DIR/config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"

export HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR"

# shellcheck disable=SC1090
source "$DOTFILES_ROOT/scripts/lib/install/bootstrap.bash"

install_simplified_test::fail() {
  printf 'install-simplified-flow: %s\n' "$1" >&2
  exit 1
}

install_simplified_test::assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    install_simplified_test::fail "$message"
  fi
}

install_simplified_test::assert_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if ! install::contains_word "$list" "$word"; then
    install_simplified_test::fail "$message"
  fi
}

install_simplified_test::assert_contains_text() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'missing text: %s\n' "$needle" >&2
    printf 'haystack:\n%s\n' "$haystack" >&2
    install_simplified_test::fail "$message"
  fi
}

install_simplified_test::assert_not_contains_text() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'unexpected text: %s\n' "$needle" >&2
    printf 'haystack:\n%s\n' "$haystack" >&2
    install_simplified_test::fail "$message"
  fi
}

install_simplified_test::reset_case() {
  rm -f "$DOTFILES_CONFIG_DIR/git/personal.local.ini"
  rm -rf "$HOME/.oh-my-zsh"
  mkdir -p "$DOTFILES_CONFIG_DIR/git"

  install::init_state
  DOTFILES_PLATFORM="macos"
  DOTFILES_PLATFORM_LABEL="macOS"
  DOTFILES_PACKAGE_MANAGER="brew"
  DOTFILES_THEME="starship"
  install::remember_saved_runtime_defaults
}

install::package_is_installed() {
  return 1
}

install::font_is_installed() {
  return 1
}

install::desktop_app_is_installed() {
  return 1
}

install::omz_plugin_is_installed() {
  return 1
}

install_simplified_test::apply_profile() {
  DOTFILES_INSTALL_PROFILE="$1"
  DOTFILES_INSTALL_PROFILE_LABEL="$(catalog::profile_label "$DOTFILES_INSTALL_PROFILE")"
  install::apply_profile_defaults
}

install_simplified_test::assert_minimal_skips_item_review_gate() (
  prompt::confirm() {
    install_simplified_test::fail "minimal profile should not show item review gate"
  }

  prompt::multiselect() {
    install_simplified_test::fail "minimal profile should not open leaf item prompts"
  }

  install_simplified_test::reset_case
  install_simplified_test::apply_profile minimal
  install::maybe_review_leaf_items

  install_simplified_test::assert_equal "$DOTFILES_REVIEW_SELECTED_ITEMS" "no" "minimal should keep review state at no"
  install_simplified_test::assert_equal "$(install::get_module_items packages)" "" "minimal should not set package items"
  printf 'ok minimal_skips_item_review_gate\n'
)

install_simplified_test::assert_recommended_skips_leaf_prompts_by_default() (
  local confirm_count=0

  prompt::confirm() {
    local result_var="$1"
    local question="$2"

    confirm_count=$((confirm_count + 1))
    install_simplified_test::assert_equal "$question" "Review selected items?" "expected single review gate"
    printf -v "$result_var" '%s' "no"
  }

  prompt::multiselect() {
    install_simplified_test::fail "leaf item prompt should not run when review is skipped"
  }

  install_simplified_test::reset_case
  install_simplified_test::apply_profile recommended
  install::maybe_review_leaf_items

  install_simplified_test::assert_equal "$confirm_count" "1" "expected one review confirmation"
  install_simplified_test::assert_equal "$DOTFILES_REVIEW_SELECTED_ITEMS" "no" "expected review skipped"
  install_simplified_test::assert_contains_word "$(install::get_module_items packages)" "jq" "expected recommended package defaults"
  install_simplified_test::assert_contains_word "$(install::get_module_items packages)" "fnm" "expected fnm default"
  printf 'ok recommended_skips_leaf_prompts_by_default\n'
)

install_simplified_test::assert_recommended_review_yes_opens_leaf_prompts() (
  local multiselect_count=0

  prompt::confirm() {
    local result_var="$1"
    local question="$2"

    install_simplified_test::assert_equal "$question" "Review selected items?" "expected review question"
    printf -v "$result_var" '%s' "yes"
  }

  prompt::multiselect() {
    local result_var="$1"
    local question="$2"

    multiselect_count=$((multiselect_count + 1))
    install_simplified_test::assert_equal "$question" "Select base CLI packages." "expected package review prompt"
    printf -v "$result_var" '%s' "jq fnm"
  }

  install_simplified_test::reset_case
  install_simplified_test::apply_profile recommended
  install::maybe_review_leaf_items

  install_simplified_test::assert_equal "$DOTFILES_REVIEW_SELECTED_ITEMS" "yes" "expected explicit review"
  install_simplified_test::assert_equal "$multiselect_count" "1" "expected one leaf prompt for recommended"
  install_simplified_test::assert_equal "$(install::get_module_items packages)" "jq fnm" "expected reviewed package items"
  printf 'ok recommended_review_yes_opens_leaf_prompts\n'
)

install_simplified_test::assert_full_skip_uses_defaults() (
  local confirm_count=0

  prompt::confirm() {
    local result_var="$1"
    confirm_count=$((confirm_count + 1))
    printf -v "$result_var" '%s' "no"
  }

  prompt::multiselect() {
    install_simplified_test::fail "full profile should not open leaf prompts when review is skipped"
  }

  install_simplified_test::reset_case
  install_simplified_test::apply_profile full
  install::maybe_review_leaf_items

  install_simplified_test::assert_equal "$confirm_count" "1" "expected one review confirmation for full"
  install_simplified_test::assert_contains_word "$(install::get_module_items packages)" "diff-so-fancy" "expected full package defaults"
  install_simplified_test::assert_contains_word "$(install::get_module_items fonts)" "bundled-monocraft" "expected full font defaults"
  install_simplified_test::assert_contains_word "$(install::get_module_items desktop_apps)" "visual-studio-code" "expected full app defaults"
  install_simplified_test::assert_contains_word "$(install::get_module_items oh_my_zsh)" "alias-tips" "expected full plugin defaults"
  printf 'ok full_skip_uses_defaults\n'
)

install_simplified_test::assert_custom_bypasses_review_gate() (
  local multiselect_count=0

  prompt::confirm() {
    install_simplified_test::fail "custom profile should not show review gate"
  }

  prompt::multiselect() {
    local result_var="$1"

    multiselect_count=$((multiselect_count + 1))
    case "$multiselect_count" in
      1) printf -v "$result_var" '%s' "jq" ;;
      2) printf -v "$result_var" '%s' "alias-tips" ;;
      *) install_simplified_test::fail "unexpected extra multiselect call" ;;
    esac
  }

  install_simplified_test::reset_case
  install_simplified_test::apply_profile custom
  DOTFILES_SELECTED_MODULES="packages oh_my_zsh"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  install::maybe_review_leaf_items

  install_simplified_test::assert_equal "$DOTFILES_REVIEW_SELECTED_ITEMS" "yes" "custom should go straight into item review"
  install_simplified_test::assert_equal "$multiselect_count" "2" "expected one prompt per selected leaf module"
  install_simplified_test::assert_equal "$(install::get_module_items packages)" "jq" "expected custom package selection"
  install_simplified_test::assert_equal "$(install::get_module_items oh_my_zsh)" "alias-tips" "expected custom plugin selection"
  printf 'ok custom_bypasses_review_gate\n'
)

install_simplified_test::assert_existing_git_identity_reused_without_prompt() (
  prompt::select() {
    install_simplified_test::fail "existing git identity should not open a select prompt"
  }

  prompt::text() {
    install_simplified_test::fail "existing git identity should not open text prompts"
  }

  git config --file "$DOTFILES_CONFIG_DIR/git/personal.local.ini" user.name "Dotfiles User"
  git config --file "$DOTFILES_CONFIG_DIR/git/personal.local.ini" user.email "dotfiles@example.com"

  install_simplified_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  git config --file "$DOTFILES_CONFIG_DIR/git/personal.local.ini" user.name "Dotfiles User"
  git config --file "$DOTFILES_CONFIG_DIR/git/personal.local.ini" user.email "dotfiles@example.com"

  install::prompt_for_git_identity

  install_simplified_test::assert_equal "$DOTFILES_GIT_IDENTITY_MODE" "reuse_existing" "expected reuse existing mode"
  install_simplified_test::assert_contains_text "$DOTFILES_GIT_SUMMARY" "Existing machine-local Git identity" "expected reuse summary"
  printf 'ok existing_git_identity_reused_without_prompt\n'
)

install_simplified_test::assert_template_git_identity_gate_skips_by_default() (
  local summary_count=0

  prompt::summary() {
    local title="$1"
    summary_count=$((summary_count + 1))
    install_simplified_test::assert_equal "$title" "Machine-local Git config file." "expected file summary before git mode prompt"
  }

  prompt::select() {
    local result_var="$1"
    local question="$2"

    install_simplified_test::assert_equal "$question" "Machine-local Git identity." "expected git identity mode gate"
    printf -v "$result_var" '%s' "skip_for_now"
  }

  prompt::text() {
    install_simplified_test::fail "skip_for_now should not open text prompts"
  }

  install_simplified_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"

  install::prompt_for_git_identity

  install_simplified_test::assert_equal "$summary_count" "1" "expected one git file summary"
  install_simplified_test::assert_equal "$DOTFILES_GIT_IDENTITY_MODE" "skip_for_now" "expected skip mode"
  install_simplified_test::assert_contains_text "$DOTFILES_GIT_SUMMARY" "skipped for now" "expected skip summary"
  printf 'ok template_git_identity_gate_skips_by_default\n'
)

install_simplified_test::assert_configure_now_runs_value_prompts() (
  local select_count=0
  local text_count=0

  prompt::summary() {
    return 0
  }

  prompt::select() {
    local result_var="$1"
    select_count=$((select_count + 1))

    case "$select_count" in
      1) printf -v "$result_var" '%s' "configure_now" ;;
      2) printf -v "$result_var" '%s' "none" ;;
      *) install_simplified_test::fail "unexpected extra select prompt" ;;
    esac
  }

  prompt::text() {
    local result_var="$1"
    local question="$2"

    text_count=$((text_count + 1))
    case "$question" in
      "Git user.name") printf -v "$result_var" '%s' "Dotfiles User" ;;
      "Git user.email") printf -v "$result_var" '%s' "dotfiles@example.com" ;;
      *) install_simplified_test::fail "unexpected text prompt: $question" ;;
    esac
  }

  prompt::confirm() {
    local result_var="$1"
    printf -v "$result_var" '%s' "yes"
  }

  install_simplified_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"

  install::prompt_for_git_identity

  install_simplified_test::assert_equal "$DOTFILES_GIT_IDENTITY_MODE" "configure_now" "expected configure mode"
  install_simplified_test::assert_equal "$DOTFILES_GIT_CONFIGURE_PERSONAL" "yes" "expected git config enabled"
  install_simplified_test::assert_equal "$select_count" "2" "expected mode select and signing select"
  install_simplified_test::assert_equal "$text_count" "2" "expected name and email prompts only"
  install_simplified_test::assert_contains_text "$DOTFILES_GIT_SUMMARY" "without signing" "expected configure summary"
  printf 'ok configure_now_runs_value_prompts\n'
)

install_simplified_test::assert_grouped_summary_output() (
  local rendered=""

  prompt::summary() {
    local title="$1"
    shift || true
    rendered="$title"

    while [[ "$#" -gt 0 ]]; do
      rendered="${rendered}"$'\n'"$1"
      shift || true
    done
  }

  install_simplified_test::reset_case
  DOTFILES_INSTALL_PROFILE="recommended"
  DOTFILES_INSTALL_PROFILE_LABEL="Recommended"
  DOTFILES_REQUESTED_MODULES="dotfiles packages neovim"
  DOTFILES_SELECTED_MODULES="dotfiles packages neovim oh_my_zsh"
  DOTFILES_PACKAGE_MANAGER_NEEDED="1"
  DOTFILES_PACKAGE_MANAGER="brew"
  DOTFILES_THEME_NEEDED="1"
  DOTFILES_THEME="starship"
  DOTFILES_RUN_THEME_INSTALL="1"
  DOTFILES_ENABLE_OH_MY_ZSH="1"
  DOTFILES_GIT_IDENTITY_MODE="skip_for_now"
  DOTFILES_GIT_SUMMARY="Git identity setup skipped for now. Edit ~/.config/dotfiles/git/personal.local.ini directly later if needed."
  AUTO_NOTES=("oh-my-zsh was added automatically because theme 'default' requires it.")
  REUSE_NOTES=("Existing oh-my-zsh runtime will stay enabled.")
  SKIP_NOTES=("Desktop Apps was skipped because no items were selected.")
  install::set_module_items packages "jq fnm" "jq, fnm"
  install::set_module_items oh_my_zsh "alias-tips" "alias-tips"

  install::print_plan_summary

  install_simplified_test::assert_contains_text "$rendered" "Profile: Recommended" "expected grouped profile line"
  install_simplified_test::assert_contains_text "$rendered" "Will install: Modules: Dotfiles, Base CLI, Neovim, oh-my-zsh" "expected grouped install modules"
  install_simplified_test::assert_contains_text "$rendered" "Needs attention: Requested modules were adjusted" "expected adjustment note"
  install_simplified_test::assert_contains_text "$rendered" "Will reuse: Existing oh-my-zsh runtime will stay enabled." "expected reuse bucket"
  install_simplified_test::assert_contains_text "$rendered" "Skipped: Desktop Apps was skipped because no items were selected." "expected skipped bucket"
  install_simplified_test::assert_contains_text "$rendered" "Needs attention: Git: Git identity setup skipped for now." "expected git needs-attention bucket"
  install_simplified_test::assert_not_contains_text "$rendered" "Selected modules:" "old summary field should be removed"
  install_simplified_test::assert_not_contains_text "$rendered" "Final install modules:" "old summary field should be removed"
  install_simplified_test::assert_not_contains_text "$rendered" "not needed for selected plan" "old not-needed wording should be removed"
  printf 'ok grouped_summary_output\n'
)

install_simplified_test::main() {
  install_simplified_test::assert_minimal_skips_item_review_gate
  install_simplified_test::assert_recommended_skips_leaf_prompts_by_default
  install_simplified_test::assert_recommended_review_yes_opens_leaf_prompts
  install_simplified_test::assert_full_skip_uses_defaults
  install_simplified_test::assert_custom_bypasses_review_gate
  install_simplified_test::assert_existing_git_identity_reused_without_prompt
  install_simplified_test::assert_template_git_identity_gate_skips_by_default
  install_simplified_test::assert_configure_now_runs_value_prompts
  install_simplified_test::assert_grouped_summary_output
  printf 'all install simplified flow tests passed\n'
}

install_simplified_test::main "$@"
