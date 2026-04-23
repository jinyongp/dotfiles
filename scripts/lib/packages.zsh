#!/bin/zsh

typeset -gi DOTFILES_APT_READY=0
typeset -gi DOTFILES_BREW_READY=0

package_manager::brew_bin() {
  dotfiles::brew_bin_path
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

  dotfiles::execution_record_event installing "Homebrew package manager"
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

  dotfiles::execution_record_event installing "apt package index"
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

package_manager::npm_global_prefix() {
  if [[ -n "${XDG_DATA_HOME:-}" ]]; then
    print -r -- "$XDG_DATA_HOME/npm-global"
    return 0
  fi

  case "$DOTFILES_PLATFORM" in
    macos) print -r -- "$HOME/Library/Application Support/npm-global" ;;
    *) print -r -- "$HOME/.local/share/npm-global" ;;
  esac
}

package_manager::npm_global_bin_dir() {
  print -r -- "$(package_manager::npm_global_prefix)/bin"
}

package_manager::npm_global_package_installed() {
  local package_name="$1"
  local prefix

  prefix="$(package_manager::npm_global_prefix)"
  NPM_CONFIG_PREFIX="$prefix" npm list --global --depth=0 "$package_name" >/dev/null 2>&1
}

package_manager::install_npm_global() {
  local package_name="$1"
  local install_spec="${2:-$1}"
  local prefix

  prefix="$(package_manager::npm_global_prefix)"
  package_manager::prepend_path "$(package_manager::npm_global_bin_dir)"
  dotfiles::ensure_dir "$prefix"

  if package_manager::npm_global_package_installed "$package_name"; then
    dotfiles::record_reused "$package_name via npm"
    dotfiles::log_info "Already installed: $package_name"
    return 0
  fi

  dotfiles::execution_record_event installing "$package_name via npm"
  dotfiles::log_info "Installing $package_name with npm..."
  NPM_CONFIG_PREFIX="$prefix" npm install --global "$install_spec"
  dotfiles::record_installed "$package_name via npm"
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
    brew|apt) catalog::package_native_name "$DOTFILES_PACKAGE_MANAGER" "$logical_name" ;;
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

    dotfiles::record_skipped "$logical_name on $DOTFILES_PACKAGE_MANAGER (no package mapping)"
    dotfiles::log_info "Skipping $logical_name because it is not mapped for $DOTFILES_PACKAGE_MANAGER."
    return 0
  fi

  case "$DOTFILES_PACKAGE_MANAGER" in
    brew)
      package_manager::ensure_brew

      if brew list "$native_name" >/dev/null 2>&1; then
        dotfiles::record_reused "$logical_name via Homebrew"
        dotfiles::log_info "Already installed: $logical_name"
      else
        dotfiles::execution_record_event installing "$logical_name via Homebrew"
        dotfiles::log_info "Installing $logical_name with Homebrew..."
        brew install "$native_name"
        dotfiles::record_installed "$logical_name via Homebrew"
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

        dotfiles::record_skipped "$logical_name on apt (package unavailable)"
        dotfiles::log_info "Skipping $logical_name because apt cannot find $native_name."
        return 0
      fi

      dotfiles::execution_record_event installing "$logical_name via apt"
      dotfiles::log_info "Installing $logical_name with apt..."
      dotfiles::run_as_root apt-get install -y "$native_name"
      dotfiles::record_installed "$logical_name via apt"
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
  local cask_name="$1"

  if [[ -z "$cask_name" ]]; then
    dotfiles::log_error "Missing Homebrew cask name."
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

  dotfiles::execution_record_event installing "$cask_name cask"
  dotfiles::log_info "Installing $cask_name..."
  brew install --cask "$cask_name"
  dotfiles::record_installed "$cask_name cask"
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
