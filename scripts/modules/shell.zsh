#!/bin/zsh

shell::ensure_core_tools() {
  package_manager::ensure_command curl curl 1
  package_manager::ensure_command git git 1
  package_manager::ensure_command zsh zsh 1
}

shell::ensure_oh_my_zsh() {
  local target_dir="$HOME/.oh-my-zsh"

  if [[ -d "$target_dir" ]]; then
    dotfiles::record_reused "oh-my-zsh framework"
    dotfiles::log_info "oh-my-zsh is already installed."
    return 0
  fi

  dotfiles::record_installed "oh-my-zsh framework"
  dotfiles::log_info "Cloning oh-my-zsh..."
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$target_dir"
}

shell::install_oh_my_zsh_plugins() {
  local plugin_root="$HOME/.oh-my-zsh/custom/plugins"
  local plugin_id repo_name target_dir
  local -a plugin_ids

  if (( $# > 0 )); then
    plugin_ids=("$@")
  else
    plugin_ids=()
  fi

  dotfiles::ensure_dir "$plugin_root"

  for plugin_id in "${plugin_ids[@]}"; do
    repo_name="$(catalog::omz_plugin_repo "$plugin_id")"

    if [[ -z "$repo_name" ]]; then
      dotfiles::log_warn "Skipping unknown oh-my-zsh plugin: $plugin_id"
      continue
    fi

    target_dir="$plugin_root/$plugin_id"

    if [[ -d "$target_dir" ]]; then
      dotfiles::record_reused "oh-my-zsh plugin: $plugin_id"
      dotfiles::log_info "Already installed: $plugin_id"
      continue
    fi

    dotfiles::record_installed "oh-my-zsh plugin: $plugin_id"
    dotfiles::log_info "Cloning $plugin_id..."
    git clone --depth=1 "https://github.com/$repo_name.git" "$target_dir"
  done
}

shell::ensure_default_shell() {
  local zsh_bin current_shell

  if ! platform::is_wsl; then
    return 0
  fi

  zsh_bin="$(command -v zsh || true)"

  if [[ -z "$zsh_bin" ]]; then
    dotfiles::log_warn "zsh is not available yet, skipping chsh."
    return 0
  fi

  current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)"

  if [[ "$current_shell" == "$zsh_bin" ]]; then
    dotfiles::record_reused "Default shell already set to zsh"
    dotfiles::log_info "Default shell is already zsh."
    return 0
  fi

  if chsh -s "$zsh_bin" "$USER"; then
    dotfiles::record_completed_work "Changed the default shell to $(dotfiles::display_path "$zsh_bin")"
    dotfiles::log_success "Changed default shell to $zsh_bin"
  else
    dotfiles::log_warn "Failed to change the default shell automatically."
    dotfiles::log_warn "Run this manually later: chsh -s $zsh_bin"
  fi
}

module_oh_my_zsh_supported() {
  return 0
}

module_oh_my_zsh_summary() {
  echo "Install oh-my-zsh and selected plugins"
}

module_oh_my_zsh_details() {
  echo "Installs zsh, curl, and git if needed, then clones oh-my-zsh into ~/.oh-my-zsh."
  echo "Also clones only the plugins selected during the bash prompt flow."
  if platform::is_wsl; then
    echo "On WSL, also tries to change your default shell to zsh with chsh."
  fi
}

module_oh_my_zsh_install_items() {
  dotfiles::log_step "Installing oh-my-zsh"
  shell::ensure_core_tools
  shell::ensure_oh_my_zsh
  shell::install_oh_my_zsh_plugins "$@"
  shell::ensure_default_shell
}

module_oh_my_zsh_install() {
  local -a plugin_ids=("${(@f)$(catalog::omz_plugin_ids)}")
  module_oh_my_zsh_install_items "${plugin_ids[@]}"
}
