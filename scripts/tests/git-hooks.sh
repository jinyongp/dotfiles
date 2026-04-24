#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/git-hooks.XXXXXX")"
HOME_DIR="$WORK_DIR/home"
REPO_DIR="$WORK_DIR/repo"
MESSAGE_FILE="$WORK_DIR/commit-message.txt"

trap 'rm -rf "$WORK_DIR"' EXIT

git_hooks_test::fail() {
  printf 'git-hooks: %s\n' "$1" >&2
  exit 1
}

git_hooks_test::assert_contains() {
  local file="$1"
  local expected="$2"
  local message="$3"

  if ! grep -Fq -- "$expected" "$file"; then
    sed -n '1,120p' "$file" >&2
    git_hooks_test::fail "$message"
  fi
}

git_hooks_test::run_hook() {
  env -i \
    HOME="$HOME_DIR" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    "$@"
}

git_hooks_test::setup() {
  mkdir -p "$HOME_DIR" "$REPO_DIR"
  ln -s "$DOTFILES_ROOT" "$HOME_DIR/.dotfiles"

  git -C "$REPO_DIR" init -q
  git -C "$REPO_DIR" config user.name "Dotfiles Test"
  git -C "$REPO_DIR" config user.email "dotfiles@example.test"
  git -C "$REPO_DIR" config commit.gpgsign false
}

git_hooks_test::commit_empty() {
  local message="$1"

  git -c core.hooksPath=/dev/null -C "$REPO_DIR" commit --allow-empty -q -m "$message"
  git -C "$REPO_DIR" rev-parse HEAD
}

git_hooks_test::assert_commit_msg_accepts() {
  local message="$1"

  printf '%s\n' "$message" >"$MESSAGE_FILE"
  git_hooks_test::run_hook "$DOTFILES_ROOT/git/hooks/commit-msg" "$MESSAGE_FILE"
}

git_hooks_test::assert_commit_msg_rejects() {
  local message="$1"
  local output_file="$WORK_DIR/commit-msg.out"

  printf '%s\n' "$message" >"$MESSAGE_FILE"
  if git_hooks_test::run_hook "$DOTFILES_ROOT/git/hooks/commit-msg" "$MESSAGE_FILE" >"$output_file" 2>&1; then
    git_hooks_test::fail "commit-msg unexpectedly accepted: $message"
  fi

  git_hooks_test::assert_contains "$output_file" "Commit message must follow Conventional Commits." "missing conventional commit error"
}

git_hooks_test::test_commit_msg() {
  git_hooks_test::assert_commit_msg_accepts "fix(hooks): validate pushed WIP ranges"
  git_hooks_test::assert_commit_msg_accepts "feat(installer)!: change profile defaults"
  git_hooks_test::assert_commit_msg_accepts $'# comment from template\n\nchore(git): update commit template'

  git_hooks_test::assert_commit_msg_rejects "Fix: validate pushed WIP ranges"
  git_hooks_test::assert_commit_msg_rejects "fix hooks without separator"
  git_hooks_test::assert_commit_msg_rejects "fix: "

  printf 'ok commit_msg\n'
}

git_hooks_test::run_pre_push() {
  local stdin_text="$1"
  local output_file="$2"

  (
    cd "$REPO_DIR"
    printf '%s\n' "$stdin_text" | git_hooks_test::run_hook "$DOTFILES_ROOT/git/hooks/pre-push" origin example.test
  ) >"$output_file" 2>&1
}

git_hooks_test::test_pre_push_range() {
  local base_sha wip_sha good_sha output_file

  base_sha="$(git_hooks_test::commit_empty "chore: initialize test repository")"
  wip_sha="$(git_hooks_test::commit_empty "--wip-- [skip ci]")"
  good_sha="$(git_hooks_test::commit_empty "fix: keep pushed range clean")"
  output_file="$WORK_DIR/pre-push-range.out"

  git_hooks_test::run_pre_push "refs/heads/main $good_sha refs/heads/main $wip_sha" "$output_file"
  printf 'ok pre_push_ignores_wip_before_remote_sha\n'

  if git_hooks_test::run_pre_push "refs/heads/main $good_sha refs/heads/main $base_sha" "$output_file"; then
    git_hooks_test::fail "pre-push unexpectedly accepted a range containing WIP"
  fi

  git_hooks_test::assert_contains "$output_file" "A WIP commit is included in this push." "missing WIP range warning"
  git_hooks_test::assert_contains "$output_file" "$(git -C "$REPO_DIR" rev-parse --short "$wip_sha") --wip-- [skip ci]" "missing blocked commit summary"
  printf 'ok pre_push_rejects_wip_in_pushed_range\n'

  git_hooks_test::run_pre_push "refs/heads/main 0000000000000000000000000000000000000000 refs/heads/main $good_sha" "$output_file"
  printf 'ok pre_push_ignores_deletions\n'
}

git_hooks_test::main() {
  git_hooks_test::setup
  git_hooks_test::test_commit_msg
  git_hooks_test::test_pre_push_range
  printf 'all git hook tests passed\n'
}

git_hooks_test::main "$@"
