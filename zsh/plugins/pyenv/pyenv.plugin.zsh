if (( ! $+commands[pyenv] )); then
  return
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

python --version &>/dev/null
if [[ $? -eq 127 ]] && (( $+commands[python3] )); then
  alias python=python3
fi
