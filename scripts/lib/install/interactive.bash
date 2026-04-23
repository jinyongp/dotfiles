# Interactive prompt flow for module, leaf item, theme, package manager, and Git identity choices.

install::apply_single_selection_to_records() {
  local array_name="$1"
  local selected_id="$2"
  local count index=0
  local record id label description selected disabled status

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    disabled="$(prompt::record_field "$record" 5)"
    status="$(prompt::record_field "$record" 6)"

    if [[ "$id" == "$selected_id" && "$disabled" != "1" ]]; then
      selected=1
    else
      selected=0
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

install::apply_multi_selection_to_records() {
  local array_name="$1"
  local selected_ids="$2"
  local count index=0
  local record id label description selected disabled status

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    disabled="$(prompt::record_field "$record" 5)"
    status="$(prompt::record_field "$record" 6)"

    if [[ "$disabled" != "1" ]] && install::contains_word "$selected_ids" "$id"; then
      selected=1
    else
      selected=0
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

install::select_profile() {
  local profile_options=()

  install::read_records_into_array profile_options catalog::profile_records
  install::apply_single_selection_to_records profile_options "${DOTFILES_INSTALL_PROFILE:-recommended}"
  prompt::select DOTFILES_INSTALL_PROFILE "Select installation profile." "$(install::select_prompt_hint)" "${profile_options[@]}"
  DOTFILES_INSTALL_PROFILE_LABEL="$(catalog::profile_label "$DOTFILES_INSTALL_PROFILE")"
  install::apply_profile_defaults
}

install::apply_profile_defaults() {
  if [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    DOTFILES_SELECTED_MODULES=""
    DOTFILES_REQUESTED_MODULES=""
    return 0
  fi

  DOTFILES_SELECTED_MODULES="$(catalog::profile_default_modules "$DOTFILES_INSTALL_PROFILE" "$DOTFILES_PLATFORM")"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
}

install::maybe_select_theme() {
  if install::plan_needs_theme_prompt; then
    DOTFILES_THEME_NEEDED="1"
    DOTFILES_RUN_THEME_INSTALL="1"
    install::select_theme
    return 0
  fi

  DOTFILES_THEME_NEEDED="0"
  DOTFILES_RUN_THEME_INSTALL="0"
}

install::maybe_select_package_manager() {
  if install::plan_needs_package_manager; then
    DOTFILES_PACKAGE_MANAGER_NEEDED="1"
    install::select_package_manager
    return 0
  fi

  DOTFILES_PACKAGE_MANAGER_NEEDED="0"
}

install::select_package_manager() {
  local selected_package_manager=""
  local options=()

  case "$DOTFILES_PLATFORM" in
    macos)
      DOTFILES_PACKAGE_MANAGER="brew"
      prompt::summary "Package manager" "Homebrew"
      ;;
    wsl)
      options[0]=$'apt\tapt\tUse Ubuntu/Debian packages through apt-get.\t0\t0'
      options[1]=$'brew\tHomebrew\tUse Homebrew on Linux for the main install flow.\t0\t0'
      install::apply_single_selection_to_records options "${DOTFILES_PACKAGE_MANAGER:-apt}"
      prompt::select selected_package_manager "Select a package manager." "$(install::select_prompt_hint)" "${options[@]}"
      DOTFILES_PACKAGE_MANAGER="$selected_package_manager"
      ;;
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        DOTFILES_PACKAGE_MANAGER="apt"
      else
        DOTFILES_PACKAGE_MANAGER="brew"
      fi
      prompt::summary "Package manager" "$DOTFILES_PACKAGE_MANAGER"
      ;;
  esac
}

install::select_theme() {
  local theme_options=()

  install::read_records_into_array theme_options catalog::theme_records
  install::annotate_theme_records theme_options
  prompt::select DOTFILES_THEME "Select a shell theme." "$(install::select_prompt_hint)" "${theme_options[@]}"
}

install::select_prompt_hint() {
  echo "Use ↑/↓ to choose, Enter to confirm."
}

install::multiselect_prompt_hint() {
  echo "Use ↑/↓ to move, Space to toggle, Enter to confirm."
}

install::select_modules() {
  local module_options=()

  install::read_records_into_array module_options catalog::module_records "$DOTFILES_PLATFORM"
  install::apply_multi_selection_to_records module_options "$DOTFILES_SELECTED_MODULES"
  prompt::multiselect DOTFILES_SELECTED_MODULES "Select installation modules." "$(install::multiselect_prompt_hint)" "${module_options[@]}"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
}

install::leaf_prompt_title() {
  case "$1" in
    packages) echo "Select base CLI packages." ;;
    oh_my_zsh) echo "Select oh-my-zsh plugins." ;;
    fonts) echo "Select fonts to install." ;;
    desktop_apps) echo "Select desktop apps to install." ;;
  esac
}

install::leaf_prompt_hint() {
  case "$1" in
    packages) echo "Use ↑/↓ to move, Space to toggle packages, Enter to confirm." ;;
    oh_my_zsh) echo "Use ↑/↓ to move, Space to toggle plugins, Enter to confirm." ;;
    fonts) echo "Use ↑/↓ to move, Space to toggle fonts, Enter to confirm." ;;
    desktop_apps) echo "Use ↑/↓ to move, Space to toggle apps, Enter to confirm." ;;
  esac
}

install::load_leaf_records() {
  local module_id="$1"
  local array_name="$2"

  case "$module_id" in
    packages)
      install::read_records_into_array "$array_name" catalog::package_records "$DOTFILES_PACKAGE_MANAGER"
      install::annotate_package_records "$array_name"
      ;;
    oh_my_zsh)
      install::read_records_into_array "$array_name" catalog::omz_plugin_records
      install::annotate_omz_plugin_records "$array_name"
      ;;
    fonts)
      install::read_records_into_array "$array_name" catalog::font_records
      install::annotate_font_records "$array_name"
      ;;
    desktop_apps)
      install::read_records_into_array "$array_name" catalog::desktop_app_records
      install::annotate_desktop_app_records "$array_name"
      ;;
  esac
}

install::prepare_leaf_options() {
  local module_id="$1"
  local array_name="$2"

  install::load_leaf_records "$module_id" "$array_name"
  if install::module_item_state_exists "$module_id"; then
    install::apply_multi_selection_to_records "$array_name" "$(install::get_module_items "$module_id")"
  else
    install::apply_profile_leaf_defaults "$module_id" "$array_name"
  fi
}

install::apply_profile_leaf_defaults() {
  local module_id="$1"
  local array_name="$2"
  local default_item_ids=""
  local count index=0
  local record id label description selected disabled status

  default_item_ids="$(catalog::profile_default_item_ids "$DOTFILES_INSTALL_PROFILE" "$module_id")"
  [[ -n "$default_item_ids" ]] || return 0

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled="$(prompt::record_field "$record" 5)"
    status="$(prompt::record_field "$record" 6)"

    if [[ "$disabled" == "1" ]]; then
      selected=0
    elif install::contains_word "$default_item_ids" "$id"; then
      selected=1
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

install::apply_leaf_selection() {
  local module_id="$1"
  local leaf_ids="$2"
  local selectable_count="$3"
  shift 3 || true

  local leaf_labels=""

  leaf_labels="$(install::selected_labels_for_items "$module_id" "$leaf_ids" "$@")"
  install::set_module_items "$module_id" "$leaf_ids" "$leaf_labels"

  case "$module_id" in
    packages|fonts|desktop_apps)
      if [[ -z "$leaf_ids" ]]; then
        install::clear_module_items "$module_id"
        DOTFILES_SELECTED_MODULES="$(install::remove_word "$DOTFILES_SELECTED_MODULES" "$module_id")"
        if [[ "$selectable_count" == "0" ]]; then
          SKIP_NOTES[${#SKIP_NOTES[@]}]="$(catalog::module_label "$module_id") was skipped because all available items are already installed."
        else
          SKIP_NOTES[${#SKIP_NOTES[@]}]="$(catalog::module_label "$module_id") was skipped because no items were selected."
        fi
      fi
      ;;
    oh_my_zsh)
      if [[ -z "$leaf_labels" ]]; then
        if [[ "$selectable_count" == "0" ]]; then
          install::set_module_items "$module_id" "$leaf_ids" "All visible plugins are already installed"
        else
          install::set_module_items "$module_id" "$leaf_ids" "No extra plugins selected"
        fi
      fi
      ;;
  esac
}

install::clear_unselected_leaf_item_state() {
  local module_id

  for module_id in $LEAF_MODULES; do
    if install::module_is_selected "$module_id"; then
      continue
    fi

    install::clear_module_items "$module_id"
  done
}

install::prompt_for_leaf_items() {
  local reviewable_only="${1:-no}"
  local module_id leaf_ids selectable_count
  local leaf_options=()

  for module_id in "${MODULE_ORDER[@]}"; do
    if ! install::module_is_selected "$module_id"; then
      continue
    fi

    if ! catalog::module_is_leaf "$module_id"; then
      continue
    fi

    install::prepare_leaf_options "$module_id" leaf_options
    selectable_count="$(install::count_selectable_records "${leaf_options[@]}")"
    if [[ "$reviewable_only" == "yes" && "$selectable_count" -eq 0 ]]; then
      install::apply_leaf_selection "$module_id" "$(install::selected_ids_from_records "${leaf_options[@]}")" "$selectable_count" "${leaf_options[@]}"
      continue
    fi
    prompt::multiselect leaf_ids "$(install::leaf_prompt_title "$module_id")" "$(install::leaf_prompt_hint "$module_id")" "${leaf_options[@]}"
    install::apply_leaf_selection "$module_id" "$leaf_ids" "$selectable_count" "${leaf_options[@]}"
  done
}

install::apply_default_leaf_items() {
  local module_id leaf_ids selectable_count
  local leaf_options=()

  for module_id in "${MODULE_ORDER[@]}"; do
    if ! install::module_is_selected "$module_id"; then
      continue
    fi

    if ! catalog::module_is_leaf "$module_id"; then
      continue
    fi

    install::prepare_leaf_options "$module_id" leaf_options
    selectable_count="$(install::count_selectable_records "${leaf_options[@]}")"
    leaf_ids="$(install::selected_ids_from_records "${leaf_options[@]}")"
    install::apply_leaf_selection "$module_id" "$leaf_ids" "$selectable_count" "${leaf_options[@]}"
  done
}

install::plan_has_reviewable_leaf_modules() {
  local module_id selectable_count
  local leaf_options=()

  for module_id in "${MODULE_ORDER[@]}"; do
    if ! install::module_is_selected "$module_id"; then
      continue
    fi

    if ! catalog::module_is_leaf "$module_id"; then
      continue
    fi

    install::prepare_leaf_options "$module_id" leaf_options
    selectable_count="$(install::count_selectable_records "${leaf_options[@]}")"
    if [[ "$selectable_count" -gt 0 ]]; then
      return 0
    fi
  done

  return 1
}

install::maybe_review_leaf_items() {
  DOTFILES_REVIEW_SELECTED_ITEMS="no"

  if [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    DOTFILES_REVIEW_SELECTED_ITEMS="yes"
    install::prompt_for_leaf_items
    return 0
  fi

  if ! install::plan_has_reviewable_leaf_modules; then
    install::apply_default_leaf_items
    return 0
  fi

  prompt::confirm DOTFILES_REVIEW_SELECTED_ITEMS "Review selected items?" "no" "Enter to keep the current profile defaults."

  if [[ "$DOTFILES_REVIEW_SELECTED_ITEMS" == "yes" ]]; then
    install::prompt_for_leaf_items
  else
    install::apply_default_leaf_items
  fi
}

install::git_identity_state_exists() {
  case "${DOTFILES_GIT_IDENTITY_MODE:-}" in
    reuse_existing|skip_for_now|configure_now) return 0 ;;
    *) return 1 ;;
  esac
}

install::clear_git_identity_state() {
  DOTFILES_GIT_CONFIGURE_PERSONAL="no"
  DOTFILES_GIT_IDENTITY_MODE="not_needed"
  DOTFILES_GIT_NAME=""
  DOTFILES_GIT_EMAIL=""
  DOTFILES_GIT_SIGNING_MODE="none"
  DOTFILES_GIT_SIGNING_KEY=""
  DOTFILES_GIT_SUMMARY=""
}

install::refresh_plan_after_structure_edit() {
  install::clear_unselected_leaf_item_state
  install::maybe_select_theme
  install::maybe_select_package_manager
  install::resolve_install_plan
  install::maybe_review_leaf_items
  install::resolve_install_plan
  install::clear_unselected_leaf_item_state
}

install::refresh_plan_after_item_edit() {
  install::resolve_install_plan
  install::clear_unselected_leaf_item_state
}

install::summary_action_records() {
  local action_id action_label action_description is_selected
  local default_action=""

  if install::plan_has_execution_targets; then
    default_action="proceed"
  elif [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    default_action="edit_modules"
  else
    default_action="edit_profile"
  fi

  if install::plan_has_execution_targets; then
    is_selected=0
    [[ "$default_action" == "proceed" ]] && is_selected=1
    printf 'proceed\tProceed\tRun the current install plan now.\t%s\t0\n' "$is_selected"
  fi

  if [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    is_selected=0
    [[ "$default_action" == "edit_modules" ]] && is_selected=1
    printf 'edit_modules\tEdit modules\tReturn to the module picker for this custom plan.\t%s\t0\n' "$is_selected"
  else
    is_selected=0
    [[ "$default_action" == "edit_profile" ]] && is_selected=1
    printf 'edit_profile\tEdit profile\tChoose a different install profile and rebuild the plan.\t%s\t0\n' "$is_selected"
  fi

  if install::plan_has_reviewable_leaf_modules; then
    printf 'edit_items\tEdit selected items\tAdjust the current package, plugin, font, or app selections.\t0\t0\n'
  fi

  if install::module_is_selected "dotfiles"; then
    printf 'edit_git\tEdit Git identity\tReopen the machine-local Git identity flow for this plan.\t0\t0\n'
  fi

  printf 'cancel\tCancel\tExit without running the current install plan.\t0\t0\n'
}

install::select_summary_action() {
  local action_options=()

  install::read_records_into_array action_options install::summary_action_records
  prompt::select DOTFILES_SUMMARY_ACTION "Final summary actions." "$(install::select_prompt_hint)" "${action_options[@]}"
}

install::edit_summary_profile() {
  install::select_profile
  if [[ "$DOTFILES_INSTALL_PROFILE" == "custom" ]]; then
    install::select_modules
  fi
  install::refresh_plan_after_structure_edit
}

install::edit_summary_modules() {
  install::select_modules
  install::refresh_plan_after_structure_edit
}

install::edit_summary_items() {
  install::prompt_for_leaf_items yes
  install::refresh_plan_after_item_edit
}

install::ensure_git_identity_for_plan() {
  if ! install::module_is_selected "dotfiles"; then
    install::clear_git_identity_state
    return 0
  fi

  if install::git_identity_state_exists; then
    return 0
  fi

  install::prompt_for_git_identity
}

install::git_personal_config_path() {
  printf '%s/git/personal.local.ini' "${DOTFILES_CONFIG_DIR:-$(dotfiles::config_dir)}"
}

install::git_personal_config_display_path() {
  install::display_path "$(install::git_personal_config_path)"
}

install::git_email_is_valid() {
  local value="$1"
  [[ -n "$value" && "$value" == *"@"* && "$value" != *[[:space:]]* ]]
}

install::print_git_identity_file_summary() {
  local personal_file_display

  personal_file_display="$(install::git_personal_config_display_path)"
  prompt::summary "Machine-local Git config file." \
    "Path: $personal_file_display" \
    "The installer may create this file from the bundled example." \
    "You can edit this file directly later."
}

install::prompt_for_git_identity_mode() {
  local default_mode="${1:-skip_for_now}"
  local mode_options=()

  install::print_git_identity_file_summary
  mode_options[0]=$'reuse_existing\tReuse existing\tKeep the current machine-local Git file state unchanged.\t0\t0'
  mode_options[1]=$'skip_for_now\tSkip for now\tDo not write Git identity during this install run.\t0\t0'
  mode_options[2]=$'configure_now\tConfigure now\tEnter Git name, email, and signing values now.\t0\t0'
  install::apply_single_selection_to_records mode_options "$default_mode"
  prompt::select DOTFILES_GIT_IDENTITY_MODE "Machine-local Git identity." "$(install::select_prompt_hint)" "${mode_options[@]}"
}

install::collect_git_identity_values() {
  local confirm_values=""
  local personal_file_display=""
  local signing_key_summary=""

  personal_file_display="$(install::git_personal_config_display_path)"

  while true; do
    prompt::text DOTFILES_GIT_NAME "Git user.name" "" "no" "Used for commits created on this machine."
    prompt::text DOTFILES_GIT_EMAIL "Git user.email" "" "no" install::git_email_is_valid \
      "Enter an email address containing @ and no spaces." \
      "Used for commits created on this machine."
    prompt::select DOTFILES_GIT_SIGNING_MODE "Configure Git signing for this machine?" "$(install::select_prompt_hint)" \
      $'none\tNo signing\tDo not enable commit or tag signing.\t1\t0' \
      $'gpg\tGPG signing\tUse an OpenPGP key ID or fingerprint.\t0\t0' \
      $'ssh\tSSH signing\tUse SSH signing with gpg.format=ssh.\t0\t0'

    case "$DOTFILES_GIT_SIGNING_MODE" in
      gpg)
        prompt::text DOTFILES_GIT_SIGNING_KEY "Git user.signingKey" "" "no" "Enter the GPG key ID or full fingerprint."
        DOTFILES_GIT_SUMMARY="Machine-local Git identity with GPG signing at $personal_file_display."
        signing_key_summary="user.signingKey: $DOTFILES_GIT_SIGNING_KEY"
        ;;
      ssh)
        prompt::text DOTFILES_GIT_SIGNING_KEY "Git user.signingKey" "$HOME/.ssh/id_ed25519.pub" "no" "Enter the SSH public key path for Git signing."
        DOTFILES_GIT_SUMMARY="Machine-local Git identity with SSH signing at $personal_file_display."
        signing_key_summary="user.signingKey: $DOTFILES_GIT_SIGNING_KEY"
        ;;
      none)
        DOTFILES_GIT_SIGNING_KEY=""
        DOTFILES_GIT_SUMMARY="Machine-local Git identity without signing at $personal_file_display."
        signing_key_summary="user.signingKey: not set"
        ;;
    esac

    prompt::summary "Review machine-local Git identity." \
      "File: $personal_file_display" \
      "user.name: $DOTFILES_GIT_NAME" \
      "user.email: $DOTFILES_GIT_EMAIL" \
      "Signing mode: $DOTFILES_GIT_SIGNING_MODE" \
      "$signing_key_summary"
    prompt::confirm confirm_values "Use these Git values?" "yes" "Enter to confirm."

    if [[ "$confirm_values" == "yes" ]]; then
      break
    fi

    prompt::summary "Machine-local Git identity." "Re-enter the Git values below."
  done
}

install::prompt_for_git_identity() {
  local force_prompt="${1:-no}"
  local personal_file=""
  local personal_file_display
  local default_mode="skip_for_now"

  if ! install::module_is_selected "dotfiles"; then
    install::clear_git_identity_state
    return 0
  fi

  personal_file="$(install::git_personal_config_path)"
  personal_file_display="$(install::git_personal_config_display_path)"

  if [[ "$force_prompt" != "yes" ]] && ! dotfiles_git_personal_config_is_template "$personal_file"; then
    DOTFILES_GIT_IDENTITY_MODE="reuse_existing"
    DOTFILES_GIT_SUMMARY="Existing machine-local Git identity at $personal_file_display. You can edit it directly later."
    DOTFILES_GIT_CONFIGURE_PERSONAL="no"
    return 0
  fi

  case "${DOTFILES_GIT_IDENTITY_MODE:-}" in
    reuse_existing|skip_for_now|configure_now)
      default_mode="$DOTFILES_GIT_IDENTITY_MODE"
      ;;
    *)
      if ! dotfiles_git_personal_config_is_template "$personal_file"; then
        default_mode="reuse_existing"
      fi
      ;;
  esac

  install::prompt_for_git_identity_mode "$default_mode"

  case "$DOTFILES_GIT_IDENTITY_MODE" in
    reuse_existing)
      DOTFILES_GIT_CONFIGURE_PERSONAL="no"
      DOTFILES_GIT_SUMMARY="Current machine-local Git file state at $personal_file_display will be kept as-is. You can edit it directly later."
      ;;
    skip_for_now)
      DOTFILES_GIT_CONFIGURE_PERSONAL="no"
      DOTFILES_GIT_SUMMARY="Git identity setup skipped for now. Edit $personal_file_display directly later if needed."
      ;;
    configure_now)
      DOTFILES_GIT_CONFIGURE_PERSONAL="yes"
      install::collect_git_identity_values
      ;;
  esac
}

install::run_summary_action_loop() {
  while true; do
    install::ensure_git_identity_for_plan
    install::finalize_runtime_state
    install::print_plan_summary
    install::select_summary_action

    case "$DOTFILES_SUMMARY_ACTION" in
      proceed)
        return 0
        ;;
      edit_profile)
        install::edit_summary_profile
        ;;
      edit_modules)
        install::edit_summary_modules
        ;;
      edit_items)
        install::edit_summary_items
        ;;
      edit_git)
        install::prompt_for_git_identity yes
        ;;
      cancel)
        return 1
        ;;
    esac
  done
}
