# Top-level installer orchestration.

main() {
  local proceed=""
  local zsh_bin=""

  enable_interactive_style
  detect_platform

  if [[ "$DOTFILES_PLATFORM" == "unknown" ]]; then
    color_red "Unsupported platform: ${OSTYPE:-unknown}"
    exit 1
  fi

  if (( $# > 0 )); then
    case "$1" in
      -h|--help|help)
        load_saved_runtime_defaults
        select_default_package_manager
        remember_saved_runtime_defaults
        print_direct_usage
        exit 0
        ;;
      list)
        load_saved_runtime_defaults
        select_default_package_manager
        remember_saved_runtime_defaults
        print_direct_target_list
        exit 0
        ;;
      *)
        run_direct_install "$@"
        exit 0
        ;;
    esac
  fi

  if [[ ! -t 0 ]]; then
    color_red "This installer is interactive and must be run from a TTY."
    exit 1
  fi

  load_saved_runtime_defaults
  select_default_package_manager
  remember_saved_runtime_defaults

  prompt::intro "Dotfiles Installer"
  prompt::summary "Detected environment." "$DOTFILES_PLATFORM_LABEL"
  select_modules
  if [[ -z "$DOTFILES_SELECTED_MODULES" ]]; then
    prompt::cancel "No installation modules were selected."
    exit 0
  fi
  maybe_select_theme
  maybe_select_package_manager
  resolve_install_plan
  prompt_for_leaf_items
  resolve_install_plan
  if ! plan_has_execution_targets; then
    prompt::cancel "No installation work remains after item selection."
    exit 0
  fi
  prompt_for_git_identity
  finalize_runtime_state
  print_plan_summary
  prompt::confirm proceed "Proceed with installation?" "yes" "Enter to start installation."

  if [[ "$proceed" != "yes" ]]; then
    prompt::cancel "Installation cancelled."
    exit 0
  fi

  run_install_plan_or_exit "Installation failed."
  prompt::outro "Installation complete."

  if should_auto_launch_zsh; then
    zsh_bin="$(find_zsh)"
    color_yellow "Starting a login zsh shell with the installed dotfiles config."
    if ! exec "$zsh_bin" -l; then
      color_red "Failed to start a login zsh shell automatically."
      color_yellow "Run this manually: exec zsh -l"
      exit 1
    fi
  fi

  color_yellow "Skipping automatic zsh launch because $(display_path "$HOME/.zshrc") is not managed by this dotfiles repo."
  color_yellow "Run this manually: exec zsh -l"
}
