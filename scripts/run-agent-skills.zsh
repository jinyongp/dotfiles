#!/bin/zsh

set -euo pipefail

DOTFILES_ROOT="${0:A:h:h}"
command_name="${1:-help}"
shift || true

source "$DOTFILES_ROOT/zsh/lib/bootstrap.zsh"
source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/help.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/catalog.sh"
source "$DOTFILES_ROOT/scripts/modules/agents.zsh"

agent_skills::usage() {
  ui::help_start "dotfiles agents" "Manage external agent skills."
  ui::help_usage \
    "dotfiles agents list" \
    "dotfiles agents sync [skill...]"
  ui::help_commands \
    $'list\tlist\tList external agent skills and installed revisions.' \
    $'sync\tsync\tFetch latest configured refs and update the local cache.'
  ui::help_environment \
    $'DOTFILES_INSTALL_UI_MODE\tDOTFILES_INSTALL_UI_MODE\tauto, plain, or json.'
}

case "$command_name" in
  -h|--help|help)
    agent_skills::usage
    ;;
  list)
    agents::list_external_skills "$@"
    ;;
  sync)
    agents::sync_external_skills "$@"
    ;;
  *)
    input_field=$'input\t'"$command_name"
    usage_field=$'usage\tdotfiles agents <command>'
    ui::validation_error "unknown dotfiles agents command" \
      "$input_field" \
      "$usage_field"
    exit 2
    ;;
esac
