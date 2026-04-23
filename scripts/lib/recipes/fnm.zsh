#!/bin/zsh

package_recipe::fnm_install_dir() {
  if [[ -n "${XDG_DATA_HOME:-}" ]]; then
    print -r -- "$XDG_DATA_HOME/fnm"
    return 0
  fi

  case "$DOTFILES_PLATFORM" in
    macos) print -r -- "$HOME/Library/Application Support/fnm" ;;
    *) print -r -- "$HOME/.local/share/fnm" ;;
  esac
}

package_recipe::fnm_activate() {
  package_manager::prepend_path "$(package_recipe::fnm_install_dir)"
}

package_recipe::fnm_install() {
  local logical_name="${1:-fnm}"
  local required="${2:-0}"
  local install_dir installer_url installer_path rc

  if [[ "$DOTFILES_PACKAGE_MANAGER" == "brew" ]]; then
    package_manager::install_native_logical "$logical_name" "$required"
    return $?
  fi

  package_recipe::fnm_activate

  if command -v fnm >/dev/null 2>&1; then
    dotfiles::record_reused "fnm command"
    dotfiles::log_info "Using existing fnm command."
    return 0
  fi

  package_manager::ensure_command curl curl 1
  package_manager::ensure_command unzip unzip 1

  install_dir="$(package_recipe::fnm_install_dir)"
  installer_url="https://fnm.vercel.app/install"
  installer_path="$(mktemp)"

  dotfiles::download_script "$installer_url" "$installer_path"
  dotfiles::execution_record_event installing "$logical_name via install script"
  dotfiles::log_info "Installing fnm with the official install script..."

  if /bin/bash "$installer_path" --install-dir "$install_dir" --skip-shell; then
    rc=0
  else
    rc=$?
  fi

  rm -f "$installer_path"

  if [[ "$rc" -ne 0 ]]; then
    return "$rc"
  fi

  package_recipe::fnm_activate

  if command -v fnm >/dev/null 2>&1; then
    dotfiles::record_installed "fnm via install script"
    dotfiles::record_completed_work "Installed fnm into $(dotfiles::display_path "$install_dir")"
    return 0
  fi

  dotfiles::log_error "fnm installation completed, but the fnm command is still unavailable."
  return 1
}
