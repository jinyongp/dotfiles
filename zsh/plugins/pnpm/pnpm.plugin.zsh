if (( ! $+commands[pnpm] )); then
  return
fi

if [[ ! -f "$ZSH_CACHE_DIR/completions/_pnpm" ]]; then
  typeset -g -A _comps
  autoload -Uz _pnpm
  _comps[docker]=_pnpm
fi

nohup pnpm completion zsh > $ZSH_CACHE_DIR/completions/_pnpm &!

export PNPM_HOME="/Users/jinyongp/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
