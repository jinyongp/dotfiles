if (( ! $+commands[ngrok] )); then
  return
fi

dotfiles_cache_zsh_completion ngrok "ngrok completion zsh" "ngrok version" _ngrok
