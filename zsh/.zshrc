# Managed By
#   This file is managed by ~/.dotfiles and linked to ~/.zshrc.
#
# Loaded As
#   Interactive zsh startup for terminal sessions.
#
# Local Overrides
#   Put machine-local interactive shell setup in:
#     ~/.config/dotfiles/local.zsh
#
# Notes
#   Universal environment belongs in ~/.config/dotfiles/env.zsh.
#   Login-shell-only setup belongs in ~/.config/dotfiles/profile.zsh.

typeset -g _dotfiles_rc_path="${${(%):-%N}:A}"
typeset -g _dotfiles_zsh_root=""
export DOTFILES="${DOTFILES:-${DOTFILES_ROOT:-${_dotfiles_rc_path:h:h}}}"

if [[ "${DOTFILES_BOOTSTRAP_LOADED:-0}" != "1" && -f "$DOTFILES/zsh/lib/bootstrap.zsh" ]]; then
  source "$DOTFILES/zsh/lib/bootstrap.zsh"
fi

export HISTSIZE=999999999
export SAVEHIST=$HISTSIZE
export HIST_STAMPS=yyyy-mm-dd
export PROMPT_EOL_MARK=

_dotfiles_zsh_root="$DOTFILES/zsh"

dotfiles_configure_state_home
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

if dotfiles_has_terminal_ui && [[ "${DOTFILES_ENABLE_OH_MY_ZSH:-0}" != "0" && -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi

dotfiles_source_custom_plugins

source "$_dotfiles_zsh_root/alias.zsh"
dotfiles_init_theme

[[ -f "$DOTFILES_LOCAL_ZSH" ]] && source "$DOTFILES_LOCAL_ZSH"

unset _dotfiles_zsh_root _dotfiles_rc_path
