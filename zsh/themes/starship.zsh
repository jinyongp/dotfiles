export STARSHIP_CONFIG="$DOTFILES/zsh/themes/starship.toml"

if [[ -n "${STARSHIP_CACHE:-}" ]]; then
  export STARSHIP_CACHE
fi

dotfiles_cache_zsh_script starship generated starship "starship init zsh" "starship --version" "config:${STARSHIP_CONFIG:-}"
