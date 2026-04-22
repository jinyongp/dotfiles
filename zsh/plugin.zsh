plugins=(
  git
  python
  gitignore
)

if [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
  plugins+=(copyfile copypath)
fi

if dotfiles_has_command vundle; then
  plugins+=(vundle)
fi

typeset -A plugin_map=(
  gh gh
  fnm fnm
  rust rustc
  direnv direnv
)

for plugin command in ${(kv)plugin_map}; do
  if dotfiles_has_command "$command"; then
    plugins+=($plugin)
  fi
done

third_party_plugins=(
  alias-tips
  autoupdate
  zsh-completions
  zsh-autosuggestions
  fast-syntax-highlighting
  zsh-better-npm-completion
)

third_party_plugins_dir="$ZSH_CUSTOM/plugins"
if [[ "${DOTFILES_ENABLE_OH_MY_ZSH:-0}" != "0" ]]; then
  for plugin in $third_party_plugins; do
    if [[ -d $third_party_plugins_dir/$plugin ]]; then
      plugins+=($plugin)
    fi
  done
fi

# python
PYTHON_AUTO_VRUN=true
PYTHON_VENV_NAME=.venv
PYTHON_VENV_NAMES=($PYTHON_VENV_NAME venv)

# autoupdate
UPDATE_ZSH_DAYS=14

# zsh-autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=245"

custom_plugins_dir="$DOTFILES/zsh/plugins"
dotfiles_source_custom_plugins() {
  local plugin_dir plugin_file
  local -a plugin_files

  for plugin_dir in $custom_plugins_dir/*(/N); do
    plugin_files=($plugin_dir/*.plugin.zsh(N))

    for plugin_file in $plugin_files; do
      if [[ $(basename "$plugin_file") == -* ]]; then
        continue
      fi

      source "$plugin_file"
    done
  done
}
