#!/bin/zsh

typeset -g DOTFILES_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
typeset -g DOTFILES_INSTALL_ENV="$DOTFILES_CONFIG_DIR/install.env"
typeset -g DOTFILES_LOCAL_ZSH="$DOTFILES_CONFIG_DIR/local.zsh"
typeset -gaU DOTFILES_RESULT_INSTALLED_ITEMS=()
typeset -gaU DOTFILES_RESULT_REUSED_ITEMS=()
typeset -gaU DOTFILES_RESULT_CREATED_FILES=()
typeset -gaU DOTFILES_RESULT_UPDATED_FILES=()
typeset -gaU DOTFILES_RESULT_LINKED_FILES=()
typeset -gaU DOTFILES_RESULT_BACKED_UP_FILES=()
typeset -gaU DOTFILES_RESULT_COMPLETED_WORK=()
typeset -gaU DOTFILES_RESULT_NOTES=()
typeset -gaU DOTFILES_RESULT_WARNINGS=()

dotfiles::require_tty() {
  if [[ ! -t 0 ]]; then
    echo "$(red This installer is interactive and must be run from a TTY.)" >&2
    exit 1
  fi
}

dotfiles::ensure_dir() {
  mkdir -p "$1"
}

dotfiles::display_path() {
  local path="$1"

  case "$path" in
    "$HOME")
      print -r -- "~"
      ;;
    "$HOME"/*)
      print -r -- "~${path#$HOME}"
      ;;
    *)
      print -r -- "$path"
      ;;
  esac
}

dotfiles::array_contains() {
  local needle="$1"
  shift || true

  local value
  for value in "$@"; do
    [[ "$value" == "$needle" ]] && return 0
  done

  return 1
}

dotfiles::record_installed() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_INSTALLED_ITEMS+=("$1")
}

dotfiles::record_reused() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_REUSED_ITEMS+=("$1")
}

dotfiles::record_file_created() {
  local path_display
  path_display="$(dotfiles::display_path "$1")"
  DOTFILES_RESULT_CREATED_FILES+=("$path_display")
}

dotfiles::record_file_updated() {
  local path_display
  path_display="$(dotfiles::display_path "$1")"

  if dotfiles::array_contains "$path_display" "${DOTFILES_RESULT_CREATED_FILES[@]}"; then
    return 0
  fi

  DOTFILES_RESULT_UPDATED_FILES+=("$path_display")
}

dotfiles::record_file_linked() {
  local target_display source_display
  target_display="$(dotfiles::display_path "$1")"
  source_display="$(dotfiles::display_path "$2")"
  DOTFILES_RESULT_LINKED_FILES+=("$target_display -> $source_display")
}

dotfiles::record_file_backed_up() {
  local source_display backup_display
  source_display="$(dotfiles::display_path "$1")"
  backup_display="$(dotfiles::display_path "$2")"
  DOTFILES_RESULT_BACKED_UP_FILES+=("$source_display -> $backup_display")
}

dotfiles::record_completed_work() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_COMPLETED_WORK+=("$1")
}

dotfiles::record_note() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_NOTES+=("$1")
}

dotfiles::record_warning() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_WARNINGS+=("$1")
}

dotfiles::record_bootstrap_results() {
  case "${DOTFILES_BOOTSTRAP_ZSH_STATUS:-none}" in
    installed)
      dotfiles::record_installed "zsh (bootstrap via ${DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER:-package manager})"
      ;;
    reused)
      dotfiles::record_reused "zsh command for installer startup"
      ;;
  esac
}

dotfiles::repo_managed_zshrc_path() {
  print -r -- "$DOTFILES_ROOT/zsh/.zshrc"
}

dotfiles::should_auto_launch_zsh() {
  if [[ "${DOTFILES_ALLOW_AUTO_LAUNCH_ZSH:-1}" != "1" ]]; then
    return 1
  fi

  if [[ " ${DOTFILES_SELECTED_MODULES:-} " == *" dotfiles "* ]]; then
    return 0
  fi

  if [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$(dotfiles::repo_managed_zshrc_path)" ]]; then
    return 0
  fi

  return 1
}

dotfiles::print_report_section() {
  local title="$1"
  shift || true
  local line

  echo
  echo "$(b_green $title)"

  if (( $# == 0 )); then
    echo "  - None"
    return 0
  fi

  for line in "$@"; do
    [[ -n "$line" ]] || continue
    echo "  - $line"
  done
}

dotfiles::print_install_report() {
  local personal_file_display next_action_message next_action_detail
  local -a completed_items=()
  local note warning
  personal_file_display="$(dotfiles::display_path "$DOTFILES_CONFIG_DIR/git/personal.local.ini")"

  completed_items=("${DOTFILES_RESULT_COMPLETED_WORK[@]}")
  for note in "${DOTFILES_RESULT_NOTES[@]}"; do
    completed_items+=("Note: $note")
  done
  for warning in "${DOTFILES_RESULT_WARNINGS[@]}"; do
    completed_items+=("Warning: $warning")
  done

  echo
  echo "$(green Post-install report)"

  dotfiles::print_report_section "Installed items" "${DOTFILES_RESULT_INSTALLED_ITEMS[@]}"
  dotfiles::print_report_section "Reused existing items" "${DOTFILES_RESULT_REUSED_ITEMS[@]}"
  dotfiles::print_report_section "Created files" "${DOTFILES_RESULT_CREATED_FILES[@]}"
  dotfiles::print_report_section "Updated files" "${DOTFILES_RESULT_UPDATED_FILES[@]}"
  dotfiles::print_report_section "Linked files" "${DOTFILES_RESULT_LINKED_FILES[@]}"
  dotfiles::print_report_section "Backed up files" "${DOTFILES_RESULT_BACKED_UP_FILES[@]}"
  dotfiles::print_report_section "Completed work" "${completed_items[@]}"

  echo
  echo "$(b_green Git personal config)"
  echo "  - File: $personal_file_display"
  echo "  - You can edit this file directly later."

  if dotfiles::should_auto_launch_zsh; then
    next_action_message="The installer will now start a login zsh shell."
    next_action_detail="If that does not happen, run: exec zsh -l"
  else
    next_action_message="Automatic zsh launch is skipped because dotfiles shell config is not active yet."
    next_action_detail="Run: exec zsh -l"
  fi

  echo
  echo "$(b_green Next shell action)"
  echo "  - $next_action_message"
  echo "  - $next_action_detail"
}

dotfiles::log_step() {
  echo
  echo "$(green $1)"
}

dotfiles::log_info() {
  echo "$1"
}

dotfiles::log_warn() {
  dotfiles::record_warning "$1"
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
  local env_file_exists=0

  dotfiles::ensure_dir "$DOTFILES_CONFIG_DIR"
  [[ -e "$DOTFILES_INSTALL_ENV" ]] && env_file_exists=1

  cat >"$DOTFILES_INSTALL_ENV" <<EOF
export DOTFILES_PLATFORM="$DOTFILES_PLATFORM"
export DOTFILES_PACKAGE_MANAGER="$DOTFILES_PACKAGE_MANAGER"
export DOTFILES_THEME="$DOTFILES_THEME"
export DOTFILES_ENABLE_OH_MY_ZSH="$DOTFILES_ENABLE_OH_MY_ZSH"
export DOTFILES_ROOT="$DOTFILES_ROOT"
EOF

  if [[ "$env_file_exists" == "1" ]]; then
    dotfiles::record_file_updated "$DOTFILES_INSTALL_ENV"
  else
    dotfiles::record_file_created "$DOTFILES_INSTALL_ENV"
  fi
  dotfiles::record_completed_work "Saved installer state"
  dotfiles::log_success "Wrote installer state to $DOTFILES_INSTALL_ENV"
}
