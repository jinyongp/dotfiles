#!/bin/zsh

CWD=$(cd "$(dirname "$0")" && pwd)

reset='\033[0m'
green() { printf "\033[0;32m$*$reset" }
cyan() { printf "\033[0;36m$*$reset" }
red() { printf "\033[0;31m$*$reset" }

if ! type brew &>/dev/null; then
  echo
  echo -ne "$(green Installing homebrew...)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo -e "$(green Done)"
fi

if type brew &>/dev/null; then
  echo -e "$(green Installing homebrew packages...)"
  local formulaes=(jq bat direnv gnupg exa gh node)
  for formula in ${formulaes[*]}; do
    echo -ne "Installing $formula... "
    if brew list $formula &>/dev/null; then
      echo -e "$(cyan Already installed)"
    else
      brew install $formula
      echo -e "$(green Installed)"
    fi
  done

  local casks=(iterm2 miniconda karabiner-elements raycast keka kekaexternalhelper google-chrome macvim visual-studio-code)
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
  echo -ne "$(green Installing awesome fonts... )"
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
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &>/dev/null & wait
  echo -e "$(green Done)"
fi

if [[ -d "$ZSH" ]]; then
  echo -ne "$(green Installing powerlevel10k theme... )"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k &>/dev/null & wait
  echo -e "$(green Done)"

  echo -ne "$(green Installing vundlevim... )"
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim &>/dev/null & wait
  echo -e "$(green Done)"

  echo -e "$(green Installing oh-my-zsh plugins... )"
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
[[ ${#overwritten[@]} > 0 ]] && echo -e "Backup files in $BACKUP_DIR"
echo -e "\n$(cyan All dotfiles installed!!)"
echo -e "Run $(green $ omz reload) to reload oh-my-zsh."
echo -e "Run $(green $ vundle) to install vim plugins."

GIT_TEMPLATE_DIR=$HOME/.git_template
GIT_HOOKS_DIR=$GIT_TEMPLATE_DIR/hooks
if [[ ! -d "$GIT_TEMPLATE_DIR" ]]; then
  echo -e "Git hooks not found. Installing..."
  mkdir -p $GIT_HOOKS_DIR

  ln -sf $CWD/git/hooks $GIT_HOOKS_DIR
  echo -e "Done."
fi

mkdir -p $HOME/.vim/undo $HOME/.vim/backup $HOME/.vim/swap
