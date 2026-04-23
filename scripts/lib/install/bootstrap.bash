# Source installer dependencies and focused install libraries in dependency order.

source "$DOTFILES_ROOT/scripts/lib/runtime-shared.zsh"

export DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-$(dotfiles::config_dir)}"
export DOTFILES_INSTALL_ENV="${DOTFILES_INSTALL_ENV:-$(dotfiles::install_env_path)}"
export DOTFILES_ENV_ZSH="${DOTFILES_ENV_ZSH:-$(dotfiles::env_zsh_path)}"
export DOTFILES_PROFILE_ZSH="${DOTFILES_PROFILE_ZSH:-$(dotfiles::profile_zsh_path)}"
export DOTFILES_LOCAL_ZSH="${DOTFILES_LOCAL_ZSH:-$(dotfiles::local_zsh_path)}"

source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/prompt.bash"
source "$DOTFILES_ROOT/scripts/lib/catalog.sh"
source "$DOTFILES_ROOT/scripts/lib/git-config.sh"

source "$DOTFILES_ROOT/scripts/lib/install/state.bash"
source "$DOTFILES_ROOT/scripts/lib/install/runtime.bash"
source "$DOTFILES_ROOT/scripts/lib/install/plan.bash"
source "$DOTFILES_ROOT/scripts/lib/install/status.bash"
source "$DOTFILES_ROOT/scripts/lib/install/interactive.bash"
source "$DOTFILES_ROOT/scripts/lib/install/runner.bash"
source "$DOTFILES_ROOT/scripts/lib/install/direct.bash"
source "$DOTFILES_ROOT/scripts/lib/install/main.bash"
