#!/usr/bin/env bash

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/jinyongp/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REF="${DOTFILES_REF:-main}"

install_remote::json_escape() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

install_remote::ui_mode() {
  install_remote::load_ui
  if declare -F ui::mode >/dev/null 2>&1; then
    ui::mode
    return 0
  fi

  case "${DOTFILES_INSTALL_UI_MODE:-auto}" in
    auto|plain|json) printf '%s' "${DOTFILES_INSTALL_UI_MODE:-auto}" ;;
    *) printf 'auto' ;;
  esac
}

install_remote::fallback_validation_error() {
  local message="$1"
  shift || true
  local record label value json_fields="" escaped_label escaped_value

  if [[ "$(install_remote::ui_mode)" == "json" ]]; then
    for record in "$@"; do
      IFS=$'\t' read -r label value <<<"$record"
      [[ -n "$label" ]] || continue
      escaped_label="$(install_remote::json_escape "$label")"
      escaped_value="$(install_remote::json_escape "$value")"
      json_fields="${json_fields}${json_fields:+,}\"$escaped_label\":\"$escaped_value\""
    done
    printf '{"schema":"dotfiles.ui.v1","type":"validation_error","surface":"install","mode":"json","data":{"message":"%s","fields":{%s}}}\n' \
      "$(install_remote::json_escape "$message")" \
      "$json_fields" >&2
    return 0
  fi

  printf 'dotfiles install: %s\n' "$message" >&2
  for record in "$@"; do
    IFS=$'\t' read -r label value <<<"$record"
    [[ -n "$label" && -n "$value" ]] || continue
    printf '  %s: %s\n' "$label" "$value" >&2
  done
}

install_remote::load_ui() {
  if declare -F ui::validation_error >/dev/null 2>&1; then
    return 0
  fi

  if [[ -f "$DOTFILES_DIR/scripts/lib/ui/errors.sh" ]]; then
    # shellcheck disable=SC1090
    source "$DOTFILES_DIR/scripts/lib/ui/errors.sh"
  fi
}

install_remote::validation_error() {
  local message="$1"
  shift || true

  install_remote::load_ui
  if declare -F ui::validation_error >/dev/null 2>&1; then
    ui::validation_error "$message" "$@"
  else
    install_remote::fallback_validation_error "$message" "$@"
  fi
}

install_remote::require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    install_remote::validation_error "required command not found" \
      $'command\t'"$1"
    return 1
  fi
}

install_remote::ensure_clean_worktree() {
  local status=""

  status="$(git -C "$DOTFILES_DIR" status --porcelain)"
  if [[ -n "$status" ]]; then
    install_remote::validation_error "local changes found; refusing to update" \
      $'path\t'"$DOTFILES_DIR" \
      $'status\t'"$status" \
      $'next\tcommit, stash, or discard local changes before update'
    if [[ "$(install_remote::ui_mode)" != "json" ]]; then
      printf '%s\n' "$status" >&2
    fi
    return 1
  fi
}

install_remote::clone_or_update_repo() {
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    install_remote::load_ui
  elif [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    install_remote::validation_error "path exists but is not a git repo" \
      $'path\t'"$DOTFILES_DIR"
    return 1
  else
    install_remote::load_ui
  fi

  install_remote::ensure_clean_worktree

  git -C "$DOTFILES_DIR" fetch --prune origin
  git -C "$DOTFILES_DIR" checkout "$DOTFILES_REF"
  git -C "$DOTFILES_DIR" pull --ff-only origin "$DOTFILES_REF"
}

install_remote::main() {
  install_remote::require_command git
  install_remote::require_command bash

  install_remote::clone_or_update_repo
  exec "$DOTFILES_DIR/install" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  install_remote::main "$@"
fi
