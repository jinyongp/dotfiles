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
  echo "Also writes machine-local Git path settings and can prompt for your per-machine Git identity/signing file."
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

  tmp_file="$(dotfiles::git_local_config_tmpfile "$config_file")"

  git config --file "$tmp_file" init.templateDir "$DOTFILES_ROOT/git"
  git config --file "$tmp_file" core.hooksPath "$DOTFILES_ROOT/git/hooks"
  git config --file "$tmp_file" commit.template "$DOTFILES_ROOT/git/templates/gitmessage"

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$config_file"
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

dotfiles::signing_mode_default_index() {
  local config_file="$1"
  local gpg_format signing_key

  gpg_format="$(dotfiles::git_config_get "$config_file" "gpg.format")"
  signing_key="$(dotfiles::git_config_get "$config_file" "user.signingKey")"

  if [[ "$gpg_format" == "ssh" ]]; then
    echo 3
    return 0
  fi

  if [[ -n "$signing_key" ]]; then
    echo 2
    return 0
  fi

  echo 1
}

dotfiles::write_personal_git_config() {
  local config_file="$1"
  local git_name="$2"
  local git_email="$3"
  local signing_mode="$4"
  local signing_key="$5"
  local enable_signing="$6"
  local tmp_file

  tmp_file="$(dotfiles::git_local_config_tmpfile "$config_file")"

  git config --file "$tmp_file" user.name "$git_name"
  git config --file "$tmp_file" user.email "$git_email"

  case "$signing_mode" in
    gpg)
      git config --file "$tmp_file" user.signingKey "$signing_key"
      ;;
    ssh)
      git config --file "$tmp_file" gpg.format ssh
      git config --file "$tmp_file" user.signingKey "$signing_key"
      ;;
  esac

  if [[ "$enable_signing" == "yes" ]]; then
    git config --file "$tmp_file" commit.gpgsign true
    git config --file "$tmp_file" tag.gpgsign true
    git config --file "$tmp_file" tag.forceSignAnnotated true
  fi

  chmod 600 "$tmp_file"
  mv "$tmp_file" "$config_file"
}

dotfiles::prompt_for_personal_git_config() {
  local config_file="$1"
  local git_name=""
  local git_email=""
  local signing_mode=""
  local signing_key=""
  local enable_signing="no"
  local default_mode_index

  if ! dotfiles::git_personal_config_is_template "$config_file"; then
    dotfiles::log_info "Using existing machine-local Git config at $config_file"
    return 0
  fi

  if ! prompt::yes_no \
    "Configure machine-local Git identity now?" \
    "yes" \
    "This writes $config_file for this machine only." \
    "You can skip and edit it later if you prefer."; then
    dotfiles::log_warn "Skipped Git identity setup. Edit $config_file later."
    return 0
  fi

  git_name="$(prompt::read_string \
    "Git user.name" \
    "" \
    "no" \
    "Used for commits created on this machine.")"

  git_email="$(prompt::read_string \
    "Git user.email" \
    "" \
    "no" \
    "Used for commits created on this machine.")"

  default_mode_index="$(dotfiles::signing_mode_default_index "$config_file")"
  signing_mode="$(prompt::choose_one_described \
    "Configure Git signing for this machine?" \
    "$default_mode_index" \
    "none::Do not enable commit or tag signing in personal.local.ini." \
    "gpg::Use an OpenPGP key ID or fingerprint in user.signingKey." \
    "ssh::Use SSH signing with gpg.format=ssh and a public key path in user.signingKey.")"

  case "$signing_mode" in
    gpg)
      signing_key="$(prompt::read_string \
        "Git user.signingKey" \
        "" \
        "no" \
        "Enter the GPG key ID, long fingerprint, or other value Git should use on this machine.")"
      enable_signing="yes"
      ;;
    ssh)
      signing_key="$(prompt::read_string \
        "Git user.signingKey" \
        "~/.ssh/id_ed25519.pub" \
        "no" \
        "Enter the SSH public key path Git should use on this machine.")"
      enable_signing="yes"
      ;;
    none)
      enable_signing="no"
      ;;
  esac

  dotfiles::write_personal_git_config \
    "$config_file" \
    "$git_name" \
    "$git_email" \
    "$signing_mode" \
    "$signing_key" \
    "$enable_signing"

  dotfiles::log_success "Wrote machine-local Git config to $config_file"
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
      dotfiles::log_info "Already linked: $target_path"
      continue
    fi

    if [[ -e "$target_path" || -L "$target_path" ]]; then
      dotfiles::ensure_dir "$backup_dir"
      mv "$target_path" "$backup_dir/${target_path:t}"
      dotfiles::log_info "Backed up $target_path to $backup_dir"
    fi

    ln -s "$source_path" "$target_path"
    dotfiles::log_success "Linked $target_path"
  done

  dotfiles::ensure_local_git_config_files
  dotfiles::prompt_for_personal_git_config "$personal_file"
}
