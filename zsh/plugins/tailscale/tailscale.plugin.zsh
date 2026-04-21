if (( ! $+commands[tailscale] )); then
  return
fi

if [[ ! -f "$ZSH_CACHE_DIR/completions/_tailscale" ]]; then
  typeset -g -A _comps
  autoload -Uz _tailscale
  _comps[tailscale]=_tailscale
fi

tailscale_completion="$(tailscale completion zsh 2>/dev/null || true)"

if [[ "$tailscale_completion" == "#compdef "* ]]; then
  source <(print -r -- "$tailscale_completion")
fi

unset tailscale_completion
