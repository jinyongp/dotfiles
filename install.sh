#!/bin/bash

CWD=$(dirname $(readlink -f $0))

dotfiles=(
  .zshrc
  .zshrc_alias
  .zshrc_env
  .vimrc
  .gitconfig
  .gitconfig_personal
  .gitconfig_company
)

echo "Installing dotfiles..."
for file in ${dotfiles[*]}; do
  if [[ -f $HOME/$file ]]; then
    rm $HOME/$file
    overwrite=true
  fi
  ln -s $CWD/$file $HOME/$file
  echo -e "\t$file linked. $([[ $overwrite == true ]] && echo '(overwritten)')"
done
echo "Done."

GIT_HOOKS_DIR=$HOME/.git-template/hooks
if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo "\nGit hooks directory not found. Creating..."
  mkdir -p $GIT_HOOKS_DIR
  git clone https://gist.github.com/d8a4ce41e4bb52e352d45306691e3122.git $GIT_HOOKS_DIR --quiet
  echo "Git hooks installed. Check it out $GIT_HOOKS_DIR"
fi
