#!/bin/zsh

typeset -ga DOTFILES_BASE_PACKAGES=(
  jq
  gh
  fd
  eza
  tldr
  gnupg
  diff-so-fancy
)

module_packages_supported() {
  return 0
}

module_packages_summary() {
  echo "Base CLI packages via $DOTFILES_PACKAGE_MANAGER"
}

module_packages_details() {
  local native_packages=()
  local package_name
  local native_name

  for package_name in "${DOTFILES_BASE_PACKAGES[@]}"; do
    native_name="$(package_manager::logical_to_native "$package_name" 2>/dev/null || true)"
    [[ -n "$native_name" ]] && native_packages+=("$native_name")
  done

  echo "Installs common CLI tools: jq, gh, fd, eza, tldr/tealdeer, gnupg, diff-so-fancy."
  echo "Uses $DOTFILES_PACKAGE_MANAGER and installs these native packages: ${native_packages[*]}."
  echo "May ask for sudo if the selected package manager requires elevated access."
}

module_packages_install() {
  local package_name

  dotfiles::log_step "Installing base CLI packages"

  for package_name in "${DOTFILES_BASE_PACKAGES[@]}"; do
    package_manager::install_logical "$package_name" 0
  done
}
