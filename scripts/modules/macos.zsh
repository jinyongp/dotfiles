#!/bin/zsh

module_fonts_supported() {
  platform::is_macos
}

module_fonts_summary() {
  echo "Install selected fonts"
}

module_fonts_details() {
  echo "Installs only the selected Nerd Fonts or bundled font families."
}

macos::install_bundled_font_family() {
  local family_dir="$1"
  local font_path font_name

  mkdir -p "$HOME/Library/Fonts"

  while IFS= read -r font_path; do
    font_name="${font_path:t}"
    cp "$font_path" "$HOME/Library/Fonts/$font_name"
    dotfiles::log_info "Installed bundled font: $font_name"
  done < <(find "$DOTFILES_ROOT/assets/fonts/$family_dir" -type f \( -name '*.otf' -o -name '*.ttf' \) 2>/dev/null)
}

module_fonts_install_items() {
  local -a font_ids
  local font_id font_kind font_source

  if (( $# > 0 )); then
    font_ids=("$@")
  else
    font_ids=("${(@f)$(catalog::font_ids)}")
  fi

  dotfiles::log_step "Installing selected fonts"

  for font_id in "${font_ids[@]}"; do
    font_kind="$(catalog::font_kind "$font_id")"
    font_source="$(catalog::font_source "$font_id")"

    case "$font_kind" in
      cask)
        package_manager::install_brew_cask "$font_source"
        ;;
      bundled)
        macos::install_bundled_font_family "$font_source"
        dotfiles::record_installed "Bundled font family: $(catalog::font_label "$font_id")"
        ;;
      *)
        dotfiles::log_warn "Skipping unknown font item: $font_id"
        ;;
    esac
  done
}

module_fonts_install() {
  module_fonts_install_items
}

module_desktop_apps_supported() {
  platform::is_macos
}

module_desktop_apps_summary() {
  echo "Install selected macOS desktop applications"
}

module_desktop_apps_details() {
  echo "Installs only the selected macOS applications via Homebrew cask."
}

module_desktop_apps_install_items() {
  local -a cask_ids
  local cask_id

  if (( $# > 0 )); then
    cask_ids=("$@")
  else
    cask_ids=("${(@f)$(catalog::desktop_app_ids)}")
  fi

  dotfiles::log_step "Installing selected desktop applications"

  for cask_id in "${cask_ids[@]}"; do
    package_manager::install_brew_cask "$cask_id"
  done
}

module_desktop_apps_install() {
  module_desktop_apps_install_items
}

module_macos_defaults_supported() {
  platform::is_macos
}

module_macos_defaults_summary() {
  echo "Apply macOS keybinding defaults"
}

module_macos_defaults_details() {
  echo "Writes ~/Library/KeyBindings/DefaultKeyBinding.dict."
  echo "Adds the won-sign/backtick keybinding remap currently used in this dotfiles setup."
}

module_macos_defaults_install() {
  local keybindings_dir="$HOME/Library/KeyBindings"
  local keybindings_file="$keybindings_dir/DefaultKeyBinding.dict"
  local keybindings_exists=0

  dotfiles::log_step "Applying macOS defaults"
  mkdir -p "$keybindings_dir"
  [[ -e "$keybindings_file" ]] && keybindings_exists=1

  cat >"$keybindings_file" <<'EOF'
{
  "₩" = ("insertText:", "\`");
  "~₩" = ("insertText:", "₩");
}
EOF

  if [[ "$keybindings_exists" == "1" ]]; then
    dotfiles::record_file_updated "$keybindings_file"
  else
    dotfiles::record_file_created "$keybindings_file"
  fi
  dotfiles::log_success "Updated $keybindings_file"
}
