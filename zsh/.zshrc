# Shared dotfiles shell entrypoint.

typeset -g _dotfiles_rc_path="${${(%):-%N}:A}"
typeset -g _dotfiles_zsh_root=""
export DOTFILES="${DOTFILES:-${DOTFILES_ROOT:-${_dotfiles_rc_path:h:h}}}"
export PATH="$DOTFILES/cmd:$PATH"

export DOTFILES_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
export DOTFILES_INSTALL_ENV="$DOTFILES_CONFIG_DIR/install.env"
export DOTFILES_LOCAL_ZSH="$DOTFILES_CONFIG_DIR/local.zsh"

export HISTSIZE=999999999
export SAVEHIST=$HISTSIZE
export HIST_STAMPS=yyyy-mm-dd
export PROMPT_EOL_MARK=

_dotfiles_zsh_root="$DOTFILES/zsh"

source "$_dotfiles_zsh_root/lib/helpers.zsh"
dotfiles_load_install_env
dotfiles_detect_platform
dotfiles_configure_oh_my_zsh

if [[ -z "${LANG:-}" ]]; then
  if [[ "$DOTFILES_PLATFORM" == "macos" ]]; then
    export LANG="en_US.UTF-8"
  else
    export LANG="C.UTF-8"
  fi
fi

if [[ -z "${LC_ALL:-}" ]]; then
  export LC_ALL="$LANG"
fi

source "$_dotfiles_zsh_root/theme.zsh"
dotfiles_configure_theme
source "$_dotfiles_zsh_root/env.zsh"
source "$_dotfiles_zsh_root/plugin.zsh"

if [[ "${DOTFILES_ENABLE_OH_MY_ZSH:-0}" != "0" && -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

dotfiles_source_custom_plugins

source "$_dotfiles_zsh_root/alias.zsh"
dotfiles_init_theme

[[ -f "$DOTFILES_LOCAL_ZSH" ]] && source "$DOTFILES_LOCAL_ZSH"

unset _dotfiles_zsh_root _dotfiles_rc_path
