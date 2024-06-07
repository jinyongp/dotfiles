# Environment variables
export EDITOR=$(which vim)

# Path
export PATH=$HOME/.scripts:$PATH
export PATH="$(brew --prefix)/opt/postgresql@16/bin:$PATH"

# Configuration
HISTSIZE=999999999
SAVEHIST=$HISTSIZE
HIST_STAMPS="yyyy-mm-dd"
PROMPT_EOL_MARK=

setopt hist_ignore_all_dups
setopt hist_ignore_space

function exists() {
  type "$1" &>/dev/null
}

if exists brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

if exists ngrok; then
  source <(ngrok completion)
fi

if exists docker; then
  source <(docker completion zsh)
fi

if exists deno; then
  deno completions zsh >"$(brew --prefix)/share/zsh/site-functions/_deno"
fi

if exists pyenv; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

if exists direnv; then
  eval "$(direnv hook zsh)"
fi

if exists fnm; then
  eval "$(fnm env --use-on-cd)"
fi

if exists poetry; then
  poetry completions zsh >"$(brew --prefix)/share/zsh/site-functions/_poetry"
fi

if exists tuist; then
  tuist --generate-completion-script >"$(brew --prefix)/share/zsh/site-functions/_tuist"
fi

if exists orbctl; then
  orbctl completion zsh >"$(brew --prefix)/share/zsh/site-functions/_orb"
fi

if exists bat; then
  export BAT_THEME="GitHub"
fi

if exists gh; then
  eval "$(gh copilot alias -- zsh 2>/dev/null)"
fi

compinit -d $ZSH_COMPDUMP

unset -f exists
