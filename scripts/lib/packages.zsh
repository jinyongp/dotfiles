#!/bin/zsh

typeset -gA DOTFILES_BREW_FORMULAE=(
  [curl]="curl"
  [diff-so-fancy]="diff-so-fancy"
  [eza]="eza"
  [fd]="fd"
  [fnm]="fnm"
  [gh]="gh"
  [git]="git"
  [gnupg]="gnupg"
  [jq]="jq"
  [starship]="starship"
  [tldr]="tlrc"
  [unzip]="unzip"
  [vim]="vim"
  [zsh]="zsh"
)

typeset -gA DOTFILES_APT_PACKAGES=(
  [curl]="curl"
  [diff-so-fancy]="diff-so-fancy"
  [eza]="eza"
  [fd]="fd-find"
  [gh]="gh"
  [git]="git"
  [gnupg]="gnupg"
  [jq]="jq"
  [starship]="starship"
  [tldr]="tealdeer"
  [unzip]="unzip"
  [vim]="vim"
  [zsh]="zsh"
)

typeset -gA DOTFILES_BREW_CASKS=(
  [arc]="arc"
  [font-fira-code-nerd-font]="font-fira-code-nerd-font"
  [font-victor-mono-nerd-font]="font-victor-mono-nerd-font"
  [iterm2]="iterm2"
  [karabiner-elements]="karabiner-elements"
  [keka]="keka"
  [kekaexternalhelper]="kekaexternalhelper"
  [raycast]="raycast"
  [visual-studio-code]="visual-studio-code"
)

typeset -gi DOTFILES_APT_READY=0
typeset -gi DOTFILES_BREW_READY=0

package_manager::brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
    return 0
  fi

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    echo /home/linuxbrew/.linuxbrew/bin/brew
    return 0
  fi

  if [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    echo "$HOME/.linuxbrew/bin/brew"
    return 0
  fi

  return 1
}

package_manager::activate_brew() {
  local brew_bin
  brew_bin="$(package_manager::brew_bin)"
  eval "$("$brew_bin" shellenv)"
}

package_manager::ensure_brew() {
  local installer_url installer_path

  if (( DOTFILES_BREW_READY == 1 )); then
    return 0
  fi

  if package_manager::brew_bin >/dev/null 2>&1; then
    package_manager::activate_brew
    DOTFILES_BREW_READY=1
    dotfiles::record_reused "Homebrew package manager"
    return 0
  fi

  dotfiles::log_step "Installing Homebrew"

  installer_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  installer_path="$(mktemp)"

  dotfiles::download_script "$installer_url" "$installer_path"
  /bin/bash "$installer_path"
  rm -f "$installer_path"

  package_manager::activate_brew
  DOTFILES_BREW_READY=1
  dotfiles::record_installed "Homebrew package manager"
}

package_manager::ensure_apt() {
  if (( DOTFILES_APT_READY == 1 )); then
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    dotfiles::log_error "apt-get is not available on this system."
    return 1
  fi

  dotfiles::log_step "Refreshing apt package index"
  dotfiles::run_as_root apt-get update
  DOTFILES_APT_READY=1
  dotfiles::record_completed_work "Refreshed apt package index"
}

package_manager::prepend_path() {
  local path_entry="$1"

  [[ -d "$path_entry" ]] || return 0

  case ":$PATH:" in
    *":$path_entry:"*) ;;
    *) export PATH="$path_entry:$PATH" ;;
  esac
}

package_manager::recipe_key() {
  print -r -- "${1//-/_}"
}

package_manager::recipe_install_function() {
  print -r -- "package_recipe::$(package_manager::recipe_key "$1")_install"
}

package_manager::has_recipe_install() {
  typeset -f "$(package_manager::recipe_install_function "$1")" >/dev/null 2>&1
}

package_manager::install_via_recipe() {
  local logical_name="$1"
  local required="${2:-0}"
  local install_function

  install_function="$(package_manager::recipe_install_function "$logical_name")"
  "$install_function" "$logical_name" "$required"
}

package_manager::logical_to_native() {
  local logical_name="$1"

  case "$DOTFILES_PACKAGE_MANAGER" in
    brew) echo "${DOTFILES_BREW_FORMULAE[$logical_name]:-}" ;;
    apt) echo "${DOTFILES_APT_PACKAGES[$logical_name]:-}" ;;
    *)
      dotfiles::log_error "Unsupported package manager: $DOTFILES_PACKAGE_MANAGER"
      return 1
      ;;
  esac
}

package_manager::ensure_command() {
  local logical_name="$1"
  local command_name="${2:-$logical_name}"
  local required="${3:-1}"

  if command -v "$command_name" >/dev/null 2>&1; then
    dotfiles::record_reused "$command_name command"
    dotfiles::log_info "Using existing $command_name command."
    return 0
  fi

  package_manager::install_logical "$logical_name" "$required"
}

package_manager::install_native_logical() {
  local logical_name="$1"
  local required="${2:-0}"
  local native_name=""

  native_name="$(package_manager::logical_to_native "$logical_name")"

  if [[ -z "$native_name" ]]; then
    if [[ "$required" == "1" ]]; then
      dotfiles::log_error "No package mapping exists for $logical_name on $DOTFILES_PACKAGE_MANAGER."
      return 1
    fi

    dotfiles::log_warn "Skipping $logical_name because it is not mapped for $DOTFILES_PACKAGE_MANAGER."
    return 0
  fi

  case "$DOTFILES_PACKAGE_MANAGER" in
    brew)
      package_manager::ensure_brew

      if brew list "$native_name" >/dev/null 2>&1; then
        dotfiles::record_reused "$logical_name via Homebrew"
        dotfiles::log_info "Already installed: $logical_name"
      else
        dotfiles::record_installed "$logical_name via Homebrew"
        dotfiles::log_info "Installing $logical_name with Homebrew..."
        brew install "$native_name"
      fi
      ;;
    apt)
      package_manager::ensure_apt

      if dpkg -s "$native_name" >/dev/null 2>&1; then
        dotfiles::record_reused "$logical_name via apt"
        dotfiles::log_info "Already installed: $logical_name"
        return 0
      fi

      if ! apt-cache show "$native_name" >/dev/null 2>&1; then
        if [[ "$required" == "1" ]]; then
          dotfiles::log_error "Package $native_name is not available from apt."
          return 1
        fi

        dotfiles::log_warn "Skipping $logical_name because apt cannot find $native_name."
        return 0
      fi

      dotfiles::record_installed "$logical_name via apt"
      dotfiles::log_info "Installing $logical_name with apt..."
      dotfiles::run_as_root apt-get install -y "$native_name"
      ;;
  esac
}

package_manager::install_logical() {
  local logical_name="$1"
  local required="${2:-0}"

  if package_manager::has_recipe_install "$logical_name"; then
    package_manager::install_via_recipe "$logical_name" "$required"
    return $?
  fi

  package_manager::install_native_logical "$logical_name" "$required"
}

package_manager::install_brew_cask() {
  local cask_key="$1"
  local cask_name="${DOTFILES_BREW_CASKS[$cask_key]:-}"

  if [[ -z "$cask_name" ]]; then
    dotfiles::log_error "No cask mapping exists for $cask_key."
    return 1
  fi

  package_manager::ensure_brew

  if [[ "$cask_name" == font-* ]]; then
    brew tap homebrew/cask-fonts >/dev/null 2>&1 || true
  fi

  if brew list --cask "$cask_name" >/dev/null 2>&1; then
    dotfiles::record_reused "$cask_name cask"
    dotfiles::log_info "Already installed: $cask_name"
    return 0
  fi

  dotfiles::record_installed "$cask_name cask"
  dotfiles::log_info "Installing $cask_name..."
  brew install --cask "$cask_name"
}

package_manager::load_recipes() {
  local recipe_dir="$DOTFILES_ROOT/scripts/lib/recipes"
  local recipe_file

  [[ -d "$recipe_dir" ]] || return 0

  for recipe_file in "$recipe_dir"/*.zsh(N); do
    source "$recipe_file"
  done
}

package_manager::load_recipes
