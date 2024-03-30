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
    jq         # https://github.com/jqlang/jq
    gh         # https://github.com/cli/cli
    fd         # https://github.com/sharkdp/fd
    fnm        # https://github.com/Schniz/fnm
    eza        # https://github.com/eza-community/eza
    bat        # https://github.com/sharkdp/bat
    bat-extras # https://github.com/eth-p/bat-extras
    ripgrep    # https://github.com/BurntSushi/ripgrep
    tlrc       # https://github.com/tldr-pages/tldr
    direnv     # https://github.com/direnv/direnv
    gnupg      # https://gnupg.org/
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
    iterm2             # https://iterm2.com/
    raycast            # https://raycast.com/
    google-chrome      # https://www.google.com/chrome/
    keka               # https://github.com/aonez/Keka
    kekaexternalhelper # https://github.com/aonez/Keka/wiki/Default-application
    visual-studio-code # https://code.visualstudio.com/
    karabiner-elements # https://karabiner-elements.pqrs.org/
  )
  for package in ${packages[*]}; do
    echo -ne "Installing $package... "
    brew install --cask $package &>/dev/null
    echo -e "$(green Installed)"
  done

  echo
fi
