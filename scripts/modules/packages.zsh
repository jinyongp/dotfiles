#!/bin/zsh

module_packages_supported() {
  return 0
}

module_packages_summary() {
  echo "Selected base CLI packages via $DOTFILES_PACKAGE_MANAGER"
}

module_packages_details() {
  echo "Installs only the selected CLI packages through $DOTFILES_PACKAGE_MANAGER."
}

module_packages_install_items() {
  local -a package_ids
  local package_id

  if (( $# > 0 )); then
    package_ids=("$@")
  else
    package_ids=("${(@f)$(catalog::package_ids)}")
  fi

  dotfiles::log_step "Installing selected base CLI packages"

  for package_id in "${package_ids[@]}"; do
    package_manager::install_logical "$package_id" 0
  done
}

module_packages_install() {
  module_packages_install_items
}
