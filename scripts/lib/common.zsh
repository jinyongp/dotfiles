#!/bin/zsh

if ! typeset -f dotfiles_style >/dev/null 2>&1 && [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/style.sh" ]]; then
  source "$DOTFILES_ROOT/scripts/lib/style.sh"
fi

source "$DOTFILES_ROOT/scripts/lib/runtime-shared.zsh"

if ! typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
  dotfiles::execution_record_event() {
    return 0
  }
fi

typeset -g DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-$(dotfiles::config_dir)}"
typeset -g DOTFILES_INSTALL_ENV="${DOTFILES_INSTALL_ENV:-$(dotfiles::install_env_path)}"
typeset -g DOTFILES_ENV_ZSH="${DOTFILES_ENV_ZSH:-$(dotfiles::env_zsh_path)}"
typeset -g DOTFILES_PROFILE_ZSH="${DOTFILES_PROFILE_ZSH:-$(dotfiles::profile_zsh_path)}"
typeset -g DOTFILES_LOCAL_ZSH="${DOTFILES_LOCAL_ZSH:-$(dotfiles::local_zsh_path)}"
typeset -gaU DOTFILES_RESULT_INSTALLED_ITEMS=()
typeset -gaU DOTFILES_RESULT_REUSED_ITEMS=()
typeset -gaU DOTFILES_RESULT_SKIPPED_ITEMS=()
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
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event installed "$1"
  fi
}

dotfiles::record_reused() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_REUSED_ITEMS+=("$1")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event reused "$1"
  fi
}

dotfiles::record_skipped() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_SKIPPED_ITEMS+=("$1")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event skipped "$1"
  fi
}

dotfiles::record_file_created() {
  local path_display
  path_display="$(dotfiles::display_path "$1")"
  DOTFILES_RESULT_CREATED_FILES+=("$path_display")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event file_change "Created $path_display"
  fi
}

dotfiles::record_file_updated() {
  local path_display
  path_display="$(dotfiles::display_path "$1")"

  if dotfiles::array_contains "$path_display" "${DOTFILES_RESULT_CREATED_FILES[@]}"; then
    return 0
  fi

  DOTFILES_RESULT_UPDATED_FILES+=("$path_display")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event file_change "Updated $path_display"
  fi
}

dotfiles::record_file_linked() {
  local target_display source_display
  target_display="$(dotfiles::display_path "$1")"
  source_display="$(dotfiles::display_path "$2")"
  DOTFILES_RESULT_LINKED_FILES+=("$target_display -> $source_display")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event file_change "Linked $target_display -> $source_display"
  fi
}

dotfiles::record_file_backed_up() {
  local source_display backup_display
  source_display="$(dotfiles::display_path "$1")"
  backup_display="$(dotfiles::display_path "$2")"
  DOTFILES_RESULT_BACKED_UP_FILES+=("$source_display -> $backup_display")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event file_change "Backed up $source_display -> $backup_display"
  fi
}

dotfiles::record_completed_work() {
  [[ -n "${1:-}" ]] || return 0
  DOTFILES_RESULT_COMPLETED_WORK+=("$1")
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event completed_work "$1"
  fi
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

dotfiles::current_shell_uses_repo_zshrc() {
  [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$(dotfiles::repo_managed_zshrc_path)" ]]
}

dotfiles::plan_requires_shell_restart() {
  if [[ " ${DOTFILES_SELECTED_MODULES:-} " == *" dotfiles "* || " ${DOTFILES_SELECTED_MODULES:-} " == *" oh_my_zsh "* ]]; then
    return 0
  fi

  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" == "1" ]] && dotfiles::current_shell_uses_repo_zshrc; then
    return 0
  fi

  return 1
}

dotfiles::should_auto_launch_zsh() {
  if [[ "${DOTFILES_ALLOW_AUTO_LAUNCH_ZSH:-1}" != "1" ]]; then
    return 1
  fi

  dotfiles::plan_requires_shell_restart
}

dotfiles::style_path() {
  dotfiles_path "$1"
}

dotfiles::style_command() {
  dotfiles_code "$1"
}

dotfiles::style_link() {
  dotfiles_link "$1" "${2:-$1}"
}

dotfiles::print_report_section() {
  local title="$1"
  shift || true
  local line
  local -a lines=()

  for line in "$@"; do
    [[ -n "$line" ]] || continue
    lines+=("$line")
  done

  if (( ${#lines[@]} == 0 )); then
    return 0
  fi

  echo
  echo "$(dotfiles_heading "$title")"

  for line in "${lines[@]}"; do
    echo "  $(dotfiles_muted •) $line"
  done
}

dotfiles::report_join_items() {
  local -a items=("$@")
  print -r -- "${(j:, :)items}"
}

dotfiles::report_reused_items() {
  local line
  local -a lines=()
  local -a managed_links=()

  for line in "${DOTFILES_RESULT_REUSED_ITEMS[@]}"; do
    case "$line" in
      "Managed link already in place: "*)
        managed_links+=("${line#Managed link already in place: }")
        ;;
      "Machine-local Git identity")
        if [[ " ${DOTFILES_SELECTED_MODULES:-} " == *" dotfiles "* ]]; then
          continue
        fi
        lines+=("$line")
        ;;
      *)
        lines+=("$line")
        ;;
    esac
  done

  if (( ${#managed_links[@]} > 0 )); then
    lines+=("Managed links already in place: $(dotfiles::report_join_items "${managed_links[@]}")")
  fi

  printf '%s\n' "${lines[@]}"
}

dotfiles::report_file_change_items() {
  local -a lines=()

  if (( ${#DOTFILES_RESULT_CREATED_FILES[@]} > 0 )); then
    lines+=("Created: $(dotfiles::report_join_items "${DOTFILES_RESULT_CREATED_FILES[@]}")")
  fi

  if (( ${#DOTFILES_RESULT_UPDATED_FILES[@]} > 0 )); then
    lines+=("Updated: $(dotfiles::report_join_items "${DOTFILES_RESULT_UPDATED_FILES[@]}")")
  fi

  if (( ${#DOTFILES_RESULT_LINKED_FILES[@]} > 0 )); then
    lines+=("Linked: $(dotfiles::report_join_items "${DOTFILES_RESULT_LINKED_FILES[@]}")")
  fi

  if (( ${#DOTFILES_RESULT_BACKED_UP_FILES[@]} > 0 )); then
    lines+=("Backed up: $(dotfiles::report_join_items "${DOTFILES_RESULT_BACKED_UP_FILES[@]}")")
  fi

  printf '%s\n' "${lines[@]}"
}

dotfiles::report_completed_items() {
  local line
  local -a lines=()

  for line in "${DOTFILES_RESULT_COMPLETED_WORK[@]}"; do
    case "$line" in
      "Saved installer state"|\
      Completed\ *\ setup|\
      Completed\ theme\ dependency\ setup\ for\ *)
        continue
        ;;
    esac

    lines+=("$line")
  done

  for line in "${DOTFILES_RESULT_NOTES[@]}"; do
    lines+=("$(dotfiles_warning Note:) $line")
  done

  for line in "${DOTFILES_RESULT_WARNINGS[@]}"; do
    lines+=("$(dotfiles_error Warning:) $line")
  done

  printf '%s\n' "${lines[@]}"
}

dotfiles::print_install_report() {
  local personal_file_display next_action_message next_action_detail
  local -a reused_items=()
  local -a skipped_items=()
  local -a file_change_items=()
  local -a completed_items=()
  personal_file_display="$(dotfiles::display_path "$DOTFILES_CONFIG_DIR/git/personal.local.ini")"

  reused_items=("${(@f)$(dotfiles::report_reused_items)}")
  skipped_items=("${DOTFILES_RESULT_SKIPPED_ITEMS[@]}")
  file_change_items=("${(@f)$(dotfiles::report_file_change_items)}")
  completed_items=("${(@f)$(dotfiles::report_completed_items)}")

  echo
  echo "$(dotfiles_heading 'Post-install Report')"

  dotfiles::print_report_section "Installed" "${DOTFILES_RESULT_INSTALLED_ITEMS[@]}"
  dotfiles::print_report_section "Reused" "${reused_items[@]}"
  dotfiles::print_report_section "Skipped" "${skipped_items[@]}"
  dotfiles::print_report_section "File changes" "${file_change_items[@]}"
  dotfiles::print_report_section "Completed work" "${completed_items[@]}"

  if [[ " ${DOTFILES_SELECTED_MODULES:-} " == *" dotfiles "* ]]; then
    echo
    echo "$(dotfiles_heading 'Git personal config')"
    echo "  $(dotfiles_muted •) $(dotfiles::style_path "$personal_file_display") $(dotfiles_muted '(edit directly if needed)')"
  fi

  if dotfiles::should_auto_launch_zsh; then
    next_action_message="Starting a login zsh shell now."
    next_action_detail="If needed: exec zsh -l"
  else
    next_action_message="No shell restart is needed."
    next_action_detail=""
  fi

  echo
  echo "$(dotfiles_heading 'Next')"
  echo "  $(dotfiles_muted •) $next_action_message"
  if [[ -n "$next_action_detail" ]]; then
    echo "  $(dotfiles_muted •) $(dotfiles::style_command "$next_action_detail")"
  fi
}

dotfiles::log_step() {
  echo
  echo "$(dotfiles_accent "$1")"
}

dotfiles::log_info() {
  echo "$(dotfiles_muted "$1")"
}

dotfiles::log_warn() {
  dotfiles::record_warning "$1"
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event warning "$1"
  fi
  echo "$(dotfiles_warning "$1")"
}

dotfiles::log_success() {
  echo "$(dotfiles_success "$1")"
}

dotfiles::log_error() {
  if typeset -f dotfiles::execution_record_event >/dev/null 2>&1; then
    dotfiles::execution_record_event error "$1"
  fi
  echo "$(dotfiles_error "$1")" >&2
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
  dotfiles::log_info "  $(dotfiles::style_link "$url" "$url")"

  curl -fsSL "$url" -o "$destination"
}
