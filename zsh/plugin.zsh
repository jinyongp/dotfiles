plugins=(
  gh
  git
  fnm
  orb
  rust
  pyenv
  python
  direnv
  vundle
  copyfile
  copypath
  gitignore
  alias-tips
  autoupdate
  poetry-env
  # auto-notify
  zsh-completions
  zsh-autosuggestions
  fast-syntax-highlighting
  zsh-better-npm-completion
)

# pyenv
ZSH_PYENV_QUIET=true

# python
PYTHON_AUTO_VRUN=true
PYTHON_VENV_NAME=venv

# autoupdate
UPDATE_ZSH_DAYS=14

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=245"
