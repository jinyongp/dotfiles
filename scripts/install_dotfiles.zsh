#!/bin/zsh

cd "$(dirname $0)/.."

source ./utils/colors.zsh

dotfiles=(
  .zshrc
  .vimrc
  .gitconfig
)

echo -e "$(green Installing dotfiles...)"

overwritten=()
linked=()

for file in ${dotfiles[*]}; do
  overwrite=false
  filepath=$(find . -name $file ! -path "*/.backup/*" | xargs realpath)

  linkpath=$HOME/$file
  if [[ -f $linkpath ]]; then
    BACKUP_DIR=./.backup/$(date +%Y-%m-%d__%H:%M:%S)
    mkdir -p $BACKUP_DIR
    cp $linkpath $BACKUP_DIR/$file
    rm $linkpath
    overwrite=true
  fi

  if ln -sf $filepath $linkpath; then
    if [[ $overwrite == true ]]; then
      overwritten+=("$file")
    else
      linked+=("$file")
    fi
  fi
done

[[ ${#overwritten[@]} > 0 ]] && (
  echo "Overwritten:"
  printf "  %s\n" ${overwritten[@]}
)

[[ ${#linked[@]} > 0 ]] && (
  echo "New linked:"
  printf "  %s\n" ${linked[@]}
)

[[ ${#overwritten[@]} > 0 ]] && (
  echo -e "\nCreated backup files in $(realpath $BACKUP_DIR)"
)

echo
