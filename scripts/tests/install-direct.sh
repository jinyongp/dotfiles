#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RUNNER="$DOTFILES_ROOT/scripts/run-install-plan.zsh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-direct.XXXXXX")"
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

install_direct_test::fail() {
  printf 'install-direct: %s\n' "$1" >&2
  exit 1
}

install_direct_test::assert_equal() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    printf 'expected: %s\nactual:   %s\n' "$expected" "$actual" >&2
    install_direct_test::fail "$message"
  fi
}

install_direct_test::reset_case() {
  install::init_state
  DOTFILES_PLATFORM="macos"
  DOTFILES_PLATFORM_LABEL="macOS"
}

install_direct_test::assert_alias_normalization() {
  install_direct_test::assert_equal "$(install::normalize_direct_target vim)" "neovim" "expected vim alias"
  install_direct_test::assert_equal "$(install::normalize_direct_target nvim)" "neovim" "expected nvim alias"
  install_direct_test::assert_equal "$(install::normalize_direct_target omz)" "oh_my_zsh" "expected omz alias"
  install_direct_test::assert_equal "$(install::normalize_direct_target desktop-apps)" "desktop_apps" "expected desktop-apps alias"
  install_direct_test::assert_equal "$(install::normalize_direct_target macos-defaults)" "macos_defaults" "expected macos-defaults alias"
  printf 'ok alias_normalization\n'
}

install_direct_test::assert_invalid_target_fails() {
  install_direct_test::reset_case

  if install::configure_direct_install definitely-not-a-target >/dev/null 2>"$WORK_DIR/invalid-target.err"; then
    install_direct_test::fail "invalid direct target unexpectedly succeeded"
  fi

  if ! grep -Fq "Unknown install target: definitely-not-a-target" "$WORK_DIR/invalid-target.err"; then
    sed -n '1,120p' "$WORK_DIR/invalid-target.err" >&2
    install_direct_test::fail "expected invalid target error"
  fi

  printf 'ok invalid_target_fails\n'
}

install_direct_test::assert_item_args_rejected_for_non_leaf_module() {
  install_direct_test::reset_case

  if install::configure_direct_install neovim fnm >/dev/null 2>"$WORK_DIR/non-leaf-items.err"; then
    install_direct_test::fail "non-leaf module accepted item arguments"
  fi

  if ! grep -Fq "Module 'neovim' does not accept item arguments." "$WORK_DIR/non-leaf-items.err"; then
    sed -n '1,120p' "$WORK_DIR/non-leaf-items.err" >&2
    install_direct_test::fail "expected non-leaf item rejection"
  fi

  printf 'ok non_leaf_item_args_rejected\n'
}

install_direct_test::assert_packages_items_configured() {
  install_direct_test::reset_case

  install::configure_direct_install packages fnm eza

  install_direct_test::assert_equal "$DOTFILES_SELECTED_MODULES" "packages" "expected packages selected"
  install_direct_test::assert_equal "$DOTFILES_PACKAGE_MANAGER" "brew" "expected brew package manager on macOS"
  install_direct_test::assert_equal "$(install::get_module_items packages)" "fnm eza" "expected package item ids"
  install_direct_test::assert_equal "$(install::get_module_item_labels packages)" "eza, fnm" "expected package item labels"
  install_direct_test::assert_equal "$DOTFILES_RUN_THEME_INSTALL" "0" "did not expect theme install for packages"
  printf 'ok packages_items_configured\n'
}

install_direct_test::assert_direct_item_dependencies_configured() {
  install_direct_test::reset_case

  install::configure_direct_install packages zoxide

  install_direct_test::assert_equal "$(install::get_module_items packages)" "zoxide fzf" "expected fzf added for direct zoxide install"
  install_direct_test::assert_equal "$(install::get_module_item_labels packages)" "zoxide, fzf" "expected direct package dependency labels"

  install::configure_direct_install desktop_apps keka

  install_direct_test::assert_equal "$(install::get_module_items desktop_apps)" "keka kekaexternalhelper" "expected helper added for direct Keka install"
  install_direct_test::assert_equal "$(install::get_module_item_labels desktop_apps)" "Keka, KekaExternalHelper" "expected direct desktop app dependency labels"

  printf 'ok direct_item_dependencies_configured\n'
}

install_direct_test::assert_theme_target_configured() {
  install_direct_test::reset_case

  install::configure_direct_install theme

  install_direct_test::assert_equal "$DOTFILES_SELECTED_MODULES" "" "did not expect module selection for theme target"
  install_direct_test::assert_equal "$DOTFILES_RUN_THEME_INSTALL" "1" "expected theme install enabled"
  install_direct_test::assert_equal "$DOTFILES_ALLOW_AUTO_LAUNCH_ZSH" "1" "expected zsh launch allowed for theme target"

  if install::configure_direct_install theme extra >/dev/null 2>"$WORK_DIR/theme-extra.err"; then
    install_direct_test::fail "theme target accepted extra item arguments"
  fi

  if ! grep -Fq "The theme target does not accept extra item arguments." "$WORK_DIR/theme-extra.err"; then
    sed -n '1,120p' "$WORK_DIR/theme-extra.err" >&2
    install_direct_test::fail "expected theme extra args rejection"
  fi

  printf 'ok theme_target_configured\n'
}

install_direct_test::main() {
  install_direct_test::assert_alias_normalization
  install_direct_test::assert_invalid_target_fails
  install_direct_test::assert_item_args_rejected_for_non_leaf_module
  install_direct_test::assert_packages_items_configured
  install_direct_test::assert_direct_item_dependencies_configured
  install_direct_test::assert_theme_target_configured
  printf 'all install direct tests passed\n'
}

install_direct_test::main "$@"
