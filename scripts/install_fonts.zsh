#!/bin/zsh

cd "$(dirname $0)/.."

source ./utils/colors.zsh

if type brew &>/dev/null; then
  echo -ne "$(green Installing awesome nerd fonts...) "

  nerd_fonts=(
    font-fira-code-nerd-font
    font-victor-mono-nerd-font
  )
  for nerd_font in ${nerd_fonts[*]}; do
    brew list $nerd_font &>/dev/null || {
      brew tap homebrew/cask-fonts &>/dev/null
      brew install --cask $nerd_font &>/dev/null
    }
  done
  internal_fonts=($(find ./assets/fonts -name '*.?tf'))
  for font in ${internal_fonts[*]}; do
    font_name=$(basename $font)
    cp $font $HOME/Library/Fonts/$font_name
  done

  echo -e "$(green Done)\n"
fi
