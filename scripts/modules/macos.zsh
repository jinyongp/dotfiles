#!/bin/zsh

module_fonts_supported() {
  platform::is_macos
}

module_fonts_summary() {
  echo "Install Nerd Fonts and bundled fonts"
}

module_fonts_details() {
  echo "Installs Fira Code Nerd Font and Victor Mono Nerd Font via Homebrew casks."
  echo "Also copies bundled font files from the repository's assets/fonts directory into ~/Library/Fonts."
  echo "Useful for starship/powerlevel10k glyph rendering in terminal apps."
}

module_fonts_install() {
  local font_path font_name

  dotfiles::log_step "Installing fonts"
  package_manager::install_brew_cask font-fira-code-nerd-font
  package_manager::install_brew_cask font-victor-mono-nerd-font

  mkdir -p "$HOME/Library/Fonts"

  while IFS= read -r font_path; do
    font_name="${font_path:t}"
    cp "$font_path" "$HOME/Library/Fonts/$font_name"
    dotfiles::log_info "Installed bundled font: $font_name"
  done < <(find "$DOTFILES_ROOT/assets/fonts" -type f \( -name '*.otf' -o -name '*.ttf' \) 2>/dev/null)
}

module_desktop_apps_supported() {
  platform::is_macos
}

module_desktop_apps_summary() {
  echo "Install macOS desktop applications"
}

module_desktop_apps_details() {
  echo "Installs these macOS apps via Homebrew cask: Arc, iTerm2, Raycast, Keka, KekaExternalHelper, Karabiner-Elements, Visual Studio Code."
  echo "This is the most invasive macOS-only option because it installs GUI applications."
}

module_desktop_apps_install() {
  local cask_name
  local casks=(
    arc
    iterm2
    raycast
    keka
    kekaexternalhelper
    karabiner-elements
    visual-studio-code
  )

  dotfiles::log_step "Installing desktop applications"

  for cask_name in "${casks[@]}"; do
    package_manager::install_brew_cask "$cask_name"
  done
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

  dotfiles::log_step "Applying macOS defaults"
  mkdir -p "$keybindings_dir"

  cat >"$keybindings_file" <<'EOF'
{
  "₩" = ("insertText:", "\`");
  "~₩" = ("insertText:", "₩");
}
EOF

  dotfiles::log_success "Updated $keybindings_file"
}
