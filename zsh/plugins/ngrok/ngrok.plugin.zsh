if (( ! $+commands[ngrok] )); then
  return
fi

if [[ ! -f "$ZSH_CACHE_DIR/completions/_ngrok" ]]; then
  typeset -g -A _comps
  autoload -Uz _ngrok
  _comps[ngrok]=_ngrok
fi

nohup ngrok completion zsh > $ZSH_CACHE_DIR/completions/_ngrok &!
