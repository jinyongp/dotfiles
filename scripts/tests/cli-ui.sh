#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cli-ui.XXXXXX")"
HOME_DIR="$WORK_DIR/home"
CONFIG_DIR="$WORK_DIR/config"

trap 'rm -rf "$WORK_DIR"' EXIT

mkdir -p "$HOME_DIR" "$CONFIG_DIR"

cli_ui_test::fail() {
  printf 'cli-ui: %s\n' "$1" >&2
  exit 1
}

cli_ui_test::assert_contains() {
  local file="$1"
  local expected="$2"

  grep -Fq -- "$expected" "$file" || {
    sed -n '1,120p' "$file" >&2
    cli_ui_test::fail "expected '$expected' in $file"
  }
}

cli_ui_test::assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq -- "$unexpected" "$file"; then
    sed -n '1,120p' "$file" >&2
    cli_ui_test::fail "did not expect '$unexpected' in $file"
  fi
}

cli_ui_test::run_cmd() {
  local name="$1"
  shift || true

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_PLATFORM="macos" \
    PATH="$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    "$@" >"$WORK_DIR/$name.out" 2>"$WORK_DIR/$name.err"
}

cli_ui_test::run_cmd_json() {
  local name="$1"
  shift || true

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_PLATFORM="macos" \
    DOTFILES_INSTALL_UI_MODE="json" \
    PATH="$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    "$@" >"$WORK_DIR/$name.out" 2>"$WORK_DIR/$name.err"
}

cli_ui_test::assert_json_file() {
  python3 -m json.tool "$1" >/dev/null
}

cli_ui_test::assert_agents_inventory() {
  local output_file="$WORK_DIR/agents_inventory.out"
  local error_file="$WORK_DIR/agents_inventory.err"
  local codex_skills="$HOME_DIR/.codex/skills"

  mkdir -p "$codex_skills"
  ln -s "$DOTFILES_ROOT/agents/skills/planning" "$codex_skills/planning"
  mkdir -p "$codex_skills/review-loop"
  ln -s "$WORK_DIR/not-the-taskwarrior-skill" "$codex_skills/taskwarrior"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_PLATFORM="macos" \
    DOTFILES_INSTALL_UI_MODE="json" \
    PATH="$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    dotfiles agents list >"$output_file" 2>"$error_file"

  cli_ui_test::assert_json_file "$output_file"
  [[ ! -s "$error_file" ]] || cli_ui_test::fail "agents inventory JSON should not emit stderr"

  python3 - "$output_file" "$DOTFILES_ROOT" "$HOME_DIR" <<'PY'
import json
import sys

path, root, home = sys.argv[1:]
records = json.load(open(path, encoding="utf-8"))
by_id = {record["id"]: record for record in records}

for skill_id in ("planning", "review-loop", "taskwarrior", "git-commit", "caveman"):
    assert skill_id in by_id, skill_id
    assert by_id[skill_id]["kind"] == "internal"
    assert by_id[skill_id]["source"] == "repository"
    assert by_id[skill_id]["sourcePath"].startswith(root + "/agents/skills/")

assert by_id["gate"]["kind"] == "external"
assert by_id["gate"]["source"] == "external"
assert "adapterTargets" in by_id["gate"]
assert by_id["impeccable"]["kind"] == "external"
assert by_id["impeccable"]["source"] == "external"
assert by_id["impeccable-claude"]["kind"] == "external"
assert by_id["impeccable-claude"]["source"] == "external"

def target_status(skill_id, adapter):
    targets = by_id[skill_id]["adapterTargets"]
    return next(item for item in targets if item["adapter"] == adapter)

planning = target_status("planning", "codex")
assert planning["status"] == "linked"
assert planning["linkType"] == "symlink"
assert planning["linkTarget"] == root + "/agents/skills/planning"

review_loop = target_status("review-loop", "codex")
assert review_loop["status"] == "materialized"
assert review_loop["linkType"] == "directory"

taskwarrior = target_status("taskwarrior", "codex")
assert taskwarrior["status"] == "conflict"
assert taskwarrior["linkType"] == "symlink"

git_commit = target_status("git-commit", "codex")
assert git_commit["status"] == "missing"
assert git_commit["adapterAvailable"] is True

claude = target_status("git-commit", "claude")
assert claude["status"] == "unavailable"
assert claude["adapterAvailable"] is False
PY

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_PLATFORM="macos" \
    PATH="$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
    zsh -f -c 'dfx() { dotfiles "$@"; }; dfx agents list' >"$WORK_DIR/dfx_agents_list.out" 2>"$WORK_DIR/dfx_agents_list.err"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_agents_list.out" "AGENT SKILLS"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_agents_list.out" "planning"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_agents_list.out" "codex:linked"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_agents_list.out" "claude:unavailable"

  printf 'ok agents_inventory\n'
}

cli_ui_test::assert_dotfiles() {
  cli_ui_test::run_cmd dotfiles_help dotfiles help
  cli_ui_test::assert_not_contains "$WORK_DIR/dotfiles_help.out" "Usage:"
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_help.out" "COMMANDS"
  cli_ui_test::assert_not_contains "$WORK_DIR/dotfiles_help.out" "complete"
  cli_ui_test::assert_not_contains "$WORK_DIR/dotfiles_help.out" "DOTFILES_INSTALL_UI_MODE"

  cli_ui_test::run_cmd dotfiles_path dotfiles path
  [[ "$(cat "$WORK_DIR/dotfiles_path.out")" == "$DOTFILES_ROOT" ]] || cli_ui_test::fail "dotfiles path output changed"

  cli_ui_test::run_cmd dotfiles_complete_commands dotfiles complete commands
  diff -u "$WORK_DIR/dotfiles_complete_commands.out" - <<'EOF'
install:run the interactive installer or direct install target
uninstall:remove dotfiles-managed links and agent instruction blocks
list:list direct install targets
themes:manage shell theme selection and dependencies
agents:manage external agent skills
update:fast-forward this dotfiles repository
path:print the dotfiles repository path
doctor:check the local dotfiles setup
help:show help
EOF

  cli_ui_test::run_cmd_json dotfiles_complete_json dotfiles complete commands
  diff -u "$WORK_DIR/dotfiles_complete_commands.out" "$WORK_DIR/dotfiles_complete_json.out"

  if cli_ui_test::run_cmd dotfiles_complete_no_context dotfiles complete; then
    cli_ui_test::fail "dotfiles complete without context unexpectedly succeeded"
  fi
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_complete_no_context.err" "completion context required"
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_complete_no_context.err" "usage"

  cli_ui_test::run_cmd dotfiles_complete_targets dotfiles complete targets
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_complete_targets.out" "dotfiles:Dotfiles"
  cli_ui_test::assert_not_contains "$WORK_DIR/dotfiles_complete_targets.out" "theme:"
  cli_ui_test::run_cmd dotfiles_complete_theme_commands dotfiles complete theme-commands
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_complete_theme_commands.out" "use:set the saved shell theme and install dependencies"
  cli_ui_test::run_cmd dotfiles_complete_theme_items dotfiles complete items themes
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_complete_theme_items.out" "starship:starship"
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_complete_theme_items.out" "none:none"
  cli_ui_test::assert_contains "$DOTFILES_ROOT/zsh/completions/_dotfiles" "_describe -V -t commands"

  cli_ui_test::run_cmd dotfiles_agents_help dotfiles agents
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_help.out" "COMMANDS"
  cli_ui_test::assert_not_contains "$WORK_DIR/dotfiles_agents_help.out" "DOTFILES_INSTALL_UI_MODE"
  [[ ! -s "$WORK_DIR/dotfiles_agents_help.err" ]] || cli_ui_test::fail "dotfiles agents emitted stderr"

  cli_ui_test::run_cmd dotfiles_themes_help dotfiles themes
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_themes_help.out" "COMMANDS"
  cli_ui_test::assert_not_contains "$WORK_DIR/dotfiles_themes_help.out" "DOTFILES_INSTALL_UI_MODE"
  [[ ! -s "$WORK_DIR/dotfiles_themes_help.err" ]] || cli_ui_test::fail "dotfiles themes emitted stderr"

  cli_ui_test::run_cmd dotfiles_themes_list dotfiles themes list
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_themes_list.out" "Shell themes"
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_themes_list.out" "starship"

  env -i \
    HOME="$HOME_DIR" \
    USER="${USER:-dotfiles}" \
    LOGNAME="${USER:-dotfiles}" \
    XDG_CONFIG_HOME="$CONFIG_DIR" \
    DOTFILES_ROOT="$DOTFILES_ROOT" \
    DOTFILES_PLATFORM="macos" \
    PATH="$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" \
    TERM="xterm-256color" \
  zsh -f -c 'source "$DOTFILES_ROOT/zsh/lib/bootstrap.zsh"; source "$DOTFILES_ROOT/zsh/alias.zsh"; type dfx; eval "dfx --help"; eval "dfx list"' >"$WORK_DIR/dfx_help_list.out" 2>"$WORK_DIR/dfx_help_list.err"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_help_list.out" "dfx is an alias"
  cli_ui_test::assert_not_contains "$WORK_DIR/dfx_help_list.out" "Usage:"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_help_list.out" "Install targets"
  cli_ui_test::assert_contains "$WORK_DIR/dfx_help_list.out" "usage: dfx install <target> [item...]"

  cli_ui_test::run_cmd_json dotfiles_agents_json dotfiles agents list
  cli_ui_test::assert_json_file "$WORK_DIR/dotfiles_agents_json.out"
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_json.out" '"id": "gate"'
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_json.out" '"id": "impeccable"'
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_json.out" '"id": "impeccable-claude"'
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_json.out" '"id": "planning"'
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_json.out" '"kind": "internal"'
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_agents_json.out" '"adapterTargets":'

  if cli_ui_test::run_cmd_json dotfiles_agents_json_flag dotfiles agents list --json; then
    cli_ui_test::fail "dotfiles agents list --json unexpectedly succeeded"
  fi
  cli_ui_test::assert_json_file "$WORK_DIR/dotfiles_agents_json_flag.err"

  fake_git_path="$WORK_DIR/fake-git"
  mkdir -p "$fake_git_path"
cat >"$fake_git_path/git" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-C" && "$3" == "rev-parse" && "$4" == "--is-inside-work-tree" ]]; then
  printf 'true\n'
  exit 0
fi
if [[ "$1" == "-C" && "$3" == "status" && "$4" == "--porcelain" ]]; then
  printf ' M changed-file\n'
  exit 0
fi
printf 'unexpected git invocation: %s\n' "$*" >&2
exit 2
EOF
  chmod +x "$fake_git_path/git"
  if env -i HOME="$HOME_DIR" USER="${USER:-dotfiles}" LOGNAME="${USER:-dotfiles}" XDG_CONFIG_HOME="$CONFIG_DIR" DOTFILES_PLATFORM=macos DOTFILES_INSTALL_UI_MODE=json PATH="$fake_git_path:$DOTFILES_ROOT/cmd:/usr/bin:/bin:/usr/sbin:/sbin" TERM=xterm-256color dotfiles update >"$WORK_DIR/dotfiles_update_dirty.out" 2>"$WORK_DIR/dotfiles_update_dirty.err"; then
    cli_ui_test::fail "dotfiles update dirty worktree unexpectedly succeeded"
  fi
  cli_ui_test::assert_json_file "$WORK_DIR/dotfiles_update_dirty.err"
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_update_dirty.err" '"status":" M changed-file"'

  printf 'ok dotfiles_cli\n'
}

cli_ui_test::assert_uninstall() {
  local codex_agents="$HOME_DIR/.codex/AGENTS.md"
  local claude_agents="$HOME_DIR/.claude/CLAUDE.md"
  local codex_skills="$HOME_DIR/.codex/skills"
  local claude_skills="$HOME_DIR/.claude/skills"
  local external_cache="$CONFIG_DIR/dotfiles/agents/external-skills/gate"
  local fake_brew_path=""

  mkdir -p "$HOME_DIR/.config" "$codex_skills" "$claude_skills" "$external_cache" "$HOME_DIR/.codex" "$HOME_DIR/.claude"
  ln -s "$DOTFILES_ROOT/zsh/.zshenv" "$HOME_DIR/.zshenv"
  ln -s "$DOTFILES_ROOT/zsh/.zprofile" "$HOME_DIR/.zprofile"
  ln -s "$DOTFILES_ROOT/zsh/.zshrc" "$HOME_DIR/.zshrc"
  ln -s "$DOTFILES_ROOT/vim/.vimrc" "$HOME_DIR/.vimrc"
  ln -s "$DOTFILES_ROOT/git/.gitconfig" "$HOME_DIR/.gitconfig"
  ln -s "$DOTFILES_ROOT/nvim" "$HOME_DIR/.config/nvim"
  ln -s "$DOTFILES_ROOT/agents/skills/planning" "$codex_skills/planning"
  ln -s "$external_cache" "$codex_skills/gate"
  ln -s "$DOTFILES_ROOT/agents/skills/git-commit" "$claude_skills/git-commit"
  ln -s "$WORK_DIR/not-managed" "$codex_skills/custom"
  printf '%s\n' \
    "keep codex before" \
    "<!-- dotfiles:agents:codex:start -->" \
    "@/tmp/remove-me" \
    "<!-- dotfiles:agents:codex:end -->" \
    "keep codex after" >"$codex_agents"
  printf '%s\n' \
    "keep claude before" \
    "<!-- dotfiles:agents:claude:start -->" \
    "@/tmp/remove-me" \
    "<!-- dotfiles:agents:claude:end -->" \
    "keep claude after" >"$claude_agents"

  if cli_ui_test::run_cmd dotfiles_uninstall_missing_yes dotfiles uninstall; then
    cli_ui_test::fail "dotfiles uninstall without -y unexpectedly succeeded"
  fi
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_uninstall_missing_yes.err" "uninstall requires explicit confirmation"

  cli_ui_test::run_cmd dotfiles_uninstall dotfiles uninstall -y
  cli_ui_test::assert_contains "$WORK_DIR/dotfiles_uninstall.out" "uninstall finished"
  [[ ! -e "$HOME_DIR/.zshenv" ]] || cli_ui_test::fail "managed .zshenv link was not removed"
  [[ ! -e "$HOME_DIR/.zprofile" ]] || cli_ui_test::fail "managed .zprofile link was not removed"
  [[ ! -e "$HOME_DIR/.zshrc" ]] || cli_ui_test::fail "managed .zshrc link was not removed"
  [[ ! -e "$HOME_DIR/.vimrc" ]] || cli_ui_test::fail "managed .vimrc link was not removed"
  [[ ! -e "$HOME_DIR/.gitconfig" ]] || cli_ui_test::fail "managed .gitconfig link was not removed"
  [[ ! -e "$HOME_DIR/.config/nvim" ]] || cli_ui_test::fail "managed nvim link was not removed"
  [[ ! -e "$codex_skills/planning" ]] || cli_ui_test::fail "managed codex skill link was not removed"
  [[ ! -e "$codex_skills/gate" ]] || cli_ui_test::fail "managed external skill link was not removed"
  [[ ! -e "$claude_skills/git-commit" ]] || cli_ui_test::fail "managed claude skill link was not removed"
  [[ -L "$codex_skills/custom" ]] || cli_ui_test::fail "unmanaged skill link should be preserved"
  cli_ui_test::assert_contains "$codex_agents" "keep codex before"
  cli_ui_test::assert_contains "$codex_agents" "keep codex after"
  cli_ui_test::assert_not_contains "$codex_agents" "dotfiles:agents:codex:start"
  cli_ui_test::assert_contains "$claude_agents" "keep claude before"
  cli_ui_test::assert_contains "$claude_agents" "keep claude after"
  cli_ui_test::assert_not_contains "$claude_agents" "dotfiles:agents:claude:start"

  rm -rf "$HOME_DIR/.codex" "$HOME_DIR/.claude" "$HOME_DIR/.config"

  printf 'ok uninstall\n'
}

cli_ui_test::assert_small_commands() {
  cli_ui_test::run_cmd text_help text --help
  cli_ui_test::assert_not_contains "$WORK_DIR/text_help.out" "Usage:"
  cli_ui_test::assert_contains "$WORK_DIR/text_help.out" "OPTIONS"

  if cli_ui_test::run_cmd_json text_invalid text --bad; then
    cli_ui_test::fail "text invalid option unexpectedly succeeded"
  fi
  cli_ui_test::assert_json_file "$WORK_DIR/text_invalid.err"

  cli_ui_test::run_cmd text_payload text "Hello" -f 42
  sed -n l "$WORK_DIR/text_payload.out" | grep -Fq '\033[38;5;42mHello\033[0m' \
    || cli_ui_test::fail "text payload changed"

  cli_ui_test::run_cmd colorls_help colorls --help
  cli_ui_test::assert_not_contains "$WORK_DIR/colorls_help.out" "Usage:"
  if cli_ui_test::run_cmd_json colorls_invalid colorls --bad; then
    cli_ui_test::fail "colorls invalid option unexpectedly succeeded"
  fi
  cli_ui_test::assert_json_file "$WORK_DIR/colorls_invalid.err"

  cli_ui_test::run_cmd cloc_help cloc-git --help
  cli_ui_test::assert_not_contains "$WORK_DIR/cloc_help.out" "Usage:"
  tmp_path="$WORK_DIR/path"
  mkdir -p "$tmp_path"
  ln -s "$(command -v git)" "$tmp_path/git"
  if env -i DOTFILES_INSTALL_UI_MODE=json HOME="$HOME_DIR" PATH="$tmp_path:/usr/bin:/bin" TERM=xterm-256color "$DOTFILES_ROOT/cmd/cloc-git" https://github.com/owner/repo >"$WORK_DIR/cloc_missing.out" 2>"$WORK_DIR/cloc_missing.err"; then
    cli_ui_test::fail "cloc-git without cloc unexpectedly succeeded"
  fi
  cli_ui_test::assert_json_file "$WORK_DIR/cloc_missing.err"

  clone_path="$WORK_DIR/clone-path"
  mkdir -p "$clone_path"
  cat >"$clone_path/git" <<'EOF'
#!/usr/bin/env bash
printf 'fatal: raw clone failure\n' >&2
exit 1
EOF
  cat >"$clone_path/cloc" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$clone_path/git" "$clone_path/cloc"
  if env -i DOTFILES_INSTALL_UI_MODE=json HOME="$HOME_DIR" PATH="$clone_path:/usr/bin:/bin" TERM=xterm-256color "$DOTFILES_ROOT/cmd/cloc-git" https://github.com/owner/repo >"$WORK_DIR/cloc_clone.out" 2>"$WORK_DIR/cloc_clone.err"; then
    cli_ui_test::fail "cloc-git clone failure unexpectedly succeeded"
  fi
  cli_ui_test::assert_json_file "$WORK_DIR/cloc_clone.err"
  cli_ui_test::assert_contains "$WORK_DIR/cloc_clone.err" '"type":"warning"'
  if grep -Fq "fatal: raw clone failure" "$WORK_DIR/cloc_clone.err"; then
    sed -n '1,120p' "$WORK_DIR/cloc_clone.err" >&2
    cli_ui_test::fail "cloc-git JSON stderr contains raw clone log"
  fi

  printf 'ok small_commands\n'
}

cli_ui_test::main() {
  cli_ui_test::assert_dotfiles
  cli_ui_test::assert_uninstall
  cli_ui_test::assert_agents_inventory
  cli_ui_test::assert_small_commands
  printf 'all cli ui tests passed\n'
}

cli_ui_test::main "$@"
