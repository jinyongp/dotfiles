# Environment variables
export EDITOR=$(which vim)

# Path
export PATH=$HOME/.scripts:$PATH
export PATH="$(brew --prefix)/opt/postgresql@16/bin:$PATH"

# Configuration
HIST_STAMPS="yyyy-mm-dd"

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

# docker
if exists docker; then
  source <(docker completion zsh)
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

# bat
if exists bat; then
  export BAT_THEME="GitHub"
fi

autoload -Uz compinit && compinit

unset -f exists
