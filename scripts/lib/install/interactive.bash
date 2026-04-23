# Interactive prompt flow for module, leaf item, theme, package manager, and Git identity choices.

maybe_select_theme() {
  if plan_needs_theme_prompt; then
    DOTFILES_THEME_NEEDED="1"
    DOTFILES_RUN_THEME_INSTALL="1"
    select_theme
    return 0
  fi

  DOTFILES_THEME_NEEDED="0"
  DOTFILES_RUN_THEME_INSTALL="0"
}

maybe_select_package_manager() {
  if plan_needs_package_manager; then
    DOTFILES_PACKAGE_MANAGER_NEEDED="1"
    select_package_manager
    return 0
  fi

  DOTFILES_PACKAGE_MANAGER_NEEDED="0"
}

select_package_manager() {
  local selected_package_manager=""
  local options=()

  case "$DOTFILES_PLATFORM" in
    macos)
      DOTFILES_PACKAGE_MANAGER="brew"
      prompt::summary "Package manager" "Homebrew"
      ;;
    wsl)
      options[0]=$'apt\tapt\tUse Ubuntu/Debian packages through apt-get.\t1\t0'
      options[1]=$'brew\tHomebrew\tUse Homebrew on Linux for the main install flow.\t0\t0'
      prompt::select selected_package_manager "Select a package manager." "$(select_prompt_hint)" "${options[@]}"
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

select_theme() {
  local theme_options=()

  read_records_into_array theme_options catalog::theme_records
  annotate_theme_records theme_options
  prompt::select DOTFILES_THEME "Select a shell theme." "$(select_prompt_hint)" "${theme_options[@]}"
}

select_prompt_hint() {
  echo "Use ↑/↓ to choose, Enter to confirm."
}

multiselect_prompt_hint() {
  echo "Use ↑/↓ to move, Space to toggle, Enter to confirm."
}

select_modules() {
  local module_options=()

  read_records_into_array module_options catalog::module_records "$DOTFILES_PLATFORM"
  prompt::multiselect DOTFILES_SELECTED_MODULES "Select installation modules." "$(multiselect_prompt_hint)" "${module_options[@]}"
  DOTFILES_REQUESTED_MODULES="$DOTFILES_SELECTED_MODULES"
}

leaf_prompt_title() {
  case "$1" in
    packages) echo "Select base CLI packages." ;;
    oh_my_zsh) echo "Select oh-my-zsh plugins." ;;
    fonts) echo "Select fonts to install." ;;
    desktop_apps) echo "Select desktop apps to install." ;;
  esac
}

leaf_prompt_hint() {
  case "$1" in
    packages) echo "Use ↑/↓ to move, Space to toggle packages, Enter to confirm." ;;
    oh_my_zsh) echo "Use ↑/↓ to move, Space to toggle plugins, Enter to confirm." ;;
    fonts) echo "Use ↑/↓ to move, Space to toggle fonts, Enter to confirm." ;;
    desktop_apps) echo "Use ↑/↓ to move, Space to toggle apps, Enter to confirm." ;;
  esac
}

load_leaf_records() {
  local module_id="$1"
  local array_name="$2"

  case "$module_id" in
    packages)
      read_records_into_array "$array_name" catalog::package_records "$DOTFILES_PACKAGE_MANAGER"
      annotate_package_records "$array_name"
      ;;
    oh_my_zsh)
      read_records_into_array "$array_name" catalog::omz_plugin_records
      annotate_omz_plugin_records "$array_name"
      ;;
    fonts)
      read_records_into_array "$array_name" catalog::font_records
      annotate_font_records "$array_name"
      ;;
    desktop_apps)
      read_records_into_array "$array_name" catalog::desktop_app_records
      annotate_desktop_app_records "$array_name"
      ;;
  esac
}

prompt_for_leaf_items() {
  local module_id leaf_ids leaf_labels selectable_count
  local leaf_options=()

  for module_id in "${MODULE_ORDER[@]}"; do
    if ! module_is_selected "$module_id"; then
      continue
    fi

    if ! catalog::module_is_leaf "$module_id"; then
      continue
    fi

    load_leaf_records "$module_id" leaf_options
    selectable_count="$(count_selectable_records "${leaf_options[@]}")"
    prompt::multiselect leaf_ids "$(leaf_prompt_title "$module_id")" "$(leaf_prompt_hint "$module_id")" "${leaf_options[@]}"
    leaf_labels="$(selected_labels_for_items "$module_id" "$leaf_ids" "${leaf_options[@]}")"
    set_module_items "$module_id" "$leaf_ids" "$leaf_labels"

    case "$module_id" in
      packages|fonts|desktop_apps)
        if [[ -z "$leaf_ids" ]]; then
          DOTFILES_SELECTED_MODULES="$(remove_word "$DOTFILES_SELECTED_MODULES" "$module_id")"
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
            set_module_items "$module_id" "$leaf_ids" "All visible plugins are already installed"
          else
            set_module_items "$module_id" "$leaf_ids" "No extra plugins selected"
          fi
        fi
        ;;
    esac
  done
}

git_personal_config_path() {
  printf '%s/git/personal.local.ini' "$DOTFILES_CONFIG_DIR"
}

git_personal_config_display_path() {
  display_path "$(git_personal_config_path)"
}

git_email_is_valid() {
  local value="$1"
  [[ -n "$value" && "$value" == *"@"* && "$value" != *[[:space:]]* ]]
}

collect_git_identity_values() {
  local confirm_values=""
  local personal_file_display
  local signing_key_summary=""

  personal_file_display="$(git_personal_config_display_path)"
  prompt::summary "Machine-local Git config file." \
    "Path: $personal_file_display" \
    "The installer may create this file from the bundled example." \
    "You can edit this file directly later."

  while true; do
    prompt::text DOTFILES_GIT_NAME "Git user.name" "" "no" "Used for commits created on this machine."
    prompt::text DOTFILES_GIT_EMAIL "Git user.email" "" "no" git_email_is_valid \
      "Enter an email address containing @ and no spaces." \
      "Used for commits created on this machine."
    prompt::select DOTFILES_GIT_SIGNING_MODE "Configure Git signing for this machine?" "$(select_prompt_hint)" \
      $'none\tNo signing\tDo not enable commit or tag signing.\t1\t0' \
      $'gpg\tGPG signing\tUse an OpenPGP key ID or fingerprint.\t0\t0' \
      $'ssh\tSSH signing\tUse SSH signing with gpg.format=ssh.\t0\t0'

    case "$DOTFILES_GIT_SIGNING_MODE" in
      gpg)
        prompt::text DOTFILES_GIT_SIGNING_KEY "Git user.signingKey" "" "no" "Enter the GPG key ID or full fingerprint."
        DOTFILES_GIT_SUMMARY="Write Git identity with GPG signing to $personal_file_display."
        signing_key_summary="user.signingKey: $DOTFILES_GIT_SIGNING_KEY"
        ;;
      ssh)
        prompt::text DOTFILES_GIT_SIGNING_KEY "Git user.signingKey" "$HOME/.ssh/id_ed25519.pub" "no" "Enter the SSH public key path for Git signing."
        DOTFILES_GIT_SUMMARY="Write Git identity with SSH signing to $personal_file_display."
        signing_key_summary="user.signingKey: $DOTFILES_GIT_SIGNING_KEY"
        ;;
      none)
        DOTFILES_GIT_SIGNING_KEY=""
        DOTFILES_GIT_SUMMARY="Write Git identity without signing to $personal_file_display."
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

prompt_for_git_identity() {
  local personal_file configure_now=""
  local personal_file_display

  if ! module_is_selected "dotfiles"; then
    DOTFILES_GIT_SUMMARY="Dotfiles module not selected."
    return 0
  fi

  personal_file="$(git_personal_config_path)"
  personal_file_display="$(git_personal_config_display_path)"

  if ! dotfiles_git_personal_config_is_template "$personal_file"; then
    DOTFILES_GIT_SUMMARY="Reuse existing machine-local Git identity at $personal_file_display. You can edit it directly later."
    return 0
  fi

  prompt::confirm configure_now "Configure machine-local Git identity now?" "yes" "Enter to confirm."

  if [[ "$configure_now" != "yes" ]]; then
    DOTFILES_GIT_CONFIGURE_PERSONAL="no"
    DOTFILES_GIT_SUMMARY="Skip Git identity setup for now. Edit $personal_file_display directly later if needed."
    return 0
  fi

  DOTFILES_GIT_CONFIGURE_PERSONAL="yes"
  collect_git_identity_values
}
