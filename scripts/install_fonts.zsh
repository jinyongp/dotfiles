#!/bin/zsh

ROOT="$(git rev-parse --show-toplevel)"

source $ROOT/utils/colors.zsh

if type brew &>/dev/null; then
  echo -ne "$(green Installing awesome nerd fonts...) "

  nerd_font="font-fira-code-nerd-font"
  brew list $nerd_font &>/dev/null || {
    brew tap homebrew/cask-fonts &>/dev/null
    brew install --cask $nerd_font &>/dev/null
  }
  internal_fonts=($(find $ROOT/assets/fonts -name '*.?tf'))
  for font in ${internal_fonts[*]}; do
    font_name=$(basename $font)
    cp $font $HOME/Library/Fonts/$font_name
  done

  echo -e "$(green Done)\n"
fi
