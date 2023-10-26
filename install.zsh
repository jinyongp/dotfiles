#!/bin/zsh

ROOT="$(git rev-parse --show-toplevel)"

source $ROOT/scripts/install_homebrew.zsh
source $ROOT/scripts/install_fonts.zsh
source $ROOT/scripts/install_ohmyzsh.zsh
source $ROOT/scripts/install_vundlevim.zsh
source $ROOT/scripts/install_dotfiles.zsh
source $ROOT/scripts/setup_macos.zsh

echo -e "🎉 Installation complete! Enjoy!"
