# Runtime bootstrap, platform detection, and terminal-facing helpers.

color_green() {
  printf '%s\n' "$(dotfiles_success "$1")"
}

color_yellow() {
  printf '%s\n' "$(dotfiles_warning "$1")"
}

color_red() {
  printf '%s\n' "$(dotfiles_error "$1")" >&2
}

log_step() {
  printf '\n'
  color_green "$1"
}

display_path() {
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

record_bootstrap_zsh_reused() {
  if [[ "$DOTFILES_BOOTSTRAP_ZSH_STATUS" == "none" ]]; then
    DOTFILES_BOOTSTRAP_ZSH_STATUS="reused"
    DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER="existing"
  fi
}

record_bootstrap_zsh_installed() {
  DOTFILES_BOOTSTRAP_ZSH_STATUS="installed"
  DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER="$1"
}

repo_managed_zshrc_path() {
  printf '%s/zsh/.zshrc' "$DOTFILES_ROOT"
}

current_shell_uses_repo_zshrc() {
  [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$(repo_managed_zshrc_path)" ]]
}

plan_requires_shell_restart() {
  if module_is_selected "dotfiles" || module_is_selected "oh_my_zsh"; then
    return 0
  fi

  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" == "1" ]] && current_shell_uses_repo_zshrc; then
    return 0
  fi

  return 1
}

should_auto_launch_zsh() {
  if [[ "${DOTFILES_ALLOW_AUTO_LAUNCH_ZSH:-1}" != "1" ]]; then
    return 1
  fi

  plan_requires_shell_restart
}

enable_interactive_style() {
  if [[ -t 0 && -t 1 && -z "${DOTFILES_FORCE_COLOR:-}" ]]; then
    export DOTFILES_FORCE_COLOR=1
  fi
}

detect_platform() {
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    DOTFILES_PLATFORM="macos"
    DOTFILES_PLATFORM_LABEL="macOS"
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    DOTFILES_PLATFORM="wsl"
    DOTFILES_PLATFORM_LABEL="WSL"
    return 0
  fi

  if grep -qi microsoft /proc/version 2>/dev/null; then
    DOTFILES_PLATFORM="wsl"
    DOTFILES_PLATFORM_LABEL="WSL"
    return 0
  fi

  if [[ "${OSTYPE:-}" == linux* ]]; then
    DOTFILES_PLATFORM="linux"
    DOTFILES_PLATFORM_LABEL="Linux"
    return 0
  fi

  DOTFILES_PLATFORM="unknown"
  DOTFILES_PLATFORM_LABEL="Unknown"
}

find_brew() {
  local candidate

  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  for candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew \
    "$HOME/.linuxbrew/bin/brew"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_zsh() {
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

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return 0
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return 0
  fi

  color_red "This step requires root privileges, but sudo is not available."
  return 1
}

ensure_zsh_with_apt() {
  log_step "Bootstrapping zsh with apt"
  color_yellow "zsh is not installed yet. Running apt-get update/install so the zsh runner can start."
  run_as_root apt-get update
  run_as_root apt-get install -y zsh
}

ensure_zsh_with_brew() {
  local brew_bin

  brew_bin="$(find_brew)"
  log_step "Bootstrapping zsh with Homebrew"
  color_yellow "zsh is not installed yet. Installing it with Homebrew so the zsh runner can start."
  "$brew_bin" install zsh
}

ensure_zsh() {
  local platform="$1"
  local preferred_package_manager="${2:-}"

  if find_zsh >/dev/null 2>&1; then
    record_bootstrap_zsh_reused
    return 0
  fi

  case "$platform" in
    macos)
      if find_brew >/dev/null 2>&1; then
        ensure_zsh_with_brew
        record_bootstrap_zsh_installed "brew"
      else
        color_red "zsh was not found on macOS and Homebrew is unavailable."
        color_red "Install zsh manually, then rerun $DOTFILES_ROOT/install"
        return 1
      fi
      ;;
    wsl|linux)
      if [[ "$preferred_package_manager" == "brew" ]] && find_brew >/dev/null 2>&1; then
        ensure_zsh_with_brew
        record_bootstrap_zsh_installed "brew"
      elif command -v apt-get >/dev/null 2>&1; then
        if [[ "$preferred_package_manager" == "brew" ]]; then
          color_yellow "Homebrew was selected for package installs, but zsh bootstrap is falling back to apt because brew is not ready yet."
        fi
        ensure_zsh_with_apt
        record_bootstrap_zsh_installed "apt"
      elif find_brew >/dev/null 2>&1; then
        ensure_zsh_with_brew
        record_bootstrap_zsh_installed "brew"
      else
        color_red "zsh is missing and no supported bootstrap package manager was found."
        color_red "Install zsh manually, then rerun $DOTFILES_ROOT/install"
        return 1
      fi
      ;;
    *)
      color_red "Unsupported platform for bootstrap."
      return 1
      ;;
  esac

  if ! find_zsh >/dev/null 2>&1; then
    color_red "zsh installation did not produce a usable zsh binary."
    return 1
  fi
}
