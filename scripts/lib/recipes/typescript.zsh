#!/bin/zsh

package_recipe::typescript_install() {
  local logical_name="${1:-typescript}"
  local required="${2:-0}"

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    if [[ "$required" == "1" ]]; then
      dotfiles::log_error "Node.js and npm are required to install $logical_name."
      return 1
    fi

    dotfiles::log_warn "Skipping $logical_name because node/npm is not available."
    return 0
  fi

  package_manager::install_npm_global "$logical_name"
}

package_recipe::typescript_language_server_install() {
  local logical_name="${1:-typescript-language-server}"
  local required="${2:-0}"

  if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
    if [[ "$required" == "1" ]]; then
      dotfiles::log_error "Node.js and npm are required to install $logical_name."
      return 1
    fi

    dotfiles::log_warn "Skipping $logical_name because node/npm is not available."
    return 0
  fi

  package_manager::install_npm_global "$logical_name"
}
