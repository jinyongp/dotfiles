plugins=(
  git
  python
  vundle
  copyfile
  copypath
  gitignore
  alias-tips
  autoupdate
  zsh-completions
  zsh-autosuggestions
  fast-syntax-highlighting
)

typeset -A plugin_map=(
  gh gh
  fnm fnm
  rust rustc
  vundle vundle
  direnv direnv
)

for plugin command in ${(kv)plugin_map}; do
  if (( $+commands[$command] )); then
    plugins+=($plugin)
  fi
done

third_party_plugins=(
  orb
  alias-tips
  autoupdate
  zsh-completions
  zsh-autosuggestions
  fast-syntax-highlighting
  zsh-better-npm-completion
)

third_party_plugins_dir="$ZSH_CUSTOM/plugins"
for plugin in $third_party_plugins; do
  if [[ -d $third_party_plugins_dir/$plugin ]]; then
    plugins+=($plugin)
  fi
done

# python
PYTHON_AUTO_VRUN=true
PYTHON_VENV_NAME=.venv
PYTHON_VENV_NAMES=($PYTHON_VENV_NAME venv)

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
