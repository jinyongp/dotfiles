#!/usr/bin/env bash

set -euo pipefail

# End-to-end temp-home smoke coverage for the real ./install entrypoint on the
# current host platform. Non-host platform branches are covered separately by
# sourceable module tests so this harness can stay hermetic and deterministic.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
REAL_ZSH_BIN="${REAL_ZSH_BIN:-/bin/zsh}"
SCRIPT_BIN="${SCRIPT_BIN:-$(command -v script || true)}"
ROOT_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-smoke.XXXXXX")"
BASE_GIT_STATUS="$(git -C "$DOTFILES_ROOT" status --porcelain 2>/dev/null || true)"

trap 'rm -rf "$ROOT_WORK_DIR"' EXIT

install_smoke_test::fail() {
  printf 'install-smoke: %s\n' "$1" >&2
  exit 1
}

install_smoke_test::write_executable() {
  local path="$1"
  shift || true

  mkdir -p "$(dirname -- "$path")"
  printf '%s\n' "$@" >"$path"
  chmod +x "$path"
}

install_smoke_test::normalize_file() {
  perl -0pe '
    s/\e\][^\a]*(?:\a|\e\\\\)//g;
    s/\e\[[0-?]*[ -\/]*[@-~]//g;
    s/.\x08//g;
    s/\r//g;
    s/[\x00-\x08\x0b-\x1f\x7f]//g;
    s/\n+\z/\n/;
  ' "$1"
}

install_smoke_test::assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if ! printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    printf '%s\n' "$haystack" >&2
    install_smoke_test::fail "$message"
  fi
}

install_smoke_test::assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    printf '%s\n' "$haystack" >&2
    install_smoke_test::fail "$message"
  fi
}

install_smoke_test::assert_file_exists() {
  local path="$1"
  [[ -e "$path" ]] || install_smoke_test::fail "expected path to exist: $path"
}

install_smoke_test::assert_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || install_smoke_test::fail "did not expect path to exist: $path"
}

install_smoke_test::assert_symlink_target() {
  local path="$1"
  local expected="$2"

  [[ -L "$path" ]] || install_smoke_test::fail "expected symlink: $path"

  if [[ "$(readlink "$path")" != "$expected" ]]; then
    printf 'expected symlink target: %s\nactual symlink target:   %s\n' "$expected" "$(readlink "$path")" >&2
    install_smoke_test::fail "unexpected symlink target for $path"
  fi
}

install_smoke_test::assert_file_contains() {
  local path="$1"
  local expected="$2"
  local message="$3"

  install_smoke_test::assert_file_exists "$path"
  if ! grep -Fq -- "$expected" "$path"; then
    sed -n '1,120p' "$path" >&2
    install_smoke_test::fail "$message"
  fi
}

install_smoke_test::assert_no_stderr() {
  local path="$1"

  if [[ -s "$path" ]]; then
    sed -n '1,160p' "$path" >&2
    install_smoke_test::fail "unexpected stderr output: $path"
  fi
}

install_smoke_test::assert_login_zsh_launched() {
  local path="$1"

  if ! grep -Fqx -- "-l" "$path"; then
    sed -n '1,120p' "$path" >&2
    install_smoke_test::fail "expected login zsh launch"
  fi
}

install_smoke_test::assert_login_zsh_not_launched() {
  local path="$1"

  if grep -Fqx -- "-l" "$path"; then
    sed -n '1,120p' "$path" >&2
    install_smoke_test::fail "did not expect login zsh launch"
  fi
}

install_smoke_test::assert_git_status_unchanged() {
  local current_status

  current_status="$(git -C "$DOTFILES_ROOT" status --porcelain 2>/dev/null || true)"
  if [[ "$current_status" != "$BASE_GIT_STATUS" ]]; then
    printf 'before:\n%s\nafter:\n%s\n' "$BASE_GIT_STATUS" "$current_status" >&2
    install_smoke_test::fail "repo status changed during smoke test"
  fi
}

install_smoke_test::reset_case_config() {
  SMOKE_PLATFORM_OSTYPE="darwin23"
  SMOKE_WSL_DISTRO_NAME=""
  SMOKE_INSTALL_PACKAGE_MANAGER="brew"
  SMOKE_INSTALL_THEME="starship"
  SMOKE_INSTALL_ENABLE_OH_MY_ZSH="0"
  SMOKE_CHSH_SHOULD_FAIL="0"
  SMOKE_GETENT_SHELL="/bin/bash"
}

install_smoke_test::setup_case() {
  local case_name="$1"

  CASE_DIR="$ROOT_WORK_DIR/$case_name"
  HOME_DIR="$CASE_DIR/home"
  XDG_CONFIG_HOME="$CASE_DIR/config"
  DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"
  INITIAL_BIN="$CASE_DIR/bin"
  TMP_DIR="$CASE_DIR/tmp"
  STATE_DIR="$CASE_DIR/state"
  FAKE_BREW_PREFIX="$CASE_DIR/homebrew"
  OUTPUT_FILE="$CASE_DIR/output.out"
  ERROR_FILE="$CASE_DIR/output.err"
  TRANSCRIPT_FILE="$CASE_DIR/transcript.out"
  ZSH_LOG_FILE="$STATE_DIR/zsh-invocations.log"
  BREW_LOG_FILE="$STATE_DIR/brew.log"
  NPM_LOG_FILE="$STATE_DIR/npm.log"
  APT_LOG_FILE="$STATE_DIR/apt-get.log"
  GIT_LOG_FILE="$STATE_DIR/git.log"
  CHSH_LOG_FILE="$STATE_DIR/chsh.log"

  mkdir -p \
    "$HOME_DIR" \
    "$XDG_CONFIG_HOME" \
    "$DOTFILES_CONFIG_DIR" \
    "$INITIAL_BIN" \
    "$TMP_DIR" \
    "$STATE_DIR" \
    "$FAKE_BREW_PREFIX/bin"

  : "${SMOKE_PLATFORM_OSTYPE:=darwin23}"
  : "${SMOKE_WSL_DISTRO_NAME:=}"
  : "${SMOKE_INSTALL_PACKAGE_MANAGER:=brew}"
  : "${SMOKE_INSTALL_THEME:=starship}"
  : "${SMOKE_INSTALL_ENABLE_OH_MY_ZSH:=0}"
  : "${SMOKE_CHSH_SHOULD_FAIL:=0}"
  : "${SMOKE_GETENT_SHELL:=/bin/bash}"

  cat >"$DOTFILES_CONFIG_DIR/install.env" <<EOF
export DOTFILES_PACKAGE_MANAGER=${SMOKE_INSTALL_PACKAGE_MANAGER}
export DOTFILES_THEME=${SMOKE_INSTALL_THEME}
export DOTFILES_ENABLE_OH_MY_ZSH=${SMOKE_INSTALL_ENABLE_OH_MY_ZSH}
EOF

  install_smoke_test::write_fake_commands
}

install_smoke_test::write_fake_commands() {
  install_smoke_test::write_executable "$INITIAL_BIN/zsh" \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "${SMOKE_STATE_DIR}/zsh-invocations.log"' \
    'if [ "${1:-}" = "-l" ] && [ "$#" -eq 1 ]; then' \
    '  exit 0' \
    'fi' \
    'exec "$REAL_ZSH_BIN" "$@"'

  install_smoke_test::write_executable "$INITIAL_BIN/brew" \
    '#!/bin/sh' \
    'log_file="${SMOKE_STATE_DIR}/brew.log"' \
    'formula_dir="${SMOKE_STATE_DIR}/brew-formula"' \
    'cask_dir="${SMOKE_STATE_DIR}/brew-cask"' \
    'prefix="${FAKE_BREW_PREFIX}"' \
    'mkdir -p "$formula_dir" "$cask_dir" "$prefix/bin"' \
    'printf "%s\n" "$*" >> "$log_file"' \
    'make_cmd() {' \
    '  command_name="$1"' \
    '  target="$prefix/bin/$command_name"' \
    '  [ -n "$command_name" ] || return 0' \
    '  printf "#!/bin/sh\nexit 0\n" > "$target"' \
    '  chmod +x "$target"' \
    '}' \
    'install_formula() {' \
    '  formula_name="$1"' \
    '  : > "$formula_dir/$formula_name"' \
    '  case "$formula_name" in' \
    '    starship) make_cmd starship ;;' \
    '    neovim) make_cmd nvim ;;' \
    '    ripgrep) make_cmd rg ;;' \
    '    fd) make_cmd fd ;;' \
    '    eza) make_cmd eza ;;' \
    '    fnm) make_cmd fnm ;;' \
    '    jq) make_cmd jq ;;' \
    '    gh) make_cmd gh ;;' \
    '    zsh) make_cmd zsh ;;' \
    '  esac' \
    '}' \
    'install_cask() {' \
    '  cask_name="$1"' \
    '  : > "$cask_dir/$cask_name"' \
    '}' \
    'case "${1:-}" in' \
    '  shellenv)' \
    '    printf "export HOMEBREW_PREFIX=\"%s\"\n" "$prefix"' \
    '    printf "export HOMEBREW_CELLAR=\"%s/Cellar\"\n" "$prefix"' \
    '    printf "export HOMEBREW_REPOSITORY=\"%s\"\n" "$prefix"' \
    '    printf "export PATH=\"%s/bin:$PATH\"\n" "$prefix"' \
    '    exit 0' \
    '    ;;' \
    '  list)' \
    '    if [ "${2:-}" = "--cask" ]; then' \
    '      [ -f "$cask_dir/${3:-}" ]' \
    '      exit $?' \
    '    fi' \
    '    [ -f "$formula_dir/${2:-}" ]' \
    '    exit $?' \
    '    ;;' \
    '  install)' \
    '    if [ "${2:-}" = "--cask" ]; then' \
    '      install_cask "${3:-}"' \
    '      exit 0' \
    '    fi' \
    '    install_formula "${2:-}"' \
    '    exit 0' \
    '    ;;' \
    '  tap)' \
    '    exit 0' \
    '    ;;' \
    'esac' \
    'exit 1'

  install_smoke_test::write_executable "$INITIAL_BIN/git" \
    '#!/bin/sh' \
    'log_file="${SMOKE_STATE_DIR}/git.log"' \
    'printf "%s\n" "$*" >> "$log_file"' \
    'if [ "${1:-}" = "clone" ]; then' \
    '  target=""' \
    '  for arg in "$@"; do' \
    '    target="$arg"' \
    '  done' \
    '  mkdir -p "$target"' \
    '  case "$target" in' \
    '    */.oh-my-zsh)' \
    '      mkdir -p "$target/custom/plugins" "$target/custom/themes"' \
    '      ;;' \
    '  esac' \
    '  exit 0' \
    'fi' \
    'exec /usr/bin/git "$@"'

  install_smoke_test::write_executable "$INITIAL_BIN/node" '#!/bin/sh' 'exit 0'

  install_smoke_test::write_executable "$INITIAL_BIN/npm" \
    '#!/bin/sh' \
    'log_file="${SMOKE_STATE_DIR}/npm.log"' \
    'state_dir="${SMOKE_STATE_DIR}/npm-global"' \
    'prefix="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"' \
    'bin_dir="$prefix/bin"' \
    'last_arg=""' \
    'mkdir -p "$state_dir" "$bin_dir"' \
    'printf "%s\n" "$*" >> "$log_file"' \
    'for arg in "$@"; do' \
    '  last_arg="$arg"' \
    'done' \
    'case "${1:-}" in' \
    '  list)' \
    '    [ -f "$state_dir/$last_arg" ]' \
    '    exit $?' \
    '    ;;' \
    '  install)' \
    '    : > "$state_dir/$last_arg"' \
    '    printf "#!/bin/sh\nexit 0\n" > "$bin_dir/$last_arg"' \
    '    chmod +x "$bin_dir/$last_arg"' \
    '    exit 0' \
    '    ;;' \
    'esac' \
    'exit 1'

  install_smoke_test::write_executable "$INITIAL_BIN/pnpm" '#!/bin/sh' 'exit 0'

  install_smoke_test::write_executable "$INITIAL_BIN/curl" \
    '#!/bin/sh' \
    'log_file="${SMOKE_STATE_DIR}/curl.log"' \
    'destination=""' \
    'previous=""' \
    'printf "%s\n" "$*" >> "$log_file"' \
    'for arg in "$@"; do' \
    '  if [ "$previous" = "-o" ]; then' \
    '    destination="$arg"' \
    '    break' \
    '  fi' \
    '  previous="$arg"' \
    'done' \
    'if [ -n "$destination" ]; then' \
    '  printf "#!/bin/sh\nexit 0\n" > "$destination"' \
    '  chmod +x "$destination"' \
    'fi' \
    'exit 0'

  install_smoke_test::write_executable "$INITIAL_BIN/unzip" '#!/bin/sh' 'exit 0'

  install_smoke_test::write_executable "$INITIAL_BIN/sudo" \
    '#!/bin/sh' \
    'exec "$@"'

  install_smoke_test::write_executable "$INITIAL_BIN/apt-cache" \
    '#!/bin/sh' \
    'package_name="${2:-}"' \
    'case "$package_name" in' \
    '  jq|eza|git|curl|unzip|zsh|neovim|ripgrep|fd-find|tealdeer|gnupg|starship|gh)' \
    '    exit 0' \
    '    ;;' \
    'esac' \
    'exit 1'

  install_smoke_test::write_executable "$INITIAL_BIN/dpkg" \
    '#!/bin/sh' \
    'installed_dir="${SMOKE_STATE_DIR}/apt-installed"' \
    'if [ "${1:-}" = "-s" ] && [ -f "$installed_dir/${2:-}" ]; then' \
    '  exit 0' \
    'fi' \
    'exit 1'

  install_smoke_test::write_executable "$INITIAL_BIN/apt-get" \
    '#!/bin/sh' \
    'log_file="${SMOKE_STATE_DIR}/apt-get.log"' \
    'installed_dir="${SMOKE_STATE_DIR}/apt-installed"' \
    'mkdir -p "$installed_dir"' \
    'printf "%s\n" "$*" >> "$log_file"' \
    'make_cmd() {' \
    '  command_name="$1"' \
    '  target="${SMOKE_INITIAL_BIN}/$command_name"' \
    '  [ -n "$command_name" ] || return 0' \
    '  if [ ! -x "$target" ]; then' \
    '    printf "#!/bin/sh\nexit 0\n" > "$target"' \
    '    chmod +x "$target"' \
    '  fi' \
    '}' \
    'install_pkg() {' \
    '  package_name="$1"' \
    '  : > "$installed_dir/$package_name"' \
    '  case "$package_name" in' \
    '    jq) make_cmd jq ;;' \
    '    eza) make_cmd eza ;;' \
    '    gh) make_cmd gh ;;' \
    '    neovim) make_cmd nvim ;;' \
    '    ripgrep) make_cmd rg ;;' \
    '    fd-find) make_cmd fdfind ;;' \
    '    tealdeer) make_cmd tldr ;;' \
    '    gnupg) make_cmd gpg ;;' \
    '    starship) make_cmd starship ;;' \
    '  esac' \
    '}' \
    'case "${1:-}" in' \
    '  update)' \
    '    exit 0' \
    '    ;;' \
    '  install)' \
    '    shift' \
    '    if [ "${1:-}" = "-y" ]; then' \
    '      shift' \
    '    fi' \
    '    for package_name in "$@"; do' \
    '      install_pkg "$package_name"' \
    '    done' \
    '    exit 0' \
    '    ;;' \
    'esac' \
    'exit 1'

  install_smoke_test::write_executable "$INITIAL_BIN/getent" \
    '#!/bin/sh' \
    'if [ "${1:-}" = "passwd" ]; then' \
    '  printf "%s:x:1000:1000::%s:%s\n" "${2:-dotfiles}" "$HOME" "${SMOKE_GETENT_SHELL:-/bin/bash}"' \
    '  exit 0' \
    'fi' \
    'exit 1'

  install_smoke_test::write_executable "$INITIAL_BIN/chsh" \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "${SMOKE_STATE_DIR}/chsh.log"' \
    'if [ "${SMOKE_CHSH_SHOULD_FAIL:-0}" = "1" ]; then' \
    '  exit 1' \
    'fi' \
    'exit 0'
}

install_smoke_test::with_env() {
  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    DOTFILES_CONFIG_DIR="$DOTFILES_CONFIG_DIR" \
    PATH="$INITIAL_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    TMPDIR="$TMP_DIR/" \
    OSTYPE="$SMOKE_PLATFORM_OSTYPE" \
    WSL_DISTRO_NAME="$SMOKE_WSL_DISTRO_NAME" \
    FAKE_BREW_PREFIX="$FAKE_BREW_PREFIX" \
    SMOKE_STATE_DIR="$STATE_DIR" \
    SMOKE_INITIAL_BIN="$INITIAL_BIN" \
    SMOKE_CHSH_SHOULD_FAIL="$SMOKE_CHSH_SHOULD_FAIL" \
    SMOKE_GETENT_SHELL="$SMOKE_GETENT_SHELL" \
    REAL_ZSH_BIN="$REAL_ZSH_BIN" \
    "$@"
}

install_smoke_test::run_direct_install() {
  install_smoke_test::with_env \
    bash "$DOTFILES_ROOT/install" "$@" >"$OUTPUT_FILE" 2>"$ERROR_FILE"
}

install_smoke_test::run_interactive_install() {
  local key_sequence="$1"

  [[ -n "$SCRIPT_BIN" ]] || install_smoke_test::fail "script command is required for interactive smoke tests"

  printf '%b' "$key_sequence" | install_smoke_test::with_env \
    "$SCRIPT_BIN" -q "$TRANSCRIPT_FILE" bash "$DOTFILES_ROOT/install" >"$OUTPUT_FILE" 2>"$ERROR_FILE"
}

install_smoke_test::single_backup_dir() {
  local backup_root="$DOTFILES_CONFIG_DIR/backups"
  local backup_dirs
  local backup_count

  install_smoke_test::assert_file_exists "$backup_root"
  backup_dirs="$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d | sort)"
  backup_count="$(printf '%s\n' "$backup_dirs" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "$backup_count" != "1" ]]; then
    printf 'backup dirs:\n%s\n' "$backup_dirs" >&2
    install_smoke_test::fail "expected exactly one backup directory"
  fi

  printf '%s\n' "$backup_dirs"
}

install_smoke_test::assert_direct_dotfiles() {
  local normalized_output
  local backup_dir

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-dotfiles"

  printf '%s\n' 'export LEGACY_ZSHENV=1' >"$HOME_DIR/.zshenv"
  mkdir -p "$HOME_DIR/.config/nvim"
  printf '%s\n' 'set number' >"$HOME_DIR/.config/nvim/init.lua"

  install_smoke_test::run_direct_install dotfiles
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Post-install Report" "dotfiles install should print final report"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "dotfiles direct install should complete"

  install_smoke_test::assert_symlink_target "$HOME_DIR/.zshenv" "$DOTFILES_ROOT/zsh/.zshenv"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.zprofile" "$DOTFILES_ROOT/zsh/.zprofile"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.zshrc" "$DOTFILES_ROOT/zsh/.zshrc"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.vimrc" "$DOTFILES_ROOT/vim/.vimrc"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.gitconfig" "$DOTFILES_ROOT/git/.gitconfig"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.config/nvim" "$DOTFILES_ROOT/nvim"

  install_smoke_test::assert_file_contains "$DOTFILES_CONFIG_DIR/env.zsh" "# Managed By" "env.zsh header missing"
  install_smoke_test::assert_file_contains "$DOTFILES_CONFIG_DIR/profile.zsh" "# Managed By" "profile.zsh header missing"
  install_smoke_test::assert_file_contains "$DOTFILES_CONFIG_DIR/local.zsh" "# Managed By" "local.zsh header missing"
  install_smoke_test::assert_file_exists "$DOTFILES_CONFIG_DIR/git/personal.local.ini"
  install_smoke_test::assert_file_exists "$DOTFILES_CONFIG_DIR/git/root.local.ini"

  if [[ "$(git config --file "$DOTFILES_CONFIG_DIR/git/root.local.ini" --get core.hooksPath)" != "$DOTFILES_ROOT/git/hooks" ]]; then
    install_smoke_test::fail "root.local.ini should point hooksPath at repo hooks"
  fi

  install_smoke_test::assert_file_contains "$DOTFILES_CONFIG_DIR/install.env" "DOTFILES_PACKAGE_MANAGER=brew" "install.env should persist brew package manager"
  install_smoke_test::assert_file_contains "$DOTFILES_CONFIG_DIR/install.env" "DOTFILES_THEME=starship" "install.env should persist starship theme"

  backup_dir="$(install_smoke_test::single_backup_dir)"
  install_smoke_test::assert_file_contains "$backup_dir/.zshenv" "LEGACY_ZSHENV=1" "expected .zshenv backup in config backup root"
  install_smoke_test::assert_file_contains "$backup_dir/nvim/init.lua" "set number" "expected nvim backup in config backup root"

  install_smoke_test::assert_login_zsh_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_dotfiles\n'
}

install_smoke_test::assert_direct_neovim() {
  local normalized_output

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-neovim"
  install_smoke_test::run_direct_install neovim
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "neovim direct install should complete"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.config/nvim" "$DOTFILES_ROOT/nvim"
  install_smoke_test::assert_not_exists "$HOME_DIR/.zshenv"
  install_smoke_test::assert_not_exists "$HOME_DIR/.zprofile"
  install_smoke_test::assert_not_exists "$HOME_DIR/.zshrc"
  install_smoke_test::assert_not_exists "$HOME_DIR/.gitconfig"
  install_smoke_test::assert_not_exists "$DOTFILES_CONFIG_DIR/git"
  install_smoke_test::assert_login_zsh_not_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install neovim" "expected brew install for neovim"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install ripgrep" "expected brew install for ripgrep"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install fd" "expected brew install for fd"
  install_smoke_test::assert_file_contains "$NPM_LOG_FILE" "install --global typescript" "expected npm install for typescript"
  install_smoke_test::assert_file_contains "$NPM_LOG_FILE" "install --global typescript-language-server" "expected npm install for typescript-language-server"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_neovim\n'
}

install_smoke_test::assert_direct_packages() {
  local normalized_output

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-packages"
  install_smoke_test::run_direct_install packages fnm eza
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "packages direct install should complete"
  install_smoke_test::assert_contains "$normalized_output" "No shell restart is needed." "packages direct install should not need shell restart"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install fnm" "expected brew install for fnm"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install eza" "expected brew install for eza"
  install_smoke_test::assert_file_exists "$FAKE_BREW_PREFIX/bin/fnm"
  install_smoke_test::assert_file_exists "$FAKE_BREW_PREFIX/bin/eza"
  install_smoke_test::assert_not_exists "$HOME_DIR/.zshenv"
  install_smoke_test::assert_not_exists "$DOTFILES_CONFIG_DIR/git"
  install_smoke_test::assert_login_zsh_not_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_packages\n'
}

install_smoke_test::assert_direct_theme() {
  local normalized_output

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-theme"

  ln -s "$DOTFILES_ROOT/zsh/.zshrc" "$HOME_DIR/.zshrc"

  install_smoke_test::run_direct_install theme
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "theme direct install should complete"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install starship" "theme direct install should install starship"
  install_smoke_test::assert_login_zsh_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_theme\n'
}

install_smoke_test::assert_direct_fonts() {
  local normalized_output

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-fonts"

  install_smoke_test::run_direct_install fonts bundled-monocraft font-fira-code-nerd-font
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "fonts direct install should complete"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install --cask font-fira-code-nerd-font" "expected font cask install"
  install_smoke_test::assert_file_exists "$HOME_DIR/Library/Fonts/Monocraft.otf"
  install_smoke_test::assert_file_exists "$HOME_DIR/Library/Fonts/MonocraftNF.otf"
  install_smoke_test::assert_login_zsh_not_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_fonts\n'
}

install_smoke_test::assert_direct_desktop_apps() {
  local normalized_output

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-desktop-apps"

  install_smoke_test::run_direct_install desktop_apps iterm2 raycast
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "desktop apps direct install should complete"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install --cask iterm2" "expected iterm2 cask install"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install --cask raycast" "expected raycast cask install"
  install_smoke_test::assert_login_zsh_not_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_desktop_apps\n'
}

install_smoke_test::assert_direct_macos_defaults() {
  local normalized_output

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "direct-macos-defaults"

  install_smoke_test::run_direct_install macos_defaults
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_output="$(install_smoke_test::normalize_file "$OUTPUT_FILE")"
  install_smoke_test::assert_contains "$normalized_output" "Direct install complete." "macos defaults direct install should complete"
  install_smoke_test::assert_file_contains "$HOME_DIR/Library/KeyBindings/DefaultKeyBinding.dict" '"₩" = ("insertText:", "\`");' "expected keybinding file contents"
  install_smoke_test::assert_login_zsh_not_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok direct_macos_defaults\n'
}

install_smoke_test::assert_interactive_minimal() {
  local normalized_transcript

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "interactive-minimal"
  install_smoke_test::run_interactive_install $'\033[A\r\r\r\r'
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_transcript="$(install_smoke_test::normalize_file "$TRANSCRIPT_FILE")"
  install_smoke_test::assert_contains "$normalized_transcript" "Select installation profile." "interactive install should show profile picker"
  install_smoke_test::assert_contains "$normalized_transcript" "Final summary actions." "interactive install should show summary actions"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install starship" "minimal interactive install should install starship"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.zshenv" "$DOTFILES_ROOT/zsh/.zshenv"
  install_smoke_test::assert_symlink_target "$HOME_DIR/.zshrc" "$DOTFILES_ROOT/zsh/.zshrc"
  install_smoke_test::assert_file_exists "$DOTFILES_CONFIG_DIR/git/personal.local.ini"
  install_smoke_test::assert_file_contains "$DOTFILES_CONFIG_DIR/install.env" "DOTFILES_THEME=starship" "interactive install should persist starship theme"
  install_smoke_test::assert_login_zsh_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok interactive_minimal\n'
}

install_smoke_test::assert_interactive_recommended() {
  local normalized_transcript

  install_smoke_test::reset_case_config
  install_smoke_test::setup_case "interactive-recommended"
  install_smoke_test::run_interactive_install $'\r\r\r\r\r'
  install_smoke_test::assert_no_stderr "$ERROR_FILE"

  normalized_transcript="$(install_smoke_test::normalize_file "$TRANSCRIPT_FILE")"
  install_smoke_test::assert_contains "$normalized_transcript" "Review selected items?" "recommended interactive flow should offer review gate"
  install_smoke_test::assert_contains "$normalized_transcript" "Machine-local Git identity." "recommended interactive flow should open the Git identity gate"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install gh" "recommended interactive flow should install gh"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install fd" "recommended interactive flow should install fd"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install eza" "recommended interactive flow should install eza"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install fnm" "recommended interactive flow should install fnm"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install neovim" "recommended interactive flow should install neovim"
  install_smoke_test::assert_file_contains "$BREW_LOG_FILE" "install ripgrep" "recommended interactive flow should install ripgrep"
  install_smoke_test::assert_not_contains "$(cat "$BREW_LOG_FILE")" "install tealdeer" "recommended interactive flow should not install tldr by default"
  install_smoke_test::assert_not_contains "$(cat "$BREW_LOG_FILE")" "install gnupg" "recommended interactive flow should not install gnupg by default"
  install_smoke_test::assert_not_contains "$(cat "$BREW_LOG_FILE")" "install diff-so-fancy" "recommended interactive flow should not install diff-so-fancy by default"
  install_smoke_test::assert_login_zsh_launched "$ZSH_LOG_FILE"
  install_smoke_test::assert_git_status_unchanged
  printf 'ok interactive_recommended\n'
}

install_smoke_test::main() {
  [[ -x "$REAL_ZSH_BIN" ]] || install_smoke_test::fail "zsh not found: $REAL_ZSH_BIN"
  install_smoke_test::assert_direct_dotfiles
  install_smoke_test::assert_direct_theme
  install_smoke_test::assert_direct_neovim
  install_smoke_test::assert_direct_packages
  install_smoke_test::assert_direct_fonts
  install_smoke_test::assert_direct_desktop_apps
  install_smoke_test::assert_direct_macos_defaults
  install_smoke_test::assert_interactive_minimal
  install_smoke_test::assert_interactive_recommended
  printf 'all install smoke tests passed\n'
}

install_smoke_test::main "$@"
