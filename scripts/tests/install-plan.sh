#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RUNNER="$DOTFILES_ROOT/scripts/run-install-plan.zsh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-plan.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$WORK_DIR/config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"

export HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR"

source "$DOTFILES_ROOT/scripts/lib/install/bootstrap.bash"

install::package_is_installed() {
  return 1
}

install::desktop_app_is_installed() {
  return 1
}

install_plan_test::fail() {
  printf 'install-plan: %s\n' "$1" >&2
  exit 1
}

install_plan_test::assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    install_plan_test::fail "$message"
  fi
}

install_plan_test::assert_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if ! install::contains_word "$list" "$word"; then
    install_plan_test::fail "$message"
  fi
}

install_plan_test::assert_not_contains_word() {
  local list="$1"
  local word="$2"
  local message="$3"

  if install::contains_word "$list" "$word"; then
    install_plan_test::fail "$message"
  fi
}

install_plan_test::reset_case() {
  rm -rf "$HOME/.oh-my-zsh"
  install::init_state
  DOTFILES_PLATFORM="macos"
  DOTFILES_PLATFORM_LABEL="macOS"
  DOTFILES_PACKAGE_MANAGER="brew"
  DOTFILES_THEME="starship"
  install::remember_saved_runtime_defaults
}

install_plan_test::assert_powerlevel10k_adds_oh_my_zsh() {
  install_plan_test::reset_case
  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  DOTFILES_THEME="powerlevel10k"

  install::resolve_install_plan

  install_plan_test::assert_contains_word "$DOTFILES_SELECTED_MODULES" "oh_my_zsh" "expected oh_my_zsh auto-added"
  install_plan_test::assert_contains_word "$DOTFILES_AUTO_SELECTED_MODULES" "oh_my_zsh" "expected oh_my_zsh in auto-selected modules"
  install_plan_test::assert_equal "${#AUTO_NOTES[@]}" "1" "expected one auto note"
  install_plan_test::assert_equal "$DOTFILES_ENABLE_OH_MY_ZSH" "1" "expected oh-my-zsh runtime enabled"
  printf 'ok powerlevel10k_auto_adds_oh_my_zsh\n'
}

install_plan_test::assert_powerlevel10k_reuses_existing_oh_my_zsh() {
  install_plan_test::reset_case
  mkdir -p "$HOME/.oh-my-zsh"
  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  DOTFILES_THEME="powerlevel10k"

  install::resolve_install_plan

  install_plan_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "oh_my_zsh" "did not expect oh_my_zsh auto-added"
  install_plan_test::assert_equal "$DOTFILES_AUTO_SELECTED_MODULES" "" "expected no auto-selected modules"
  install_plan_test::assert_equal "${#REUSE_NOTES[@]}" "1" "expected one reuse note"
  install_plan_test::assert_equal "$DOTFILES_ENABLE_OH_MY_ZSH" "1" "expected oh-my-zsh runtime enabled"
  printf 'ok powerlevel10k_reuses_existing_oh_my_zsh\n'
}

install_plan_test::assert_neovim_does_not_add_dotfiles() {
  install_plan_test::reset_case
  DOTFILES_SELECTED_MODULES="neovim"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  DOTFILES_RUN_THEME_INSTALL="0"

  install::resolve_install_plan

  install_plan_test::assert_equal "$DOTFILES_SELECTED_MODULES" "neovim" "expected neovim selection unchanged"
  install_plan_test::assert_not_contains_word "$DOTFILES_SELECTED_MODULES" "dotfiles" "did not expect dotfiles auto-added"
  install_plan_test::assert_equal "$DOTFILES_AUTO_SELECTED_MODULES" "" "expected no auto-selected modules"
  printf 'ok neovim_does_not_add_dotfiles\n'
}

install_plan_test::assert_macos_defaults_needs_no_theme_or_package_manager() {
  install_plan_test::reset_case
  DOTFILES_SELECTED_MODULES="macos_defaults"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"

  install::resolve_install_plan

  install_plan_test::assert_equal "$DOTFILES_THEME_NEEDED" "0" "expected no theme prompt"
  install_plan_test::assert_equal "$DOTFILES_PACKAGE_MANAGER_NEEDED" "0" "expected no package manager prompt"
  install_plan_test::assert_equal "$DOTFILES_SELECTED_MODULES" "macos_defaults" "expected macos_defaults selection unchanged"
  printf 'ok macos_defaults_no_theme_or_package_manager\n'
}

install_plan_test::assert_required_leaf_item_dependencies_are_added() {
  install_plan_test::reset_case
  DOTFILES_SELECTED_MODULES="packages desktop_apps"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
  install::set_module_items packages "zoxide" "zoxide"
  install::set_module_items desktop_apps "keka" "Keka"

  install::resolve_install_plan

  install_plan_test::assert_equal "$(install::get_module_items packages)" "zoxide fzf" "expected fzf added for zoxide"
  install_plan_test::assert_equal "$(install::get_module_item_labels packages)" "zoxide, fzf" "expected package dependency labels"
  install_plan_test::assert_equal "$(install::get_module_items desktop_apps)" "keka kekaexternalhelper" "expected helper added for Keka"
  install_plan_test::assert_equal "$(install::get_module_item_labels desktop_apps)" "Keka, KekaExternalHelper" "expected desktop app dependency labels"
  install_plan_test::assert_equal "${#AUTO_NOTES[@]}" "2" "expected two auto dependency notes"
  printf 'ok required_leaf_item_dependencies\n'
}

install_plan_test::main() {
  install_plan_test::assert_powerlevel10k_adds_oh_my_zsh
  install_plan_test::assert_powerlevel10k_reuses_existing_oh_my_zsh
  install_plan_test::assert_neovim_does_not_add_dotfiles
  install_plan_test::assert_macos_defaults_needs_no_theme_or_package_manager
  install_plan_test::assert_required_leaf_item_dependencies_are_added
  printf 'all install plan tests passed\n'
}

install_plan_test::main "$@"
