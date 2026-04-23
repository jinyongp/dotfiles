# Source installer dependencies and focused install libraries in dependency order.

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
