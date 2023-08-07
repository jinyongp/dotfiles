#!/bin/zsh

ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$ROOT/scripts"

source $ROOT/utils/colors.zsh

source $SCRIPT/install_homebrew.zsh
source $SCRIPT/install_fonts.zsh
source $SCRIPT/install_ohmyzsh.zsh
source $SCRIPT/install_vundlevim.zsh
source $SCRIPT/install_dotfiles.zsh
