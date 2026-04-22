export STARSHIP_CONFIG="$DOTFILES/zsh/themes/starship.toml"

if [[ -n "${STARSHIP_CACHE:-}" ]]; then
  export STARSHIP_CACHE
fi

eval "$(starship init zsh)"
