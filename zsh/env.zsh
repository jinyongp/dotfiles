export EDITOR=$(which vim)

export BAT_THEME="GitHub"

# language
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# custom scripts
export PATH=$HOME/.scripts:$PATH

function exists() {
  type "$1" &>/dev/null
}

# ngrok
if exists ngrok; then
  source <(ngrok completion)
fi

# deno
if exists deno; then
  deno completions zsh >"$(brew --prefix)/share/zsh/site-functions/_deno"
fi

# pyenv
if exists pyenv; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

# fnm
if exists fnm; then
  eval "$(fnm env --use-on-cd)"
fi

# bun
if exists bun; then
  source "$HOME/.bun/_bun"
fi

# poetry
if exists poetry; then
  poetry completions zsh >"$(brew --prefix)/share/zsh/site-functions/_poetry"
fi

# brew
if exists brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit && compinit
fi

unset -f exists
