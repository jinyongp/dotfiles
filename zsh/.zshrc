# ============================= #
# author: jinyongp              #
# email: dev.jinyongp@gmail.com #
# github: github.com/jinyongp   #
# ============================= #

export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
export DOTFILES="$HOME/.dotfiles"

source $DOTFILES/zsh/themes/powerlevel10k.zsh
# source $DOTFILES/zsh/themes/spaceship.zsh

source $DOTFILES/zsh/plugin.zsh
source $DOTFILES/zsh/utility.zsh

source $ZSH/oh-my-zsh.sh

source $DOTFILES/zsh/alias.zsh
source $DOTFILES/zsh/env.zsh

[ -f $DOTFILES/zsh/private.zsh ] && source $DOTFILES/zsh/private.zsh

unset zsh
