# Installed/current status detection for interactive prompt records.

install::package_command_name() {
  catalog::package_command_name "$DOTFILES_PACKAGE_MANAGER" "$1"
}

install::package_is_installed() {
  local package_id="$1"
  local command_name

  command_name="$(install::package_command_name "$package_id")"
  command -v "$command_name" >/dev/null 2>&1
}

install::omz_plugin_is_installed() {
  [[ -d "$HOME/.oh-my-zsh/custom/plugins/$1" ]]
}

install::brew_cask_is_installed() {
  local cask_name="$1"
  local brew_bin=""

  brew_bin="$(install::find_brew 2>/dev/null || true)"
  [[ -n "$brew_bin" ]] || return 1

  "$brew_bin" list --cask "$cask_name" >/dev/null 2>&1
}

install::bundled_font_family_is_installed() {
  local family_dir="$1"
  local font_path
  local found_any=0

  while IFS= read -r font_path; do
    [[ -n "$font_path" ]] || continue
    found_any=1
    [[ -f "$HOME/Library/Fonts/${font_path##*/}" ]] || return 1
  done < <(find "$DOTFILES_ROOT/assets/fonts/$family_dir" -type f \( -name '*.otf' -o -name '*.ttf' \) 2>/dev/null)

  [[ "$found_any" == "1" ]]
}

install::font_is_installed() {
  local font_id="$1"
  local font_kind font_source

  font_kind="$(catalog::font_kind "$font_id")"
  font_source="$(catalog::font_source "$font_id")"

  case "$font_kind" in
    cask) install::brew_cask_is_installed "$font_source" ;;
    bundled) install::bundled_font_family_is_installed "$font_source" ;;
    *) return 1 ;;
  esac
}

install::desktop_app_is_installed() {
  install::brew_cask_is_installed "$(catalog::desktop_app_source "$1")"
}

install::theme_status_for() {
  local theme_id="$1"

  if [[ "$theme_id" == "$DOTFILES_SAVED_THEME" ]]; then
    printf 'current'
    return 0
  fi

  case "$theme_id" in
    starship)
      if command -v starship >/dev/null 2>&1; then
        printf 'installed'
      fi
      ;;
    powerlevel10k)
      if [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
        printf 'installed'
      fi
      ;;
  esac
}

install::annotate_theme_records() {
  local array_name="$1"
  local count index=0
  local record id label description status selected

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    status="$(install::theme_status_for "$id")"
    selected=0

    if [[ "$id" == "$DOTFILES_THEME" ]]; then
      selected=1
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "0" "$status")"
    index=$((index + 1))
  done
}

install::annotate_package_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if install::package_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

install::annotate_omz_plugin_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if install::omz_plugin_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

install::annotate_font_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if install::font_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

install::annotate_desktop_app_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(install::array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(install::array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if install::desktop_app_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    install::array_record_set "$array_name" "$index" "$(install::compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}
