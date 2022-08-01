# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# ============================= #
# author: jinyongp              #
# email: dev.jinyongp@gmail.com #
# ============================= #

export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"

setopt PROMPT_CR
unsetopt PROMPT_SP

HIST_STAMPS="yyyy-mm-dd"
PROMPT_EOL_MARK=

[[ -f $HOME/.zshrc_theme ]] && source $HOME/.zshrc_theme || echo "~/.zshrc_theme not found"
[[ -f $HOME/.zshrc_plugin ]] && source $HOME/.zshrc_plugin || echo "~/.zshrc_plugin not found"
[[ -f $HOME/./zshrc_utils ]] && source $HOME/./zshrc_utils || echo "~/.zshrc_utils not found"

source $ZSH/oh-my-zsh.sh

[[ -f $HOME/.zshrc_alias ]] && source $HOME/.zshrc_alias || echo "~/.zshrc_alias not found"
[[ -f $HOME/.zshrc_env ]] && source $HOME/.zshrc_env || echo "~/.zshrc_env not found"
