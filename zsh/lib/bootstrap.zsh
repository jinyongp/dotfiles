# Non-interactive-safe dotfiles environment bootstrap.

if [[ "${DOTFILES_BOOTSTRAP_LOADED:-0}" == "1" ]]; then
  return 0
fi

typeset -g _dotfiles_bootstrap_path="${${(%):-%N}:A}"
export DOTFILES="${DOTFILES:-${DOTFILES_ROOT:-${_dotfiles_bootstrap_path:h:h:h}}}"
typeset -g DOTFILES_BOOTSTRAP_LOADED=1

source "$DOTFILES/zsh/lib/helpers.zsh"

dotfiles_prepend_path "$DOTFILES/cmd"
dotfiles_load_install_env
dotfiles_detect_platform || true
dotfiles_configure_base_toolchain
dotfiles_source_if_exists "$DOTFILES_ENV_ZSH"

unset _dotfiles_bootstrap_path
