# Top-level installer orchestration.

install::main() {
  local zsh_bin=""

  install::init_state
  install::enable_interactive_style
  install::detect_platform

  if [[ "$DOTFILES_PLATFORM" == "unknown" ]]; then
    install::color_red "Unsupported platform: ${OSTYPE:-unknown}"
    exit 1
  fi

  if (( $# > 0 )); then
    case "$1" in
      -h|--help|help)
        install::load_saved_runtime_defaults
        install::select_default_package_manager
        install::remember_saved_runtime_defaults
        install::print_direct_usage
        exit 0
        ;;
      list)
        install::load_saved_runtime_defaults
        install::select_default_package_manager
        install::remember_saved_runtime_defaults
        install::print_direct_target_list
        exit 0
        ;;
      *)
        install::run_direct_install "$@"
        exit 0
        ;;
    esac
  fi

  if [[ ! -t 0 ]]; then
    install::color_red "This installer is interactive and must be run from a TTY."
    exit 1
  fi

  install::load_saved_runtime_defaults
  install::select_default_package_manager
  install::remember_saved_runtime_defaults

  prompt::intro "Dotfiles Installer" "$DOTFILES_PLATFORM_LABEL"
  install::select_profile
  if [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    install::select_modules
  fi
  install::refresh_plan_after_structure_edit

  if ! install::run_summary_action_loop; then
    prompt::cancel "Installation cancelled."
    exit 0
  fi

  install::run_install_plan_or_exit "Installation failed."
  prompt::outro "Installation complete."

  if install::should_auto_launch_zsh; then
    zsh_bin="$(install::find_zsh)"
    install::color_yellow "Starting a login zsh shell with the installed dotfiles config."
    if ! exec "$zsh_bin" -l; then
      install::color_red "Failed to start a login zsh shell automatically."
      install::color_yellow "Run this manually: exec zsh -l"
      exit 1
    fi
  fi

  install::color_yellow "Skipping automatic zsh launch because $(install::display_path "$HOME/.zshrc") is not managed by this dotfiles repo."
  install::color_yellow "Run this manually: exec zsh -l"
}
