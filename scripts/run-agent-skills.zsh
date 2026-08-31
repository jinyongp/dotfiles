#!/bin/zsh

set -euo pipefail

DOTFILES_ROOT="${0:A:h:h}"
command_name="${1:-help}"
if (( $# > 0 )); then
  shift
fi

source "$DOTFILES_ROOT/zsh/lib/bootstrap.zsh"
source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/help.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/catalog.sh"
source "$DOTFILES_ROOT/scripts/modules/agents.zsh"

agent_skills::usage() {
  ui::help_start "dotfiles agents" "Manage agent rules and skills."
  ui::help_usage \
    "dotfiles agents list" \
    "dotfiles agents sync [skill...]"
  ui::help_commands \
    $'list\tlist\tList internal and external skills with adapter install state.' \
    $'sync\tsync\tRefresh detected agent rules and all skills; named skills stay scoped.'
}

case "$command_name" in
  -h|--help|help)
    agent_skills::usage
    ;;
  list)
    agents::list_external_skills "$@"
    ;;
  sync)
    agents::sync_skills "$@"
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
