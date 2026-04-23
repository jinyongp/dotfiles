#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-report.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$HOME/.config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"

export DOTFILES_ROOT HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR/git"

source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"

install_report_test::fail() {
  print -u2 -- "install-report: $1"
  exit 1
}

install_report_test::assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  print -r -- "$haystack" | grep -Fq -- "$needle" || install_report_test::fail "$message"
}

install_report_test::assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if print -r -- "$haystack" | grep -Fq -- "$needle"; then
    install_report_test::fail "$message"
  fi
}

install_report_test::normalize() {
  perl -0pe '
    s/\e\][^\a]*(?:\a|\e\\\\)//g;
    s/\e\[[0-?]*[ -\/]*[@-~]//g;
    s/\r//g;
    s/\n+\z/\n/;
  ' "$1"
}

install_report_test::main() {
  local raw_file="$WORK_DIR/report.raw"
  local output=""

  DOTFILES_SELECTED_MODULES="dotfiles"
  DOTFILES_RUN_THEME_INSTALL=1
  DOTFILES_ALLOW_AUTO_LAUNCH_ZSH=1
  DOTFILES_RESULT_INSTALLED_ITEMS=()
  DOTFILES_RESULT_REUSED_ITEMS=(
    "zsh command for installer startup"
    "starship prompt binary"
    "Managed link already in place: ~/.vimrc"
    "Managed link already in place: ~/.zprofile"
    "Managed link already in place: ~/.gitconfig"
    "Machine-local Git identity"
  )
  DOTFILES_RESULT_CREATED_FILES=()
  DOTFILES_RESULT_UPDATED_FILES=(
    "~/.config/dotfiles/install.env"
    "~/.config/dotfiles/git/root.local.ini"
  )
  DOTFILES_RESULT_LINKED_FILES=()
  DOTFILES_RESULT_BACKED_UP_FILES=()
  DOTFILES_RESULT_COMPLETED_WORK=(
    "Saved installer state"
    "Completed theme dependency setup for starship"
    "Completed Dotfiles setup"
  )
  DOTFILES_RESULT_NOTES=()
  DOTFILES_RESULT_WARNINGS=()

  dotfiles::print_install_report >"$raw_file"
  output="$(install_report_test::normalize "$raw_file")"

  install_report_test::assert_contains "$output" "Post-install Report" "missing report title"
  install_report_test::assert_contains "$output" "Reused" "missing reused section"
  install_report_test::assert_contains "$output" "Managed links already in place: ~/.vimrc, ~/.zprofile, ~/.gitconfig" "expected managed link aggregation"
  install_report_test::assert_contains "$output" "File changes" "missing file changes section"
  install_report_test::assert_contains "$output" "Updated: ~/.config/dotfiles/install.env, ~/.config/dotfiles/git/root.local.ini" "expected updated files aggregation"
  install_report_test::assert_contains "$output" "Git personal config" "missing git config section"
  install_report_test::assert_contains "$output" "~/.config/dotfiles/git/personal.local.ini" "missing git config path"
  install_report_test::assert_contains "$output" "Next" "missing next section"
  install_report_test::assert_contains "$output" "Starting a login zsh shell now." "missing next shell message"

  install_report_test::assert_not_contains "$output" "Installed items" "old installed-items title should be gone"
  install_report_test::assert_not_contains "$output" "Reused existing items" "old reused title should be gone"
  install_report_test::assert_not_contains "$output" "Created files" "empty created-files section should be hidden"
  install_report_test::assert_not_contains "$output" "Linked files" "empty linked-files section should be hidden"
  install_report_test::assert_not_contains "$output" "Backed up files" "empty backup section should be hidden"
  install_report_test::assert_not_contains "$output" "Completed work" "generic completed-work section should be hidden"
  install_report_test::assert_not_contains "$output" "Saved installer state" "low-signal completed item should be filtered"
  install_report_test::assert_not_contains "$output" "Machine-local Git identity" "git identity reuse should be absorbed by git section"
  install_report_test::assert_not_contains "$output" "None" "empty-section placeholder should be hidden"

  print -- "all install report tests passed"
}

install_report_test::main "$@"
