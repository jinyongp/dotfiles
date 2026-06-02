# Runtime bootstrap, platform detection, and terminal-facing helpers.

install::color_green() {
  printf '%s\n' "$(dotfiles_success "$1")"
}

install::color_yellow() {
  printf '%s\n' "$(dotfiles_warning "$1")"
}

install::color_red() {
  printf '%s\n' "$(dotfiles_error "$1")" >&2
}

install::log_step() {
  ui::step "$1"
}

install::display_path() {
  local path="$1"

  case "$path" in
    "$HOME")
      printf '~'
      ;;
    "$HOME"/*)
      printf '~%s' "${path#"$HOME"}"
      ;;
    *)
      printf '%s' "$path"
      ;;
  esac
}

install::record_bootstrap_zsh_reused() {
  if [[ "$DOTFILES_BOOTSTRAP_ZSH_STATUS" == "none" ]]; then
    DOTFILES_BOOTSTRAP_ZSH_STATUS="reused"
    DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER="existing"
  fi
}

install::record_bootstrap_zsh_installed() {
  DOTFILES_BOOTSTRAP_ZSH_STATUS="installed"
  DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER="$1"
}

install::repo_managed_zshrc_path() {
  printf '%s/zsh/.zshrc' "$DOTFILES_ROOT"
}

install::current_shell_uses_repo_zshrc() {
  [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$(install::repo_managed_zshrc_path)" ]]
}

install::plan_requires_shell_restart() {
  if install::module_is_selected "dotfiles" || install::module_is_selected "oh_my_zsh"; then
    return 0
  fi

  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" == "1" ]] && install::current_shell_uses_repo_zshrc; then
    return 0
  fi

  return 1
}

install::should_auto_launch_zsh() {
  if [[ "${DOTFILES_ALLOW_AUTO_LAUNCH_ZSH:-1}" != "1" ]]; then
    return 1
  fi

  install::plan_requires_shell_restart
}

install::enable_interactive_style() {
  return 0
}

install::detect_platform() {
  DOTFILES_PLATFORM="$(dotfiles::detect_platform_id || true)"

  case "$DOTFILES_PLATFORM" in
    macos) DOTFILES_PLATFORM_LABEL="macOS" ;;
    wsl) DOTFILES_PLATFORM_LABEL="WSL" ;;
    linux) DOTFILES_PLATFORM_LABEL="Linux" ;;
    *)
      DOTFILES_PLATFORM="unknown"
      DOTFILES_PLATFORM_LABEL="Unknown"
      ;;
  esac
}

install::find_brew() {
  dotfiles::brew_bin_path
}

install::find_zsh() {
  local candidate

  if command -v zsh >/dev/null 2>&1; then
    command -v zsh
    return 0
  fi

  for candidate in \
    /bin/zsh \
    /usr/bin/zsh \
    /opt/homebrew/bin/zsh \
    /usr/local/bin/zsh \
    /home/linuxbrew/.linuxbrew/bin/zsh \
    "$HOME/.linuxbrew/bin/zsh"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

install::run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return 0
  fi

  ui::validation_error "root privileges required" \
    $'command\tsudo' \
    $'expected\tsudo command available or root user'
  return 1
}

install::ensure_zsh_with_apt() {
  install::log_step "Bootstrapping zsh with apt"
  ui::note "zsh is not installed yet. Running apt-get update/install so the zsh runner can start."
  install::run_as_root apt-get update
  install::run_as_root apt-get install -y zsh
}

install::ensure_zsh_with_brew() {
  local brew_bin

  brew_bin="$(install::find_brew)"
  install::log_step "Bootstrapping zsh with Homebrew"
  ui::note "zsh is not installed yet. Installing it with Homebrew so the zsh runner can start."
  "$brew_bin" install zsh
}

install::ensure_zsh() {
  local platform="$1"
  local preferred_package_manager="${2:-}"

  if install::find_zsh >/dev/null 2>&1; then
    install::record_bootstrap_zsh_reused
    return 0
  fi

  case "$platform" in
    macos)
      if install::find_brew >/dev/null 2>&1; then
        install::ensure_zsh_with_brew
        install::record_bootstrap_zsh_installed "brew"
      else
        ui::validation_error "zsh bootstrap unavailable" \
          $'platform\tmacos' \
          $'expected\tHomebrew or existing zsh' \
          $'next\t'"Install zsh manually, then rerun $DOTFILES_ROOT/install"
        return 1
      fi
      ;;
    wsl|linux)
      if [[ "$preferred_package_manager" == "brew" ]] && install::find_brew >/dev/null 2>&1; then
        install::ensure_zsh_with_brew
        install::record_bootstrap_zsh_installed "brew"
      elif command -v apt-get >/dev/null 2>&1; then
        if [[ "$preferred_package_manager" == "brew" ]]; then
          ui::warn "Homebrew was selected for package installs, but zsh bootstrap is falling back to apt because brew is not ready yet."
        fi
        install::ensure_zsh_with_apt
        install::record_bootstrap_zsh_installed "apt"
      elif install::find_brew >/dev/null 2>&1; then
        install::ensure_zsh_with_brew
        install::record_bootstrap_zsh_installed "brew"
      else
        ui::validation_error "zsh bootstrap unavailable" \
          $'platform\t'"$platform" \
          $'expected\tapt, Homebrew, or existing zsh' \
          $'next\t'"Install zsh manually, then rerun $DOTFILES_ROOT/install"
        return 1
      fi
      ;;
    *)
      ui::validation_error "unsupported platform for bootstrap" \
        $'platform\t'"$platform"
      return 1
      ;;
  esac

  if ! install::find_zsh >/dev/null 2>&1; then
    ui::validation_error "zsh installation did not produce a usable zsh binary" \
      $'expected\tzsh command available'
    return 1
  fi
}
