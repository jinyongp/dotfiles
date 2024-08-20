# Environment variables
export EDITOR=$(which vim)

# Path
export PATH="$(brew --prefix)/opt/postgresql@16/bin:$PATH"

if exists brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

if exists ngrok; then
  eval "$(ngrok completion zsh)"
fi

if exists docker; then
  source <(docker completion zsh)
fi

if exists fnm; then
  eval "$(fnm env --use-on-cd --shell zsh --version-file-strategy=recursive)"
fi

if exists gh; then
  eval "$(gh copilot alias -- zsh 2>/dev/null)"
fi

if exists bat; then
  export BAT_THEME="ansi"
fi
