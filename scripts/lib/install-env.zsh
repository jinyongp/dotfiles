#!/bin/zsh

dotfiles::write_install_env() {
  local env_file_exists=0
  local tmp_file=""

  dotfiles::ensure_dir "$DOTFILES_CONFIG_DIR"
  [[ -e "$DOTFILES_INSTALL_ENV" ]] && env_file_exists=1

  tmp_file="$(mktemp "$DOTFILES_CONFIG_DIR/install.env.tmp.XXXXXX")"

  {
    printf 'export DOTFILES_PLATFORM=%q\n' "$DOTFILES_PLATFORM"
    printf 'export DOTFILES_PACKAGE_MANAGER=%q\n' "$DOTFILES_PACKAGE_MANAGER"
    printf 'export DOTFILES_THEME=%q\n' "$DOTFILES_THEME"
    printf 'export DOTFILES_ENABLE_OH_MY_ZSH=%q\n' "$DOTFILES_ENABLE_OH_MY_ZSH"
    printf 'export DOTFILES_ROOT=%q\n' "$DOTFILES_ROOT"
  } >"$tmp_file"

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$DOTFILES_INSTALL_ENV"

  if [[ "$env_file_exists" == "1" ]]; then
    dotfiles::record_file_updated "$DOTFILES_INSTALL_ENV"
  else
    dotfiles::record_file_created "$DOTFILES_INSTALL_ENV"
  fi
  dotfiles::record_completed_work "Saved installer state"
  dotfiles::log_success "Wrote installer state to $DOTFILES_INSTALL_ENV"
}
