#!/bin/zsh

cd "$(dirname $0)/.."

source ./utils/colors.zsh

if ! type brew &>/dev/null; then
  echo -e "$(green Installing homebrew...)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo
else
  echo -e "$(green 'Updating homebrew... ')"
  brew update && brew upgrade && brew cleanup
  echo
fi

if type brew &>/dev/null; then
  echo -e "$(green Installing homebrew formulae packages...)"

  packages=(
    jq            # https://github.com/jqlang/jq
    gh            # https://github.com/cli/cli
    fd            # https://github.com/sharkdp/fd
    eza           # https://github.com/eza-community/eza
    tlrc          # https://github.com/tldr-pages/tldr
    gnupg         # https://gnupg.org/
    diff-so-fancy # https://github.com/so-fancy/diff-so-fancy
  )
  for package in ${packages[*]}; do
    echo -ne "Installing $package... "
    brew list $package &>/dev/null || {
      brew install $package &>/dev/null
    }
    echo -e "$(green Installed)"
  done

  echo
fi

if type brew &>/dev/null; then
  echo -e "$(green Installing homebrew cask packages...)"

  packages=(
    arc                # https://arc.net/
    iterm2             # https://iterm2.com/
    raycast            # https://raycast.com/
    keka               # https://github.com/aonez/Keka
    kekaexternalhelper # https://github.com/aonez/Keka/wiki/Default-application
    karabiner-elements # https://karabiner-elements.pqrs.org/
    visual-studio-code # https://code.visualstudio.com/
  )
  for package in ${packages[*]}; do
    echo -ne "Installing $package... "
    brew list --cask $package &>/dev/null || {
      brew install --cask $package &>/dev/null
    }
    echo -e "$(green Installed)"
  done

  echo
fi
