if (( ! $+commands[docker] )); then
  return
fi

dotfiles_cache_zsh_completion docker "docker completion zsh" "docker --version" _docker
