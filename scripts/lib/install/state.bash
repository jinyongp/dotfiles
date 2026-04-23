# Installer state defaults and small data-structure helpers.

MODULE_ORDER=(
  packages
  dotfiles
  oh_my_zsh
  neovim
  fonts
  desktop_apps
  macos_defaults
)

LEAF_MODULES="packages oh_my_zsh fonts desktop_apps"

# Mutable installer state is initialized explicitly so tests and entrypoints can
# reset plan state without re-sourcing libraries.
install::init_state() {
  local module_id

  DOTFILES_PLATFORM=""
  DOTFILES_PLATFORM_LABEL=""
  DOTFILES_INSTALL_PROFILE=""
  DOTFILES_INSTALL_PROFILE_LABEL=""
  DOTFILES_REVIEW_SELECTED_ITEMS=""
  DOTFILES_PACKAGE_MANAGER=""
  DOTFILES_THEME=""
  DOTFILES_ENABLE_OH_MY_ZSH="0"
  DOTFILES_SELECTED_MODULES=""
  DOTFILES_GIT_CONFIGURE_PERSONAL="no"
  DOTFILES_GIT_IDENTITY_MODE=""
  DOTFILES_GIT_NAME=""
  DOTFILES_GIT_EMAIL=""
  DOTFILES_GIT_SIGNING_MODE="none"
  DOTFILES_GIT_SIGNING_KEY=""
  DOTFILES_GIT_SUMMARY=""
  DOTFILES_BOOTSTRAP_ZSH_STATUS="none"
  DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER=""
  DOTFILES_RUN_THEME_INSTALL="1"
  DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="1"
  DOTFILES_REQUESTED_MODULES=""
  DOTFILES_AUTO_SELECTED_MODULES=""
  DOTFILES_SAVED_THEME=""
  DOTFILES_SAVED_ENABLE_OH_MY_ZSH=""
  DOTFILES_THEME_NEEDED="0"
  DOTFILES_PACKAGE_MANAGER_NEEDED="0"

  AUTO_NOTES=()
  REUSE_NOTES=()
  SKIP_NOTES=()

  for module_id in "${MODULE_ORDER[@]}"; do
    unset "MODULE_ITEMS_${module_id}"
    unset "MODULE_ITEM_LABELS_${module_id}"
  done
}

install::contains_word() {
  local list="$1"
  local word="$2"

  case " $list " in
    *" $word "*) return 0 ;;
    *) return 1 ;;
  esac
}

install::add_word() {
  local list="$1"
  local word="$2"

  if install::contains_word "$list" "$word"; then
    printf '%s' "$list"
    return 0
  fi

  if [[ -n "$list" ]]; then
    printf '%s %s' "$list" "$word"
  else
    printf '%s' "$word"
  fi
}

install::remove_word() {
  local list="$1"
  local word="$2"
  local rebuilt=""
  local item

  for item in $list; do
    if [[ "$item" == "$word" ]]; then
      continue
    fi

    if [[ -n "$rebuilt" ]]; then
      rebuilt="$rebuilt $item"
    else
      rebuilt="$item"
    fi
  done

  printf '%s' "$rebuilt"
}

install::set_named_value() {
  local variable_name="$1"
  local named_value="$2"

  printf -v "$variable_name" '%s' "$named_value"
}

install::get_named_value() {
  local variable_name="$1"
  eval "printf '%s' \"\${$variable_name-}\""
}

install::read_records_into_array() {
  local array_name="$1"
  shift

  local line
  local index=0
  local quoted_line=""

  eval "$array_name=()"

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    quoted_line="$(printf '%q' "$line")"
    # shellcheck disable=SC1087
    eval "${array_name}[$index]=$quoted_line"
    index=$((index + 1))
  done < <("$@")
}

install::module_is_selected() {
  install::contains_word "$DOTFILES_SELECTED_MODULES" "$1"
}

install::module_item_var_name() {
  printf 'MODULE_ITEMS_%s' "$1"
}

install::module_item_labels_var_name() {
  printf 'MODULE_ITEM_LABELS_%s' "$1"
}

install::set_module_items() {
  local module_id="$1"
  local selected_ids="$2"
  local selected_labels="$3"

  install::set_named_value "$(install::module_item_var_name "$module_id")" "$selected_ids"
  install::set_named_value "$(install::module_item_labels_var_name "$module_id")" "$selected_labels"
}

install::get_module_items() {
  install::get_named_value "$(install::module_item_var_name "$1")"
}

install::get_module_item_labels() {
  install::get_named_value "$(install::module_item_labels_var_name "$1")"
}

install::item_label_for() {
  catalog::item_label "$1" "$2"
}

install::selected_labels_for_items() {
  local module_id="$1"
  local selected_ids="$2"
  shift 2 || true

  prompt::selected_labels_from_records "$selected_ids" "$@"
}

install::selected_ids_from_records() {
  local record id selected
  local selected_ids=""

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    selected="$(prompt::record_field "$record" 4)"

    if [[ "$selected" == "1" ]]; then
      selected_ids="$(install::add_word "$selected_ids" "$id")"
    fi
  done

  printf '%s' "$selected_ids"
}

install::array_record_count() {
  local array_name="$1"
  eval "printf '%s' \"\${#${array_name}[@]}\""
}

install::array_record_get() {
  local array_name="$1"
  local index="$2"
  eval "printf '%s' \"\${${array_name}[$index]}\""
}

install::array_record_set() {
  local array_name="$1"
  local index="$2"
  local record="$3"
  local quoted_record

  quoted_record="$(printf '%q' "$record")"
  # shellcheck disable=SC1087
  eval "${array_name}[$index]=$quoted_record"
}

install::compose_prompt_record() {
  local id="$1"
  local label="$2"
  local description="$3"
  local is_selected="${4:-0}"
  local is_disabled="${5:-0}"
  local status="${6:-}"

  printf '%s\t%s\t%s\t%s\t%s\t%s' "$id" "$label" "$description" "$is_selected" "$is_disabled" "$status"
}

install::count_selectable_records() {
  local record
  local selectable=0

  for record in "$@"; do
    if [[ "$(prompt::record_field "$record" 5)" != "1" ]]; then
      selectable=$((selectable + 1))
    fi
  done

  printf '%s' "$selectable"
}

install::module_labels_for_selection() {
  local selection="$1"
  local labels=()
  local module_id

  for module_id in $selection; do
    labels[${#labels[@]}]="$(catalog::module_label "$module_id")"
  done

  if [[ "${#labels[@]}" -eq 0 ]]; then
    return 0
  fi

  prompt::join_by ", " "${labels[@]}"
}

install::module_labels_or_none() {
  local selection="$1"
  local selection_labels=""

  selection_labels="$(install::module_labels_for_selection "$selection")"
  if [[ -n "$selection_labels" ]]; then
    printf '%s' "$selection_labels"
  else
    printf 'None'
  fi
}
