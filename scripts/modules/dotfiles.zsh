#!/bin/zsh

source "$DOTFILES_ROOT/scripts/lib/git-config.sh"

typeset -gA DOTFILES_LINK_TARGETS=(
  ["$DOTFILES_ROOT/zsh/.zshenv"]="$HOME/.zshenv"
  ["$DOTFILES_ROOT/zsh/.zprofile"]="$HOME/.zprofile"
  ["$DOTFILES_ROOT/zsh/.zshrc"]="$HOME/.zshrc"
  ["$DOTFILES_ROOT/vim/.vimrc"]="$HOME/.vimrc"
  ["$DOTFILES_ROOT/nvim"]="$HOME/.config/nvim"
  ["$DOTFILES_ROOT/git/.gitconfig"]="$HOME/.gitconfig"
)

module_dotfiles_supported() {
  return 0
}

module_dotfiles_summary() {
  echo "Link ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.vimrc, ~/.config/nvim, and ~/.gitconfig, then prepare local Git config"
}

module_dotfiles_details() {
  echo "Creates symlinks for ~/.zshenv, ~/.zprofile, ~/.zshrc, ~/.vimrc, ~/.config/nvim, and ~/.gitconfig."
  echo "If those files already exist, moves them into $DOTFILES_CONFIG_DIR/backups/<timestamp> first."
  echo "This changes which config files your shell, Vim, Neovim, and Git load by default."
  echo "Also writes machine-local Git path settings and applies any Git identity values passed from the bash installer."
}

dotfiles::backup_root() {
  print -r -- "${DOTFILES_BACKUP_DIR:-$DOTFILES_CONFIG_DIR/backups}"
}

dotfiles::link_target() {
  local source_path="$1"
  local target_path="$2"
  local backup_dir="$3"

  dotfiles::ensure_dir "${target_path:h}"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    dotfiles::record_reused "Managed link already in place: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Already linked: $target_path"
    return 0
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    dotfiles::ensure_dir "$backup_dir"
    mv "$target_path" "$backup_dir/${target_path:t}"
    dotfiles::record_file_backed_up "$target_path" "$backup_dir/${target_path:t}"
    dotfiles::log_info "Backed up $target_path to $backup_dir"
  fi

  ln -s "$source_path" "$target_path"
  dotfiles::record_file_linked "$target_path" "$source_path"
  dotfiles::log_success "Linked $target_path"
}

dotfiles::link_repo_managed_targets() {
  local source_path target_path backup_dir timestamp

  timestamp="$(date +%Y-%m-%d__%H-%M-%S)"
  backup_dir="$(dotfiles::backup_root)/$timestamp"

  for source_path target_path in "${(@kv)DOTFILES_LINK_TARGETS}"; do
    dotfiles::link_target "$source_path" "$target_path" "$backup_dir"
  done
}

dotfiles::link_neovim_config() {
  local source_path="$DOTFILES_ROOT/nvim"
  local target_path="$HOME/.config/nvim"
  local backup_dir timestamp

  timestamp="$(date +%Y-%m-%d__%H-%M-%S)"
  backup_dir="$(dotfiles::backup_root)/$timestamp"

  dotfiles::link_target "$source_path" "$target_path" "$backup_dir"
}

dotfiles::write_local_zsh_override_template() {
  local config_file="$1"
  local title="$2"
  local loaded_as="$3"
  local examples="$4"
  local tmp_file config_exists=0

  [[ -e "$config_file" ]] && config_exists=1
  [[ "$config_exists" == "0" ]] || return 0

  tmp_file="$(dotfiles::local_config_tmpfile "$config_file")"

  {
    print -r -- "# $title"
    print -r -- "#"
    print -r -- "# Managed By"
    print -r -- "#   This machine-local file is created by the dotfiles installer."
    print -r -- "#   It is intentionally not stored in the repository."
    print -r -- "#"
    print -r -- "# Loaded As"
    print -r -- "#   $loaded_as"
    print -r -- "#"
    print -r -- "# Usage"
    print -r -- "#   Add machine-specific shell setup here. Keep secrets out unless this"
    print -r -- "#   file is protected appropriately on this machine."
    if [[ -n "$examples" ]]; then
      print -r -- "#"
      print -r -- "# Examples"
      print -r -- "$examples"
    fi
    print -r -- ""
  } >"$tmp_file"

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$config_file"
  dotfiles::record_file_created "$config_file"
  dotfiles::log_success "Created machine-local shell override file at $config_file"
}

dotfiles::ensure_local_shell_override_files() {
  dotfiles::ensure_dir "$DOTFILES_CONFIG_DIR"

  dotfiles::write_local_zsh_override_template \
    "$DOTFILES_ENV_ZSH" \
    "Universal zsh environment overrides" \
    "Loaded by ~/.zshenv for every zsh process, including non-interactive commands." \
    "#   . \"\$HOME/.cargo/env\""

  dotfiles::write_local_zsh_override_template \
    "$DOTFILES_PROFILE_ZSH" \
    "Login zsh profile overrides" \
    "Loaded by ~/.zprofile for login zsh shells." \
    "#   source ~/.orbstack/shell/init.zsh 2>/dev/null || :"

  dotfiles::write_local_zsh_override_template \
    "$DOTFILES_LOCAL_ZSH" \
    "Interactive zsh overrides" \
    "Loaded by ~/.zshrc for interactive terminal sessions." \
    "#   alias ll='ls -la'"
}

dotfiles::local_config_tmpfile() {
  local config_file="$1"
  local config_dir="${config_file:h}"

  dotfiles::ensure_dir "$config_dir"
  mktemp "$config_dir/${config_file:t}.tmp.XXXXXX"
}

dotfiles::git_local_config_tmpfile() {
  dotfiles::local_config_tmpfile "$1"
}

dotfiles::write_root_git_config() {
  local config_file="$1"
  local tmp_file
  local config_exists=0

  [[ -e "$config_file" ]] && config_exists=1

  tmp_file="$(dotfiles::local_config_tmpfile "$config_file")"

  git config --file "$tmp_file" init.templateDir "$DOTFILES_ROOT/git"
  git config --file "$tmp_file" core.hooksPath "$DOTFILES_ROOT/git/hooks"
  git config --file "$tmp_file" commit.template "$DOTFILES_ROOT/git/templates/gitmessage"

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$config_file"
  if [[ "$config_exists" == "1" ]]; then
    dotfiles::record_file_updated "$config_file"
  else
    dotfiles::record_file_created "$config_file"
  fi
  dotfiles::log_success "Wrote machine-local Git path config to $config_file"
}

dotfiles::ensure_local_git_config_files() {
  local git_config_dir="$DOTFILES_CONFIG_DIR/git"
  local root_file="$git_config_dir/root.local.ini"
  local personal_file="$git_config_dir/personal.local.ini"

  dotfiles::ensure_dir "$git_config_dir"
  dotfiles::write_root_git_config "$root_file"

  if [[ ! -f "$personal_file" ]]; then
    cp "$DOTFILES_ROOT/git/configs/personal.local.example.ini" "$personal_file"
    dotfiles::record_file_created "$personal_file"
    dotfiles::record_note "Created the machine-local Git personal config from the bundled example."
    dotfiles::log_info "Created $personal_file"
  fi
}

dotfiles::write_personal_git_config() {
  local config_file="$1"
  local git_name="$2"
  local git_email="$3"
  local signing_mode="$4"
  local signing_key="$5"
  local tmp_file
  local config_exists=0

  [[ -e "$config_file" ]] && config_exists=1

  tmp_file="$(dotfiles::git_local_config_tmpfile "$config_file")"

  git config --file "$tmp_file" user.name "$git_name"
  git config --file "$tmp_file" user.email "$git_email"

  case "$signing_mode" in
    gpg)
      git config --file "$tmp_file" user.signingKey "$signing_key"
      git config --file "$tmp_file" commit.gpgsign true
      git config --file "$tmp_file" tag.gpgsign true
      git config --file "$tmp_file" tag.forceSignAnnotated true
      ;;
    ssh)
      git config --file "$tmp_file" gpg.format ssh
      git config --file "$tmp_file" user.signingKey "$signing_key"
      git config --file "$tmp_file" commit.gpgsign true
      git config --file "$tmp_file" tag.gpgsign true
      git config --file "$tmp_file" tag.forceSignAnnotated true
      ;;
  esac

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$config_file"
  if [[ "$config_exists" == "1" ]]; then
    dotfiles::record_file_updated "$config_file"
  else
    dotfiles::record_file_created "$config_file"
  fi
  dotfiles::record_completed_work "Applied machine-local Git identity"
  dotfiles::log_success "Wrote machine-local Git config to $config_file"
}

dotfiles::apply_personal_git_config_from_plan() {
  local config_file="$1"

  if [[ "${DOTFILES_GIT_CONFIGURE_PERSONAL:-no}" != "yes" ]]; then
    if ! dotfiles_git_personal_config_is_template "$config_file"; then
      dotfiles::record_reused "Machine-local Git identity"
      dotfiles::log_info "Using existing machine-local Git config at $config_file"
    else
      dotfiles::record_note "Machine-local Git identity remains unconfigured."
      dotfiles::log_warn "Machine-local Git config remains unconfigured at $config_file"
    fi
    return 0
  fi

  dotfiles::write_personal_git_config \
    "$config_file" \
    "${DOTFILES_GIT_NAME:-}" \
    "${DOTFILES_GIT_EMAIL:-}" \
    "${DOTFILES_GIT_SIGNING_MODE:-none}" \
    "${DOTFILES_GIT_SIGNING_KEY:-}"
}

module_dotfiles_install() {
  local personal_file="$DOTFILES_CONFIG_DIR/git/personal.local.ini"

  dotfiles::log_step "Installing dotfile symlinks"
  dotfiles::link_repo_managed_targets

  dotfiles::ensure_local_shell_override_files
  dotfiles::ensure_local_git_config_files
  dotfiles::apply_personal_git_config_from_plan "$personal_file"
}
