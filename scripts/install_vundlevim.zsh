#!/bin/zsh

ROOT="$(git rev-parse --show-toplevel)"

source $ROOT/utils/colors.zsh

if [[ -d "$HOME/.vim" ]]; then
  echo -ne "$(green Installing VundleVim...) "
  git clone --depth 1 https://github.com/VundleVim/Vundle.vim.git $HOME/.vim/bundle/Vundle.vim &>/dev/null &
  wait
  echo -e "$(green Done)\n"
fi

for folder in undo backup swap; do
  mkdir -p $HOME/.vim/$folder
done

echo -e "Run $(green $ vundle) to install vim plugins.\n"
