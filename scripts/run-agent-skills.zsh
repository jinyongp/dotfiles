#!/bin/zsh

set -euo pipefail

DOTFILES_ROOT="${0:A:h:h}"
command_name="${1:-help}"
shift || true

source "$DOTFILES_ROOT/zsh/lib/bootstrap.zsh"
source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/catalog.sh"
source "$DOTFILES_ROOT/scripts/modules/agents.zsh"

agent_skills::usage() {
  cat <<'EOF'
Usage:
  dotfiles agents list
  dotfiles agents sync [skill...]

Commands:
  list            List external agent skills and installed revisions.
  sync [skill...] Fetch latest configured refs and update the local cache.
EOF
}

case "$command_name" in
  -h|--help|help)
    agent_skills::usage
    ;;
  list)
    agents::list_external_skills
    ;;
  sync)
    agents::sync_external_skills "$@"
    ;;
  *)
    print -u2 -- "dotfiles agents: unknown command: $command_name"
    agent_skills::usage >&2
    exit 2
    ;;
esac
