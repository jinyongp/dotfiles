if (( ! $+commands[gate] )); then
  return
fi

dotfiles_cache_zsh_completion gate "gate completion zsh" "gate --version" "_gate"
