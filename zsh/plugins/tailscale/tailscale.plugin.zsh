if (( ! $+commands[tailscale] )); then
  return
fi

dotfiles_cache_zsh_completion tailscale "tailscale completion zsh | sed -n '/^#compdef /,\$p'" "tailscale version" _tailscale
