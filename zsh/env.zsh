# Editor (https://github.com/macvim-dev/macvim)
export EDITOR=$(which mvim)

# Manpage (https://github.com/sharkdp/bat)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Language
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Custom Scripts
export PATH=$HOME/.scripts:$PATH

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
  deno completions zsh >"$(brew --prefix)/share/zsh/site-functions/_deno"
fi

# pyenv
if type pyenv &>/dev/null; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

# fnm
eval "$(fnm env --use-on-cd)"
