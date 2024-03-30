# ============================= #
# author: jinyongp              #
# email: dev.jinyongp@gmail.com #
# github: github.com/jinyongp   #
# ============================= #

export ZSH="$HOME/.oh-my-zsh"
export ZSH_CACHE_DIR="$ZSH/cache"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
export DOTFILES="$HOME/.dotfiles"

zsh=$DOTFILES/zsh

source $zsh/themes/powerlevel10k.zsh
# source $zsh/themes/spaceship.zsh

source $zsh/plugin.zsh
source $zsh/utility.zsh

source $ZSH/oh-my-zsh.sh

source $zsh/alias.zsh
source $zsh/env.zsh

[ -f $zsh/private.zsh ] && source $zsh/private.zsh

unset zsh
