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

echo -e "Installing dotfiles...\n"

for file in ${dotfiles[*]}; do

  if [[ -f $HOME/$file ]]; then
    BACKUP_DIR=$CWD/backup/$(date +%Y-%m-%d-%H-%M)
    mkdir -p $BACKUP_DIR
    cp $HOME/$file $BACKUP_DIR/$file
    rm $HOME/$file
    overwrite=true
  fi

  ln -s $CWD/$file $HOME/$file
  [[ $? == 0 ]] &&
    echo -e " $file is $([[ $overwrite == true ]] && echo 'overwritten' || echo 'linked')" ||
    echo -e " $file linking failed."
done
echo
[[ $overwrite == true ]] && echo -e "Backed up in $BACKUP_DIR\n"

echo -e "All dotfiles installed. Enjoy! :)"

GIT_HOOKS_DIR=$HOME/.git-template/hooks
if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo -e -e "\nGit hooks not found. Installing..."
  mkdir -p $GIT_HOOKS_DIR
  git clone https://gist.github.com/d8a4ce41e4bb52e352d45306691e3122.git $GIT_HOOKS_DIR --quiet
  echo -e "Git hooks installed. Check it out $GIT_HOOKS_DIR"
fi
