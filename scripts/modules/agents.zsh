#!/bin/zsh

typeset -ga AGENTS_MANAGED_RULE_FILES=(
  BASE.md
  RTK.md
  CAVEMAN.md
)

module_agents_supported() {
  return 0
}

module_agents_summary() {
  echo "Install shared AI agent rules for selected tool adapters"
}

module_agents_details() {
  echo "Keeps shared rules in the dotfiles agents directory and updates selected tool-native instruction files."
  echo "Codex uses ~/.codex/AGENTS.md."
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
    dotfiles::record_reused "$(catalog::agent_label "$adapter_id") instruction block"
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

agents::link_preserving_existing() {
  local source_path="$1"
  local target_path="$2"

  dotfiles::ensure_dir "${target_path:h}"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    dotfiles::record_reused "Agent skill link already in place: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Already linked: $target_path"
    return 0
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    dotfiles::record_skipped "Agent skill already exists: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Preserving existing agent skill: $target_path"
    return 0
  fi

  ln -s "$source_path" "$target_path"
  dotfiles::record_file_linked "$target_path" "$source_path"
  dotfiles::log_success "Linked $target_path"
}

agents::install_codex_skills() {
  local source_path target_path skill_name
  local target_dir

  target_dir="$(agents::codex_skills_dir)"
  dotfiles::ensure_dir "$target_dir"

  for source_path in "$DOTFILES_ROOT"/agents/skills/*(/N); do
    skill_name="${source_path:t}"
    target_path="$target_dir/$skill_name"
    agents::link_preserving_existing "$source_path" "$target_path"
  done
}

agents::install_adapter() {
  local adapter_id="$1"

  case "$adapter_id" in
    codex)
      agents::upsert_managed_block codex "$(agents::codex_path)"
      agents::install_codex_skills
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

  for adapter_id in codex; do
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
