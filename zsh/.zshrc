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

zsh_files=(
  .zshrc_theme
  .zshrc_plugin
  .zshrc_utils
  .zshrc_alias
  .zshrc_env
)

for file in ${zsh_files[*]}; do
  [[ -f "$HOME/$file" ]] && source "$HOME/$file" || echo "$file not found"
done

source $ZSH/oh-my-zsh.sh
