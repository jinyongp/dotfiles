# ============================= #
# author: jinyongp              #
# email: dev.jinyongp@gmail.com #
# ============================= #

export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
export DOTFILES="$HOME/.dotfiles"

setopt PROMPT_CR
unsetopt PROMPT_SP

HIST_STAMPS="yyyy-mm-dd"
PROMPT_EOL_MARK=

CWD="$DOTFILES/zsh"

source $CWD/themes/powerlevel10k.zsh
# source $CWD/themes/spaceship.zsh

source $CWD/plugin.zsh
source $CWD/utility.zsh

source $ZSH/oh-my-zsh.sh

source $CWD/alias.zsh
source $CWD/env.zsh

[ -f $CWD/private.zsh ] && source $CWD/private.zsh
