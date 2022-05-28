#!/bin/bash

CWD=$(dirname $(readlink -f $0))

dotfiles=(
  .zshrc
  .zshrc_env
  .zshrc_alias
  .zshrc_theme
  .zshrc_plugin
  .vimrc
  .gitconfig
  .gitconfig_personal
  .gitconfig_company
)

echo -e "Installing dotfiles...\n"

overwritten=()
linked=()

for file in ${dotfiles[*]}; do
  overwrite=false

  if [[ -f $HOME/$file ]]; then
    BACKUP_DIR=$CWD/.backup/$(date +%Y-%m-%d__%H-%M)
    mkdir -p $BACKUP_DIR
    cp $HOME/$file $BACKUP_DIR/$file
    rm $HOME/$file
    overwrite=true
  fi

  ln -s $CWD/$file $HOME/$file
  [[ $? == 0 ]] && [[ $overwrite == true ]] &&
    overwritten+=("$file") ||
    linked+=("$file")

done

[[ ${#overwritten[@]} > 0 ]] && (
  echo "Overwritten:"
  printf "  %s\n" ${overwritten[@]}
)

echo

[[ ${#linked[@]} > 0 ]] && (
  echo "New linked:"
  printf "  %s\n" ${linked[@]}
)

[[ ${#overwritten[@]} > 0 ]] && echo -e "\nYour original files are backed up in $BACKUP_DIR\n"

echo -e "All dotfiles installed. Enjoy! :)"

GIT_HOOKS_DIR=$HOME/.git-template/hooks
if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo -e -e "\nGit hooks not found. Installing..."
  mkdir -p $GIT_HOOKS_DIR
  git clone https://gist.github.com/d8a4ce41e4bb52e352d45306691e3122.git $GIT_HOOKS_DIR --quiet
  echo -e "Git hooks installed. Check it out $GIT_HOOKS_DIR"
fi
