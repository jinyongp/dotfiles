ZSH_THEME="powerlevel10k/powerlevel10k"

# _instant_prompt="${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh"
# [[ -r $_instant_prompt ]] && {
#   POWERLEVEL9K_INSTANT_PROMPT=quiet
#   source $_instant_prompt
# }

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
POWERLEVEL9K_DISABLE_HOT_RELOAD=true
POWERLEVEL9K_MODE="nerdfont-complete"

function p10k-on-pre-prompt() {
  p10k display empty_line=show
}

POWERLEVEL9K_TRANSIENT_PROMPT=always # "always" "same-dir" "off"
POWERLEVEL9K_PROMPT_ON_NEWLINE=true

POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_FOREGROUND="250"
POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND="250"
POWERLEVEL9K_PROMPT_CHAR_OK_VIINS_CONTENT_EXPANSION="󰄾"
POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_CONTENT_EXPANSION="󰄾"

POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
POWERLEVEL9K_PROMPT_ADD_NEWLINE_COUNT=1
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=""
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=" 󰄾 "
POWERLEVEL9K_INSTANT_PROMPT_COMMAND_LINES=0
POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=true

# LEFT PROMPT
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(root_indicator dir virtualenv anaconda)
POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=""
POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR="%F{008}%F{008}"

# RIGHT PROMPT
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(dir_writable nodeenv nodenv vcs time status)
POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=""
POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR="%F{008}%F{008}"

POWERLEVEL9K_SHORTEN_DELIMITER="%F{007}…%F{007}"
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_to_last" # truncate_{absolute_chars|middle|from_right|absolute|to_last|to_first_and_last|to_unique|with_package_name|with_folder_marker}

POWERLEVEL9K_DIR_PACKAGE_FILES=(package.json)
POWERLEVEL9K_DIR_OMIT_FIRST_CHARACTER=true

# POWERLEVEL9K_TIME_FORMAT="%D{%b %d \'%y    %H:%M:%S 󱦟}"
POWERLEVEL9K_TIME_ICON=""

# VSC
POWERLEVEL9K_HIDE_BRANCH_ICON=false
POWERLEVEL9K_SHOW_CHANGESET=true
POWERLEVEL9K_CHANGESET_HASH_LENGTH=4

POWERLEVEL9K_VCS_LOADING_TEXT=loading
POWERLEVEL9K_VCS_LOADING_PREFIX=

# VIRTUAL ENV
POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
POWERLEVEL9K_VIRTUALENV_GENERIC_NAMES=(virtualenv venv .venv env)
POWERLEVEL9K_VIRTUALENV_LEFT_DELIMITER="\b"
POWERLEVEL9K_VIRTUALENV_RIGHT_DELIMITER=""

# ANACONDA
POWERLEVEL9K_ANACONDA_SHOW_PYTHON_VERSION=false
POWERLEVEL9K_ANACONDA_LEFT_DELIMITER="\b"
POWERLEVEL9K_ANACONDA_RIGHT_DELIMITER=""

# ICON
# POWERLEVEL9K_HOME_ICON=""
# POWERLEVEL9K_HOME_SUB_ICON=""
# POWERLEVEL9K_FOLDER_ICON=""
POWERLEVEL9K_ETC_ICON=""

# POWERLEVEL9K_OS_ICON_BACKGROUND="none"
# POWERLEVEL9K_OS_ICON_FOREGROUND="cyan"

POWERLEVEL9K_CARRIAGE_RETURN_ICON=""

# ICON(VCS)
#POWERLEVEL9K_VCS_GIT_ICON=""
#POWERLEVEL9K_VCS_BRANCH_ICON=""
#POWERLEVEL9K_VCS_COMMIT_ICON="ﰖ"

# COLOR
POWERLEVEL9K_DIR_BACKGROUND="none"
# POWERLEVEL9K_DIR_FOREGROUND="250"
POWERLEVEL9K_DIR_HOME_BACKGROUND="none"
# POWERLEVEL9K_DIR_HOME_FOREGROUND="250"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND="none"
# POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND="250"
POWERLEVEL9K_DIR_PATH_SEPARATOR_FOREGROUND="007"

POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_BACKGROUND="none"
POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_FOREGROUND="red"

POWERLEVEL9K_STATUS_ERROR_BACKGROUND="none"
POWERLEVEL9K_STATUS_ERROR_FOREGROUND="001"
POWERLEVEL9K_STATUS_OK_BACKGROUND="none"
POWERLEVEL9K_STATUS_BACKGROUND="none"

POWERLEVEL9K_TIME_BACKGROUND="none"
# POWERLEVEL9K_TIME_FOREGROUND="250"

POWERLEVEL9K_VIRTUALENV_BACKGROUND="none"
POWERLEVEL9K_VIRTUALENV_FOREGROUND="003"
POWERLEVEL9K_ANACONDA_BACKGROUND="none"
POWERLEVEL9K_ANACONDA_FOREGROUND="003"

# COLOR(VCS)
POWERLEVEL9K_VCS_CLEAN_BACKGROUND="none"
POWERLEVEL9K_VCS_CLEAN_FOREGROUND="002"
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND="none"
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND="001"
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND="none"
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND="208"
POWERLEVEL9K_VCS_LOADING_BACKGROUND="none"
POWERLEVEL9K_VCS_LOADING_FOREGROUND="001"
