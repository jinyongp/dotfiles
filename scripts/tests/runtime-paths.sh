#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
ZSH_BIN="${ZSH_BIN:-/bin/zsh}"

runtime_paths_test::fail() {
  printf 'runtime-paths: %s\n' "$1" >&2
  exit 1
}

runtime_paths_test::setup_fixture() {
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/runtime-paths.XXXXXX")"
  HOME_DIR="$WORK_DIR/home"
  CONFIG_HOME_DIR="$WORK_DIR/config"
  DATA_HOME_DIR="$WORK_DIR/data"
  TMP_ROOT="$WORK_DIR/tmp"
  RUNTIME_DIR="$WORK_DIR/runtime"
  UNWRITABLE_RUNTIME_DIR="$WORK_DIR/runtime-readonly"
  PROBE_SCRIPT="$WORK_DIR/probe.sh"

  mkdir -p \
    "$HOME_DIR" \
    "$CONFIG_HOME_DIR" \
    "$DATA_HOME_DIR" \
    "$TMP_ROOT" \
    "$RUNTIME_DIR" \
    "$UNWRITABLE_RUNTIME_DIR"

  chmod 555 "$UNWRITABLE_RUNTIME_DIR"

  cat >"$PROBE_SCRIPT" <<'EOF'
source "$DOTFILES_ROOT/scripts/lib/runtime-shared.zsh"

printf 'config_dir=%s\n' "$(dotfiles::config_dir)"
printf 'install_env_path=%s\n' "$(dotfiles::install_env_path)"
printf 'env_zsh_path=%s\n' "$(dotfiles::env_zsh_path)"
printf 'profile_zsh_path=%s\n' "$(dotfiles::profile_zsh_path)"
printf 'local_zsh_path=%s\n' "$(dotfiles::local_zsh_path)"
printf 'npm_global_prefix=%s\n' "$(dotfiles::npm_global_prefix)"
printf 'npm_global_bin_dir=%s\n' "$(dotfiles::npm_global_bin_dir)"
printf 'pnpm_home=%s\n' "$(dotfiles::pnpm_home)"
printf 'fnm_install_dir=%s\n' "$(dotfiles::fnm_install_dir)"
printf 'fnm_runtime_dir=%s\n' "$(dotfiles::fnm_runtime_dir)"
EOF
}

runtime_paths_test::run_probe() {
  local shell_name="$1"
  local output_file="$2"
  shift 2 || true
  local shell_bin=""
  local -a extra_env=("$@")

  case "$shell_name" in
    bash) shell_bin="/bin/bash" ;;
    zsh) shell_bin="$ZSH_BIN" ;;
    *) runtime_paths_test::fail "unsupported shell: $shell_name" ;;
  esac

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    DOTFILES_ROOT="$DOTFILES_ROOT" \
    XDG_CONFIG_HOME="$CONFIG_HOME_DIR" \
    TMPDIR="$TMP_ROOT/" \
    "${extra_env[@]}" \
    "$shell_bin" "$PROBE_SCRIPT" >"$output_file"
}

runtime_paths_test::assert_output_equals() {
  local output_file="$1"
  local expected="$2"
  local label="$3"

  if ! diff -u <(printf '%s\n' "$expected") "$output_file"; then
    runtime_paths_test::fail "unexpected output for $label"
  fi
}

runtime_paths_test::assert_shell_parity() {
  local case_name="$1"
  local expected="$2"
  shift 2 || true
  local bash_output="$WORK_DIR/${case_name}.bash.out"
  local zsh_output="$WORK_DIR/${case_name}.zsh.out"

  runtime_paths_test::run_probe bash "$bash_output" "$@"
  runtime_paths_test::run_probe zsh "$zsh_output" "$@"

  if ! diff -u "$bash_output" "$zsh_output"; then
    runtime_paths_test::fail "bash/zsh mismatch for $case_name"
  fi

  runtime_paths_test::assert_output_equals "$bash_output" "$expected" "$case_name"
  printf 'ok %s\n' "$case_name"
}

runtime_paths_test::expected_lines() {
  local platform="$1"
  local runtime_dir="$2"
  local config_dir="$CONFIG_HOME_DIR/dotfiles"
  local install_env_path="$config_dir/install.env"
  local env_zsh_path="$config_dir/env.zsh"
  local profile_zsh_path="$config_dir/profile.zsh"
  local local_zsh_path="$config_dir/local.zsh"
  local npm_global_prefix=""
  local pnpm_home=""
  local fnm_install_dir=""
  local data_home="${XDG_DATA_HOME_OVERRIDE:-}"

  if [[ -n "$data_home" ]]; then
    npm_global_prefix="$data_home/npm-global"
    pnpm_home="$data_home/pnpm"
    fnm_install_dir="$data_home/fnm"
  elif [[ "$platform" == "macos" ]]; then
    npm_global_prefix="$HOME_DIR/Library/Application Support/npm-global"
    pnpm_home="$HOME_DIR/Library/pnpm"
    fnm_install_dir="$HOME_DIR/Library/Application Support/fnm"
  else
    npm_global_prefix="$HOME_DIR/.local/share/npm-global"
    pnpm_home="$HOME_DIR/.local/share/pnpm"
    fnm_install_dir="$HOME_DIR/.local/share/fnm"
  fi

  printf '%s\n' \
    "config_dir=$config_dir" \
    "install_env_path=$install_env_path" \
    "env_zsh_path=$env_zsh_path" \
    "profile_zsh_path=$profile_zsh_path" \
    "local_zsh_path=$local_zsh_path" \
    "npm_global_prefix=$npm_global_prefix" \
    "npm_global_bin_dir=$npm_global_prefix/bin" \
    "pnpm_home=$pnpm_home" \
    "fnm_install_dir=$fnm_install_dir" \
    "fnm_runtime_dir=$runtime_dir"
}

runtime_paths_test::assert_macos_defaults() {
  local current_uid expected

  current_uid="$(id -u)"
  expected="$(runtime_paths_test::expected_lines macos "$TMP_ROOT/fnm-runtime-$current_uid")"
  runtime_paths_test::assert_shell_parity "macos_defaults" "$expected" "DOTFILES_PLATFORM=macos"
}

runtime_paths_test::assert_linux_defaults() {
  local current_uid expected

  current_uid="$(id -u)"
  expected="$(runtime_paths_test::expected_lines linux "$TMP_ROOT/fnm-runtime-$current_uid")"
  runtime_paths_test::assert_shell_parity "linux_defaults" "$expected" "DOTFILES_PLATFORM=linux"
}

runtime_paths_test::assert_xdg_data_home_override() {
  local current_uid expected

  current_uid="$(id -u)"
  XDG_DATA_HOME_OVERRIDE="$DATA_HOME_DIR"
  expected="$(runtime_paths_test::expected_lines linux "$TMP_ROOT/fnm-runtime-$current_uid")"
  unset XDG_DATA_HOME_OVERRIDE

  runtime_paths_test::assert_shell_parity \
    "xdg_data_home_override" \
    "$expected" \
    "DOTFILES_PLATFORM=linux" \
    "XDG_DATA_HOME=$DATA_HOME_DIR"
}

runtime_paths_test::assert_writable_runtime_dir() {
  local expected

  expected="$(runtime_paths_test::expected_lines linux "$RUNTIME_DIR")"
  runtime_paths_test::assert_shell_parity \
    "writable_runtime_dir" \
    "$expected" \
    "DOTFILES_PLATFORM=linux" \
    "XDG_RUNTIME_DIR=$RUNTIME_DIR"
}

runtime_paths_test::assert_unwritable_runtime_dir() {
  local current_uid expected

  current_uid="$(id -u)"
  expected="$(runtime_paths_test::expected_lines linux "$TMP_ROOT/fnm-runtime-$current_uid")"
  runtime_paths_test::assert_shell_parity \
    "unwritable_runtime_dir" \
    "$expected" \
    "DOTFILES_PLATFORM=linux" \
    "XDG_RUNTIME_DIR=$UNWRITABLE_RUNTIME_DIR"
}

runtime_paths_test::main() {
  trap '[[ -n "${WORK_DIR:-}" ]] && chmod 755 "$UNWRITABLE_RUNTIME_DIR" 2>/dev/null || true; [[ -n "${WORK_DIR:-}" ]] && rm -rf "$WORK_DIR"' EXIT

  [[ -x "$ZSH_BIN" ]] || runtime_paths_test::fail "zsh not found: $ZSH_BIN"

  runtime_paths_test::setup_fixture
  runtime_paths_test::assert_macos_defaults
  runtime_paths_test::assert_linux_defaults
  runtime_paths_test::assert_xdg_data_home_override
  runtime_paths_test::assert_writable_runtime_dir
  runtime_paths_test::assert_unwritable_runtime_dir
  printf 'all runtime path tests passed\n'
}

runtime_paths_test::main "$@"
