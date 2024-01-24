export EDITOR=$(which vim)

export BAT_THEME="GitHub"

# language
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Path
export PATH=$HOME/.scripts:$PATH
export PATH="$(brew --prefix)/opt/postgresql@16/bin:$PATH"

function exists() {
  type "$1" &>/dev/null
}

# brew
if exists brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

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

# direnv
if exists direnv; then
  eval "$(direnv hook zsh)"
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

# tuist
if exists tuist; then
  tuist --generate-completion-script >"$(brew --prefix)/share/zsh/site-functions/_tuist"
fi

# orb
if exists orbctl; then
  orbctl completion zsh >"$(brew --prefix)/share/zsh/site-functions/_orb"
fi

autoload -Uz compinit && compinit

unset -f exists
