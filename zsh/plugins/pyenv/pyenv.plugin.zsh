if (( ! $+commands[pyenv] )); then
  return
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if [[ -d "$PYENV_ROOT/shims" ]]; then
  export PATH="$PYENV_ROOT/shims:$PATH"
fi

if dotfiles_ensure_writable_dir "$PYENV_ROOT/shims"; then
  eval "$(pyenv init -)"
fi

python --version &>/dev/null
if [[ $? -eq 127 ]] && (( $+commands[python3] )); then
  alias python=python3
fi
