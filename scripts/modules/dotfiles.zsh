#!/bin/zsh

typeset -gA DOTFILES_LINK_TARGETS=(
  ["$DOTFILES_ROOT/zsh/.zshrc"]="$HOME/.zshrc"
  ["$DOTFILES_ROOT/vim/.vimrc"]="$HOME/.vimrc"
  ["$DOTFILES_ROOT/git/.gitconfig"]="$HOME/.gitconfig"
)

module_dotfiles_supported() {
  return 0
}

module_dotfiles_summary() {
  echo "Symlink ~/.zshrc, ~/.vimrc, and ~/.gitconfig, then prepare local Git config"
}

module_dotfiles_details() {
  echo "Creates symlinks for ~/.zshrc, ~/.vimrc, and ~/.gitconfig."
  echo "If those files already exist, moves them into $DOTFILES_ROOT/.backup/<timestamp> first."
  echo "This changes which config files your shell, Vim, and Git load by default."
  echo "Also writes machine-local Git path settings and applies any Git identity values passed from the bash installer."
}

dotfiles::git_local_config_tmpfile() {
  local config_file="$1"
  local config_dir="${config_file:h}"

  dotfiles::ensure_dir "$config_dir"
  mktemp "$config_dir/${config_file:t}.tmp.XXXXXX"
}

dotfiles::write_root_git_config() {
  local config_file="$1"
  local tmp_file
  local config_exists=0

  [[ -e "$config_file" ]] && config_exists=1

  tmp_file="$(dotfiles::git_local_config_tmpfile "$config_file")"

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

dotfiles::git_config_get() {
  local config_file="$1"
  local key="$2"

  git config --file "$config_file" --get "$key" 2>/dev/null || true
}

dotfiles::git_personal_config_is_template() {
  local config_file="$1"
  local keys=(
    user.name
    user.email
    user.signingKey
    gpg.format
    commit.gpgsign
    tag.gpgsign
  )
  local key value

  for key in "${keys[@]}"; do
    value="$(dotfiles::git_config_get "$config_file" "$key")"
    if [[ -n "$value" ]]; then
      return 1
    fi
  done

  return 0
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
    if ! dotfiles::git_personal_config_is_template "$config_file"; then
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
  local source_path target_path backup_dir timestamp
  local personal_file="$DOTFILES_CONFIG_DIR/git/personal.local.ini"

  dotfiles::log_step "Installing dotfile symlinks"

  timestamp="$(date +%Y-%m-%d__%H-%M-%S)"
  backup_dir="$DOTFILES_ROOT/.backup/$timestamp"

  for source_path target_path in "${(@kv)DOTFILES_LINK_TARGETS}"; do
    dotfiles::ensure_dir "${target_path:h}"

    if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
      dotfiles::record_reused "Managed link already in place: $(dotfiles::display_path "$target_path")"
      dotfiles::log_info "Already linked: $target_path"
      continue
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
  done

  dotfiles::ensure_local_git_config_files
  dotfiles::apply_personal_git_config_from_plan "$personal_file"
}
