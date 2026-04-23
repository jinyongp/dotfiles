# Install plan requirement detection, dependency resolution, and final summaries.

plan_needs_theme_prompt() {
  module_is_selected "dotfiles" || module_is_selected "oh_my_zsh"
}

plan_needs_package_manager() {
  if module_is_selected "packages" \
    || module_is_selected "neovim" \
    || module_is_selected "oh_my_zsh" \
    || module_is_selected "fonts" \
    || module_is_selected "desktop_apps"; then
    return 0
  fi

  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" != "1" ]]; then
    return 1
  fi

  case "${DOTFILES_THEME:-none}" in
    starship)
      if command -v starship >/dev/null 2>&1; then
        return 1
      fi

      return 0
      ;;
    powerlevel10k)
      if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        return 0
      fi

      if ! command -v git >/dev/null 2>&1; then
        return 0
      fi

      return 1
      ;;
    default|none|"")
      if [[ ! -d "$HOME/.oh-my-zsh" && "${DOTFILES_THEME:-}" == "default" ]]; then
        return 0
      fi

      return 1
      ;;
  esac

  return 1
}

refresh_plan_requirements() {
  if plan_needs_theme_prompt; then
    DOTFILES_THEME_NEEDED="1"
  else
    DOTFILES_THEME_NEEDED="0"
  fi

  if plan_needs_package_manager; then
    DOTFILES_PACKAGE_MANAGER_NEEDED="1"
  else
    DOTFILES_PACKAGE_MANAGER_NEEDED="0"
  fi
}

plan_has_execution_targets() {
  [[ -n "${DOTFILES_SELECTED_MODULES:-}" || "${DOTFILES_RUN_THEME_INSTALL:-0}" == "1" ]]
}

record_auto_selected_module() {
  local module_id="$1"
  local reason="$2"

  if module_is_selected "$module_id"; then
    return 0
  fi

  DOTFILES_SELECTED_MODULES="$(add_word "$DOTFILES_SELECTED_MODULES" "$module_id")"
  DOTFILES_AUTO_SELECTED_MODULES="$(add_word "$DOTFILES_AUTO_SELECTED_MODULES" "$module_id")"
  AUTO_NOTES[${#AUTO_NOTES[@]}]="$(catalog::module_label "$module_id") was added automatically because $reason."
}

remember_saved_runtime_defaults() {
  DOTFILES_SAVED_THEME="$DOTFILES_THEME"
  DOTFILES_SAVED_ENABLE_OH_MY_ZSH="$DOTFILES_ENABLE_OH_MY_ZSH"
}

saved_install_value() {
  local variable_name="$1"
  local config_file="$DOTFILES_CONFIG_DIR/install.env"
  local value=""

  [[ -f "$config_file" ]] || return 1
  value="$(
    bash --noprofile --norc -c '
      config_file="$1"
      variable_name="$2"
      source "$config_file" >/dev/null 2>&1 || exit 1
      printf "%s" "${!variable_name-}"
    ' _ "$config_file" "$variable_name" 2>/dev/null
  )"
  [[ -n "$value" ]] || return 1
  printf '%s' "$value"
}

select_default_package_manager() {
  local saved_package_manager=""

  saved_package_manager="$(saved_install_value DOTFILES_PACKAGE_MANAGER || true)"

  case "$DOTFILES_PLATFORM" in
    macos)
      DOTFILES_PACKAGE_MANAGER="brew"
      ;;
    wsl|linux)
      if [[ "$saved_package_manager" == "brew" ]] && find_brew >/dev/null 2>&1; then
        DOTFILES_PACKAGE_MANAGER="brew"
      elif [[ "$saved_package_manager" == "apt" ]] && command -v apt-get >/dev/null 2>&1; then
        DOTFILES_PACKAGE_MANAGER="apt"
      elif command -v apt-get >/dev/null 2>&1; then
        DOTFILES_PACKAGE_MANAGER="apt"
      else
        DOTFILES_PACKAGE_MANAGER="brew"
      fi
      ;;
  esac
}

load_saved_runtime_defaults() {
  local saved_theme=""
  local saved_oh_my_zsh=""

  saved_theme="$(saved_install_value DOTFILES_THEME || true)"
  saved_oh_my_zsh="$(saved_install_value DOTFILES_ENABLE_OH_MY_ZSH || true)"

  DOTFILES_THEME="${saved_theme:-starship}"

  case "$saved_oh_my_zsh" in
    0|1)
      DOTFILES_ENABLE_OH_MY_ZSH="$saved_oh_my_zsh"
      ;;
    *)
      case "$DOTFILES_THEME" in
        powerlevel10k|default) DOTFILES_ENABLE_OH_MY_ZSH="1" ;;
        *) DOTFILES_ENABLE_OH_MY_ZSH="0" ;;
      esac
      ;;
  esac
}

update_planned_oh_my_zsh_runtime() {
  local should_enable="${DOTFILES_SAVED_ENABLE_OH_MY_ZSH:-0}"

  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" != "1" ]]; then
    DOTFILES_ENABLE_OH_MY_ZSH="${DOTFILES_SAVED_ENABLE_OH_MY_ZSH:-$DOTFILES_ENABLE_OH_MY_ZSH}"
    return 0
  fi

  case "$DOTFILES_THEME" in
    powerlevel10k|default)
      should_enable="1"
      if ! module_is_selected "oh_my_zsh"; then
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
          REUSE_NOTES[${#REUSE_NOTES[@]}]="Existing oh-my-zsh will be reused because the selected theme requires it."
        else
          record_auto_selected_module "oh_my_zsh" "theme '$DOTFILES_THEME' requires it"
        fi
      fi
      ;;
    *)
      if module_is_selected "oh_my_zsh"; then
        should_enable="1"
      elif [[ "${DOTFILES_SAVED_ENABLE_OH_MY_ZSH:-0}" == "1" && -d "$HOME/.oh-my-zsh" ]]; then
        should_enable="1"
        if [[ "${DOTFILES_THEME_NEEDED:-0}" == "1" ]]; then
          REUSE_NOTES[${#REUSE_NOTES[@]}]="Existing oh-my-zsh runtime will stay enabled."
        fi
      else
        should_enable="0"
      fi
      ;;
  esac

  DOTFILES_ENABLE_OH_MY_ZSH="$should_enable"
}

resolve_install_plan() {
  DOTFILES_AUTO_SELECTED_MODULES=""
  AUTO_NOTES=()
  REUSE_NOTES=()

  refresh_plan_requirements
  update_planned_oh_my_zsh_runtime
}

finalize_runtime_state() {
  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" != "1" ]]; then
    DOTFILES_ENABLE_OH_MY_ZSH="${DOTFILES_SAVED_ENABLE_OH_MY_ZSH:-$DOTFILES_ENABLE_OH_MY_ZSH}"
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="0"
    return 0
  fi

  case "$DOTFILES_THEME" in
    powerlevel10k|default)
      DOTFILES_ENABLE_OH_MY_ZSH="1"
      ;;
    *)
      if module_is_selected "oh_my_zsh"; then
        DOTFILES_ENABLE_OH_MY_ZSH="1"
      elif [[ "${DOTFILES_SAVED_ENABLE_OH_MY_ZSH:-0}" == "1" && -d "$HOME/.oh-my-zsh" ]]; then
        DOTFILES_ENABLE_OH_MY_ZSH="1"
      else
        DOTFILES_ENABLE_OH_MY_ZSH="0"
      fi
      ;;
  esac

  if module_is_selected "dotfiles" || module_is_selected "oh_my_zsh"; then
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="1"
  else
    DOTFILES_ALLOW_AUTO_LAUNCH_ZSH="0"
  fi
}

planned_oh_my_zsh_runtime_label() {
  local state_label="disabled"

  if [[ "${DOTFILES_ENABLE_OH_MY_ZSH:-0}" == "1" ]]; then
    state_label="enabled"
  fi

  if [[ "${DOTFILES_RUN_THEME_INSTALL:-0}" != "1" ]] \
    && ! module_is_selected "dotfiles" \
    && ! module_is_selected "oh_my_zsh"; then
    printf '%s (unchanged)' "$state_label"
    return 0
  fi

  printf '%s' "$state_label"
}

print_plan_summary() {
  local summary_lines=()
  local module_id item_labels
  local note

  summary_lines[${#summary_lines[@]}]="Platform: $DOTFILES_PLATFORM_LABEL"
  if [[ "${DOTFILES_PACKAGE_MANAGER_NEEDED:-0}" == "1" ]]; then
    summary_lines[${#summary_lines[@]}]="Package manager: $DOTFILES_PACKAGE_MANAGER"
  else
    summary_lines[${#summary_lines[@]}]="Package manager: not needed for selected plan"
  fi
  if [[ "${DOTFILES_THEME_NEEDED:-0}" == "1" ]]; then
    summary_lines[${#summary_lines[@]}]="Theme: $(catalog::theme_label "$DOTFILES_THEME")"
  else
    summary_lines[${#summary_lines[@]}]="Theme: not needed for selected plan"
  fi
  summary_lines[${#summary_lines[@]}]="Selected modules: $(module_labels_or_none "$DOTFILES_REQUESTED_MODULES")"
  summary_lines[${#summary_lines[@]}]="Final install modules: $(module_labels_or_none "$DOTFILES_SELECTED_MODULES")"
  if [[ -n "$DOTFILES_AUTO_SELECTED_MODULES" ]]; then
    summary_lines[${#summary_lines[@]}]="Auto-added modules: $(module_labels_for_selection "$DOTFILES_AUTO_SELECTED_MODULES")"
  fi
  if module_is_selected "dotfiles"; then
    summary_lines[${#summary_lines[@]}]="Dotfiles links: ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.vimrc, ~/.config/nvim, ~/.gitconfig"
  fi
  summary_lines[${#summary_lines[@]}]="oh-my-zsh runtime: $(planned_oh_my_zsh_runtime_label)"

  for module_id in "${MODULE_ORDER[@]}"; do
    if ! module_is_selected "$module_id"; then
      continue
    fi

    if catalog::module_is_leaf "$module_id"; then
      item_labels="$(get_module_item_labels "$module_id")"
      if [[ -n "$item_labels" ]]; then
        summary_lines[${#summary_lines[@]}]="$(catalog::module_label "$module_id"): $item_labels"
      fi
    fi
  done

  for note in "${AUTO_NOTES[@]:-}"; do
    [[ -n "$note" ]] || continue
    summary_lines[${#summary_lines[@]}]="Auto: $note"
  done

  for note in "${REUSE_NOTES[@]:-}"; do
    [[ -n "$note" ]] || continue
    summary_lines[${#summary_lines[@]}]="Reuse: $note"
  done

  for note in "${SKIP_NOTES[@]:-}"; do
    [[ -n "$note" ]] || continue
    summary_lines[${#summary_lines[@]}]="Skip: $note"
  done

  if [[ -n "$DOTFILES_GIT_SUMMARY" ]]; then
    summary_lines[${#summary_lines[@]}]="Git identity: $DOTFILES_GIT_SUMMARY"
  fi

  prompt::summary "Planned configuration." "${summary_lines[@]}"
}
