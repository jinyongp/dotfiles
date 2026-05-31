dotfiles_prepend_path "/usr/local/bin"
dotfiles_prepend_path "$HOME/.local/bin"

if [[ -n "${PRX_BIN_DIR:-}" ]]; then
  dotfiles_prepend_path "$PRX_BIN_DIR"
fi

if (( ! $+commands[prx] )); then
  return
fi

dotfiles_cache_zsh_completion prx "prx completion zsh" "prx --version" "_prx"
