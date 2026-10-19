# Managed By
#   This file is managed by ~/.dotfiles and linked to ~/.zprofile.
#
# Loaded As
#   Login-shell startup for zsh sessions such as `zsh -l`.
#
# Local Overrides
#   Put machine-local login-shell lines in:
#     ~/.config/dotfiles/profile.zsh
#
# Examples:
#     source ~/.orbstack/shell/init.zsh 2>/dev/null || :
#
# Notes
#   Restore toolchain paths after system login profiles reorder PATH. Keep prompt,
#   aliases, completions, and other interactive behavior in ~/.zshrc or
#   ~/.config/dotfiles/local.zsh instead.

typeset -g _dotfiles_zprofile_path="${${(%):-%N}:A}"
export DOTFILES="${DOTFILES:-${DOTFILES_ROOT:-${_dotfiles_zprofile_path:h:h}}}"

if [[ "${DOTFILES_BOOTSTRAP_LOADED:-0}" != "1" && -f "$DOTFILES/zsh/lib/bootstrap.zsh" ]]; then
  source "$DOTFILES/zsh/lib/bootstrap.zsh"
fi

# /etc/zprofile (including macOS path_helper) runs after ~/.zshenv.
typeset -ga _dotfiles_login_paths
_dotfiles_login_paths=("${(@s.:.)DOTFILES_BOOTSTRAP_PATH}")
for _dotfiles_login_path in "${(@Oa)_dotfiles_login_paths}"; do
  dotfiles_prepend_path "$_dotfiles_login_path"
done
unset _dotfiles_login_paths _dotfiles_login_path

dotfiles_source_if_exists "$DOTFILES_PROFILE_ZSH"

unset _dotfiles_zprofile_path
