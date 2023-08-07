#!/bin/zsh

ROOT="$(git rev-parse --show-toplevel)"

source $ROOT/utils/colors.zsh

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
  filepath=$(find $ROOT -name $file ! -path "*/.backup/*")

  linkpath=$HOME/$file
  if [[ -f $linkpath ]]; then
    BACKUP_DIR=$ROOT/.backup/$(date +%Y-%m-%d__%H:%M:%S)
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
  echo -e "\nCreated backup files in $BACKUP_DIR"
)

echo -e "\n$(cyan All dotfiles installed!!)\n"
