#!/usr/bin/env zsh

package_recipe::gate_install() {
  local logical_name="${1:-gate}"
  local required="${2:-0}"
  local installer_url installer_path rc

  if command -v gate >/dev/null 2>&1; then
    dotfiles::record_reused "gate command"
    dotfiles::log_info "Using existing gate command."
    return 0
  fi

  if [[ "$DOTFILES_PACKAGE_MANAGER" == "brew" ]]; then
    package_manager::install_native_logical "$logical_name" "$required"
    return $?
  fi

  package_manager::ensure_command curl curl 1

  dotfiles::execution_record_event installing "$logical_name via install script"
  dotfiles::log_info "Installing gate with the official install script..."

  installer_url="https://raw.githubusercontent.com/jinyongp/gate/main/scripts/install.sh"
  installer_path="$(mktemp)"
  dotfiles::download_script "$installer_url" "$installer_path"

  if sh "$installer_path"; then
    rc=0
  else
    rc=$?
  fi

  rm -f "$installer_path"

  if [[ "$rc" -eq 0 ]]; then
    dotfiles::record_installed "$logical_name via install script"
    return 0
  fi

  if [[ "$required" == "1" ]]; then
    return 1
  fi

  dotfiles::record_skipped "$logical_name install script failed"
  return 0
}
