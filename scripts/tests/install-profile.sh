#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RUNNER="$DOTFILES_ROOT/scripts/run-install-plan.zsh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-profile.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$WORK_DIR/config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"

export HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR"

# shellcheck disable=SC1090
source "$DOTFILES_ROOT/scripts/lib/install/bootstrap.bash"

install_profile_test::fail() {
  printf 'install-profile: %s\n' "$1" >&2
  exit 1
}

install_profile_test::assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    install_profile_test::fail "$message"
  fi
}

install_profile_test::assert_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if ! install::contains_word "$list" "$word"; then
    install_profile_test::fail "$message"
  fi
}

install_profile_test::assert_not_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if install::contains_word "$list" "$word"; then
    install_profile_test::fail "$message"
  fi
}

install_profile_test::reset_case() {
  local platform="${1:-macos}"

  install::init_state
  DOTFILES_PLATFORM="$platform"
  case "$platform" in
    macos) DOTFILES_PLATFORM_LABEL="macOS" ;;
    wsl) DOTFILES_PLATFORM_LABEL="WSL" ;;
    linux) DOTFILES_PLATFORM_LABEL="Linux" ;;
  esac
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

install_profile_test::apply_profile() {
  DOTFILES_INSTALL_PROFILE="$1"
  DOTFILES_INSTALL_PROFILE_LABEL="$(catalog::profile_label "$DOTFILES_INSTALL_PROFILE")"
  install::apply_profile_defaults
}

install_profile_test::selected_record_ids() {
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

install_profile_test::record_field_for_id() {
  local wanted_id="$1"
  local field_index="$2"
  shift 2 || true

  local record id

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    if [[ "$id" == "$wanted_id" ]]; then
      prompt::record_field "$record" "$field_index"
      return 0
    fi
  done

  return 1
}

install_profile_test::assert_minimal_profile() {
  install_profile_test::reset_case macos
  install_profile_test::apply_profile minimal

  install_profile_test::assert_equal "$DOTFILES_SELECTED_MODULES" "dotfiles" "expected minimal modules"
  install_profile_test::assert_equal "$DOTFILES_REQUESTED_MODULES" "dotfiles" "expected minimal requested modules"
  install_profile_test::assert_equal "$DOTFILES_INSTALL_PROFILE_LABEL" "Minimal" "expected minimal label"

  install_profile_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "packages" "minimal should not select packages"
  install_profile_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "fonts" "minimal should not select fonts"

  printf 'ok minimal_profile\n'
}

install_profile_test::assert_recommended_profile() {
  local package_options=()
  local selected_ids=""

  install_profile_test::reset_case macos
  install_profile_test::apply_profile recommended

  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "dotfiles" "recommended should select dotfiles"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "packages" "recommended should select packages"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "neovim" "recommended should select neovim"
  install_profile_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "fonts" "recommended should not select fonts"

  install::load_leaf_records packages package_options
  install::apply_profile_leaf_defaults packages package_options
  selected_ids="$(install_profile_test::selected_record_ids "${package_options[@]}")"

  install_profile_test::assert_equal "$selected_ids" "jq gh fd eza fnm" "recommended should preselect the lean package set"
  install_profile_test::assert_not_contains_word "$selected_ids" "tldr" "recommended should not preselect tldr"
  install_profile_test::assert_not_contains_word "$selected_ids" "gnupg" "recommended should not preselect gnupg"
  install_profile_test::assert_not_contains_word "$selected_ids" "diff-so-fancy" "recommended should not preselect diff-so-fancy"

  printf 'ok recommended_profile\n'
}

install_profile_test::assert_profile_record_cues() {
  local macos_records=()
  local linux_records=()
  local recommended_status=""
  local full_status=""
  local custom_status=""
  local minimal_description=""
  local recommended_description=""

  install::read_records_into_array macos_records catalog::profile_records macos
  install::read_records_into_array linux_records catalog::profile_records linux

  recommended_status="$(install_profile_test::record_field_for_id recommended 6 "${macos_records[@]}")"
  full_status="$(install_profile_test::record_field_for_id full 6 "${macos_records[@]}")"
  custom_status="$(install_profile_test::record_field_for_id custom 6 "${macos_records[@]}")"
  minimal_description="$(install_profile_test::record_field_for_id minimal 3 "${macos_records[@]}")"
  recommended_description="$(install_profile_test::record_field_for_id recommended 3 "${macos_records[@]}")"

  install_profile_test::assert_equal "$recommended_status" "3 modules · 5 packages" "expected recommended cue"
  install_profile_test::assert_equal "$full_status" "7 modules · 10 packages · 6 plugins · 4 fonts · 6 apps" "expected macOS full cue"
  install_profile_test::assert_equal "$custom_status" "manual" "expected custom cue"
  install_profile_test::assert_equal "$minimal_description" "Dotfiles only." "expected minimal description"
  install_profile_test::assert_equal "$recommended_description" "Dotfiles + base CLI + Neovim baseline." "expected recommended description"

  full_status="$(install_profile_test::record_field_for_id full 6 "${linux_records[@]}")"
  install_profile_test::assert_equal "$full_status" "4 modules · 10 packages · 6 plugins" "expected linux full cue"

  printf 'ok profile_record_cues\n'
}

install_profile_test::assert_full_profile_by_platform() {
  install_profile_test::reset_case macos
  install_profile_test::apply_profile full

  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "dotfiles" "full macOS should select dotfiles"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "packages" "full macOS should select packages"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "oh_my_zsh" "full macOS should select oh_my_zsh"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "neovim" "full macOS should select neovim"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "fonts" "full macOS should select fonts"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "desktop_apps" "full macOS should select desktop_apps"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "macos_defaults" "full macOS should select macos_defaults"

  install_profile_test::reset_case linux
  install_profile_test::apply_profile full

  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "dotfiles" "full Linux should select dotfiles"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "packages" "full Linux should select packages"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "oh_my_zsh" "full Linux should select oh_my_zsh"
  install_profile_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "neovim" "full Linux should select neovim"
  install_profile_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "fonts" "full Linux should not select fonts"
  install_profile_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "desktop_apps" "full Linux should not select desktop_apps"
  install_profile_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "macos_defaults" "full Linux should not select macos_defaults"

  printf 'ok full_profile_by_platform\n'
}

install_profile_test::assert_full_leaf_defaults() {
  local font_options=()
  local app_options=()
  local plugin_options=()
  local selected_ids=""

  install_profile_test::reset_case macos
  install_profile_test::apply_profile full

  install::load_leaf_records fonts font_options
  install::apply_profile_leaf_defaults fonts font_options
  selected_ids="$(install_profile_test::selected_record_ids "${font_options[@]}")"
  install_profile_test::assert_contains_word "$selected_ids" "font-fira-code-nerd-font" "full should preselect cask fonts"
  install_profile_test::assert_contains_word "$selected_ids" "bundled-monocraft" "full should preselect bundled fonts"

  install::load_leaf_records desktop_apps app_options
  install::apply_profile_leaf_defaults desktop_apps app_options
  selected_ids="$(install_profile_test::selected_record_ids "${app_options[@]}")"
  install_profile_test::assert_contains_word "$selected_ids" "iterm2" "full should preselect desktop apps"
  install_profile_test::assert_contains_word "$selected_ids" "visual-studio-code" "full should preselect VS Code"

  install::load_leaf_records oh_my_zsh plugin_options
  install::apply_profile_leaf_defaults oh_my_zsh plugin_options
  selected_ids="$(install_profile_test::selected_record_ids "${plugin_options[@]}")"
  install_profile_test::assert_contains_word "$selected_ids" "alias-tips" "full should preselect optional plugins"
  install_profile_test::assert_contains_word "$selected_ids" "fast-syntax-highlighting" "full should preselect default plugins"

  printf 'ok full_leaf_defaults\n'
}

install_profile_test::assert_custom_profile() {
  install_profile_test::reset_case macos
  install_profile_test::apply_profile custom

  install_profile_test::assert_equal "$DOTFILES_SELECTED_MODULES" "" "custom should not preset modules"
  install_profile_test::assert_equal "$DOTFILES_REQUESTED_MODULES" "" "custom should not preset requested modules"
  install_profile_test::assert_equal "$DOTFILES_INSTALL_PROFILE_LABEL" "Custom" "expected custom label"

  printf 'ok custom_profile\n'
}

install_profile_test::assert_select_profile_prompt() (
  prompt::select() {
    local result_var="$1"
    local question="$2"
    shift 3 || true
    local records=("$@")
    local recommended_status=""

    install_profile_test::assert_equal "$question" "Select installation profile." "expected profile prompt title"
    recommended_status="$(install_profile_test::record_field_for_id recommended 6 "${records[@]}")"
    install_profile_test::assert_equal "$recommended_status" "3 modules · 5 packages" "expected recommended status cue in prompt"
    printf -v "$result_var" '%s' "minimal"
  }

  install_profile_test::reset_case macos
  install::select_profile

  install_profile_test::assert_equal "$DOTFILES_INSTALL_PROFILE" "minimal" "expected selected profile"
  install_profile_test::assert_equal "$DOTFILES_INSTALL_PROFILE_LABEL" "Minimal" "expected selected profile label"
  install_profile_test::assert_equal "$DOTFILES_SELECTED_MODULES" "dotfiles" "expected selected profile defaults"

  printf 'ok select_profile_prompt\n'
)

install_profile_test::assert_disabled_items_stay_unselected() (
  install::package_is_installed() {
    [[ "$1" == "jq" ]]
  }

  local package_options=()
  local jq_selected jq_disabled fnm_selected

  install_profile_test::reset_case macos
  install_profile_test::apply_profile recommended
  install::load_leaf_records packages package_options
  install::apply_profile_leaf_defaults packages package_options

  jq_selected="$(install_profile_test::record_field_for_id jq 4 "${package_options[@]}")"
  jq_disabled="$(install_profile_test::record_field_for_id jq 5 "${package_options[@]}")"
  fnm_selected="$(install_profile_test::record_field_for_id fnm 4 "${package_options[@]}")"

  install_profile_test::assert_equal "$jq_disabled" "1" "expected installed jq disabled"
  install_profile_test::assert_equal "$jq_selected" "0" "installed jq should stay unselected"
  install_profile_test::assert_equal "$fnm_selected" "1" "non-installed fnm should be selected"

  printf 'ok disabled_items_stay_unselected\n'
)

install_profile_test::main() {
  install_profile_test::assert_minimal_profile
  install_profile_test::assert_recommended_profile
  install_profile_test::assert_profile_record_cues
  install_profile_test::assert_full_profile_by_platform
  install_profile_test::assert_full_leaf_defaults
  install_profile_test::assert_custom_profile
  install_profile_test::assert_select_profile_prompt
  install_profile_test::assert_disabled_items_stay_unselected
  printf 'all install profile tests passed\n'
}

install_profile_test::main "$@"
