#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
ZSH_BIN="${ZSH_BIN:-/bin/zsh}"

zsh_bootstrap_test::fail() {
  printf 'zsh-bootstrap: %s\n' "$1" >&2
  exit 1
}

zsh_bootstrap_test::write_executable() {
  local path="$1"
  shift || true

  mkdir -p "$(dirname -- "$path")"
  printf '%s\n' "$@" >"$path"
  chmod +x "$path"
}

zsh_bootstrap_test::setup_fixture() {
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zsh-bootstrap.XXXXXX")"
  HOME_DIR="$WORK_DIR/home"
  INITIAL_BIN="$WORK_DIR/initial-bin"
  FAKE_BREW_PREFIX="$WORK_DIR/homebrew"
  FNM_TEST_ROOT="$WORK_DIR/fnm"
  TEST_TMPDIR="$WORK_DIR/tmp"
  NPM_GLOBAL_BIN="$HOME_DIR/Library/Application Support/npm-global/bin"
  FNM_INSTALL_DIR="$HOME_DIR/Library/Application Support/fnm"
  VSCODE_SHELL_INTEGRATION_SCRIPT="$WORK_DIR/vscode-shellIntegration-rc.zsh"

  mkdir -p \
    "$HOME_DIR" \
    "$HOME_DIR/.config/dotfiles" \
    "$INITIAL_BIN" \
    "$FAKE_BREW_PREFIX/bin" \
    "$FNM_TEST_ROOT/node-bin" \
    "$NPM_GLOBAL_BIN" \
    "$FNM_INSTALL_DIR" \
    "$TEST_TMPDIR" \
    "$HOME_DIR/Library/pnpm" \
    "$HOME_DIR/.local/share/pnpm"

  ln -s "$DOTFILES_ROOT/zsh/.zshenv" "$HOME_DIR/.zshenv"
  ln -s "$DOTFILES_ROOT/zsh/.zprofile" "$HOME_DIR/.zprofile"
  ln -s "$DOTFILES_ROOT/zsh/.zshrc" "$HOME_DIR/.zshrc"

  zsh_bootstrap_test::write_executable "$INITIAL_BIN/brew" \
    '#!/bin/sh' \
    'if [ "${1:-}" = "shellenv" ]; then' \
    '  printf "export HOMEBREW_PREFIX=\"%s\"\n" "$FAKE_BREW_PREFIX"' \
    '  printf "export HOMEBREW_CELLAR=\"%s/Cellar\"\n" "$FAKE_BREW_PREFIX"' \
    '  printf "export HOMEBREW_REPOSITORY=\"%s\"\n" "$FAKE_BREW_PREFIX"' \
    '  printf "export PATH=\"%s/bin:$PATH\"\n" "$FAKE_BREW_PREFIX"' \
    '  printf "export MANPATH=\"%s/share/man:$MANPATH\"\n" "$FAKE_BREW_PREFIX"' \
    '  printf "export INFOPATH=\"%s/share/info:$INFOPATH\"\n" "$FAKE_BREW_PREFIX"' \
    '  exit 0' \
    'fi' \
    'exit 1'

  zsh_bootstrap_test::write_executable "$FAKE_BREW_PREFIX/bin/fnm" \
    '#!/bin/sh' \
    'if [ "${1:-}" = "env" ]; then' \
    '  printf "%s\n" "$*" >> "$FNM_TEST_ROOT/fnm-args.log"' \
    '  printf "export PATH=\"%s/node-bin:$PATH\"\n" "$FNM_TEST_ROOT"' \
    '  printf "export FNM_MULTISHELL_PATH=\"%s/fnm_multishell\"\n" "${XDG_RUNTIME_DIR:-$FNM_TEST_ROOT/runtime}"' \
    '  printf "export FNM_VERSION_FILE_STRATEGY=\"recursive\"\n"' \
    '  printf "export FNM_DIR=\"%s\"\n" "$FNM_TEST_ROOT"' \
    '  case " $* " in' \
    '    *" --use-on-cd "*)' \
    '      printf "autoload -U add-zsh-hook\n"' \
    '      printf "_fnm_autoload_hook () { :; }\n"' \
    '      printf "add-zsh-hook -D chpwd _fnm_autoload_hook\n"' \
    '      printf "add-zsh-hook chpwd _fnm_autoload_hook\n"' \
    '      ;;' \
    '  esac' \
    '  printf "rehash\n"' \
    '  exit 0' \
    'fi' \
    'exit 1'

  zsh_bootstrap_test::write_executable "$FNM_TEST_ROOT/node-bin/node" '#!/bin/sh' 'printf "node\n"'
  zsh_bootstrap_test::write_executable "$FNM_TEST_ROOT/node-bin/npm" '#!/bin/sh' 'printf "npm\n"'
  zsh_bootstrap_test::write_executable "$HOME_DIR/Library/pnpm/pnpm" '#!/bin/sh' 'printf "pnpm\n"'
  zsh_bootstrap_test::write_executable "$HOME_DIR/.local/share/pnpm/pnpm" '#!/bin/sh' 'printf "pnpm\n"'
  zsh_bootstrap_test::write_executable "$INITIAL_BIN/code" \
    '#!/bin/sh' \
    'if [ "${1:-}" = "--locate-shell-integration-path" ]; then' \
    '  printf "%s\n" "$VSCODE_SHELL_INTEGRATION_SCRIPT"' \
    '  exit 0' \
    'fi' \
    'exit 1'
  printf '%s\n' \
    'print -r -- "vscode-integration-loaded"' \
    'if [[ "${VSCODE_INJECTION:-}" == "1" && -f "$USER_ZDOTDIR/.zshrc" ]]; then' \
    '  source "$USER_ZDOTDIR/.zshrc"' \
    'fi' \
    >"$VSCODE_SHELL_INTEGRATION_SCRIPT"

  CHECK_SCRIPT="$WORK_DIR/check-toolchain.zsh"
  cat >"$CHECK_SCRIPT" <<'EOF'
for command_name in brew fnm node npm pnpm; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    print -r -- "$command_name missing"
    exit 1
  fi
done
print -r -- "toolchain-ok"
EOF
}

zsh_bootstrap_test::run_zsh() {
  local name="$1"
  shift || true
  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    PATH="$INITIAL_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    ZDOTDIR="$HOME_DIR" \
    TERM="xterm-256color" \
    TMPDIR="$TEST_TMPDIR/" \
    FAKE_BREW_PREFIX="$FAKE_BREW_PREFIX" \
    FNM_TEST_ROOT="$FNM_TEST_ROOT" \
    VSCODE_SHELL_INTEGRATION_SCRIPT="$VSCODE_SHELL_INTEGRATION_SCRIPT" \
    "$ZSH_BIN" "$@" >"$output_file" 2>"$error_file"
}

zsh_bootstrap_test::assert_output() {
  local name="$1"
  local expected="$2"
  local output_file="$WORK_DIR/${name}.out"

  if ! diff -u <(printf '%s\n' "$expected") "$output_file"; then
    zsh_bootstrap_test::fail "unexpected stdout for $name"
  fi
}

zsh_bootstrap_test::assert_no_stderr() {
  local name="$1"
  local error_file="$WORK_DIR/${name}.err"

  if [[ -s "$error_file" ]]; then
    sed -n '1,120p' "$error_file" >&2
    zsh_bootstrap_test::fail "unexpected stderr for $name"
  fi
}

zsh_bootstrap_test::assert_toolchain_case() {
  local name="$1"
  shift || true

  zsh_bootstrap_test::run_zsh "$name" "$@"
  zsh_bootstrap_test::assert_output "$name" "toolchain-ok"
  zsh_bootstrap_test::assert_no_stderr "$name"
  printf 'ok %s\n' "$name"
}

zsh_bootstrap_test::assert_noninteractive_fnm_mode() {
  if grep -q -- '--use-on-cd' "$FNM_TEST_ROOT/fnm-args.log"; then
    zsh_bootstrap_test::fail "non-interactive zsh loaded fnm --use-on-cd"
  fi
  printf 'ok fnm_base_mode\n'
}

zsh_bootstrap_test::assert_bootstrap_guard_not_exported() {
  local name="bootstrap_guard_scope"

  zsh_bootstrap_test::run_zsh "$name" -c 'if env | grep -q "^DOTFILES_BOOTSTRAP_LOADED="; then print -r -- guard-exported; exit 1; fi; print -r -- guard-ok'
  zsh_bootstrap_test::assert_output "$name" "guard-ok"
  zsh_bootstrap_test::assert_no_stderr "$name"
  printf 'ok %s\n' "$name"
}

zsh_bootstrap_test::assert_set_e_direct_bootstrap() {
  local name="set_e_direct_bootstrap"
  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"
  local unlinked_home="$WORK_DIR/unlinked-home"

  mkdir -p "$unlinked_home"

  env -i \
    HOME="$unlinked_home" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    PATH="$INITIAL_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    TMPDIR="$TEST_TMPDIR/" \
    DOTFILES_ROOT="$DOTFILES_ROOT" \
    FAKE_BREW_PREFIX="$FAKE_BREW_PREFIX" \
    FNM_TEST_ROOT="$FNM_TEST_ROOT" \
    "$ZSH_BIN" -c 'set -euo pipefail; source "$DOTFILES_ROOT/zsh/lib/bootstrap.zsh"; print -r -- set-e-ok' \
    >"$output_file" 2>"$error_file"

  zsh_bootstrap_test::assert_output "$name" "set-e-ok"
  zsh_bootstrap_test::assert_no_stderr "$name"
  printf 'ok %s\n' "$name"
}

zsh_bootstrap_test::assert_interactive_fnm_hook() {
  local name="interactive_fnm_hook"

  zsh_bootstrap_test::run_zsh "$name" -ic 'if (( $+functions[_fnm_autoload_hook] )); then print -r -- hook-ok; else print -r -- hook-missing; exit 1; fi'
  zsh_bootstrap_test::assert_output "$name" "hook-ok"
  zsh_bootstrap_test::assert_no_stderr "$name"

  if ! grep -q -- '--use-on-cd' "$FNM_TEST_ROOT/fnm-args.log"; then
    zsh_bootstrap_test::fail "interactive zsh did not load fnm --use-on-cd"
  fi

  printf 'ok %s\n' "$name"
}

zsh_bootstrap_test::assert_shared_runtime_paths() {
  local name="shared_runtime_paths"
  local current_uid expected_runtime_dir

  current_uid="$(id -u)"
  expected_runtime_dir="${TEST_TMPDIR%/}/fnm-runtime-${current_uid}"

  zsh_bootstrap_test::run_zsh "$name" -c '
    case ":$PATH:" in
      *":'"$NPM_GLOBAL_BIN"':"*) ;;
      *) print -r -- "missing-npm-global-path"; exit 1 ;;
    esac

    case ":$PATH:" in
      *":'"$HOME_DIR"'/Library/pnpm:"*) ;;
      *) print -r -- "missing-pnpm-home-path"; exit 1 ;;
    esac

    case ":$PATH:" in
      *":'"$FNM_INSTALL_DIR"':"*) ;;
      *) print -r -- "missing-fnm-install-path"; exit 1 ;;
    esac

    print -r -- "config=$DOTFILES_CONFIG_DIR"
    print -r -- "install_env=$DOTFILES_INSTALL_ENV"
    print -r -- "env_zsh=$DOTFILES_ENV_ZSH"
    print -r -- "profile_zsh=$DOTFILES_PROFILE_ZSH"
    print -r -- "local_zsh=$DOTFILES_LOCAL_ZSH"
    print -r -- "pnpm_home=$PNPM_HOME"
    print -r -- "fnm_multishell=$FNM_MULTISHELL_PATH"
    print -r -- "paths-ok"
  '

  zsh_bootstrap_test::assert_output "$name" "$(cat <<EOF
config=$HOME_DIR/.config/dotfiles
install_env=$HOME_DIR/.config/dotfiles/install.env
env_zsh=$HOME_DIR/.config/dotfiles/env.zsh
profile_zsh=$HOME_DIR/.config/dotfiles/profile.zsh
local_zsh=$HOME_DIR/.config/dotfiles/local.zsh
pnpm_home=$HOME_DIR/Library/pnpm
fnm_multishell=$expected_runtime_dir/fnm_multishell
paths-ok
EOF
)"
  zsh_bootstrap_test::assert_no_stderr "$name"
  printf 'ok %s\n' "$name"
}

zsh_bootstrap_test::assert_vscode_injection_does_not_resource_zshrc() {
  local name="vscode_injection_no_zshrc_recursion"
  local output_file="$WORK_DIR/${name}.out"
  local error_file="$WORK_DIR/${name}.err"

  printf '%s\n' 'print -r -- "local-zsh-loaded"' >"$HOME_DIR/.config/dotfiles/local.zsh"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    PATH="$INITIAL_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    ZDOTDIR="$HOME_DIR" \
    TERM="xterm-256color" \
    TERM_PROGRAM="vscode" \
    TMPDIR="$TEST_TMPDIR/" \
    FAKE_BREW_PREFIX="$FAKE_BREW_PREFIX" \
    FNM_TEST_ROOT="$FNM_TEST_ROOT" \
    VSCODE_INJECTION="1" \
    USER_ZDOTDIR="$HOME_DIR" \
    VSCODE_SHELL_INTEGRATION_SCRIPT="$VSCODE_SHELL_INTEGRATION_SCRIPT" \
    "$ZSH_BIN" -ic 'print -r -- vscode-shell-ready' >"$output_file" 2>"$error_file"

  zsh_bootstrap_test::assert_output "$name" $'local-zsh-loaded\nvscode-shell-ready'
  zsh_bootstrap_test::assert_no_stderr "$name"
  printf 'ok %s\n' "$name"
}

zsh_bootstrap_test::main() {
  WORK_DIR=""
  trap '[[ -n "${WORK_DIR:-}" ]] && rm -rf "$WORK_DIR"' EXIT

  [[ -x "$ZSH_BIN" ]] || zsh_bootstrap_test::fail "zsh not found: $ZSH_BIN"

  zsh_bootstrap_test::setup_fixture
  zsh_bootstrap_test::assert_toolchain_case "zsh_c" -c 'source "$0"' "$CHECK_SCRIPT"
  zsh_bootstrap_test::assert_toolchain_case "zsh_lc" -lc 'source "$0"' "$CHECK_SCRIPT"
  zsh_bootstrap_test::assert_toolchain_case "zsh_script" "$CHECK_SCRIPT"
  zsh_bootstrap_test::assert_noninteractive_fnm_mode
  zsh_bootstrap_test::assert_bootstrap_guard_not_exported
  zsh_bootstrap_test::assert_set_e_direct_bootstrap
  zsh_bootstrap_test::assert_shared_runtime_paths
  zsh_bootstrap_test::assert_interactive_fnm_hook
  zsh_bootstrap_test::assert_vscode_injection_does_not_resource_zshrc

  printf 'all zsh bootstrap tests passed\n'
}

zsh_bootstrap_test::main "$@"
