if ! dotfiles_has_command brew; then
  return
fi

autoenv_prefix="${HOMEBREW_PREFIX:-}/opt/autoenv"
if [[ ! -f "$autoenv_prefix/activate.sh" ]]; then
  autoenv_prefix="$(dotfiles_brew_prefix autoenv 2>/dev/null || true)"
fi

if [[ -n "$autoenv_prefix" && -f "$autoenv_prefix/activate.sh" ]]; then
  AUTOENV_ENABLE_LEAVE=yes
  source "$autoenv_prefix/activate.sh"
fi
