#!/bin/bash

CWD=$(dirname $(readlink -f $0))

dotfiles=(
  .zshrc
  .zshrc_env
  .zshrc_utils
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
  filepath=$(find $CWD -name $file ! -path "*/.backup/*")

  if [[ -f $HOME/$file ]]; then
    BACKUP_DIR=$CWD/.backup/$(date +%Y-%m-%d__%H-%M)
    mkdir -p $BACKUP_DIR
    cp $HOME/$file $BACKUP_DIR/$file
    rm $HOME/$file
    overwrite=true
  fi

  ln -sf $filepath $HOME/$file
  [[ $? == 0 ]] && [[ $overwrite == true ]] &&
    overwritten+=("$file") ||
    linked+=("$file")
done

[[ ${#overwritten[@]} > 0 ]] && (
  echo "Overwritten:"
  printf "  %s\n" ${overwritten[@]}
)

[[ ${#linked[@]} > 0 ]] && (
  echo "New linked:"
  printf "  %s\n" ${linked[@]}
)

echo
[[ ${#overwritten[@]} > 0 ]] && echo -e "Backup files in $BACKUP_DIR"
echo -e "\nAll dotfiles installed!"
echo -e "Need to restart your terminal to apply changes.\n"

GIT_TEMPLATE_DIR=$HOME/.git_template
GIT_HOOKS_DIR=$GIT_TEMPLATE_DIR/hooks
if [[ ! -d "$GIT_TEMPLATE_DIR" ]]; then
  echo -e "Git hooks not found. Installing..."
  mkdir -p $GIT_HOOKS_DIR

  ln -sf $CWD/git/hooks $GIT_HOOKS_DIR
  echo -e "Done."
fi

mkdir -p $HOME/.vim/undo $HOME/.vim/backup $HOME/.vim/swap
