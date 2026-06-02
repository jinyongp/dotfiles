#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$DOTFILES_ROOT/scripts/run-install-plan.zsh"

source "$DOTFILES_ROOT/scripts/lib/install/bootstrap.bash"

themes::usage() {
  ui::help_start "dotfiles themes" "Manage shell theme selection and dependencies."
  ui::help_commands \
    $'list\tlist\tList available shell themes and saved state.' \
    $'use\tuse <theme>\tSet the saved shell theme and install dependencies.' \
    $'install\tinstall\tInstall dependencies for the saved shell theme.'
  ui::help_examples \
    "dfx themes list" \
    "dfx themes use starship" \
    "dfx themes use none" \
    "dfx themes install"
}

themes::prepare_state() {
  install::init_state
  install::detect_platform

  if [[ "$DOTFILES_PLATFORM" == "unknown" ]]; then
    ui::validation_error "unsupported platform" \
      $'input\t'"${OSTYPE:-unknown}" \
      $'expected\tmacos, linux, or wsl' \
      $'next\tUse a supported macOS, Linux, or WSL environment.'
    return 1
  fi

  install::load_saved_runtime_defaults
  install::select_default_package_manager
  install::remember_saved_runtime_defaults
}

themes::theme_ids() {
  local records=()
  local record theme_id
  local ids=()

  install::read_records_into_array records catalog::theme_records

  for record in "${records[@]}"; do
    theme_id="$(prompt::record_field "$record" 1)"
    ids[${#ids[@]}]="$theme_id"
  done

  prompt::join_by ", " "${ids[@]}"
}

themes::theme_exists() {
  local expected_theme="$1"
  local records=()
  local record theme_id

  install::read_records_into_array records catalog::theme_records

  for record in "${records[@]}"; do
    theme_id="$(prompt::record_field "$record" 1)"
    [[ "$theme_id" == "$expected_theme" ]] && return 0
  done

  return 1
}

themes::configure_install() {
  DOTFILES_SELECTED_MODULES=""
  DOTFILES_RUN_THEME_INSTALL="1"
  DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="1"
  DOTFILES_ENABLE_OH_MY_ZSH="0"

  case "$DOTFILES_THEME" in
    powerlevel10k|default) DOTFILES_ENABLE_OH_MY_ZSH="1" ;;
  esac
}

themes::maybe_auto_launch_zsh() {
  local zsh_bin=""

  if install::should_auto_launch_zsh; then
    zsh_bin="$(install::find_zsh)"
    ui::note "Starting a login zsh shell with the installed dotfiles config."
    if ! exec "$zsh_bin" -l; then
      ui::fail "Failed to start a login zsh shell automatically."
      ui::note "Run this manually: exec zsh -l"
      exit 1
    fi
  fi
}

themes::print_list_json() {
  local records=()
  local record id label description status selected first=1

  install::read_records_into_array records catalog::theme_records
  install::annotate_theme_records records

  printf '['
  for record in "${records[@]}"; do
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    status="$(prompt::record_field "$record" 6)"

    if [[ "$first" -eq 0 ]]; then
      printf ','
    fi
    printf '{"id":"%s","label":"%s","description":"%s","current":%s,"status":"%s"}' \
      "$(ui::json_escape "$id")" \
      "$(ui::json_escape "$label")" \
      "$(ui::json_escape "$description")" \
      "$([[ "$selected" == "1" ]] && printf true || printf false)" \
      "$(ui::json_escape "$status")"
    first=0
  done
  printf ']\n'
}

themes::list() {
  local records=()
  local record id description status selected status_label

  themes::prepare_state

  if ui::is_json; then
    themes::print_list_json
    return 0
  fi

  install::read_records_into_array records catalog::theme_records
  install::annotate_theme_records records

  printf '%s\n' "$(ui::heading "Shell themes")"
  printf '%s\n' "$(ui::line "$(ui::align_pair "$(ui::style table_header "theme")" "$(ui::align_pair "$(ui::style table_header "status")" "$(ui::style table_header "description")" 14)" 18)")"

  for record in "${records[@]}"; do
    id="$(prompt::record_field "$record" 1)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    status="$(prompt::record_field "$record" 6)"

    if [[ "$selected" == "1" ]]; then
      status_label="current"
    elif [[ -n "$status" ]]; then
      status_label="$status"
    else
      status_label=""
    fi

    printf '%s\n' "$(ui::line "$(ui::align_pair "$(ui::body "$id")" "$(ui::align_pair "$(ui::description "$status_label")" "$(ui::body "$description")" 14)" 18)")"
  done
}

themes::install_saved() {
  themes::prepare_state
  themes::configure_install

  printf '%s\n' "$(ui::status starting "theme install")"
  printf '%s\n' "$(ui::line "$(ui::field theme "$DOTFILES_THEME")")"
  printf '%s\n' "$(ui::line "$(ui::field "package manager" "$DOTFILES_PACKAGE_MANAGER")")"

  install::run_install_plan_or_exit "Theme install failed."
  printf '%s\n' "$(ui::status completed "theme install complete")"
  themes::maybe_auto_launch_zsh
}

themes::use() {
  local theme_id="${1:-}"

  themes::prepare_state

  if [[ -z "$theme_id" ]]; then
    ui::validation_error "theme id required" \
      $'expected\t'"$(themes::theme_ids)" \
      $'usage\tdfx themes use <theme>' \
      $'next\tdfx themes list'
    return 2
  fi

  if (( $# > 1 )); then
    ui::validation_error "too many theme ids" \
      $'input\t'"$*" \
      $'expected\t'"$(themes::theme_ids)" \
      $'usage\tdfx themes use <theme>' \
      $'next\tdfx themes list'
    return 2
  fi

  if ! themes::theme_exists "$theme_id"; then
    ui::validation_error "unknown shell theme" \
      $'input\t'"$theme_id" \
      $'expected\t'"$(themes::theme_ids)" \
      $'usage\tdfx themes use <theme>' \
      $'next\tdfx themes list'
    return 2
  fi

  DOTFILES_THEME="$theme_id"
  themes::configure_install

  printf '%s\n' "$(ui::status starting "theme update")"
  printf '%s\n' "$(ui::line "$(ui::field theme "$DOTFILES_THEME")")"
  printf '%s\n' "$(ui::line "$(ui::field "package manager" "$DOTFILES_PACKAGE_MANAGER")")"

  install::run_install_plan_or_exit "Theme update failed."
  printf '%s\n' "$(ui::status completed "theme update complete")"
  themes::maybe_auto_launch_zsh
}

case "${1:-help}" in
  -h|--help|help)
    themes::usage
    ;;
  list)
    shift
    if (( $# > 0 )); then
      ui::validation_error "list does not accept arguments" \
        $'input\t'"$*" \
        $'usage\tdfx themes list'
      exit 2
    fi
    themes::list
    ;;
  install)
    shift
    if (( $# > 0 )); then
      ui::validation_error "install does not accept theme arguments" \
        $'input\t'"$*" \
        $'usage\tdfx themes install' \
        $'next\tdfx themes use <theme>'
      exit 2
    fi
    themes::install_saved
    ;;
  use)
    shift
    themes::use "$@"
    ;;
  *)
    ui::validation_error "unknown themes command" \
      $'input\t'"$1" \
      $'usage\tdfx themes <command>' \
      $'expected\tlist, use, install'
    exit 2
    ;;
esac
