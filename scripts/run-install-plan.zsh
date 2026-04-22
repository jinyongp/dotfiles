#!/bin/zsh

set -euo pipefail

DOTFILES_ROOT="${0:A:h:h}"
PLAN_FILE="${1:-}"

if [[ -z "$PLAN_FILE" || ! -f "$PLAN_FILE" ]]; then
  echo "Missing install plan file." >&2
  exit 1
fi

source "$PLAN_FILE"
source "$DOTFILES_ROOT/utils/colors.zsh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/platform.zsh"
source "$DOTFILES_ROOT/scripts/lib/catalog.sh"
source "$DOTFILES_ROOT/scripts/lib/packages.zsh"
source "$DOTFILES_ROOT/scripts/modules/packages.zsh"
source "$DOTFILES_ROOT/scripts/modules/dotfiles.zsh"
source "$DOTFILES_ROOT/scripts/modules/shell.zsh"
source "$DOTFILES_ROOT/scripts/modules/vim.zsh"
source "$DOTFILES_ROOT/scripts/modules/macos.zsh"

typeset -ga DOTFILES_RUN_ORDER=(
  packages
  dotfiles
  oh_my_zsh
  vim
  fonts
  desktop_apps
  macos_defaults
)

runner::module_selected() {
  local module="$1"
  [[ " ${DOTFILES_SELECTED_MODULES:-} " == *" $module "* ]]
}

runner::selected_items_for() {
  local module="$1"
  local variable_name="DOTFILES_SELECTED_ITEMS_${module}"
  local raw_value="${(P)variable_name:-}"

  print -r -- "$raw_value"
}

runner::run_module() {
  local module="$1"
  local install_function="module_${module}_install"
  local install_items_function="module_${module}_install_items"
  local raw_items
  local -a items
  local module_label=""

  if ! runner::module_selected "$module"; then
    return 0
  fi

  module_label="$(catalog::module_label "$module")"
  raw_items="$(runner::selected_items_for "$module")"

  if typeset -f "$install_items_function" >/dev/null 2>&1; then
    if [[ -n "$raw_items" ]]; then
      items=("${=raw_items}")
    else
      items=()
    fi
    "$install_items_function" "${items[@]}"
    dotfiles::record_completed_work "Completed ${module_label} setup"
    return 0
  fi

  if typeset -f "$install_function" >/dev/null 2>&1; then
    "$install_function"
    dotfiles::record_completed_work "Completed ${module_label} setup"
  fi
}

runner::install_theme() {
  module_theme_install
  dotfiles::record_completed_work "Completed theme dependency setup for $(catalog::theme_label "$DOTFILES_THEME")"
}

main() {
  local module

  dotfiles::record_bootstrap_results
  dotfiles::write_install_env

  for module in "${DOTFILES_RUN_ORDER[@]}"; do
    if [[ "$module" == "vim" ]] && runner::module_selected "vim"; then
      runner::install_theme
    fi

    runner::run_module "$module"
  done

  if ! runner::module_selected "vim"; then
    runner::install_theme
  fi

  dotfiles::print_install_report
}

main "$@"
