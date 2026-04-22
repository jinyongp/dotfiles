#!/bin/zsh

module_vim_supported() {
  return 0
}

module_vim_summary() {
  echo "Install Vim and Vundle"
}

module_vim_details() {
  echo "Installs Vim if available from the selected package manager."
  echo "Creates ~/.vim/{bundle,undo,backup,swap} and clones Vundle into ~/.vim/bundle/Vundle.vim."
  echo "Keeps the current Vim-based setup instead of migrating to Neovim or vim-plug."
}

module_vim_install() {
  dotfiles::log_step "Installing Vim tooling"
  package_manager::install_logical vim 0
  package_manager::ensure_command git git 1

  mkdir -p "$HOME/.vim/bundle" "$HOME/.vim/undo" "$HOME/.vim/backup" "$HOME/.vim/swap"

  if [[ -d "$HOME/.vim/bundle/Vundle.vim" ]]; then
    dotfiles::record_reused "Vundle plugin manager"
    dotfiles::log_info "Vundle is already installed."
  else
    dotfiles::record_installed "Vundle plugin manager"
    git clone --depth=1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
  fi
}
