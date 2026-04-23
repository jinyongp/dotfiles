# Managed By
#   This file is managed by ~/.dotfiles and linked to ~/.zshenv.
#
# Loaded As
#   Universal zsh startup for every zsh process, including non-interactive
#   commands such as `zsh -c` and `zsh <script>`.
#
# Local Overrides
#   Put machine-local universal environment lines in:
#     ~/.config/dotfiles/env.zsh
#
# Examples:
#     . "$HOME/.cargo/env"
#
# Notes
#   Keep this path silent and non-interactive. Do not add aliases, prompts,
#   completions, oh-my-zsh setup, or commands that print output.

typeset -g _dotfiles_zshenv_path="${${(%):-%N}:A}"
export DOTFILES="${DOTFILES:-${DOTFILES_ROOT:-${_dotfiles_zshenv_path:h:h}}}"

if [[ -f "$DOTFILES/zsh/lib/bootstrap.zsh" ]]; then
  source "$DOTFILES/zsh/lib/bootstrap.zsh"
fi

unset _dotfiles_zshenv_path
