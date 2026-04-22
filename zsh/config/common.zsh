dotfiles_apply_brew_shellenv

if [[ -n "${XDG_DATA_HOME:-}" ]]; then
  dotfiles_prepend_path "$XDG_DATA_HOME/npm-global/bin"
elif [[ "${DOTFILES_PLATFORM:-}" == "macos" ]]; then
  dotfiles_prepend_path "$HOME/Library/Application Support/npm-global/bin"
else
  dotfiles_prepend_path "$HOME/.local/share/npm-global/bin"
fi

if dotfiles_has_command nvim; then
  if [[ -n "${XDG_STATE_HOME:-}" ]] && dotfiles_ensure_writable_dir "$XDG_STATE_HOME/nvim"; then
    export NVIM_LOG_FILE="$XDG_STATE_HOME/nvim/nvim.log"
  fi
  export EDITOR="$(command -v nvim)"
  export VISUAL="$EDITOR"
else
  export EDITOR="${EDITOR:-$(command -v vim || command -v vi || echo vi)}"
  export VISUAL="${VISUAL:-$EDITOR}"
fi

if [[ -n "${HOMEBREW_PREFIX:-}" && -d "${HOMEBREW_PREFIX}/share/zsh/site-functions" ]]; then
  FPATH="${HOMEBREW_PREFIX}/share/zsh/site-functions:${FPATH}"
fi

if [[ "${DOTFILES_ENABLE_OH_MY_ZSH:-0}" == "0" ]]; then
  autoload -Uz compinit
  compinit
fi

if dotfiles_has_command bat; then
  export BAT_THEME="ansi"
fi

unset NODE_ENV
