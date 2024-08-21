export EDITOR=$(which vim)

if exists brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit; compinit
fi

if exists bat; then
  export BAT_THEME="ansi"
fi
