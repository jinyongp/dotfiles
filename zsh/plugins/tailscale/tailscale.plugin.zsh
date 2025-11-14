if (( ! $+commands[tailscale] )); then
  return
fi

if [[ ! -f "$ZSH_CACHE_DIR/completions/_tailscale" ]]; then
  typeset -g -A _comps
  autoload -Uz _tailscale
  _comps[tailscale]=_tailscale
fi

nohup tailscale completion zsh > $ZSH_CACHE_DIR/completions/_tailscale &!
