# Editor (https://github.com/macvim-dev/macvim)
export EDITOR=$(which mvim)

# Manpage (https://github.com/sharkdp/bat)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Language
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Custom Scripts
export PATH=$HOME/.scripts:$PATH

# NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Brew
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit && compinit
fi

# ngrok
if type ngrok &>/dev/null; then
  source <(ngrok completion)
fi

# deno
if type deno &>/dev/null; then
  deno completions zsh > "$(brew --prefix)/share/zsh/site-functions/_deno"
fi

# pyenv
if type pyenv &>/dev/null; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

# tabtab source for packages
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
miniconda="$(brew --prefix)/Caskroom/miniconda"
__conda_setup="$('$miniconda/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
  eval "$__conda_setup"
else
  if [ -f "$miniconda/base/etc/profile.d/conda.sh" ]; then
    . "$miniconda/base/etc/profile.d/conda.sh"
  else
    export PATH="$miniconda/base/bin:$PATH"
  fi
fi
unset __conda_setup
# <<< conda initialize <<<
