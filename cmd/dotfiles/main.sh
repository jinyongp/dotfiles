#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$DOTFILES_ROOT/scripts/lib/ui/help.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"
source "$DOTFILES_ROOT/scripts/lib/runtime-shared.zsh"

dotfiles::usage() {
  ui::help_start "dotfiles" "Manage this dotfiles repository and installer."
  ui::help_usage \
    "dotfiles install [target] [item...]" \
    "dotfiles uninstall -y" \
    "dotfiles list" \
    "dotfiles update" \
    "dotfiles doctor" \
    "dotfiles path"
  ui::help_commands \
    $'install\tinstall\tRun the interactive installer or a direct install target.' \
    $'uninstall\tuninstall\tRemove dotfiles-managed links.' \
    $'list\tlist\tList direct install targets.' \
    $'themes\tthemes\tManage shell theme selection and dependencies.' \
    $'update\tupdate\tFast-forward this dotfiles repository.' \
    $'path\tpath\tPrint the dotfiles repository path.' \
    $'doctor\tdoctor\tCheck the local dotfiles setup.' \
    $'help\thelp\tShow help.'
  ui::help_records "Aliases:" \
    $'dfx\tdfx\tAlias for dotfiles when no existing dfx command is installed.'
}

dotfiles::config_dir() {
  printf '%s\n' "${DOTFILES_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles}"
}

dotfiles::is_under_path() {
  local path="$1"
  local root="$2"

  case "$path" in
    "$root"|"$root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

dotfiles::remove_managed_symlink() {
  local path="$1"
  local root="$2"
  local label="${3:-managed link}"
  local target=""

  [[ -L "$path" ]] || return 0

  target="$(readlink "$path")"
  if dotfiles::is_under_path "$target" "$root"; then
    rm "$path"
    printf '%s\n' "$(ui::status completed "removed $label: $path")"
  fi
}

dotfiles::uninstall() {
  local yes=0
  local arg=""
  local path=""
  local -a managed_paths=()

  for arg in "$@"; do
    case "$arg" in
      -y|--yes)
        yes=1
        ;;
      -h|--help)
        ui::help_start "dotfiles uninstall" "Remove dotfiles-managed links."
        ui::help_options \
          $'-y, --yes\tyes\tRun uninstall without an interactive confirmation.'
        return 0
        ;;
      *)
        ui::validation_error "unknown uninstall option" \
          $'input\t'"$arg" \
          $'usage\tdotfiles uninstall -y'
        return 2
        ;;
    esac
  done

  if [[ "$yes" != "1" ]]; then
    ui::input_required "uninstall requires explicit confirmation" \
      $'usage\tdotfiles uninstall -y' \
      $'removes\tmanaged symlinks' \
      $'preserves\tpackages, apps, fonts, themes, backups, and local config'
    return 2
  fi

  managed_paths=(
    "$HOME/.zshenv"
    "$HOME/.zprofile"
    "$HOME/.zshrc"
    "$HOME/.vimrc"
    "$HOME/.gitconfig"
    "$HOME/.config/nvim"
  )

  printf '%s\n' "$(ui::section "Uninstall")"
  printf '%s\n' "$(ui::line "$(ui::field root "$DOTFILES_ROOT" path)")"

  for path in "${managed_paths[@]}"; do
    dotfiles::remove_managed_symlink "$path" "$DOTFILES_ROOT" "managed link"
  done


  printf '%s\n' "$(ui::status completed "uninstall finished")"
  printf '%s\n' "$(ui::status note "preserved packages, apps, fonts, themes, backups, and local config")"
}

dotfiles::ensure_git_repo() {
  local root_field=""
  local usage_field=""

  if ! git -C "$DOTFILES_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf -v root_field 'root\t%s' "$DOTFILES_ROOT"
    printf -v usage_field 'usage\t%s' 'git -C <root> rev-parse --is-inside-work-tree'
    ui::validation_error "not a git repository" \
      "$root_field" \
      "$usage_field"
    return 1
  fi
}

dotfiles::ensure_clean_worktree() {
  local status=""
  local root_field=""
  local next_field=""

  status="$(git -C "$DOTFILES_ROOT" status --porcelain)"
  if [[ -n "$status" ]]; then
    printf -v root_field 'root\t%s' "$DOTFILES_ROOT"
    printf -v next_field 'next\t%s' 'commit, stash, or discard local changes before update'
    ui::validation_error "local changes found; refusing to update" \
      "$root_field" \
      $'status\t'"$status" \
      "$next_field"
    if ! ui::is_json; then
      printf '%s\n' "$status" >&2
    fi
    return 1
  fi
}

dotfiles::update() {
  local upstream=""
  local local_head=""
  local remote_head=""
  local root_field=""
  local next_field=""

  dotfiles::ensure_git_repo
  dotfiles::ensure_clean_worktree

  upstream="$(git -C "$DOTFILES_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    printf -v root_field 'root\t%s' "$DOTFILES_ROOT"
    printf -v next_field 'next\t%s' "git -C $DOTFILES_ROOT pull --ff-only <remote> <branch>"
    ui::validation_error "current branch has no upstream" \
      "$root_field" \
      "$next_field"
    return 1
  fi

  git -C "$DOTFILES_ROOT" fetch --prune

  local_head="$(git -C "$DOTFILES_ROOT" rev-parse HEAD)"
  remote_head="$(git -C "$DOTFILES_ROOT" rev-parse "$upstream")"

  if [[ "$local_head" == "$remote_head" ]]; then
    printf '%s\n' "$(ui::status completed "already up to date")"
    return 0
  fi

  git -C "$DOTFILES_ROOT" pull --ff-only
}

dotfiles::doctor() {
  local failed=0
  local root_field=""
  local expected_field=""

  printf '%s\n' "$(ui::section "Doctor")"
  printf '%s\n' "$(ui::line "$(ui::field root "$DOTFILES_ROOT" path)")"

  if git -C "$DOTFILES_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' "$(ui::status completed "git repository detected")"
  else
    printf '%s\n' "$(ui::status failed "git repository missing")"
    failed=1
  fi

  if [[ -x "$DOTFILES_ROOT/install" ]]; then
    printf '%s\n' "$(ui::status completed "installer executable")"
  else
    printf '%s\n' "$(ui::status failed "installer is not executable")"
    failed=1
  fi

  if [[ -d "$DOTFILES_ROOT/zsh" && -d "$DOTFILES_ROOT/cmd/bin" ]]; then
    printf '%s\n' "$(ui::status completed "required directories present")"
  else
    printf -v root_field 'root\t%s' "$DOTFILES_ROOT"
    printf -v expected_field 'expected\t%s' 'zsh, cmd/bin'
    ui::validation_error "layout is missing expected directories" \
      "$root_field" \
      "$expected_field"
    failed=1
  fi

  return "$failed"
}

dotfiles::complete_records() {
  local id=""
  local label=""

  while IFS=$'\t' read -r id label _; do
    [[ -n "$id" ]] || continue
    printf '%s:%s\n' "$id" "$label"
  done
}

dotfiles::complete() {
  local context="${1:-commands}"
  local module_id="${2:-}"
  local platform=""

  export DOTFILES_ROOT
  # shellcheck disable=SC1091
  source "$DOTFILES_ROOT/scripts/lib/runtime-shared.zsh"
  # shellcheck disable=SC1091
  source "$DOTFILES_ROOT/scripts/lib/catalog.sh"

  platform="${DOTFILES_PLATFORM:-}"
  if [[ -z "$platform" ]]; then
    platform="$(dotfiles::detect_platform_id 2>/dev/null || true)"
  fi
  if [[ -z "$platform" ]]; then
    platform="linux"
  fi

  case "$context" in
    commands)
      cat <<'EOF'
install:run the interactive installer or direct install target
uninstall:remove dotfiles-managed links
list:list direct install targets
themes:manage shell theme selection and dependencies
update:fast-forward this dotfiles repository
path:print the dotfiles repository path
doctor:check the local dotfiles setup
help:show help
EOF
      ;;
    targets)
      catalog::module_records "$platform" | dotfiles::complete_records
      cat <<'EOF'
vim:alias for neovim
nvim:alias for neovim
omz:alias for oh_my_zsh
desktop-apps:alias for desktop_apps
EOF
      if [[ "$platform" == "macos" ]]; then
        cat <<'EOF'
macos-defaults:alias for macos_defaults
EOF
      fi
      ;;
    items)
      case "$module_id" in
        packages) catalog::package_records brew | dotfiles::complete_records ;;
        oh_my_zsh|omz) catalog::omz_plugin_records | dotfiles::complete_records ;;
        fonts) catalog::font_records | dotfiles::complete_records ;;
        desktop_apps|desktop-apps) catalog::desktop_app_records | dotfiles::complete_records ;;
        themes) catalog::theme_records | dotfiles::complete_records ;;
      esac
      ;;
    theme-commands)
      cat <<'EOF'
list:list available shell themes
use:set the saved shell theme and install dependencies
install:install dependencies for the saved shell theme
EOF
      ;;
  esac
}

case "${1:-help}" in
  -h|--help|help)
    dotfiles::usage
    ;;
  install)
    shift
    exec "$DOTFILES_ROOT/install" "$@"
    ;;
  uninstall)
    shift
    dotfiles::uninstall "$@"
    ;;
  themes)
    shift
    exec "$DOTFILES_ROOT/scripts/run-themes.bash" "$@"
    ;;
  list)
    exec "$DOTFILES_ROOT/install" list
    ;;
  update)
    dotfiles::update
    ;;
  doctor)
    dotfiles::doctor
    ;;
  path)
    printf '%s\n' "$DOTFILES_ROOT"
    ;;
  complete)
    shift
    if [[ $# -eq 0 ]]; then
      ui::validation_error "completion context required" \
        $'input\tcomplete' \
        $'usage\tdfx complete <context> [target]' \
        $'expected\tcommands, targets, items, theme-commands' \
        $'next\tThis command is used by shell completion integration.'
      exit 2
    fi
    dotfiles::complete "$@"
    ;;
  *)
    input_field=""
    usage_field=""
    printf -v input_field 'input\t%s' "$1"
    printf -v usage_field 'usage\t%s' 'dotfiles <command>'
    ui::validation_error "unknown dotfiles command" \
      "$input_field" \
      "$usage_field"
    exit 2
    ;;
esac
