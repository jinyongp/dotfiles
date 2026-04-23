#!/bin/zsh

theme::install_starship_fallback() {
  local installer_url installer_path bin_dir

  installer_url="https://starship.rs/install.sh"
  installer_path="$(mktemp)"
  bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"

  package_manager::ensure_command curl curl 1
  dotfiles::ensure_dir "$bin_dir"
  dotfiles::download_script "$installer_url" "$installer_path"
  dotfiles::execution_record_event installing "starship prompt binary (fallback installer)"
  sh "$installer_path" -y -b "$bin_dir"
  dotfiles::record_installed "starship prompt binary (fallback installer)"
  rm -f "$installer_path"
}

module_theme_install() {
  dotfiles::log_step "Installing theme dependencies"

  case "$DOTFILES_THEME" in
    starship)
      if ! command -v starship >/dev/null 2>&1; then
        package_manager::install_logical starship 0 || true
      else
        dotfiles::record_reused "starship prompt binary"
      fi

      if ! command -v starship >/dev/null 2>&1; then
        theme::install_starship_fallback
      fi
      ;;
    powerlevel10k)
      if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        shell::ensure_core_tools
        shell::ensure_oh_my_zsh
        shell::ensure_default_shell
      fi

      if [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
        dotfiles::record_reused "powerlevel10k theme"
        dotfiles::log_info "powerlevel10k is already installed."
      else
        package_manager::ensure_command git git 1
        dotfiles::execution_record_event installing "powerlevel10k theme"
        git clone --depth=1 \
          https://github.com/romkatv/powerlevel10k.git \
          "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
        dotfiles::record_installed "powerlevel10k theme"
      fi
      ;;
    default|none)
      dotfiles::record_skipped "Theme dependencies for '$(catalog::theme_label "$DOTFILES_THEME")'"
      dotfiles::log_info "No extra dependencies are required for theme '$DOTFILES_THEME'."
      ;;
    *)
      dotfiles::log_warn "Unknown theme '$DOTFILES_THEME'; skipping theme setup."
      ;;
  esac
}
