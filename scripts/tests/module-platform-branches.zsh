#!/bin/zsh

set -euo pipefail

# Sourceable platform-branch coverage for WSL/Linux-focused module behavior that
# cannot be exercised through the macOS-hosted top-level install smoke harness.

SCRIPT_DIR="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/module-platform-branches.XXXXXX")"
HOME="$WORK_DIR/home"
XDG_CONFIG_HOME="$HOME/.config"
DOTFILES_CONFIG_DIR="$XDG_CONFIG_HOME/dotfiles"
INITIAL_BIN="$WORK_DIR/bin"
STATE_DIR="$WORK_DIR/state"

export DOTFILES_ROOT HOME XDG_CONFIG_HOME DOTFILES_CONFIG_DIR
export PATH="$INITIAL_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
export SMOKE_STATE_DIR="$STATE_DIR"
export SMOKE_INITIAL_BIN="$INITIAL_BIN"
export SMOKE_GETENT_SHELL="/bin/bash"
export SMOKE_CHSH_SHOULD_FAIL="0"

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME" "$DOTFILES_CONFIG_DIR" "$INITIAL_BIN" "$STATE_DIR"

platform_module_test::write_executable() {
  local path="$1"
  shift || true

  /bin/mkdir -p "$(/usr/bin/dirname -- "$path")"
  printf '%s\n' "$@" >"$path"
  /bin/chmod +x "$path"
}

platform_module_test::setup_fake_commands() {
  platform_module_test::write_executable "$INITIAL_BIN/zsh" '#!/bin/sh' 'exit 0'
  platform_module_test::write_executable "$INITIAL_BIN/curl" '#!/bin/sh' 'exit 0'
  platform_module_test::write_executable "$INITIAL_BIN/unzip" '#!/bin/sh' 'exit 0'
  platform_module_test::write_executable "$INITIAL_BIN/sudo" '#!/bin/sh' 'exec "$@"'

  platform_module_test::write_executable "$INITIAL_BIN/git" \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "${SMOKE_STATE_DIR}/git.log"' \
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
    'exit 1'

  platform_module_test::write_executable "$INITIAL_BIN/apt-cache" \
    '#!/bin/sh' \
    'package_name="${2:-}"' \
    'case "$package_name" in' \
    '  jq|eza|git|curl|unzip|zsh|neovim|ripgrep|fd-find|tealdeer|gnupg|starship|gh)' \
    '    exit 0' \
    '    ;;' \
    'esac' \
    'exit 1'

  platform_module_test::write_executable "$INITIAL_BIN/dpkg" \
    '#!/bin/sh' \
    'installed_dir="${SMOKE_STATE_DIR}/apt-installed"' \
    'if [ "${1:-}" = "-s" ] && [ -f "$installed_dir/${2:-}" ]; then' \
    '  exit 0' \
    'fi' \
    'exit 1'

  platform_module_test::write_executable "$INITIAL_BIN/apt-get" \
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

  platform_module_test::write_executable "$INITIAL_BIN/getent" \
    '#!/bin/sh' \
    'if [ "${1:-}" = "passwd" ]; then' \
    '  printf "%s:x:1000:1000::%s:%s\n" "${2:-dotfiles}" "$HOME" "${SMOKE_GETENT_SHELL:-/bin/bash}"' \
    '  exit 0' \
    'fi' \
    'exit 1'

  platform_module_test::write_executable "$INITIAL_BIN/chsh" \
    '#!/bin/sh' \
    'printf "%s\n" "$*" >> "${SMOKE_STATE_DIR}/chsh.log"' \
    'if [ "${SMOKE_CHSH_SHOULD_FAIL:-0}" = "1" ]; then' \
    '  exit 1' \
    'fi' \
    'exit 0'
}

source "$DOTFILES_ROOT/scripts/lib/style.sh"
source "$DOTFILES_ROOT/scripts/lib/common.zsh"
source "$DOTFILES_ROOT/scripts/lib/platform.zsh"
source "$DOTFILES_ROOT/scripts/lib/catalog.sh"
source "$DOTFILES_ROOT/scripts/lib/packages.zsh"
source "$DOTFILES_ROOT/scripts/modules/shell.zsh"
source "$DOTFILES_ROOT/scripts/modules/theme.zsh"

platform_module_test::fail() {
  print -u2 -- "module-platform-branches: $1"
  exit 1
}

platform_module_test::assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  print -r -- "$haystack" | /usr/bin/grep -Fq -- "$needle" || platform_module_test::fail "$message"
}

platform_module_test::assert_file_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  [[ -f "$path" ]] || platform_module_test::fail "expected file: $path"
  if ! /usr/bin/grep -Fq -- "$needle" "$path"; then
    /usr/bin/sed -n '1,120p' "$path" >&2
    platform_module_test::fail "$message"
  fi
}

platform_module_test::assert_exists() {
  [[ -e "$1" ]] || platform_module_test::fail "expected path to exist: $1"
}

platform_module_test::normalize_file() {
  /usr/bin/perl -0pe '
    s/\e\][^\a]*(?:\a|\e\\\\)//g;
    s/\e\[[0-?]*[ -\/]*[@-~]//g;
    s/\r//g;
    s/\n+\z/\n/;
  ' "$1"
}

platform_module_test::reset_state() {
  export PATH="$INITIAL_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
  /bin/rm -rf "$STATE_DIR" "$HOME/.oh-my-zsh"
  /bin/mkdir -p "$STATE_DIR" "$DOTFILES_CONFIG_DIR"

  /bin/rm -f \
    "$INITIAL_BIN/jq" \
    "$INITIAL_BIN/eza" \
    "$INITIAL_BIN/gh" \
    "$INITIAL_BIN/nvim" \
    "$INITIAL_BIN/rg" \
    "$INITIAL_BIN/fdfind" \
    "$INITIAL_BIN/tldr" \
    "$INITIAL_BIN/gpg" \
    "$INITIAL_BIN/starship"

  DOTFILES_PLATFORM="wsl"
  DOTFILES_PACKAGE_MANAGER="apt"
  DOTFILES_THEME="starship"
  DOTFILES_RESULT_INSTALLED_ITEMS=()
  DOTFILES_RESULT_REUSED_ITEMS=()
  DOTFILES_RESULT_SKIPPED_ITEMS=()
  DOTFILES_RESULT_CREATED_FILES=()
  DOTFILES_RESULT_UPDATED_FILES=()
  DOTFILES_RESULT_LINKED_FILES=()
  DOTFILES_RESULT_BACKED_UP_FILES=()
  DOTFILES_RESULT_COMPLETED_WORK=()
  DOTFILES_RESULT_NOTES=()
  DOTFILES_RESULT_WARNINGS=()
  DOTFILES_EXECUTION_STEP_ACTIVE=0
  SMOKE_GETENT_SHELL="/bin/bash"
  SMOKE_CHSH_SHOULD_FAIL="0"
}

platform_module_test::assert_apt_package_install() {
  platform_module_test::reset_state

  package_manager::install_native_logical jq 1
  package_manager::install_native_logical eza 1

  platform_module_test::assert_file_contains "$STATE_DIR/apt-get.log" "update" "expected apt update before installs"
  platform_module_test::assert_file_contains "$STATE_DIR/apt-get.log" "install -y jq" "expected apt install for jq"
  platform_module_test::assert_file_contains "$STATE_DIR/apt-get.log" "install -y eza" "expected apt install for eza"
  platform_module_test::assert_contains "$(print -l -- "${DOTFILES_RESULT_INSTALLED_ITEMS[@]}")" "jq via apt" "expected jq install record"
  platform_module_test::assert_contains "$(print -l -- "${DOTFILES_RESULT_INSTALLED_ITEMS[@]}")" "eza via apt" "expected eza install record"
  print -- "ok apt_package_install"
}

platform_module_test::assert_default_shell_success() {
  platform_module_test::reset_state

  shell::ensure_default_shell >/dev/null
  platform_module_test::assert_file_contains "$STATE_DIR/chsh.log" "-s $INITIAL_BIN/zsh" "expected chsh invocation"
  print -- "ok default_shell_success"
}

platform_module_test::assert_default_shell_failure_warns() {
  local output_file="$WORK_DIR/chsh-failure.out"
  local output=""

  platform_module_test::reset_state
  SMOKE_CHSH_SHOULD_FAIL="1"

  shell::ensure_default_shell >"$output_file"
  output="$(platform_module_test::normalize_file "$output_file")"

  platform_module_test::assert_contains "$output" "Failed to change the default shell automatically." "missing chsh failure warning"
  platform_module_test::assert_contains "$output" "Run this manually later: chsh -s $INITIAL_BIN/zsh" "missing manual chsh follow-up"
  print -- "ok default_shell_failure_warns"
}

platform_module_test::assert_oh_my_zsh_module_wsl() {
  platform_module_test::reset_state

  module_oh_my_zsh_install_items zsh-completions fast-syntax-highlighting >/dev/null

  platform_module_test::assert_exists "$HOME/.oh-my-zsh"
  platform_module_test::assert_exists "$HOME/.oh-my-zsh/custom/plugins/zsh-completions"
  platform_module_test::assert_exists "$HOME/.oh-my-zsh/custom/plugins/fast-syntax-highlighting"
  platform_module_test::assert_file_contains "$STATE_DIR/git.log" "clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git" "expected oh-my-zsh clone"
  platform_module_test::assert_file_contains "$STATE_DIR/chsh.log" "-s $INITIAL_BIN/zsh" "expected chsh invocation during oh-my-zsh install"
  print -- "ok oh_my_zsh_module_wsl"
}

platform_module_test::assert_theme_powerlevel10k_bootstrap() {
  platform_module_test::reset_state
  DOTFILES_THEME="powerlevel10k"

  module_theme_install >/dev/null

  platform_module_test::assert_exists "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  platform_module_test::assert_file_contains "$STATE_DIR/git.log" "clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git" "expected oh-my-zsh bootstrap for powerlevel10k"
  platform_module_test::assert_file_contains "$STATE_DIR/git.log" "clone --depth=1 https://github.com/romkatv/powerlevel10k.git" "expected powerlevel10k clone"
  platform_module_test::assert_file_contains "$STATE_DIR/chsh.log" "-s $INITIAL_BIN/zsh" "expected chsh during powerlevel10k bootstrap"
  print -- "ok theme_powerlevel10k_bootstrap"
}

platform_module_test::assert_theme_skip_states() {
  platform_module_test::reset_state
  DOTFILES_THEME="default"
  module_theme_install >/dev/null
  platform_module_test::assert_contains "$(print -l -- "${DOTFILES_RESULT_SKIPPED_ITEMS[@]}")" "Theme dependencies for 'default'" "expected default theme skip"

  platform_module_test::reset_state
  DOTFILES_THEME="none"
  module_theme_install >/dev/null
  platform_module_test::assert_contains "$(print -l -- "${DOTFILES_RESULT_SKIPPED_ITEMS[@]}")" "Theme dependencies for 'none'" "expected none theme skip"
  print -- "ok theme_skip_states"
}

platform_module_test::main() {
  platform_module_test::setup_fake_commands
  platform_module_test::assert_apt_package_install
  platform_module_test::assert_default_shell_success
  platform_module_test::assert_default_shell_failure_warns
  platform_module_test::assert_oh_my_zsh_module_wsl
  platform_module_test::assert_theme_powerlevel10k_bootstrap
  platform_module_test::assert_theme_skip_states
  print -- "all module platform branch tests passed"
}

platform_module_test::main "$@"
