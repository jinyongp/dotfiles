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

if [[ -f $HOME/.zshrc_theme ]]; then source $HOME/.zshrc_theme else echo "~/.zshrc_theme not found"; fi
if [[ -f $HOME/.zshrc_plugin ]]; then source $HOME/.zshrc_plugin else echo "~/.zshrc_plugin not found"; fi
if [[ -f $HOME/.zshrc_utils ]]; then source $HOME/.zshrc_utils else echo "~/.zshrc_utils not found"; fi

source $ZSH/oh-my-zsh.sh

if [[ -f $HOME/.zshrc_alias ]]; then source $HOME/.zshrc_alias else echo "~/.zshrc_alias not found"; fi
if [[ -f $HOME/.zshrc_env ]]; then source $HOME/.zshrc_env else echo "~/.zshrc_env not found"; fi
