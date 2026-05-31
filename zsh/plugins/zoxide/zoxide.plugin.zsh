if (( ! $+commands[zoxide] )); then
  return
fi

dotfiles_cache_zsh_script zoxide generated zoxide "zoxide init zsh" "zoxide --version"
