#!/usr/bin/env bash

set -euo pipefail

shim_path="$0"
if command -v realpath >/dev/null 2>&1; then
  shim_path="$(realpath "$shim_path" 2>/dev/null || printf '%s\n' "$shim_path")"
fi
shim_dir="$(cd -- "$(dirname -- "$0")" && pwd)"

find_project_root() {
  local dir="$PWD"

  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.tasks/taskrc" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname -- "$dir")"
  done

  return 1
}

find_real_task() {
  local path_entry candidate candidate_real

  IFS=':' read -r -a path_entries <<<"${PATH:-}"
  for path_entry in "${path_entries[@]}"; do
    [[ -n "$path_entry" ]] || path_entry="."
    [[ "$path_entry" != "$shim_dir" ]] || continue

    candidate="$path_entry/task"
    [[ -x "$candidate" ]] || continue

    candidate_real="$candidate"
    if command -v realpath >/dev/null 2>&1; then
      candidate_real="$(realpath "$candidate" 2>/dev/null || printf '%s\n' "$candidate")"
    fi
    [[ "$candidate_real" != "$shim_path" ]] || continue

    printf '%s\n' "$candidate"
    return 0
  done

  return 1
}

project_root="$(find_project_root || true)"
real_task="$(find_real_task || true)"

if [[ -z "$real_task" ]]; then
  printf 'task: Taskwarrior binary not found behind dotfiles shim.\n' >&2
  printf 'task: install it with: ~/.dotfiles/install packages taskwarrior\n' >&2
  exit 127
fi

if [[ -n "$project_root" ]]; then
  export TASKRC="$project_root/.tasks/taskrc"
  export TASKDATA="$project_root/.tasks/data"
fi

exec "$real_task" "$@"
