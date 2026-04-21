#!/bin/zsh

typeset -g DOTFILES_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
typeset -g DOTFILES_INSTALL_ENV="$DOTFILES_CONFIG_DIR/install.env"
typeset -g DOTFILES_LOCAL_ZSH="$DOTFILES_CONFIG_DIR/local.zsh"

dotfiles::require_tty() {
  if [[ ! -t 0 ]]; then
    echo "$(red This installer is interactive and must be run from a TTY.)" >&2
    exit 1
  fi
}

dotfiles::ensure_dir() {
  mkdir -p "$1"
}

dotfiles::log_step() {
  echo
  echo "$(green $1)"
}

dotfiles::log_info() {
  echo "$1"
}

dotfiles::log_warn() {
  echo "$(yellow $1)"
}

dotfiles::log_success() {
  echo "$(green $1)"
}

dotfiles::log_error() {
  echo "$(red $1)" >&2
}

dotfiles::run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return 0
  fi

  dotfiles::log_error "This step requires root privileges, but sudo is not available."
  return 1
}

dotfiles::download_script() {
  local url="$1"
  local destination="$2"

  dotfiles::log_info "Downloading:"
  dotfiles::log_info "  $url"

  curl -fsSL "$url" -o "$destination"
}

dotfiles::write_install_env() {
  dotfiles::ensure_dir "$DOTFILES_CONFIG_DIR"

  cat >"$DOTFILES_INSTALL_ENV" <<EOF
export DOTFILES_PLATFORM="$DOTFILES_PLATFORM"
export DOTFILES_PACKAGE_MANAGER="$DOTFILES_PACKAGE_MANAGER"
export DOTFILES_THEME="$DOTFILES_THEME"
export DOTFILES_ENABLE_OH_MY_ZSH="$DOTFILES_ENABLE_OH_MY_ZSH"
export DOTFILES_ROOT="$DOTFILES_ROOT"
EOF

  dotfiles::log_success "Wrote installer state to $DOTFILES_INSTALL_ENV"
}
