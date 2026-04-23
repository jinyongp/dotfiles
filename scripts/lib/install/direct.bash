# Direct install target parsing and execution.

normalize_direct_target() {
  case "$1" in
    vim|nvim) printf 'neovim' ;;
    omz|oh-my-zsh) printf 'oh_my_zsh' ;;
    desktop-apps) printf 'desktop_apps' ;;
    macos-defaults) printf 'macos_defaults' ;;
    *) printf '%s' "$1" ;;
  esac
}

direct_target_exists() {
  local target="$1"
  local module_id

  if [[ "$target" == "theme" ]]; then
    return 0
  fi

  while IFS=$'\t' read -r module_id _; do
    [[ "$module_id" == "$target" ]] && return 0
  done < <(catalog::module_records "$DOTFILES_PLATFORM")

  return 1
}

module_supports_direct_items() {
  contains_word "$LEAF_MODULES" "$1"
}

load_direct_item_records() {
  local module_id="$1"
  local array_name="$2"

  case "$module_id" in
    packages) read_records_into_array "$array_name" catalog::package_records "$DOTFILES_PACKAGE_MANAGER" ;;
    oh_my_zsh) read_records_into_array "$array_name" catalog::omz_plugin_records ;;
    fonts) read_records_into_array "$array_name" catalog::font_records ;;
    desktop_apps) read_records_into_array "$array_name" catalog::desktop_app_records ;;
    *) eval "$array_name=()" ;;
  esac
}

direct_item_ids_for_module() {
  local module_id="$1"
  local records=()
  local record item_id
  local ids=()

  load_direct_item_records "$module_id" records

  for record in "${records[@]}"; do
    item_id="$(prompt::record_field "$record" 1)"
    ids[${#ids[@]}]="$item_id"
  done

  prompt::join_by ", " "${ids[@]}"
}

set_direct_items() {
  local module_id="$1"
  shift || true

  local selected_ids="$*"
  local records=()
  local selected_item_labels=""

  load_direct_item_records "$module_id" records

  if [[ -n "$selected_ids" ]]; then
    selected_item_labels="$(selected_labels_for_items "$module_id" "$selected_ids" "${records[@]}")"
  fi

  set_module_items "$module_id" "$selected_ids" "$selected_item_labels"
}

validate_direct_items() {
  local module_id="$1"
  shift || true

  local item_id record record_id
  local records=()
  local found=0

  if ! module_supports_direct_items "$module_id"; then
    if (( $# > 0 )); then
      color_red "Module '$module_id' does not accept item arguments."
      return 1
    fi

    return 0
  fi

  if (( $# == 0 )); then
    return 0
  fi

  load_direct_item_records "$module_id" records

  for item_id in "$@"; do
    found=0

    for record in "${records[@]}"; do
      record_id="$(prompt::record_field "$record" 1)"
      if [[ "$record_id" == "$item_id" ]]; then
        found=1
        break
      fi
    done

    if [[ "$found" -eq 0 ]]; then
      color_red "Unknown item '$item_id' for module '$module_id'."
      color_yellow "Available items: $(direct_item_ids_for_module "$module_id")"
      return 1
    fi
  done
}

direct_target_label() {
  local target="$1"

  if [[ "$target" == "theme" ]]; then
    printf 'Theme'
    return 0
  fi

  catalog::module_label "$target"
}

print_direct_usage() {
  cat <<EOF
Usage:
  $DOTFILES_ROOT/install
  $DOTFILES_ROOT/install list
  $DOTFILES_ROOT/install <module>
  $DOTFILES_ROOT/install <module> [item...]

Direct targets:
  packages
  dotfiles
  oh_my_zsh
  neovim
  fonts
  desktop_apps
  macos_defaults
  theme

Aliases:
  vim -> neovim
  nvim -> neovim
  omz -> oh_my_zsh

Examples:
  $DOTFILES_ROOT/install neovim
  $DOTFILES_ROOT/install packages fnm eza
  $DOTFILES_ROOT/install desktop_apps iterm2 raycast
  $DOTFILES_ROOT/install theme
EOF
}

print_direct_target_list() {
  local module_id module_description

  echo "Available direct install targets:"
  while IFS=$'\t' read -r module_id _ module_description _; do
    echo "  - $module_id: $module_description"
  done < <(catalog::module_records "$DOTFILES_PLATFORM")
  echo "  - theme: Install dependencies for the current shell theme (${DOTFILES_THEME:-starship})."
}

configure_direct_install() {
  local target="$1"
  shift || true

  target="$(normalize_direct_target "$target")"

  DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="0"
  DOTFILES_RUN_THEME_INSTALL="0"
  load_saved_runtime_defaults
  select_default_package_manager

  if ! direct_target_exists "$target"; then
    color_red "Unknown install target: $target"
    print_direct_target_list >&2
    return 1
  fi

  if [[ "$target" == "theme" ]]; then
    if (( $# > 0 )); then
      color_red "The theme target does not accept extra item arguments."
      return 1
    fi

    DOTFILES_RUN_THEME_INSTALL="1"
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="1"

    case "$DOTFILES_THEME" in
      powerlevel10k|default) DOTFILES_ENABLE_OH_MY_ZSH="1" ;;
    esac

    return 0
  fi

  validate_direct_items "$target" "$@"

  DOTFILES_SELECTED_MODULES="$target"

  if [[ "$target" == "oh_my_zsh" ]]; then
    DOTFILES_ENABLE_OH_MY_ZSH="1"
  fi

  if [[ "$target" == "dotfiles" || "$target" == "oh_my_zsh" ]]; then
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="1"
  fi

  if module_supports_direct_items "$target" && (( $# > 0 )); then
    set_direct_items "$target" "$@"
  fi
}

run_direct_install() {
  local target="$1"
  shift || true
  local zsh_bin=""
  local target_label=""
  local item_labels=""

  configure_direct_install "$target" "$@"
  target="$(normalize_direct_target "$target")"
  target_label="$(direct_target_label "$target")"

  log_step "Running direct install"
  color_yellow "Target: $target_label"
  color_yellow "Package manager: $DOTFILES_PACKAGE_MANAGER"
  color_yellow "Theme: $DOTFILES_THEME"

  if [[ "$target" != "theme" ]]; then
    item_labels="$(get_module_item_labels "$target")"
    if [[ -n "$item_labels" ]]; then
      color_yellow "Items: $item_labels"
    fi
  fi

  run_install_plan_or_exit "Direct install failed."
  color_green "Direct install complete."

  if should_auto_launch_zsh; then
    zsh_bin="$(find_zsh)"
    color_yellow "Starting a login zsh shell with the installed dotfiles config."
    if ! exec "$zsh_bin" -l; then
      color_red "Failed to start a login zsh shell automatically."
      color_yellow "Run this manually: exec zsh -l"
      exit 1
    fi
  fi
}
