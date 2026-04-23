# Serialization and execution of the zsh install runner plan.

write_plan_var() {
  local plan_file="$1"
  local variable_name="$2"
  local value="$3"

  printf 'export %s=%q\n' "$variable_name" "$value" >>"$plan_file"
}

write_install_plan() {
  local plan_file="$1"
  local module_id

  : >"$plan_file"

  write_plan_var "$plan_file" "DOTFILES_ROOT" "$DOTFILES_ROOT"
  write_plan_var "$plan_file" "DOTFILES_PLATFORM" "$DOTFILES_PLATFORM"
  write_plan_var "$plan_file" "DOTFILES_PACKAGE_MANAGER" "$DOTFILES_PACKAGE_MANAGER"
  write_plan_var "$plan_file" "DOTFILES_THEME" "$DOTFILES_THEME"
  write_plan_var "$plan_file" "DOTFILES_ENABLE_OH_MY_ZSH" "$DOTFILES_ENABLE_OH_MY_ZSH"
  write_plan_var "$plan_file" "DOTFILES_SELECTED_MODULES" "$DOTFILES_SELECTED_MODULES"
  write_plan_var "$plan_file" "DOTFILES_GIT_CONFIGURE_PERSONAL" "$DOTFILES_GIT_CONFIGURE_PERSONAL"
  write_plan_var "$plan_file" "DOTFILES_GIT_NAME" "$DOTFILES_GIT_NAME"
  write_plan_var "$plan_file" "DOTFILES_GIT_EMAIL" "$DOTFILES_GIT_EMAIL"
  write_plan_var "$plan_file" "DOTFILES_GIT_SIGNING_MODE" "$DOTFILES_GIT_SIGNING_MODE"
  write_plan_var "$plan_file" "DOTFILES_GIT_SIGNING_KEY" "$DOTFILES_GIT_SIGNING_KEY"
  write_plan_var "$plan_file" "DOTFILES_BOOTSTRAP_ZSH_STATUS" "$DOTFILES_BOOTSTRAP_ZSH_STATUS"
  write_plan_var "$plan_file" "DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER" "$DOTFILES_BOOTSTRAP_ZSH_PACKAGE_MANAGER"
  write_plan_var "$plan_file" "DOTFILES_RUN_THEME_INSTALL" "$DOTFILES_RUN_THEME_INSTALL"
  write_plan_var "$plan_file" "DOTFILES_ALLOW_AUTO_LAUNCH_ZSH" "$DOTFILES_ALLOW_AUTO_LAUNCH_ZSH"

  for module_id in "${MODULE_ORDER[@]}"; do
    write_plan_var "$plan_file" "DOTFILES_SELECTED_ITEMS_${module_id}" "$(get_module_items "$module_id")"
  done
}

run_install_plan() {
  local zsh_bin plan_file exit_code

  ensure_zsh "$DOTFILES_PLATFORM" "$DOTFILES_PACKAGE_MANAGER"
  zsh_bin="$(find_zsh)"
  plan_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-install-plan.XXXXXX")"

  write_install_plan "$plan_file"

  set +e
  "$zsh_bin" "$RUNNER" "$plan_file"
  exit_code=$?
  set -e

  rm -f "$plan_file"
  return "$exit_code"
}

run_install_plan_or_exit() {
  local failure_message="${1:-Installation failed.}"

  if run_install_plan; then
    return 0
  fi

  if [[ "${PROMPT__SESSION_OPEN:-0}" == "1" ]]; then
    prompt::cancel "$failure_message"
  else
    color_red "$failure_message"
  fi

  exit 1
}
