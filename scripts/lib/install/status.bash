# Installed/current status detection for interactive prompt records.

package_command_name() {
  local package_id="$1"

  case "$DOTFILES_PACKAGE_MANAGER:$package_id" in
    apt:fd) printf 'fdfind' ;;
    *:gnupg) printf 'gpg' ;;
    *) printf '%s' "$package_id" ;;
  esac
}

package_is_installed() {
  local package_id="$1"
  local command_name

  command_name="$(package_command_name "$package_id")"
  command -v "$command_name" >/dev/null 2>&1
}

omz_plugin_is_installed() {
  [[ -d "$HOME/.oh-my-zsh/custom/plugins/$1" ]]
}

brew_cask_is_installed() {
  local cask_name="$1"
  local brew_bin=""

  brew_bin="$(find_brew 2>/dev/null || true)"
  [[ -n "$brew_bin" ]] || return 1

  "$brew_bin" list --cask "$cask_name" >/dev/null 2>&1
}

bundled_font_family_is_installed() {
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

font_is_installed() {
  local font_id="$1"
  local font_kind font_source

  font_kind="$(catalog::font_kind "$font_id")"
  font_source="$(catalog::font_source "$font_id")"

  case "$font_kind" in
    cask) brew_cask_is_installed "$font_source" ;;
    bundled) bundled_font_family_is_installed "$font_source" ;;
    *) return 1 ;;
  esac
}

desktop_app_is_installed() {
  brew_cask_is_installed "$1"
}

theme_status_for() {
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

annotate_theme_records() {
  local array_name="$1"
  local count index=0
  local record id label description status selected

  count="$(array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    status="$(theme_status_for "$id")"
    selected=0

    if [[ "$id" == "$DOTFILES_THEME" ]]; then
      selected=1
    fi

    array_record_set "$array_name" "$index" "$(compose_prompt_record "$id" "$label" "$description" "$selected" "0" "$status")"
    index=$((index + 1))
  done
}

annotate_package_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if package_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    array_record_set "$array_name" "$index" "$(compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

annotate_omz_plugin_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if omz_plugin_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    array_record_set "$array_name" "$index" "$(compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

annotate_font_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if font_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    array_record_set "$array_name" "$index" "$(compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}

annotate_desktop_app_records() {
  local array_name="$1"
  local count index=0
  local record id label description selected disabled status

  count="$(array_record_count "$array_name")"
  while [[ "$index" -lt "$count" ]]; do
    record="$(array_record_get "$array_name" "$index")"
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    selected="$(prompt::record_field "$record" 4)"
    disabled=0
    status=""

    if desktop_app_is_installed "$id"; then
      selected=0
      disabled=1
      status="installed"
    fi

    array_record_set "$array_name" "$index" "$(compose_prompt_record "$id" "$label" "$description" "$selected" "$disabled" "$status")"
    index=$((index + 1))
  done
}
