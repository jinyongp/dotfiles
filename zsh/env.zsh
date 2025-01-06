export EDITOR=$(which vim)

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

if exists brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit; compinit
fi

if exists bat; then
  export BAT_THEME="ansi"
fi

unset NODE_ENV
