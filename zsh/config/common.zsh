export EDITOR="${EDITOR:-$(command -v vim || command -v vi || echo vi)}"

dotfiles_apply_brew_shellenv

if dotfiles_has_command brew; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

if [[ "${DOTFILES_ENABLE_OH_MY_ZSH:-0}" == "0" ]]; then
  autoload -Uz compinit
  compinit
fi

if dotfiles_has_command bat; then
  export BAT_THEME="ansi"
fi

unset NODE_ENV
