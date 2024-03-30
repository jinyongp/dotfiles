#!/bin/zsh

cd $(dirname $0)/scripts

source ./install_homebrew.zsh
source ./install_fonts.zsh
source ./install_ohmyzsh.zsh
source ./install_vundlevim.zsh
source ./install_dotfiles.zsh
source ./setup_macos.zsh

echo "🎉 Installation complete! Enjoy!"
