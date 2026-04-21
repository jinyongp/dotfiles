if (( ! $+commands[docker] )); then
  return
fi

if [[ ! -f "$ZSH_CACHE_DIR/completions/_docker" ]]; then
  typeset -g -A _comps
  autoload -Uz _docker
  _comps[docker]=_docker
fi

source <(docker completion zsh)
