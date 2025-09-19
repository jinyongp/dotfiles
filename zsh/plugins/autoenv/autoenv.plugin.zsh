if [[ -f "$(brew --prefix autoenv)/activate.sh" ]]; then
  AUTOENV_ENABLE_LEAVE=yes

  source "$(brew --prefix autoenv)/activate.sh"
fi
