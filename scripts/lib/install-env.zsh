#!/bin/zsh

dotfiles::write_install_env() {
  local env_file_exists=0
  local tmp_file=""
  local config_dir="${DOTFILES_CONFIG_DIR:-$(dotfiles::config_dir)}"
  local install_env_path="${DOTFILES_INSTALL_ENV:-$(dotfiles::install_env_path)}"

  dotfiles::ensure_dir "$config_dir"
  [[ -e "$install_env_path" ]] && env_file_exists=1

  tmp_file="$(mktemp "$config_dir/install.env.tmp.XXXXXX")"

  {
    printf 'export DOTFILES_PLATFORM=%q\n' "$DOTFILES_PLATFORM"
    printf 'export DOTFILES_PACKAGE_MANAGER=%q\n' "$DOTFILES_PACKAGE_MANAGER"
    printf 'export DOTFILES_THEME=%q\n' "$DOTFILES_THEME"
    printf 'export DOTFILES_ENABLE_OH_MY_ZSH=%q\n' "$DOTFILES_ENABLE_OH_MY_ZSH"
    printf 'export DOTFILES_ROOT=%q\n' "$DOTFILES_ROOT"
  } >"$tmp_file"

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$install_env_path"

  export DOTFILES_CONFIG_DIR="$config_dir"
  export DOTFILES_INSTALL_ENV="$install_env_path"

  if [[ "$env_file_exists" == "1" ]]; then
    dotfiles::record_file_updated "$install_env_path"
  else
    dotfiles::record_file_created "$install_env_path"
  fi
  dotfiles::record_completed_work "Saved installer state"
  dotfiles::log_success "Wrote installer state to $install_env_path"
}
