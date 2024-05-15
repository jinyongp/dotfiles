#!/bin/zsh

SCRIPTS=$(dirname $0)/scripts

source "${SCRIPTS}/install_homebrew.zsh"
source "${SCRIPTS}/install_fonts.zsh"
source "${SCRIPTS}/install_ohmyzsh.zsh"
source "${SCRIPTS}/install_vundlevim.zsh"
source "${SCRIPTS}/install_dotfiles.zsh"
source "${SCRIPTS}/setup_macos.zsh"

echo "🎉 Installation complete! Enjoy!"
