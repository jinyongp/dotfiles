#!/bin/zsh

typeset -ga AGENTS_MANAGED_RULE_FILES=(
  BASE.md
  RTK.md
  CAVEMAN.md
  PLANNING.md
)

module_agents_supported() {
  return 0
}

module_agents_summary() {
  echo "Install shared AI agent rules for selected tool adapters"
}

module_agents_details() {
  echo "Keeps shared rules in the dotfiles agents directory and updates selected tool-native instruction files."
  echo "Codex uses ~/.codex/AGENTS.md; Claude uses ~/.claude/CLAUDE.md."
  echo "Existing auth, sessions, history, caches, and unmanaged files are preserved."
}

agents::rule_path() {
  print -r -- "$DOTFILES_ROOT/agents/rules/$1"
}

agents::tmpfile_for() {
  local target_path="$1"
  local target_dir="${target_path:h}"

  dotfiles::ensure_dir "$target_dir"
  mktemp "$target_dir/${target_path:t}.tmp.XXXXXX"
}

agents::block_start() {
  print -r -- "<!-- dotfiles:agents:${1}:start -->"
}

agents::block_end() {
  print -r -- "<!-- dotfiles:agents:${1}:end -->"
}

agents::managed_block() {
  local adapter_id="$1"
  local file_name

  agents::block_start "$adapter_id"
  for file_name in "${AGENTS_MANAGED_RULE_FILES[@]}"; do
    print -r -- "@$(agents::rule_path "$file_name")"
  done
  agents::block_end "$adapter_id"
}

agents::upsert_managed_block() {
  local adapter_id="$1"
  local target_path="$2"
  local tmp_file

  dotfiles::ensure_dir "${target_path:h}"
  tmp_file="$(agents::tmpfile_for "$target_path")"

  if [[ -f "$target_path" ]]; then
    awk \
      -v start="$(agents::block_start "$adapter_id")" \
      -v end="$(agents::block_end "$adapter_id")" \
      '
        $0 == start { skipping = 1; next }
        $0 == end { skipping = 0; next }
        skipping != 1 { print }
      ' "$target_path" >"$tmp_file"

    if [[ -s "$tmp_file" ]]; then
      print -r -- "" >>"$tmp_file"
    fi
  fi

  agents::managed_block "$adapter_id" >>"$tmp_file"

  if [[ -f "$target_path" ]] && cmp -s "$tmp_file" "$target_path"; then
    rm -f "$tmp_file"
    dotfiles::record_reused_quiet "$(catalog::agent_label "$adapter_id") instruction block"
    dotfiles::log_info "$(catalog::agent_label "$adapter_id") instruction block is already current."
    return 0
  fi

  if [[ -f "$target_path" ]]; then
    mv "$tmp_file" "$target_path"
    dotfiles::record_file_updated "$target_path"
  else
    mv "$tmp_file" "$target_path"
    dotfiles::record_file_created "$target_path"
  fi

  dotfiles::log_success "Updated $target_path"
}

agents::codex_path() {
  print -r -- "$HOME/.codex/AGENTS.md"
}

agents::codex_skills_dir() {
  print -r -- "$HOME/.codex/skills"
}

agents::claude_path() {
  print -r -- "$HOME/.claude/CLAUDE.md"
}

agents::claude_skills_dir() {
  print -r -- "$HOME/.claude/skills"
}

agents::external_skills_dir() {
  print -r -- "$DOTFILES_CONFIG_DIR/agents/external-skills"
}

agents::external_skills_lock_path() {
  print -r -- "$DOTFILES_CONFIG_DIR/agents/external-skills.lock"
}

agents::link_preserving_existing() {
  local source_path="$1"
  local target_path="$2"

  dotfiles::ensure_dir "${target_path:h}"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    dotfiles::record_reused_quiet "Agent skill link already in place: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Already linked: $target_path"
    return 0
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    dotfiles::record_skipped_quiet "Agent skill already exists: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Preserving existing agent skill: $target_path"
    return 0
  fi

  ln -s "$source_path" "$target_path"
  dotfiles::record_file_linked "$target_path" "$source_path"
  dotfiles::log_success "Linked $target_path"
}

agents::install_skills() {
  local target_dir="$1"
  local source_path target_path skill_name

  dotfiles::ensure_dir "$target_dir"

  for source_path in "$DOTFILES_ROOT"/agents/skills/*(/N); do
    skill_name="${source_path:t}"
    target_path="$target_dir/$skill_name"
    agents::link_preserving_existing "$source_path" "$target_path"
  done
}

agents::record_external_skill_version() {
  local skill_id="$1"
  local repo_url="$2"
  local ref="$3"
  local skill_path="$4"
  local revision="$5"
  local lock_path tmp_file timestamp

  lock_path="$(agents::external_skills_lock_path)"
  dotfiles::ensure_dir "${lock_path:h}"
  tmp_file="$(agents::tmpfile_for "$lock_path")"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ -f "$lock_path" ]]; then
    awk -F '\t' -v skill_id="$skill_id" '$1 != skill_id { print }' "$lock_path" >"$tmp_file"
  fi

  print -r -- "${skill_id}	${revision}	${ref}	${repo_url}	${skill_path}	${timestamp}" >>"$tmp_file"

  if [[ -f "$lock_path" ]]; then
    mv "$tmp_file" "$lock_path"
    dotfiles::record_file_updated "$lock_path"
  else
    mv "$tmp_file" "$lock_path"
    dotfiles::record_file_created "$lock_path"
  fi
}

agents::sync_external_skill() {
  local skill_id="$1"
  local repo_url="$2"
  local ref="$3"
  local skill_path="$4"
  local target_dir clone_root repo_dir stage_dir source_dir revision

  typeset -g AGENTS_SYNCED_EXTERNAL_SKILL_PATH=""
  target_dir="$(agents::external_skills_dir)/$skill_id"

  if ! command -v git >/dev/null 2>&1; then
    if [[ -d "$target_dir" ]]; then
      dotfiles::record_reused_quiet "External agent skill cached copy: $skill_id"
      dotfiles::log_warn "Using cached external agent skill because git is unavailable: $skill_id"
      AGENTS_SYNCED_EXTERNAL_SKILL_PATH="$target_dir"
      return 0
    fi

    dotfiles::record_skipped "External agent skill $skill_id because git is unavailable"
    dotfiles::log_warn "Skipping external agent skill because git is unavailable: $skill_id"
    return 1
  fi

  dotfiles::ensure_dir "$(agents::external_skills_dir)"
  clone_root="$(mktemp -d "$(agents::external_skills_dir)/.${skill_id}.clone.XXXXXX")"
  repo_dir="$clone_root/repo"
  stage_dir="$(agents::external_skills_dir)/.${skill_id}.stage.$$"

  if ! git clone --quiet --depth 1 --branch "$ref" "$repo_url" "$repo_dir" >/dev/null 2>&1; then
    rm -rf "$clone_root" "$stage_dir"

    if [[ -d "$target_dir" ]]; then
      dotfiles::record_reused_quiet "External agent skill cached copy: $skill_id"
      dotfiles::log_warn "Using cached external agent skill because update failed: $skill_id"
      AGENTS_SYNCED_EXTERNAL_SKILL_PATH="$target_dir"
      return 0
    fi

    dotfiles::record_skipped "External agent skill $skill_id because download failed"
    dotfiles::log_warn "Skipping external agent skill because download failed: $skill_id"
    return 1
  fi

  revision="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
  source_dir="$repo_dir/$skill_path"
  if [[ -z "$revision" || ! -f "$source_dir/SKILL.md" ]]; then
    rm -rf "$clone_root" "$stage_dir"
    dotfiles::record_skipped "External agent skill $skill_id because source is invalid"
    dotfiles::log_warn "Skipping external agent skill because source is invalid: $skill_id"
    return 1
  fi

  rm -rf "$stage_dir"
  dotfiles::ensure_dir "$stage_dir"
  cp -R "$source_dir"/. "$stage_dir"/
  rm -rf "$target_dir"
  mv "$stage_dir" "$target_dir"
  rm -rf "$clone_root"

  agents::record_external_skill_version "$skill_id" "$repo_url" "$ref" "$skill_path" "$revision"
  dotfiles::record_completed_work "Updated external agent skill $skill_id to $revision"
  dotfiles::log_success "Updated external agent skill $skill_id to $revision"
  AGENTS_SYNCED_EXTERNAL_SKILL_PATH="$target_dir"
}

agents::install_external_skill() {
  local skill_id="$1"
  local repo_url="$2"
  local ref="$3"
  local skill_path="$4"
  local target_dir

  typeset -g AGENTS_SYNCED_EXTERNAL_SKILL_PATH=""
  target_dir="$(agents::external_skills_dir)/$skill_id"

  if [[ -f "$target_dir/SKILL.md" ]]; then
    dotfiles::record_reused_quiet "External agent skill cached copy: $skill_id"
    dotfiles::log_info "Using cached external agent skill: $skill_id"
    AGENTS_SYNCED_EXTERNAL_SKILL_PATH="$target_dir"
    return 0
  fi

  agents::sync_external_skill "$skill_id" "$repo_url" "$ref" "$skill_path"
}

agents::install_external_skills() {
  local target_skills_dir="$1"
  local skill_id repo_url ref skill_path source_path target_path

  while IFS=$'\t' read -r skill_id repo_url ref skill_path; do
    [[ -n "$skill_id" ]] || continue
    [[ "$skill_id" == \#* ]] && continue
    [[ -n "$repo_url" && -n "$ref" && -n "$skill_path" ]] || continue

    if agents::install_external_skill "$skill_id" "$repo_url" "$ref" "$skill_path"; then
      source_path="$AGENTS_SYNCED_EXTERNAL_SKILL_PATH"
    else
      source_path=""
    fi
    [[ -n "$source_path" ]] || continue

    target_path="$target_skills_dir/$skill_id"
    agents::link_preserving_existing "$source_path" "$target_path"
  done < <(catalog::external_skill_records)
}

agents::external_skill_selected() {
  local skill_id="$1"
  shift || true

  if (( $# == 0 )); then
    return 0
  fi

  local selected_id
  for selected_id in "$@"; do
    [[ "$selected_id" == "$skill_id" ]] && return 0
  done

  return 1
}

agents::sync_external_skills() {
  local selected_ids=("$@")
  local skill_id repo_url ref skill_path synced_any=0 failed=0

  while IFS=$'\t' read -r skill_id repo_url ref skill_path; do
    [[ -n "$skill_id" ]] || continue
    [[ "$skill_id" == \#* ]] && continue
    [[ -n "$repo_url" && -n "$ref" && -n "$skill_path" ]] || continue
    agents::external_skill_selected "$skill_id" "${selected_ids[@]}" || continue

    synced_any=1
    if ! agents::sync_external_skill "$skill_id" "$repo_url" "$ref" "$skill_path"; then
      failed=1
    fi
  done < <(catalog::external_skill_records)

  if (( synced_any == 0 )); then
    dotfiles::log_warn "No matching external agent skills."
    return 1
  fi

  return "$failed"
}

agents::external_skill_lock_revision() {
  local skill_id="$1"
  local lock_path

  lock_path="$(agents::external_skills_lock_path)"
  [[ -f "$lock_path" ]] || return 0
  awk -F '\t' -v skill_id="$skill_id" '$1 == skill_id { print $2; exit }' "$lock_path"
}

agents::list_external_skills() {
  local skill_id repo_url ref skill_path revision skill_status target_dir

  while IFS=$'\t' read -r skill_id repo_url ref skill_path; do
    [[ -n "$skill_id" ]] || continue
    [[ "$skill_id" == \#* ]] && continue
    [[ -n "$repo_url" && -n "$ref" && -n "$skill_path" ]] || continue

    target_dir="$(agents::external_skills_dir)/$skill_id"
    revision="$(agents::external_skill_lock_revision "$skill_id")"
    if [[ -f "$target_dir/SKILL.md" ]]; then
      skill_status="installed"
    else
      skill_status="missing"
    fi

    print -r -- "${skill_id}	${skill_status}	${ref}	${revision:-unknown}	${repo_url}	${skill_path}"
  done < <(catalog::external_skill_records)
}

agents::install_adapter() {
  local adapter_id="$1"

  case "$adapter_id" in
    codex)
      agents::upsert_managed_block codex "$(agents::codex_path)"
      agents::install_skills "$(agents::codex_skills_dir)"
      agents::install_external_skills "$(agents::codex_skills_dir)"
      ;;
    claude)
      agents::upsert_managed_block claude "$(agents::claude_path)"
      agents::install_skills "$(agents::claude_skills_dir)"
      agents::install_external_skills "$(agents::claude_skills_dir)"
      ;;
    *)
      dotfiles::record_skipped "Unknown agent adapter: $adapter_id"
      dotfiles::log_warn "Skipping unknown agent adapter: $adapter_id"
      ;;
  esac
}

agents::detected_adapter_ids() {
  local adapter_id
  local detected_ids=()

  for adapter_id in codex claude; do
    if agents::adapter_is_detected "$adapter_id"; then
      detected_ids+=("$adapter_id")
    fi
  done

  print -r -- "${(j: :)detected_ids}"
}

agents::adapter_is_detected() {
  case "$1" in
    codex)
      command -v codex >/dev/null 2>&1 || [[ -d "$HOME/.codex" ]]
      ;;
    claude)
      command -v claude >/dev/null 2>&1 || [[ -d "$HOME/.claude" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

module_agents_install_items() {
  local adapter_ids=("$@")
  local adapter_id
  local detected_ids

  dotfiles::log_step "Installing AI agent instructions"

  if (( ${#adapter_ids[@]} == 0 )); then
    detected_ids="$(agents::detected_adapter_ids)"
    if [[ -n "$detected_ids" ]]; then
      adapter_ids=("${=detected_ids}")
    fi
  fi

  if (( ${#adapter_ids[@]} == 0 )); then
    dotfiles::record_skipped "AI agent instructions because no supported agent CLI or home directory was detected"
    dotfiles::log_info "No supported agent targets detected."
    return 0
  fi

  for adapter_id in "${adapter_ids[@]}"; do
    agents::install_adapter "$adapter_id"
  done
}
