#!/bin/zsh

CWD=$(cd "$(dirname "$0")" && pwd)

source $CWD/utils/colors.zsh

if ! type brew &>/dev/null; then
  echo
  echo -ne "$(green Installing homebrew...)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo -e "$(green Done)"
else
  echo -e "$(cyan 'Homebrew is already installed!')"
  echo -e "$(green 'Updating homebrew... ')"
  brew update && brew upgrade && brew cleanup
  echo -e "$(green 'Update homebrew... Done')"
fi

if type brew &>/dev/null; then
  echo -e "$(green Installing homebrew packages...)"
  local formulaes=(jq bat direnv gnupg exa gh fd)
  for formula in ${formulaes[*]}; do
    echo -ne "Installing $formula... "
    if brew list $formula &>/dev/null; then
      echo -e "$(cyan Already installed)"
    else
      brew install $formula &>/dev/null
      echo -e "$(green Installed)"
    fi
  done

  local casks=(
    iterm2 karabiner-elements raycast macvim
    keka kekaexternalhelper google-chrome visual-studio-code
  )
  for cask in ${casks[*]}; do
    echo -ne "Installing $cask... "
    if brew list $cask &>/dev/null; then
      echo -e "$(cyan Already installed)"
    else
      brew install --cask $cask &>/dev/null
      echo -e "$(green Installed)"
    fi
  done
  echo -e "$(green Installing homebrew packages... Done)\n"
  echo -e "$(cyan Installed homebrew packages:)"
  brew list
  echo
fi

if type brew &>/dev/null; then
  echo -ne "$(green Installing awesome nerd fonts...)"
  nerd_font="font-fira-code-nerd-font"
  brew list $nerd_font &>/dev/null || {
    brew tap homebrew/cask-fonts &>/dev/null
    brew install --cask $nerd_font &>/dev/null
  }
  IFS=$'\n'
  internal_fonts=($(find $CWD/assets/fonts -name '*.?tf'))
  IFS=$' '
  for font in ${internal_fonts[*]}; do
    font_name=$(basename $font)
    if [[ ! -f $HOME/Library/Fonts/$font_name ]]; then
      cp $font $HOME/Library/Fonts/$font_name
    fi
  done
  echo -e "$(green Done)"
fi

if [[ ! -d "$ZSH" ]]; then
  echo
  echo -ne "$(green "Installing oh-my-zsh... ")"
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &>/dev/null &
  wait
  echo -e "$(green Done)"
fi

if [[ -d "$ZSH" ]]; then
  echo -ne "$(green Installing powerlevel10k theme...)"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k &>/dev/null &
  wait
  echo -e "$(green Done)"

  echo -ne "$(green Installing vundlevim...)"
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim &>/dev/null &
  wait
  echo -e "$(green Done)"

  echo
  echo -e "$(green Installing oh-my-zsh plugins...)"
  local PLUGINS_DIR="${ZSH_CUSTOM:=$HOME/.oh-my-zsh/custom}/plugins"
  local plugins=(
    djui/alias-tips
    paulirish/git-open
    zsh-users/zsh-completions
    zsh-users/zsh-autosuggestions
    esc/conda-zsh-completion
    lukechilds/zsh-better-npm-completion
    zdharma-continuum/fast-syntax-highlighting
  )
  for plugin in ${plugins[*]}; do
    local plugin_name=$(basename $plugin)
    echo -ne "Installing $plugin_name... "
    if [[ -d "$PLUGINS_DIR/$plugin_name" ]]; then
      echo -e "$(cyan Already installed)"
    else
      git clone "https://github.com/$plugin.git" "$PLUGINS_DIR/$plugin_name" &>/dev/null
      echo -e "$(green Installed)"
    fi
  done
  echo -e "$(green Installing oh-my-zsh plugins... Done)"
  echo
fi

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
[[ ${#overwritten[@]} > 0 ]] && (
  echo -e "Created backup files in $BACKUP_DIR"
)
echo -e "\n$(cyan All dotfiles installed!!)\n"
echo -e "Run $(green $ omz reload) to reload oh-my-zsh."
echo -e "Run $(green $ vundle) to install vim plugins."

mkdir -p $HOME/.vim/undo $HOME/.vim/backup $HOME/.vim/swap
