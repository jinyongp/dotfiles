plugins=(
  gh
  git
  fnm
  orb
  rust
  python
  direnv
  vundle
  copyfile
  copypath
  gitignore
  alias-tips
  autoupdate
  zsh-completions
  zsh-autosuggestions
  fast-syntax-highlighting
  zsh-better-npm-completion
)

# pyenv
ZSH_PYENV_QUIET=true

# python
PYTHON_AUTO_VRUN=true
PYTHON_VENV_NAME=.venv

# autoupdate
UPDATE_ZSH_DAYS=14

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=245"

custom_plugins_dir="$DOTFILES/zsh/plugins"
for plugin_dir in $custom_plugins_dir/*(/); do
  plugin=$(basename $plugin_dir)
  plugin_files=($plugin_dir/*.plugin.zsh(N))

  for plugin_file in $plugin_files; do
    if [[ $(basename "$plugin_file") == -* ]]; then
      continue
    fi

    source $plugin_file
  done
done
