#!/bin/zsh

set -euo pipefail

DOTFILES_ROOT="${0:A:h:h}"

source "$DOTFILES_ROOT/utils/colors.zsh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/platform.zsh"
source "$DOTFILES_ROOT/scripts/lib/prompt.zsh"
source "$DOTFILES_ROOT/scripts/lib/packages.zsh"
source "$DOTFILES_ROOT/scripts/modules/packages.zsh"
source "$DOTFILES_ROOT/scripts/modules/dotfiles.zsh"
source "$DOTFILES_ROOT/scripts/modules/shell.zsh"
source "$DOTFILES_ROOT/scripts/modules/vim.zsh"
source "$DOTFILES_ROOT/scripts/modules/macos.zsh"

typeset -ga DOTFILES_MODULE_ORDER=(
  packages
  dotfiles
  oh_my_zsh
  theme
  vim
  fonts
  desktop_apps
  macos_defaults
)

typeset -gA DOTFILES_MODULE_LABELS=(
  [packages]="Base CLI packages"
  [dotfiles]="Dotfiles symlinks"
  [oh_my_zsh]="oh-my-zsh"
  [theme]="Theme dependencies"
  [vim]="Vim and Vundle"
  [fonts]="Fonts"
  [desktop_apps]="Desktop apps"
  [macos_defaults]="macOS defaults"
)

typeset -gA DOTFILES_MODULE_DEFAULTS=(
  [packages]="yes"
  [dotfiles]="yes"
  [oh_my_zsh]="yes"
  [theme]="yes"
  [vim]="yes"
  [fonts]="yes"
  [desktop_apps]="no"
  [macos_defaults]="yes"
)

typeset -gA DOTFILES_SELECTED_MODULES=()

installer::module_function() {
  local module="$1"
  local action="$2"
  echo "module_${module}_${action}"
}

installer::module_supported() {
  local module="$1"
  local function_name
  function_name="$(installer::module_function "$module" "supported")"

  if ! typeset -f "$function_name" >/dev/null 2>&1; then
    return 1
  fi

  "$function_name"
}

installer::module_summary() {
  local module="$1"
  local function_name
  function_name="$(installer::module_function "$module" "summary")"
  "$function_name"
}

installer::module_details() {
  local module="$1"
  local function_name
  function_name="$(installer::module_function "$module" "details")"

  if typeset -f "$function_name" >/dev/null 2>&1; then
    "$function_name"
  fi
}

installer::run_module() {
  local module="$1"
  local function_name
  function_name="$(installer::module_function "$module" "install")"
  "$function_name"
}

installer::print_environment() {
  echo
  echo "$(b_green Dotfiles Installer)"
  echo "Environment: $(cyan "$DOTFILES_PLATFORM_LABEL")"
  echo "This installer will ask what to install, explain each module, then save the chosen shell settings to ~/.config/dotfiles/install.env."

  if platform::is_wsl; then
    echo "Distribution: ${WSL_DISTRO_NAME:-unknown}"
  fi

  if platform::is_linux && ! platform::is_wsl; then
    echo "$(yellow Experimental Linux support is enabled. WSL Ubuntu/Debian is the primary target.)"
  fi
}

installer::configure_package_manager() {
  if platform::is_macos; then
    DOTFILES_PACKAGE_MANAGER="brew"
    return 0
  fi

  if platform::is_wsl; then
    DOTFILES_PACKAGE_MANAGER="$(prompt::choose_one_described \
      "Select a package manager for WSL." \
      1 \
      "apt::Uses Ubuntu/Debian packages with sudo apt-get update/install. This is the recommended path for WSL." \
      "brew::Installs Homebrew on Linux and then uses brew install. Choose this if you want package names and tooling closer to macOS.")"
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    DOTFILES_PACKAGE_MANAGER="apt"
  else
    DOTFILES_PACKAGE_MANAGER="brew"
  fi
}

installer::prompt_modules() {
  local module
  local details

  echo
  echo "$(green Select installation modules.)"

  for module in "${DOTFILES_MODULE_ORDER[@]}"; do
    if ! installer::module_supported "$module"; then
      DOTFILES_SELECTED_MODULES[$module]="no"
      continue
    fi

    details=("${(@f)$(installer::module_details "$module")}")

    if prompt::yes_no \
      "Install ${DOTFILES_MODULE_LABELS[$module]}?" \
      "${DOTFILES_MODULE_DEFAULTS[$module]}" \
      "${details[@]}"; then
      DOTFILES_SELECTED_MODULES[$module]="yes"
    else
      DOTFILES_SELECTED_MODULES[$module]="no"
    fi
  done
}

installer::prompt_theme() {
  echo
  DOTFILES_THEME="$(prompt::choose_one_described \
    "Select a shell theme." \
    1 \
    "starship::Installs and enables Starship. Cross-platform and the easiest option to keep consistent on macOS and WSL." \
    "powerlevel10k::Uses oh-my-zsh plus the powerlevel10k theme repository. Best if you want a classic zsh theme stack." \
    "default::Uses oh-my-zsh's built-in robbyrussell theme. No extra theme repository is cloned." \
    "none::Does not enable a prompt theme. Leaves the shell prompt mostly plain.")"
}

installer::normalize_configuration() {
  if [[ "$DOTFILES_THEME" == "powerlevel10k" || "$DOTFILES_THEME" == "default" ]]; then
    if [[ "${DOTFILES_SELECTED_MODULES[oh_my_zsh]:-no}" != "yes" && ! -d "$HOME/.oh-my-zsh" ]]; then
      DOTFILES_SELECTED_MODULES[oh_my_zsh]="yes"
      echo
      echo "$(yellow Enabled oh-my-zsh automatically because the selected theme requires it.)"
    fi
  fi

  case "$DOTFILES_THEME" in
    starship)
      if [[ "${DOTFILES_SELECTED_MODULES[theme]:-no}" != "yes" ]] && ! command -v starship >/dev/null 2>&1; then
        DOTFILES_SELECTED_MODULES[theme]="yes"
      fi
      ;;
    powerlevel10k)
      if [[ "${DOTFILES_SELECTED_MODULES[theme]:-no}" != "yes" && ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
        DOTFILES_SELECTED_MODULES[theme]="yes"
      fi
      ;;
  esac

  if [[ "${DOTFILES_SELECTED_MODULES[oh_my_zsh]:-no}" == "yes" || -d "$HOME/.oh-my-zsh" ]]; then
    DOTFILES_ENABLE_OH_MY_ZSH="1"
  else
    DOTFILES_ENABLE_OH_MY_ZSH="0"
  fi
}

installer::print_plan() {
  local module

  echo
  echo "$(green Planned configuration)"
  echo "  Platform:        $DOTFILES_PLATFORM_LABEL"
  echo "  Package manager: $DOTFILES_PACKAGE_MANAGER"
  echo "  Theme:           $DOTFILES_THEME"
  echo "  oh-my-zsh:       $([[ "$DOTFILES_ENABLE_OH_MY_ZSH" == "1" ]] && echo enabled || echo disabled)"
  echo "  Modules:"

  for module in "${DOTFILES_MODULE_ORDER[@]}"; do
    if [[ "${DOTFILES_SELECTED_MODULES[$module]:-no}" != "yes" ]]; then
      continue
    fi

    echo "    - $(installer::module_summary "$module")"
  done
}

installer::run_selected_modules() {
  local module

  for module in "${DOTFILES_MODULE_ORDER[@]}"; do
    if [[ "${DOTFILES_SELECTED_MODULES[$module]:-no}" != "yes" ]]; then
      continue
    fi

    installer::run_module "$module"
  done
}

main() {
  dotfiles::require_tty
  platform::detect
  installer::print_environment
  installer::configure_package_manager
  installer::prompt_modules
  installer::prompt_theme
  installer::normalize_configuration
  installer::print_plan

  if ! prompt::yes_no "Proceed with installation?" "yes"; then
    echo
    echo "$(yellow Installation canceled.)"
    exit 0
  fi

  dotfiles::write_install_env
  installer::run_selected_modules

  echo
  echo "$(b_green Installation complete.)"
}

main "$@"
