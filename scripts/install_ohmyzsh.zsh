#!/bin/zsh

cd "$(dirname $0)/.."

source ./utils/colors.zsh

if [[ ! -d "$ZSH" ]]; then
  echo -ne "$(green Installing oh-my-zsh...) "
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &>/dev/null
  echo -e "$(green Done)"
  echo
fi

if [[ -d "$ZSH" ]]; then
  echo -ne "$(green Installing powerlevel10k theme...)"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k &>/dev/null
  echo -e "$(green Done)"
fi

if [[ -d "$ZSH" ]]; then
  echo -e "$(green Installing oh-my-zsh plugins...)"
  ZSH_PLUGINS="$ZSH_CUSTOM/plugins"
  plugins=(
    djui/alias-tips
    zsh-users/zsh-completions
    zsh-users/zsh-autosuggestions
    lukechilds/zsh-better-npm-completion
    tamcore/autoupdate-oh-my-zsh-plugins
    zdharma-continuum/fast-syntax-highlighting
  )
  for plugin in ${plugins[*]}; do
    plugin_name=$(basename $plugin)
    echo -ne "Installing $plugin_name... "
    if [[ -d "$ZSH_PLUGINS/$plugin_name" ]]; then
      echo -e "$(cyan Already installed)"
    else
      git clone "https://github.com/$plugin.git" "$ZSH_PLUGINS/$plugin_name" &>/dev/null
      echo -e "$(green Installed)"
    fi
  done

  mv "$ZSH_PLUGINS/autoupdate-oh-my-zsh-plugins" "$ZSH_PLUGINS/autoupdate" &>/dev/null

  echo
fi

echo -e "Run $(green $ omz reload) to reload oh-my-zsh.\n"
