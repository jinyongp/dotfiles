if (( ! $+commands[pyenv] )); then
  return
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if [[ -d "$PYENV_ROOT/shims" ]]; then
  export PATH="$PYENV_ROOT/shims:$PATH"
fi

if dotfiles_ensure_writable_dir "$PYENV_ROOT/shims"; then
  dotfiles_cache_zsh_script pyenv generated pyenv "pyenv init - --no-rehash" "pyenv --version" "root:${PYENV_ROOT}"
fi

if (( ! $+commands[python] && $+commands[python3] )); then
  alias python=python3
fi
