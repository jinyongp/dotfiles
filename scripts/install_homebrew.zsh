#!/bin/zsh

ROOT="$(git rev-parse --show-toplevel)"

source $ROOT/utils/colors.zsh

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
    jq     # https://github.com/jqlang/jq
    bat    # https://github.com/sharkdp/bat
    direnv # https://github.com/direnv/direnv
    gnupg  # https://gnupg.org/
    exa    # https://github.com/ogham/exa
    gh     # https://github.com/cli/cli
    fd     # https://github.com/sharkdp/fd
    fnm    # https://github.com/Schniz/fnm
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
    karabiner-elements # https://karabiner-elements.pqrs.org/
    raycast            # https://raycast.com/
    macvim             # https://github.com/macvim-dev/macvim
    keka               # https://github.com/aonez/Keka
    kekaexternalhelper # https://github.com/aonez/Keka/wiki/Default-application
    google-chrome      # https://www.google.com/chrome/
    visual-studio-code # https://code.visualstudio.com/
  )
  for package in ${packages[*]}; do
    echo -ne "Installing $package... "
    brew install --cask $package &>/dev/null
    echo -e "$(green Installed)"
  done

  echo
fi
