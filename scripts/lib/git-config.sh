#!/usr/bin/env bash

dotfiles_git_config_get() {
  local config_file="$1"
  local key="$2"

  git config --file "$config_file" --get "$key" 2>/dev/null || true
}

dotfiles_git_personal_config_is_template() {
  local config_file="$1"
  local key=""
  local value=""

  if [[ ! -f "$config_file" ]]; then
    return 0
  fi

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    value="$(dotfiles_git_config_get "$config_file" "$key")"
    if [[ -n "$value" ]]; then
      return 1
    fi
  done <<'EOF'
user.name
user.email
user.signingKey
gpg.format
commit.gpgsign
tag.gpgsign
EOF

  return 0
}
