#!/bin/zsh

module_neovim_supported() {
  return 0
}

module_neovim_summary() {
  echo "Install Neovim and editor dependencies"
}

module_neovim_details() {
  echo "Installs Neovim plus git, ripgrep, and fd."
  echo "If node and npm are already available, also installs global TypeScript editor tools."
  echo "The repo-managed Neovim config is linked separately by the dotfiles module."
}

neovim::install_core_dependencies() {
  package_manager::install_logical neovim 1
  package_manager::ensure_command git git 1
  package_manager::install_logical ripgrep 1
  package_manager::install_logical fd 1
}

neovim::install_typescript_tooling() {
  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    dotfiles::log_warn "Skipping TypeScript editor tooling because node/npm is not available."
    return 0
  fi

  package_manager::install_logical typescript 1
  package_manager::install_logical typescript-language-server 1
  dotfiles::record_completed_work "Installed TypeScript editor tooling"
}

module_neovim_install() {
  dotfiles::log_step "Installing Neovim tooling"
  neovim::install_core_dependencies
  neovim::install_typescript_tooling

  if [[ " ${DOTFILES_SELECTED_MODULES:-} " != *" dotfiles "* ]]; then
    dotfiles::link_neovim_config
    dotfiles::record_completed_work "Linked repo-managed Neovim config"
  fi
}
