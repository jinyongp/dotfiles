#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-summary-actions.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$WORK_DIR/config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"

export HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR/git"

# shellcheck disable=SC1090
source "$DOTFILES_ROOT/scripts/lib/install/bootstrap.bash"

install_summary_test::fail() {
  printf 'install-summary-actions: %s\n' "$1" >&2
  exit 1
}

install_summary_test::assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    install_summary_test::fail "$message"
  fi
}

install_summary_test::assert_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if ! install::contains_word "$list" "$word"; then
    install_summary_test::fail "$message"
  fi
}

install_summary_test::assert_not_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if install::contains_word "$list" "$word"; then
    install_summary_test::fail "$message"
  fi
}

install_summary_test::assert_contains_text() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'missing text: %s\n' "$needle" >&2
    printf 'haystack:\n%s\n' "$haystack" >&2
    install_summary_test::fail "$message"
  fi
}

install_summary_test::assert_record_selected() {
  local wanted_id="$1"
  local expected="$2"
  shift 2 || true

  local record id selected

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    if [[ "$id" == "$wanted_id" ]]; then
      selected="$(prompt::record_field "$record" 4)"
      install_summary_test::assert_equal "$selected" "$expected" "unexpected selected state for $wanted_id"
      return 0
    fi
  done

  install_summary_test::fail "record not found for $wanted_id"
}

install_summary_test::record_ids() {
  local record id
  local record_ids=""

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    record_ids="$(install::add_word "$record_ids" "$id")"
  done

  printf '%s' "$record_ids"
}

install_summary_test::selected_record_ids() {
  local record id selected
  local selected_ids=""

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    selected="$(prompt::record_field "$record" 4)"
    if [[ "$selected" == "1" ]]; then
      selected_ids="$(install::add_word "$selected_ids" "$id")"
    fi
  done

  printf '%s' "$selected_ids"
}

install_summary_test::reset_case() {
  rm -f "$DOTFILES_CONFIG_DIR/git/personal.local.ini"
  rm -rf "$HOME/.oh-my-zsh"
  mkdir -p "$DOTFILES_CONFIG_DIR/git"

  install::init_state
  DOTFILES_PLATFORM="macos"
  DOTFILES_PLATFORM_LABEL="macOS"
  DOTFILES_PACKAGE_MANAGER="brew"
  DOTFILES_THEME="starship"
  DOTFILES_INSTALL_PROFILE="recommended"
  DOTFILES_INSTALL_PROFILE_LABEL="Recommended"
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

install_summary_test::assert_valid_plan_actions_default_to_proceed() {
  local action_records=()
  local record_ids=""

  install_summary_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles packages neovim"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"

  install::read_records_into_array action_records install::summary_action_records
  record_ids="$(install_summary_test::record_ids "${action_records[@]}")"

  install_summary_test::assert_contains_word "$record_ids" "proceed" "expected proceed action"
  install_summary_test::assert_contains_word "$record_ids" "edit_profile" "expected edit_profile action"
  install_summary_test::assert_contains_word "$record_ids" "edit_items" "expected edit_items action"
  install_summary_test::assert_contains_word "$record_ids" "edit_git" "expected edit_git action"
  install_summary_test::assert_contains_word "$record_ids" "cancel" "expected cancel action"
  install_summary_test::assert_record_selected "proceed" "1" "${action_records[@]}"

  printf 'ok valid_plan_actions_default_to_proceed\n'
}

install_summary_test::assert_empty_plan_still_enters_summary_actions() (
  local action_records=()
  local record_ids=""
  local summary_count=0
  local select_count=0

  install_summary_test::reset_case
  DOTFILES_INSTALL_PROFILE="custom"
  DOTFILES_INSTALL_PROFILE_LABEL="Custom"
  DOTFILES_SELECTED_MODULES=""
  DOTFILES_REQUESTED_MODULES=""
  DOTFILES_RUN_THEME_INSTALL="0"

  install::read_records_into_array action_records install::summary_action_records
  record_ids="$(install_summary_test::record_ids "${action_records[@]}")"
  install_summary_test::assert_not_contains_word "$record_ids" "proceed" "empty plan should not offer proceed"
  install_summary_test::assert_contains_word "$record_ids" "edit_modules" "custom empty plan should offer edit_modules"
  install_summary_test::assert_contains_word "$record_ids" "cancel" "empty plan should offer cancel"
  install_summary_test::assert_record_selected "edit_modules" "1" "${action_records[@]}"

  install::ensure_git_identity_for_plan() { return 0; }
  install::finalize_runtime_state() { return 0; }
  install::print_plan_summary() { summary_count=$((summary_count + 1)); }
  install::select_summary_action() {
    select_count=$((select_count + 1))
    DOTFILES_SUMMARY_ACTION="cancel"
  }

  if install::run_summary_action_loop; then
    install_summary_test::fail "summary loop should stop on cancel"
  fi

  install_summary_test::assert_equal "$summary_count" "1" "expected summary loop to render once"
  install_summary_test::assert_equal "$select_count" "1" "expected summary action prompt to run once"

  printf 'ok empty_plan_still_enters_summary_actions\n'
)

install_summary_test::assert_edit_profile_reopens_profile_and_custom_modules() (
  local profile_prompt_count=0
  local module_prompt_count=0
  local refresh_count=0

  prompt::select() {
    local result_var="$1"
    local question="$2"
    shift 3 || true

    case "$question" in
      "Select installation profile.")
        profile_prompt_count=$((profile_prompt_count + 1))
        install_summary_test::assert_record_selected "recommended" "1" "$@"
        printf -v "$result_var" '%s' "custom"
        ;;
      *)
        install_summary_test::fail "unexpected select prompt: $question"
        ;;
    esac
  }

  prompt::multiselect() {
    local result_var="$1"
    local question="$2"

    module_prompt_count=$((module_prompt_count + 1))
    install_summary_test::assert_equal "$question" "Select installation modules." "expected module picker after switching to custom"
    printf -v "$result_var" '%s' "dotfiles packages"
  }

  install::refresh_plan_after_structure_edit() {
    refresh_count=$((refresh_count + 1))
  }

  install_summary_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles packages neovim"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"

  install::edit_summary_profile

  install_summary_test::assert_equal "$profile_prompt_count" "1" "expected profile prompt"
  install_summary_test::assert_equal "$module_prompt_count" "1" "expected custom module prompt"
  install_summary_test::assert_equal "$refresh_count" "1" "expected structure refresh"
  install_summary_test::assert_equal "$DOTFILES_INSTALL_PROFILE" "custom" "expected switched custom profile"
  install_summary_test::assert_equal "$DOTFILES_SELECTED_MODULES" "dotfiles packages" "expected module picker result"

  printf 'ok edit_profile_reopens_profile_and_custom_modules\n'
)

install_summary_test::assert_edit_modules_reopens_current_custom_selection() (
  local module_prompt_count=0
  local refresh_count=0

  prompt::multiselect() {
    local result_var="$1"
    local question="$2"
    shift 3 || true

    module_prompt_count=$((module_prompt_count + 1))
    install_summary_test::assert_equal "$question" "Select installation modules." "expected module picker"
    install_summary_test::assert_record_selected "dotfiles" "1" "$@"
    install_summary_test::assert_record_selected "packages" "1" "$@"
    printf -v "$result_var" '%s' "dotfiles"
  }

  install::refresh_plan_after_structure_edit() {
    refresh_count=$((refresh_count + 1))
  }

  install_summary_test::reset_case
  DOTFILES_INSTALL_PROFILE="custom"
  DOTFILES_INSTALL_PROFILE_LABEL="Custom"
  DOTFILES_SELECTED_MODULES="dotfiles packages"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"

  install::edit_summary_modules

  install_summary_test::assert_equal "$module_prompt_count" "1" "expected module edit prompt"
  install_summary_test::assert_equal "$refresh_count" "1" "expected structure refresh"
  install_summary_test::assert_equal "$DOTFILES_SELECTED_MODULES" "dotfiles" "expected updated module selection"

  printf 'ok edit_modules_reopens_current_custom_selection\n'
)

install_summary_test::assert_edit_items_bypasses_review_gate_and_keeps_state() (
  local prompt_count=0
  local refresh_count=0

  prompt::confirm() {
    install_summary_test::fail "edit items should bypass the review gate"
  }

  prompt::multiselect() {
    local result_var="$1"
    local question="$2"
    shift 3 || true
    local selected_ids=""

    prompt_count=$((prompt_count + 1))
    install_summary_test::assert_equal "$question" "Select base CLI packages." "expected package prompt"
    selected_ids="$(install_summary_test::selected_record_ids "$@")"
    install_summary_test::assert_contains_word "$selected_ids" "jq" "expected saved jq selection"
    install_summary_test::assert_contains_word "$selected_ids" "fnm" "expected saved fnm selection"
    printf -v "$result_var" '%s' "jq"
  }

  install::refresh_plan_after_item_edit() {
    refresh_count=$((refresh_count + 1))
  }

  install_summary_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles packages"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  install::set_module_items packages "jq fnm" "jq, fnm"

  install::edit_summary_items

  install_summary_test::assert_equal "$prompt_count" "1" "expected one leaf prompt"
  install_summary_test::assert_equal "$refresh_count" "1" "expected item refresh"
  install_summary_test::assert_equal "$(install::get_module_items packages)" "jq" "expected updated saved item selection"

  printf 'ok edit_items_bypasses_review_gate_and_keeps_state\n'
)

install_summary_test::assert_edit_git_forces_prompt_and_preserves_existing_choice() (
  local select_count=0
  local prompt_seen=0

  prompt::summary() {
    return 0
  }

  prompt::select() {
    local result_var="$1"
    local question="$2"
    shift 3 || true

    case "$question" in
      "Machine-local Git identity.")
        select_count=$((select_count + 1))
        prompt_seen=1
        install_summary_test::assert_record_selected "reuse_existing" "1" "$@"
        printf -v "$result_var" '%s' "reuse_existing"
        ;;
      *)
        install_summary_test::fail "unexpected git select prompt: $question"
        ;;
    esac
  }

  prompt::text() {
    install_summary_test::fail "reuse_existing should not open text prompts"
  }

  install_summary_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  git config --file "$DOTFILES_CONFIG_DIR/git/personal.local.ini" user.name "Dotfiles User"
  git config --file "$DOTFILES_CONFIG_DIR/git/personal.local.ini" user.email "dotfiles@example.com"

  install::prompt_for_git_identity yes

  install_summary_test::assert_equal "$prompt_seen" "1" "expected forced git prompt"
  install_summary_test::assert_equal "$select_count" "1" "expected one git mode select"
  install_summary_test::assert_equal "$DOTFILES_GIT_IDENTITY_MODE" "reuse_existing" "expected reuse existing mode"
  install_summary_test::assert_contains_text "$DOTFILES_GIT_SUMMARY" "kept as-is" "expected forced reuse summary"

  DOTFILES_GIT_IDENTITY_MODE="skip_for_now"
  DOTFILES_GIT_SUMMARY="Git identity setup skipped for now."
  prompt::select() {
    install_summary_test::fail "existing git choice should be preserved without reopening prompts"
  }

  install::ensure_git_identity_for_plan
  install_summary_test::assert_equal "$DOTFILES_GIT_IDENTITY_MODE" "skip_for_now" "expected preserved git mode"
  install_summary_test::assert_equal "$DOTFILES_GIT_SUMMARY" "Git identity setup skipped for now." "expected preserved git summary"

  printf 'ok edit_git_forces_prompt_and_preserves_existing_choice\n'
)

install_summary_test::assert_wsl_package_manager_reopens_current_selection() (
  prompt::select() {
    local result_var="$1"
    local question="$2"
    shift 3 || true

    install_summary_test::assert_equal "$question" "Select a package manager." "expected package manager prompt"
    install_summary_test::assert_record_selected "brew" "1" "$@"
    printf -v "$result_var" '%s' "brew"
  }

  install_summary_test::reset_case
  DOTFILES_PLATFORM="wsl"
  DOTFILES_PLATFORM_LABEL="WSL"
  DOTFILES_PACKAGE_MANAGER="brew"

  install::select_package_manager

  install_summary_test::assert_equal "$DOTFILES_PACKAGE_MANAGER" "brew" "expected brew to stay selected"

  printf 'ok wsl_package_manager_reopens_current_selection\n'
)

install_summary_test::assert_state_preservation_rules() (
  local options=()
  local selected_ids=""

  install_summary_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles packages"
  install::set_module_items packages "jq" "jq"

  install::maybe_select_theme() {
    DOTFILES_THEME="powerlevel10k"
    DOTFILES_THEME_NEEDED="1"
    DOTFILES_RUN_THEME_INSTALL="1"
  }
  install::maybe_select_package_manager() { return 0; }
  install::resolve_install_plan() { return 0; }
  install::maybe_review_leaf_items() { return 0; }

  install::refresh_plan_after_structure_edit
  install_summary_test::assert_equal "$(install::get_module_items packages)" "jq" "theme-related structure refresh should preserve package state"

  DOTFILES_SELECTED_MODULES="dotfiles"
  install::clear_unselected_leaf_item_state
  if install::module_item_state_exists packages; then
    install_summary_test::fail "removing packages should clear saved item state"
  fi

  DOTFILES_INSTALL_PROFILE="recommended"
  DOTFILES_SELECTED_MODULES="dotfiles packages"
  install::prepare_leaf_options packages options
  selected_ids="$(install_summary_test::selected_record_ids "${options[@]}")"
  install_summary_test::assert_contains_word "$selected_ids" "jq" "re-added packages should fall back to profile defaults"
  install_summary_test::assert_contains_word "$selected_ids" "fnm" "re-added packages should include fnm default"

  printf 'ok state_preservation_rules\n'
)

install_summary_test::main() {
  install_summary_test::assert_valid_plan_actions_default_to_proceed
  install_summary_test::assert_empty_plan_still_enters_summary_actions
  install_summary_test::assert_edit_profile_reopens_profile_and_custom_modules
  install_summary_test::assert_edit_modules_reopens_current_custom_selection
  install_summary_test::assert_edit_items_bypasses_review_gate_and_keeps_state
  install_summary_test::assert_edit_git_forces_prompt_and_preserves_existing_choice
  install_summary_test::assert_wsl_package_manager_reopens_current_selection
  install_summary_test::assert_state_preservation_rules
  printf 'all install summary action tests passed\n'
}

install_summary_test::main "$@"
