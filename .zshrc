# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# ============================= #
# author: jinyongp              #
# email: dev.jinyongp@gmail.com #
# ============================= #

export ZSH="$HOME/.oh-my-zsh"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ohmyzsh"

HIST_STAMPS="yyyy-mm-dd"

# Theme

ZSH_THEME="powerlevel10k/powerlevel10k"

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
POWERLEVEL9K_MODE='nerdfont-complete' # 'FiraCode Nerd Font'

POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
POWERLEVEL9K_PROMPT_ADD_NEWLINE_COUNT=1 # POWERLEVEL9K_PROMPT_ADD_NEWLINE ? (default: 1) : pass
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=''
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=$'  '
POWERLEVEL9K_INSTANT_PROMPT_COMMAND_LINES=0

# LEFT PROMPT
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(root_indicator dir virtualenv anaconda)
POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
# POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=''
POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR='%F{008}%F{008}'

# RIGHT PROMPT
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(dir_writable vcs time status)
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''
POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR='%F{008}%F{008}'

POWERLEVEL9K_SHORTEN_DELIMITER='%F{007}…%F{007}'
#POWERLEVEL9K_SHORTEN_DIR_LENGTH=1024
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_with_package_name"

POWERLEVEL9K_DIR_PACKAGE_FILES=(package.json)
POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER=true

POWERLEVEL9K_TIME_FORMAT="%D{%b %d \'%y    %H:%M:%S }"
POWERLEVEL9K_TIME_ICON=''

# VSC
POWERLEVEL9K_HIDE_BRANCH_ICON=false
POWERLEVEL9K_SHOW_CHANGESET=true
POWERLEVEL9K_CHANGESET_HASH_LENGTH=4

# VIRTUAL ENV
POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES=(virtualenv venv .venv env)
POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER='\b'
POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER=''

# ANACONDA
POWERLEVEL9K_ANACONDA_SHOW_PYTHON_VERSION=false
POWERLEVEL9K_ANACONDA_LEFT_DELIMITER='\b'
POWERLEVEL9K_ANACONDA_RIGHT_DELIMITER=''

# ICON
POWERLEVEL9K_HOME_ICON=""
POWERLEVEL9K_ETC_ICON=''

POWERLEVEL9K_OS_ICON_BACKGROUND='none'
POWERLEVEL9K_OS_ICON_FOREGROUND='cyan'

POWERLEVEL9K_CARRIAGE_RETURN_ICON=""

# ICON(VCS)
#POWERLEVEL9K_VCS_GIT_ICON=''
#POWERLEVEL9K_VCS_BRANCH_ICON=$''
#POWERLEVEL9K_VCS_COMMIT_ICON="ﰖ"

# COLOR
POWERLEVEL9K_DIR_BACKGROUND='none'
POWERLEVEL9K_DIR_FOREGROUND='250'
POWERLEVEL9K_DIR_HOME_BACKGROUND="none"
POWERLEVEL9K_DIR_HOME_FOREGROUND="250"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND="none"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND="250"
POWERLEVEL9K_DIR_PATH_SEPARATOR_FOREGROUND='007'

POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_BACKGROUND="none"
POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_FOREGROUND="red"

POWERLEVEL9K_STATUS_ERROR_BACKGROUND="none"
POWERLEVEL9K_STATUS_ERROR_FOREGROUND="001"
POWERLEVEL9K_STATUS_OK_BACKGROUND="none"
POWERLEVEL9K_STATUS_BACKGROUND="none"

POWERLEVEL9K_TIME_BACKGROUND='none'
POWERLEVEL9K_TIME_FOREGROUND='250'

POWERLEVEL9K_VIRTUALENV_BACKGROUND='none'
POWERLEVEL9K_VIRTUALENV_FOREGROUND='149'
POWERLEVEL9K_ANACONDA_BACKGROUND='none'
POWERLEVEL9K_ANACONDA_FOREGROUND='149'

# COLOR(VCS)
POWERLEVEL9K_VCS_CLEAN_BACKGROUND='none'
POWERLEVEL9K_VCS_CLEAN_FOREGROUND='040'
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='none'
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='009'
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='none'
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='190'

# Plugin

plugins=(
  git
  vundle
  copyfile
  copypath
  virtualenv
  alias-tips
  zsh-autosuggestions
  zsh-completions
  zsh-syntax-highlighting
  git-flow-completion
  zsh-better-npm-completion
)

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'

setopt PROMPT_CR
unsetopt PROMPT_SP
PROMPT_EOL_MARK=

# Source

source $ZSH/oh-my-zsh.sh

[[ -f $HOME/.zshrc_alias ]] && source $HOME/.zshrc_alias || echo "~/.zshrc_alias not found"
[[ -f $HOME/.zshrc_env ]] && source $HOME/.zshrc_env || echo "~/.zshrc_env not found"
[[ -f $HOME/.zshrc_com ]] && source $HOME/.zshrc_com

# direnv
eval "$(direnv hook zsh)"
