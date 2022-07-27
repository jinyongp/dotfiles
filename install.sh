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
[[ ${#overwritten[@]} > 0 ]] && echo -e "Your original files are backed up in $BACKUP_DIR"
echo -e "\nAll dotfiles installed! Run \033[1;32m$ omz reload\033[0m to reload your shell."

hooks=(
  pre-push
  post-checkout
)

GIT_HOOKS_DIR=$HOME/.git_template/hooks
if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo -e "Git hooks not found. Installing..."
  mkdir -p $GIT_HOOKS_DIR


  for file in ${hooks[*]}; do
    ln -sf $CWD/git/hooks/$file $GIT_HOOKS_DIR/$file
  done
  git config --global core.hooksPath $GIT_HOOKS_DIR
  echo -e "Git hooks installed. Check it out $GIT_HOOKS_DIR"
fi

KEY_BINDINGS_DIR=$HOME/Library/KeyBindings
DEFAULT_KEY_BINDING_FILE="DefaultkeyBinding.dict"
if [[ ! -f "$KEY_BINDINGS_DIR/$DEFAULT_KEY_BINDING_FILE" ]]; then
  echo -e "Key bindings not found. Installing..."
  ORIGINAL_KEY_BINDING_FILE=$KEY_BINDINGS_DIR/$DEFAULT_KEY_BINDING_FILE
  [[ -f $ORIGINAL_KEY_BINDING_FILE ]] && cp $ORIGINAL_KEY_BINDING_FILE $BACKUP_DIR/$DEFAULT_KEY_BINDING_FILE
  mkdir -p $KEY_BINDINGS_DIR && ln -sf $CWD/dict/$DEFAULT_KEY_BINDING_FILE $ORIGINAL_KEY_BINDING_FILE
  echo -e "\nDefault key bindings installed. Check it out $ORIGINAL_KEY_BINDING_FILE"
fi
