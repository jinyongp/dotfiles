#!/bin/zsh

typeset -ga AGENTS_MANAGED_RULE_FILES=(
  BASE.md
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
  local tmp_file normalized_file

  dotfiles::ensure_dir "${target_path:h}"
  tmp_file="$(agents::tmpfile_for "$target_path")"

  if [[ -f "$target_path" ]]; then
    if ! awk \
      -v start="$(agents::block_start "$adapter_id")" \
      -v end="$(agents::block_end "$adapter_id")" \
      '
        $0 == start { skipping = 1; next }
        $0 == end { skipping = 0; next }
        skipping != 1 { print }
      ' "$target_path" >"$tmp_file"; then
      rm -f "$tmp_file"
      return 1
    fi

    if [[ -s "$tmp_file" ]]; then
      if grep -q '[^[:space:]]' "$tmp_file"; then
        normalized_file="$(agents::tmpfile_for "$target_path")"
        if ! awk '
          { lines[++count] = $0 }
          END {
            while (count > 0 && lines[count] ~ /^[[:space:]]*$/) {
              count--
            }
            for (i = 1; i <= count; i++) {
              print lines[i]
            }
          }
        ' "$tmp_file" >"$normalized_file"; then
          rm -f "$tmp_file" "$normalized_file"
          return 1
        fi
        if ! mv "$normalized_file" "$tmp_file"; then
          rm -f "$tmp_file" "$normalized_file"
          return 1
        fi
        if ! print -r -- "" >>"$tmp_file"; then
          rm -f "$tmp_file"
          return 1
        fi
      elif ! : >"$tmp_file"; then
        rm -f "$tmp_file"
        return 1
      fi
    fi
  fi

  if ! agents::managed_block "$adapter_id" >>"$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  if [[ -f "$target_path" ]] && cmp -s "$tmp_file" "$target_path"; then
    rm -f "$tmp_file"
    dotfiles::record_reused_quiet "$(catalog::agent_label "$adapter_id") instruction block"
    dotfiles::log_info "$(catalog::agent_label "$adapter_id") instruction block is already current."
    return 0
  fi

  if [[ -f "$target_path" ]]; then
    if ! mv "$tmp_file" "$target_path"; then
      rm -f "$tmp_file"
      return 1
    fi
    dotfiles::record_file_updated "$target_path"
  else
    if ! mv "$tmp_file" "$target_path"; then
      rm -f "$tmp_file"
      return 1
    fi
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

agents::codex_rules_dir() {
  print -r -- "$HOME/.codex/rules"
}

agents::codex_rules_source_path() {
  print -r -- "$DOTFILES_ROOT/agents/codex/rules/dotfiles.rules"
}

agents::install_codex_rules() {
  local source_path target_path

  source_path="$(agents::codex_rules_source_path)"
  target_path="$(agents::codex_rules_dir)/dotfiles.rules"

  agents::link_preserving_existing "$source_path" "$target_path" "Codex rules"
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

agents::external_token_valid() {
  local token="$1"

  [[ "$token" != "." && "$token" != ".." ]] || return 1
  [[ "$token" =~ '^[A-Za-z0-9._-]+$' ]]
}

agents::external_relative_path_valid() {
  local path="$1"

  [[ -n "$path" && "$path" != /* && "$path" != "." && "$path" != ".." && "$path" != ../* && "$path" != */../* && "$path" != */.. ]]
}

agents::external_artifact_metadata_valid() {
  local artifact_id="$1"
  local source_id="$2"
  local source_path="$3"
  local install_name="$4"
  local adapters="$5"
  local kind="$6"
  local copy_policy="$7"
  local adapter

  agents::external_token_valid "$artifact_id" || return 1
  agents::external_token_valid "$source_id" || return 1
  agents::external_relative_path_valid "$source_path" || return 1
  agents::external_token_valid "$install_name" || return 1
  [[ "$kind" == "skill" ]] || return 1
  [[ "$copy_policy" == "preserve" || "$copy_policy" == "materialize_repo_symlinks" ]] || return 1
  [[ -n "$adapters" && "$adapters" != *, && "$adapters" != ,* && "$adapters" != *,,* ]] || return 1
  for adapter in ${(s:,:)adapters}; do
    [[ -n "$adapter" ]] || return 1
    [[ "$adapter" == "codex" || "$adapter" == "claude" ]] || return 1
  done

  return 0
}

agents::link_preserving_existing() {
  local source_path="$1"
  local target_path="$2"
  local item_label="${3:-Agent skill}"

  dotfiles::ensure_dir "${target_path:h}"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    dotfiles::record_reused_quiet "$item_label link already in place: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Already linked: $target_path"
    return 0
  fi

  if [[ -e "$target_path" || -L "$target_path" ]]; then
    dotfiles::record_skipped_quiet "$item_label already exists: $(dotfiles::display_path "$target_path")"
    dotfiles::log_info "Preserving existing $item_label: $target_path"
    return 0
  fi

  if ! ln -s "$source_path" "$target_path"; then
    return 1
  fi
  dotfiles::record_file_linked "$target_path" "$source_path"
  dotfiles::log_success "Linked $target_path"
}

agents::install_skills() {
  local target_dir="$1"
  local source_path target_path skill_name
  local failed=0

  dotfiles::ensure_dir "$target_dir"

  for source_path in "$DOTFILES_ROOT"/agents/skills/*(/N); do
    skill_name="${source_path:t}"
    target_path="$target_dir/$skill_name"
    if ! agents::link_preserving_existing "$source_path" "$target_path"; then
      failed=1
    fi
  done

  return "$failed"
}

agents::external_artifact_cache_dir() {
  print -r -- "$(agents::external_skills_dir)/$1"
}

agents::external_artifact_adapter_enabled() {
  local adapters="$1"
  local adapter_id="$2"
  local adapter

  for adapter in ${(s:,:)adapters}; do
    [[ "$adapter" == "$adapter_id" ]] && return 0
  done

  return 1
}

agents::external_artifact_selected() {
  local artifact_id="$1"
  shift || true

  if (( $# == 0 )); then
    return 0
  fi

  local selected_id
  for selected_id in "$@"; do
    [[ "$selected_id" == "$artifact_id" ]] && return 0
  done

  return 1
}

agents::external_skill_lock_matches() {
  local artifact_id="$1"
  local source_id="$2"
  local ref="$3"
  local repo_url="$4"
  local source_path="$5"
  local install_name="$6"
  local adapters="$7"
  local kind="$8"
  local copy_policy="$9"
  local lock_path

  lock_path="$(agents::external_skills_lock_path)"
  [[ -f "$lock_path" ]] || return 1

  awk -F '\t' \
    -v artifact_id="$artifact_id" \
    -v source_id="$source_id" \
    -v ref="$ref" \
    -v repo_url="$repo_url" \
    -v source_path="$source_path" \
    -v install_name="$install_name" \
    -v adapters="$adapters" \
    -v kind="$kind" \
    -v copy_policy="$copy_policy" \
    '
      $1 == artifact_id {
        found = 1
        if ($3 == source_id && $4 == ref && $5 == repo_url && $6 == source_path && $7 == install_name && $8 == adapters && $9 == kind && $10 == copy_policy) {
          ok = 1
        }
        if (NF == 6 && artifact_id == "gate" && source_id == "gate" && repo_url == "https://github.com/jinyongp/gate.git" && source_path == "skills/gate" && install_name == "gate" && adapters == "codex,claude" && kind == "skill" && copy_policy == "preserve" && $3 == ref && $4 == repo_url && $5 == source_path) {
          ok = 1
        }
      }
      END { exit(ok ? 0 : 1) }
    ' "$lock_path"
}

agents::external_skill_lock_revision() {
  local artifact_id="$1"
  local lock_path

  lock_path="$(agents::external_skills_lock_path)"
  [[ -f "$lock_path" ]] || return 0
  awk -F '\t' -v artifact_id="$artifact_id" '$1 == artifact_id { print $2; exit }' "$lock_path"
}

agents::external_skill_cache_has_broken_symlink() {
  local target_dir="$1"
  local link_path

  while IFS= read -r link_path; do
    [[ -e "$link_path" ]] || return 0
  done < <(find "$target_dir" -type l -print 2>/dev/null)

  return 1
}

agents::external_skill_cache_has_symlink() {
  local target_dir="$1"
  local link_path

  while IFS= read -r link_path; do
    return 0
  done < <(find "$target_dir" -type l -print 2>/dev/null)

  return 1
}

agents::external_skill_cache_valid() {
  local artifact_id="$1"
  local source_id="$2"
  local ref="$3"
  local repo_url="$4"
  local source_path="$5"
  local install_name="$6"
  local adapters="$7"
  local kind="$8"
  local copy_policy="$9"
  local target_dir

  agents::external_artifact_metadata_valid "$artifact_id" "$source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || return 1
  target_dir="$(agents::external_artifact_cache_dir "$artifact_id")"
  [[ -f "$target_dir/SKILL.md" ]] || return 1
  agents::external_skill_lock_matches "$artifact_id" "$source_id" "$ref" "$repo_url" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || return 1
  if agents::external_skill_cache_has_symlink "$target_dir"; then
    return 1
  fi
  agents::external_skill_cache_has_broken_symlink "$target_dir" && return 1
  return 0
}

agents::record_external_skill_version() {
  local artifact_id="$1"
  local revision="$2"
  local source_id="$3"
  local ref="$4"
  local repo_url="$5"
  local source_path="$6"
  local install_name="$7"
  local adapters="$8"
  local kind="$9"
  local copy_policy="${10}"
  local lock_path tmp_file timestamp

  lock_path="$(agents::external_skills_lock_path)"
  dotfiles::ensure_dir "${lock_path:h}"
  tmp_file="$(agents::tmpfile_for "$lock_path")"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ -f "$lock_path" ]]; then
    if ! awk -F '\t' -v artifact_id="$artifact_id" '$1 != artifact_id { print }' "$lock_path" >"$tmp_file"; then
      rm -f "$tmp_file"
      return 1
    fi
  fi

  if ! print -r -- "${artifact_id}	${revision}	${source_id}	${ref}	${repo_url}	${source_path}	${install_name}	${adapters}	${kind}	${copy_policy}	${timestamp}" >>"$tmp_file"; then
    rm -f "$tmp_file"
    return 1
  fi

  if [[ -f "$lock_path" ]]; then
    if ! mv "$tmp_file" "$lock_path"; then
      rm -f "$tmp_file"
      return 1
    fi
    dotfiles::record_file_updated "$lock_path"
  else
    if ! mv "$tmp_file" "$lock_path"; then
      rm -f "$tmp_file"
      return 1
    fi
    dotfiles::record_file_created "$lock_path"
  fi
}

agents::external_source_has_selected_artifacts() {
  local source_id="$1"
  shift || true
  local artifact_id row_source_id source_path install_name adapters kind copy_policy

  while IFS=$'\t' read -r artifact_id row_source_id source_path install_name adapters kind copy_policy; do
    [[ "$row_source_id" == "$source_id" ]] || continue
    [[ "$kind" == "skill" ]] || continue
    agents::external_artifact_metadata_valid "$artifact_id" "$row_source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
    agents::external_artifact_selected "$artifact_id" "$@" || continue
    return 0
  done < <(catalog::external_skill_artifact_records)

  return 1
}

agents::external_artifact_contains_symlink() {
  local source_dir="$1"
  local symlink_path

  while IFS= read -r symlink_path; do
    return 0
  done < <(find "$source_dir" -type l -print 2>/dev/null)

  return 1
}

agents::external_path_inside() {
  local root_path="$1"
  local child_path="$2"

  [[ "$child_path" == "$root_path" || "$child_path" == "$root_path"/* ]]
}

agents::validate_external_artifact_symlinks() {
  local repo_dir="$1"
  local source_dir="$2"
  local copy_policy="$3"
  local artifact_id="$4"
  local repo_abs source_abs symlink_path resolved_path walk_file walk_path

  repo_abs="$(realpath "$repo_dir")" || return 1
  source_abs="$(realpath "$source_dir" 2>/dev/null || true)"
  if [[ -z "$source_abs" ]] || ! agents::external_path_inside "$repo_abs" "$source_abs"; then
    dotfiles::log_warn "External agent skill source path leaves repository: $artifact_id"
    return 1
  fi

  if ! agents::external_artifact_contains_symlink "$source_dir"; then
    return 0
  fi

  if [[ "$copy_policy" != "materialize_repo_symlinks" ]]; then
    dotfiles::log_warn "External agent skill has symlinks but copy policy does not materialize them: $artifact_id"
    return 1
  fi

  walk_file="$(mktemp "${TMPDIR:-/tmp}/agents-symlink-walk.XXXXXX")"
  if ! find -L "$source_dir" -mindepth 1 -print >"$walk_file" 2>/dev/null; then
    rm -f "$walk_file"
    dotfiles::log_warn "External agent skill symlink graph cannot be walked safely: $artifact_id"
    return 1
  fi

  while IFS= read -r walk_path; do
    resolved_path="$(realpath "$walk_path" 2>/dev/null || true)"
    if [[ -z "$resolved_path" ]] || ! agents::external_path_inside "$repo_abs" "$resolved_path"; then
      rm -f "$walk_file"
      dotfiles::log_warn "External agent skill symlink graph leaves repository: $artifact_id"
      return 1
    fi
  done <"$walk_file"
  rm -f "$walk_file"

  while IFS= read -r symlink_path; do
    resolved_path="$(realpath "$symlink_path" 2>/dev/null || true)"
    if [[ -z "$resolved_path" ]] || ! agents::external_path_inside "$repo_abs" "$resolved_path"; then
      dotfiles::log_warn "External agent skill symlink leaves repository: $artifact_id"
      return 1
    fi
  done < <(find "$source_dir" -type l -print 2>/dev/null)

  return 0
}

agents::copy_external_artifact() {
  local repo_dir="$1"
  local revision="$2"
  local source_id="$3"
  local repo_url="$4"
  local ref="$5"
  local artifact_id="$6"
  local source_path="$7"
  local install_name="$8"
  local adapters="$9"
  local kind="${10}"
  local copy_policy="${11}"
  local source_dir target_dir stage_dir backup_dir

  if ! agents::external_artifact_metadata_valid "$artifact_id" "$source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
    dotfiles::record_skipped "External agent skill $artifact_id because metadata is invalid"
    dotfiles::log_warn "Skipping external agent skill because metadata is invalid: $artifact_id"
    return 1
  fi

  source_dir="$repo_dir/$source_path"
  target_dir="$(agents::external_artifact_cache_dir "$artifact_id")"
  stage_dir="$(agents::external_skills_dir)/.${artifact_id}.stage.$$"
  backup_dir="$(agents::external_skills_dir)/.${artifact_id}.previous.$$"

  if [[ -z "$revision" || "$kind" != "skill" || ! -f "$source_dir/SKILL.md" ]]; then
    dotfiles::record_skipped "External agent skill $artifact_id because source is invalid"
    dotfiles::log_warn "Skipping external agent skill because source is invalid: $artifact_id"
    return 1
  fi

  if ! agents::validate_external_artifact_symlinks "$repo_dir" "$source_dir" "$copy_policy" "$artifact_id"; then
    dotfiles::record_skipped "External agent skill $artifact_id because symlinks are invalid"
    dotfiles::log_warn "Skipping external agent skill because symlinks are invalid: $artifact_id"
    return 1
  fi

  rm -rf "$stage_dir"
  dotfiles::ensure_dir "$stage_dir"
  case "$copy_policy" in
    preserve)
      if ! cp -R "$source_dir"/. "$stage_dir"/; then
        rm -rf "$stage_dir"
        dotfiles::record_skipped "External agent skill $artifact_id because copy failed"
        dotfiles::log_warn "Skipping external agent skill because copy failed: $artifact_id"
        return 1
      fi
      ;;
    materialize_repo_symlinks)
      if ! cp -RL "$source_dir"/. "$stage_dir"/; then
        rm -rf "$stage_dir"
        dotfiles::record_skipped "External agent skill $artifact_id because copy failed"
        dotfiles::log_warn "Skipping external agent skill because copy failed: $artifact_id"
        return 1
      fi
      ;;
    *)
      rm -rf "$stage_dir"
      dotfiles::record_skipped "External agent skill $artifact_id because copy policy is unknown"
      dotfiles::log_warn "Skipping external agent skill because copy policy is unknown: $artifact_id"
      return 1
      ;;
  esac

  if agents::external_skill_cache_has_broken_symlink "$stage_dir"; then
    rm -rf "$stage_dir"
    dotfiles::record_skipped "External agent skill $artifact_id because copied cache has broken symlinks"
    dotfiles::log_warn "Skipping external agent skill because copied cache has broken symlinks: $artifact_id"
    return 1
  fi

  rm -rf "$backup_dir"
  if [[ -e "$target_dir" || -L "$target_dir" ]]; then
    if ! mv "$target_dir" "$backup_dir"; then
      rm -rf "$stage_dir" "$backup_dir"
      dotfiles::record_skipped "External agent skill $artifact_id because existing cache backup failed"
      dotfiles::log_warn "Skipping external agent skill because existing cache backup failed: $artifact_id"
      return 1
    fi
  fi
  if ! mv "$stage_dir" "$target_dir"; then
    rm -rf "$stage_dir"
    if [[ -e "$backup_dir" || -L "$backup_dir" ]]; then
      mv "$backup_dir" "$target_dir" >/dev/null 2>&1 || true
    fi
    dotfiles::record_skipped "External agent skill $artifact_id because cache promotion failed"
    dotfiles::log_warn "Skipping external agent skill because cache promotion failed: $artifact_id"
    return 1
  fi
  if ! agents::record_external_skill_version "$artifact_id" "$revision" "$source_id" "$ref" "$repo_url" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
    rm -rf "$target_dir"
    if [[ -e "$backup_dir" || -L "$backup_dir" ]]; then
      mv "$backup_dir" "$target_dir" >/dev/null 2>&1 || true
    fi
    dotfiles::record_skipped "External agent skill $artifact_id because lock update failed"
    dotfiles::log_warn "External agent skill cache rollback after lock update failed: $artifact_id"
    return 1
  fi
  rm -rf "$backup_dir"
  dotfiles::record_completed_work "Updated external agent skill $artifact_id to $revision"
  dotfiles::log_success "Updated external agent skill $artifact_id to $revision"
}

agents::clone_external_source() {
  local source_id="$1"
  local repo_url="$2"
  local ref="$3"
  local clone_root="$4"
  local repo_dir="$clone_root/repo"

  dotfiles::ensure_dir "$(agents::external_skills_dir)"

  if ! git clone --quiet --depth 1 --branch "$ref" "$repo_url" "$repo_dir" >/dev/null 2>&1; then
    dotfiles::record_skipped "External agent skill source $source_id because download failed"
    dotfiles::log_warn "Skipping external agent skill source because download failed: $source_id"
    return 1
  fi

  return 0
}

agents::sync_external_source_artifacts() {
  local source_id="$1"
  local repo_url="$2"
  local ref="$3"
  shift 3 || true
  local selected_ids=("$@")
  local artifact_id row_source_id source_path install_name adapters kind copy_policy
  local clone_root repo_dir revision failed=0 synced_any=0

  agents::external_source_has_selected_artifacts "$source_id" "${selected_ids[@]}" || return 2

  dotfiles::ensure_dir "$(agents::external_skills_dir)"
  clone_root="$(mktemp -d "$(agents::external_skills_dir)/.${source_id}.clone.XXXXXX")"
  repo_dir="$clone_root/repo"
  if ! agents::clone_external_source "$source_id" "$repo_url" "$ref" "$clone_root"; then
    rm -rf "$clone_root"
    return 1
  fi

  revision="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
  while IFS=$'\t' read -r artifact_id row_source_id source_path install_name adapters kind copy_policy; do
    [[ "$row_source_id" == "$source_id" ]] || continue
    [[ "$kind" == "skill" ]] || continue
    agents::external_artifact_metadata_valid "$artifact_id" "$row_source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
    agents::external_artifact_selected "$artifact_id" "${selected_ids[@]}" || continue
    synced_any=1
    if ! agents::copy_external_artifact "$repo_dir" "$revision" "$source_id" "$repo_url" "$ref" "$artifact_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
      failed=1
    fi
  done < <(catalog::external_skill_artifact_records)

  rm -rf "$clone_root"

  (( synced_any == 1 )) || return 2
  return "$failed"
}

agents::install_external_source_artifacts() {
  local adapter_id="$1"
  local target_skills_dir="$2"
  local source_id="$3"
  local repo_url="$4"
  local ref="$5"
  local artifact_id row_source_id source_path install_name adapters kind copy_policy
  local target_dir source_path_cached target_path clone_root repo_dir revision needs_sync=0 failed=0
  local -a artifact_rows=()
  local -a sync_rows=()
  local row

  while IFS=$'\t' read -r artifact_id row_source_id source_path install_name adapters kind copy_policy; do
    [[ "$row_source_id" == "$source_id" ]] || continue
    [[ "$kind" == "skill" ]] || continue
    agents::external_artifact_metadata_valid "$artifact_id" "$row_source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
    agents::external_artifact_adapter_enabled "$adapters" "$adapter_id" || continue
    row="${artifact_id}	${source_path}	${install_name}	${adapters}	${kind}	${copy_policy}"
    artifact_rows+=("$row")

    if agents::external_skill_cache_valid "$artifact_id" "$source_id" "$ref" "$repo_url" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
      dotfiles::record_reused_quiet "External agent skill cached copy: $artifact_id"
      dotfiles::log_info "Using cached external agent skill: $artifact_id"
    else
      sync_rows+=("$row")
      needs_sync=1
    fi
  done < <(catalog::external_skill_artifact_records)

  (( ${#artifact_rows[@]} > 0 )) || return 0

  if (( needs_sync == 1 )); then
    if ! command -v git >/dev/null 2>&1; then
      for row in "${sync_rows[@]}"; do
        IFS=$'\t' read -r artifact_id source_path install_name adapters kind copy_policy <<<"$row"
        dotfiles::record_skipped "External agent skill $artifact_id because git is unavailable"
        dotfiles::log_warn "Skipping external agent skill because git is unavailable: $artifact_id"
      done
      failed=1
    else
      dotfiles::ensure_dir "$(agents::external_skills_dir)"
      clone_root="$(mktemp -d "$(agents::external_skills_dir)/.${source_id}.clone.XXXXXX")"
      repo_dir="$clone_root/repo"
      if agents::clone_external_source "$source_id" "$repo_url" "$ref" "$clone_root"; then
        revision="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
        for row in "${sync_rows[@]}"; do
          IFS=$'\t' read -r artifact_id source_path install_name adapters kind copy_policy <<<"$row"
          if ! agents::copy_external_artifact "$repo_dir" "$revision" "$source_id" "$repo_url" "$ref" "$artifact_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
            failed=1
          fi
        done
      else
        failed=1
      fi
      rm -rf "$clone_root"
    fi
  fi

  for row in "${artifact_rows[@]}"; do
    IFS=$'\t' read -r artifact_id source_path install_name adapters kind copy_policy <<<"$row"
    if ! agents::external_skill_cache_valid "$artifact_id" "$source_id" "$ref" "$repo_url" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
      failed=1
      continue
    fi
    source_path_cached="$(agents::external_artifact_cache_dir "$artifact_id")"
    target_path="$target_skills_dir/$install_name"
    if ! agents::link_preserving_existing "$source_path_cached" "$target_path"; then
      failed=1
    fi
  done

  return "$failed"
}

agents::install_external_skills() {
  local target_skills_dir="$1"
  local adapter_id="$2"
  local source_id repo_url ref failed=0

  while IFS=$'\t' read -r source_id repo_url ref; do
    [[ -n "$source_id" ]] || continue
    [[ "$source_id" == \#* ]] && continue
    [[ -n "$repo_url" && -n "$ref" ]] || continue

    if ! agents::install_external_source_artifacts "$adapter_id" "$target_skills_dir" "$source_id" "$repo_url" "$ref"; then
      failed=1
    fi
  done < <(catalog::external_skill_source_records)

  return "$failed"
}

agents::internal_skill_path() {
  local skill_id="$1"
  local skill_path="$DOTFILES_ROOT/agents/skills/$skill_id"

  [[ -f "$skill_path/SKILL.md" ]] || return 1
  print -r -- "$skill_path"
}

agents::external_skill_known() {
  local selected_id="$1"
  local artifact_id source_id source_path install_name adapters kind copy_policy

  while IFS=$'\t' read -r artifact_id source_id source_path install_name adapters kind copy_policy; do
    [[ "$artifact_id" == "$selected_id" ]] || continue
    agents::external_artifact_metadata_valid "$artifact_id" "$source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
    return 0
  done < <(catalog::external_skill_artifact_records)

  return 1
}

agents::selected_skill_ids_valid() {
  local selected_id invalid=0

  for selected_id in "$@"; do
    if agents::internal_skill_path "$selected_id" >/dev/null 2>&1 || agents::external_skill_known "$selected_id"; then
      continue
    fi
    dotfiles::log_warn "Unknown agent skill: $selected_id"
    invalid=1
  done

  return "$invalid"
}

agents::reconcile_skill_link() {
  local adapter_id="$1"
  local source_path="$2"
  local install_name="$3"
  local target_dir target_path

  target_dir="$(agents::adapter_skills_dir "$adapter_id")" || return 1
  target_path="$target_dir/$install_name"
  agents::set_adapter_target_state "$adapter_id" "$source_path" "$install_name"

  case "$AGENTS_ADAPTER_TARGET_STATUS" in
    linked)
      dotfiles::record_reused_quiet "Agent skill link already in place: $(dotfiles::display_path "$target_path")"
      return 0
      ;;
    conflict|materialized)
      (( AGENTS_SYNC_CONFLICTS += 1 ))
      dotfiles::log_warn "Preserving existing agent skill target: $target_path"
      return 1
      ;;
  esac

  dotfiles::ensure_dir "$target_dir"
  if ! ln -s "$source_path" "$target_path"; then
    return 1
  fi
  dotfiles::record_file_linked "$target_path" "$source_path"
  dotfiles::log_success "Linked agent skill $install_name for $adapter_id"
}

agents::sync_internal_skill_links() {
  local selected_ids=("$@")
  local detected_ids source_path skill_id adapter_id failed=0

  detected_ids="$(agents::detected_adapter_ids)"
  [[ -n "$detected_ids" ]] || return 0

  for source_path in "$DOTFILES_ROOT"/agents/skills/*(/N); do
    skill_id="${source_path:t}"
    agents::external_artifact_selected "$skill_id" "${selected_ids[@]}" || continue
    for adapter_id in ${=detected_ids}; do
      if ! agents::reconcile_skill_link "$adapter_id" "$source_path" "$skill_id"; then
        failed=1
      fi
    done
  done

  return "$failed"
}

agents::sync_external_skill_links() {
  local selected_ids=("$@")
  local detected_ids artifact_id source_id source_path install_name adapters kind copy_policy
  local row_source_id repo_url ref adapter_id cache_path failed=0

  detected_ids="$(agents::detected_adapter_ids)"
  [[ -n "$detected_ids" ]] || return 0

  while IFS=$'\t' read -r artifact_id source_id source_path install_name adapters kind copy_policy; do
    [[ "$kind" == "skill" ]] || continue
    agents::external_artifact_metadata_valid "$artifact_id" "$source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
    agents::external_artifact_selected "$artifact_id" "${selected_ids[@]}" || continue
    repo_url=""
    ref=""
    while IFS=$'\t' read -r row_source_id repo_url ref; do
      [[ "$row_source_id" == "$source_id" ]] || continue
      break
    done < <(catalog::external_skill_source_records)
    if [[ -z "$repo_url" || -z "$ref" ]] || ! agents::external_skill_cache_valid "$artifact_id" "$source_id" "$ref" "$repo_url" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
      failed=1
      continue
    fi
    cache_path="$(agents::external_artifact_cache_dir "$artifact_id")"
    for adapter_id in ${=detected_ids}; do
      agents::external_artifact_adapter_enabled "$adapters" "$adapter_id" || continue
      if ! agents::reconcile_skill_link "$adapter_id" "$cache_path" "$install_name"; then
        failed=1
      fi
    done
  done < <(catalog::external_skill_artifact_records)

  return "$failed"
}

agents::print_sync_summary() {
  local linked="$1"
  local updated="$2"
  local reused="$3"
  local conflicts="$4"

  ui::is_json && return 0
  printf '\n%s\n' "$(ui::section "Agent skills synced")"
  printf '  %s\n' "$(ui::align_pair "$(ui::muted "linked")" "$linked" 12)"
  printf '  %s\n' "$(ui::align_pair "$(ui::muted "updated")" "$updated" 12)"
  printf '  %s\n' "$(ui::align_pair "$(ui::muted "reused")" "$reused" 12)"
  printf '  %s\n' "$(ui::align_pair "$(ui::muted "conflicts")" "$conflicts" 12)"
  printf '  %s\n' "$(ui::align_pair "$(ui::muted "next")" "Start a new agent task to reload updated skills." 12)"
}

agents::sync_external_skills() {
  local selected_ids=("$@")
  local source_id repo_url ref synced_any=0 failed=0 sync_status

  if ! agents::external_selected_ids_valid "${selected_ids[@]}"; then
    return 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    dotfiles::log_warn "Cannot sync external agent skills because git is unavailable."
    return 1
  fi

  while IFS=$'\t' read -r source_id repo_url ref; do
    [[ -n "$source_id" ]] || continue
    [[ "$source_id" == \#* ]] && continue
    [[ -n "$repo_url" && -n "$ref" ]] || continue

    sync_status=0
    agents::sync_external_source_artifacts "$source_id" "$repo_url" "$ref" "${selected_ids[@]}" || sync_status=$?
    case "$sync_status" in
      0)
        synced_any=1
        ;;
      1)
        synced_any=1
        failed=1
        ;;
      2)
        ;;
      *)
        synced_any=1
        failed=1
        ;;
    esac
  done < <(catalog::external_skill_source_records)

  if (( synced_any == 0 )); then
    if (( ${#selected_ids[@]} == 0 )); then
      dotfiles::log_warn "No external agent skills configured."
    else
      dotfiles::log_warn "No matching external agent skills."
    fi
    return 1
  fi

  return "$failed"
}

agents::external_selected_ids_valid() {
  local selected_ids=("$@")
  local selected_id artifact_id source_id source_path install_name adapters kind copy_policy found invalid=0

  for selected_id in "${selected_ids[@]}"; do
    found=0
    while IFS=$'\t' read -r artifact_id source_id source_path install_name adapters kind copy_policy; do
      [[ "$artifact_id" == "$selected_id" ]] || continue
      agents::external_artifact_metadata_valid "$artifact_id" "$source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
      found=1
      break
    done < <(catalog::external_skill_artifact_records)
    if (( found == 0 )); then
      dotfiles::log_warn "Unknown external agent skill: $selected_id"
      invalid=1
    fi
  done

  return "$invalid"
}

agents::sync_skills() {
  local selected_ids=("$@")
  local -a external_ids=()
  local selected_id failed=0 external_requested=0
  local linked_before reused_before updated_before linked updated reused

  agents::selected_skill_ids_valid "${selected_ids[@]}" || return 1

  if (( ${#selected_ids[@]} == 0 )); then
    external_requested=1
  else
    for selected_id in "${selected_ids[@]}"; do
      if agents::external_skill_known "$selected_id"; then
        external_ids+=("$selected_id")
        external_requested=1
      fi
    done
  fi

  linked_before=${#DOTFILES_RESULT_LINKED_FILES[@]}
  reused_before=${#DOTFILES_RESULT_REUSED_ITEMS[@]}
  updated_before=${#DOTFILES_RESULT_COMPLETED_WORK[@]}
  typeset -g AGENTS_SYNC_CONFLICTS=0

  if (( external_requested == 1 )); then
    if (( ${#selected_ids[@]} == 0 )); then
      agents::sync_external_skills || failed=1
    else
      agents::sync_external_skills "${external_ids[@]}" || failed=1
    fi
  fi

  agents::sync_internal_skill_links "${selected_ids[@]}" || failed=1
  if (( external_requested == 1 )); then
    if (( ${#selected_ids[@]} == 0 )); then
      agents::sync_external_skill_links || failed=1
    else
      agents::sync_external_skill_links "${external_ids[@]}" || failed=1
    fi
  fi

  linked=$((${#DOTFILES_RESULT_LINKED_FILES[@]} - linked_before))
  reused=$((${#DOTFILES_RESULT_REUSED_ITEMS[@]} - reused_before))
  updated=$((${#DOTFILES_RESULT_COMPLETED_WORK[@]} - updated_before))
  agents::print_sync_summary "$linked" "$updated" "$reused" "$AGENTS_SYNC_CONFLICTS"

  return "$failed"
}

agents::print_json_string() {
  local value="$1"

  if typeset -f ui::json_escape >/dev/null 2>&1; then
    print -rn -- "\"$(ui::json_escape "$value")\""
    return 0
  fi

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  print -rn -- "\"$value\""
}

agents::print_json_string_array() {
  local values="$1"
  local item first=1

  print -rn -- "["
  for item in ${(s:,:)values}; do
    if (( first == 0 )); then
      print -rn -- ","
    fi
    agents::print_json_string "$item"
    first=0
  done
  print -rn -- "]"
}

agents::adapter_skills_dir() {
  case "$1" in
    codex) agents::codex_skills_dir ;;
    claude) agents::claude_skills_dir ;;
    *) return 1 ;;
  esac
}

agents::set_adapter_target_state() {
  local adapter_id="$1"
  local source_path="$2"
  local install_name="$3"
  local target_dir target_path target_status link_type link_target adapter_available

  target_dir="$(agents::adapter_skills_dir "$adapter_id")" || return 1
  target_path="$target_dir/$install_name"
  link_target=""
  adapter_available=0
  [[ -d "$target_dir" ]] && adapter_available=1

  if [[ -L "$target_path" ]]; then
    link_target="$(readlink "$target_path" 2>/dev/null || true)"
    link_type="symlink"
    if [[ "$link_target" == "$source_path" ]]; then
      target_status="linked"
    else
      target_status="conflict"
    fi
  elif [[ -e "$target_path" ]]; then
    if [[ -d "$target_path" ]]; then
      link_type="directory"
    elif [[ -f "$target_path" ]]; then
      link_type="file"
    else
      link_type="other"
    fi
    target_status="materialized"
  else
    link_type="none"
    if [[ "$adapter_available" -eq 1 ]]; then
      target_status="missing"
    else
      target_status="unavailable"
    fi
  fi

  AGENTS_ADAPTER_TARGET_ADAPTER="$adapter_id"
  AGENTS_ADAPTER_TARGET_PATH="$target_path"
  AGENTS_ADAPTER_TARGET_STATUS="$target_status"
  AGENTS_ADAPTER_TARGET_LINK_TYPE="$link_type"
  AGENTS_ADAPTER_TARGET_LINK_TARGET="$link_target"
  AGENTS_ADAPTER_TARGET_AVAILABLE="$adapter_available"
}

agents::print_json_adapter_targets() {
  local adapters="$1"
  local source_path="$2"
  local install_name="$3"
  local adapter_id first=1

  print -rn -- "["
  for adapter_id in ${(s:,:)adapters}; do
    [[ -n "$adapter_id" ]] || continue
    agents::set_adapter_target_state "$adapter_id" "$source_path" "$install_name"
    if (( first == 0 )); then
      print -rn -- ","
    fi
    print -rn -- "{"
    print -rn -- '"adapter":'
    agents::print_json_string "$AGENTS_ADAPTER_TARGET_ADAPTER"
    print -rn -- ',"targetPath":'
    agents::print_json_string "$AGENTS_ADAPTER_TARGET_PATH"
    print -rn -- ',"status":'
    agents::print_json_string "$AGENTS_ADAPTER_TARGET_STATUS"
    print -rn -- ',"linkType":'
    agents::print_json_string "$AGENTS_ADAPTER_TARGET_LINK_TYPE"
    print -rn -- ',"linkTarget":'
    agents::print_json_string "$AGENTS_ADAPTER_TARGET_LINK_TARGET"
    print -rn -- ',"adapterAvailable":'
    if [[ "$AGENTS_ADAPTER_TARGET_AVAILABLE" -eq 1 ]]; then
      print -rn -- "true"
    else
      print -rn -- "false"
    fi
    print -rn -- "}"
    first=0
  done
  print -rn -- "]"
}

agents::human_status() {
  local label="$1"
  local state="$2"

  case "$state" in
    linked|materialized|installed) ui::apply "$label" green ;;
    missing|not_installed) ui::apply "$label" magenta ;;
    conflict) ui::apply "$label" red ;;
    unavailable) ui::muted "$label" ;;
    *) ui::body "$label" ;;
  esac
}

agents::adapter_icon() {
  local adapter_id="$1"

  if ui::is_plain; then
    print -rn -- "$adapter_id"
    return 0
  fi

  case "$adapter_id" in
    codex) print -rn -- $'\xee\xb2\x81' ;;
    claude) print -rn -- $'\xee\xb2\x82' ;;
    *) print -rn -- "$adapter_id" ;;
  esac
}

agents::human_linked_adapters() {
  local adapters="$1"
  local source_path="$2"
  local install_name="$3"
  local adapter_id separator="" linked_any=0 icon

  for adapter_id in ${(s:,:)adapters}; do
    [[ -n "$adapter_id" ]] || continue
    agents::set_adapter_target_state "$adapter_id" "$source_path" "$install_name"
    [[ "$AGENTS_ADAPTER_TARGET_STATUS" == "linked" ]] || continue
    icon="$(agents::adapter_icon "$adapter_id")"
    print -n -- "$separator"
    print -n -- "$icon"
    separator=" "
    linked_any=1
  done

  if (( linked_any == 0 )); then
    ui::muted "nowhere"
  fi
}

agents::print_skill_json_record() {
  local id="$1"
  local inventory_kind="$2"
  local record_status="$3"
  local source="$4"
  local source_id="$5"
  local ref="$6"
  local revision="$7"
  local install_name="$8"
  local adapters="$9"
  local copy_policy="${10}"
  local repo_url="${11}"
  local source_path="${12}"
  local cache_path="${13:-}"

  print -r -- "  {"
  print -n -- '    "id": '
  agents::print_json_string "$id"
  print -r -- ","
  print -n -- '    "kind": '
  agents::print_json_string "$inventory_kind"
  print -r -- ","
  print -n -- '    "status": '
  agents::print_json_string "$record_status"
  print -r -- ","
  print -n -- '    "source": '
  agents::print_json_string "$source"
  print -r -- ","
  print -n -- '    "sourceId": '
  agents::print_json_string "$source_id"
  print -r -- ","
  print -n -- '    "ref": '
  agents::print_json_string "$ref"
  print -r -- ","
  print -n -- '    "revision": '
  agents::print_json_string "$revision"
  print -r -- ","
  print -n -- '    "installName": '
  agents::print_json_string "$install_name"
  print -r -- ","
  print -n -- '    "adapters": '
  agents::print_json_string_array "$adapters"
  print -r -- ","
  print -n -- '    "adapterTargets": '
  agents::print_json_adapter_targets "$adapters" "${cache_path:-$source_path}" "$install_name"
  print -r -- ","
  print -n -- '    "copyPolicy": '
  agents::print_json_string "$copy_policy"
  print -r -- ","
  print -n -- '    "repoUrl": '
  agents::print_json_string "$repo_url"
  print -r -- ","
  print -n -- '    "sourcePath": '
  agents::print_json_string "$source_path"
  if [[ -n "$cache_path" ]]; then
    print -r -- ","
    print -n -- '    "cachePath": '
    agents::print_json_string "$cache_path"
  fi
  print -r -- ""
  print -n -- "  }"
}

agents::skill_human_record() {
  local id="$1"
  local inventory_kind="$2"
  local record_status="$3"
  local source="$4"
  local source_id="$5"
  local ref="$6"
  local revision="$7"
  local install_name="$8"
  local adapters="${9}"
  local source_path="${10}"
  local target_source_path="${11}"
  local linked_adapters source_detail revision_detail display_path status_label

  linked_adapters="$(agents::human_linked_adapters "$adapters" "$target_source_path" "$install_name")"
  source_detail="$source_id"
  [[ -n "$source_detail" ]] || source_detail="$source"
  revision_detail="$revision"
  [[ -n "$revision_detail" ]] || revision_detail="unknown"
  display_path="$source_path"

  if [[ "$inventory_kind" == "internal" ]]; then
    display_path="${source_path#$DOTFILES_ROOT/}"
  fi

  print -r -- "$(ui::list_item "$(ui::code "$id")")"
  if [[ "$inventory_kind" == "external" ]]; then
    status_label="$(agents::human_status "$record_status" "${record_status// /_}")"
    print -r -- "    $(ui::align_pair "$(ui::muted "status")" "$status_label" 9)"
  fi
  print -r -- "    $(ui::align_pair "$(ui::muted "linked")" "$linked_adapters" 9)"
  if [[ "$inventory_kind" == "external" ]]; then
    if [[ "$revision_detail" != "unknown" ]]; then
      revision_detail="${revision_detail[1,12]}"
    fi
    source_detail="${source_detail}@${revision_detail}"
    [[ -n "$ref" ]] && source_detail="${source_detail} (${ref})"
    print -r -- "    $(ui::align_pair "$(ui::muted "source")" "$source_detail" 9)"
  fi
  print -r -- "    $(ui::align_pair "$(ui::muted "path")" "$display_path" 9)"
}

agents::print_skill_human_section() {
  local title="$1"
  shift || true
  local record

  (( $# > 0 )) || return 0
  printf '\n%s\n' "$(ui::section "$title")"
  for record in "$@"; do
    print -r -- "$record"
  done
}

agents::list_external_skills() {
  local artifact_id source_id source_path install_name adapters kind copy_policy revision skill_status target_dir
  local row_source_id row_repo_url row_ref repo_url ref
  local skill_id skill_path
  local listed=0 first_json=1 output_json=0
  local input_field="" usage_field=""
  local -a internal_records=() external_records=()
  local human_record

  if (( $# > 0 )); then
    if typeset -f ui::validation_error >/dev/null 2>&1; then
      input_field=$'input\t'"$*"
      usage_field=$'usage\tdotfiles agents list'
      ui::validation_error "dotfiles agents list does not accept options" \
        "$input_field" \
        "$usage_field"
    else
      dotfiles::log_warn "dotfiles agents list does not accept options."
    fi
    return 2
  fi

  if typeset -f ui::is_json >/dev/null 2>&1 && ui::is_json; then
    output_json=1
  fi

  if [[ "$output_json" -eq 1 ]]; then
    print -r -- "["
  fi

  for skill_path in "$DOTFILES_ROOT"/agents/skills/*(/N); do
    skill_id="${skill_path:t}"
    [[ -f "$skill_path/SKILL.md" ]] || continue
    listed=1
    if [[ "$output_json" -eq 1 ]]; then
      if (( first_json == 0 )); then
        print -r -- ","
      fi
      agents::print_skill_json_record "$skill_id" "internal" "available" "repository" "dotfiles" "" "" "$skill_id" "codex,claude" "preserve" "" "$skill_path" ""
      first_json=0
    else
      human_record="$(agents::skill_human_record "$skill_id" "internal" "available" "repository" "dotfiles" "" "" "$skill_id" "codex,claude" "$skill_path" "$skill_path")"
      internal_records+=("$human_record")
    fi
  done

  while IFS=$'\t' read -r artifact_id source_id source_path install_name adapters kind copy_policy; do
    [[ -n "$artifact_id" ]] || continue
    [[ "$artifact_id" == \#* ]] && continue
    [[ "$kind" == "skill" ]] || continue
    agents::external_artifact_metadata_valid "$artifact_id" "$source_id" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy" || continue
    repo_url=""
    ref=""
    while IFS=$'\t' read -r row_source_id row_repo_url row_ref; do
      [[ "$row_source_id" == "$source_id" ]] || continue
      repo_url="$row_repo_url"
      ref="$row_ref"
      break
    done < <(catalog::external_skill_source_records)
    [[ -n "$repo_url" && -n "$ref" ]] || continue

    target_dir="$(agents::external_artifact_cache_dir "$artifact_id")"
    revision="$(agents::external_skill_lock_revision "$artifact_id")"
    if agents::external_skill_cache_valid "$artifact_id" "$source_id" "$ref" "$repo_url" "$source_path" "$install_name" "$adapters" "$kind" "$copy_policy"; then
      skill_status="installed"
    else
      skill_status="not_installed"
    fi

    listed=1
    if [[ "$output_json" -eq 1 ]]; then
      if (( first_json == 0 )); then
        print -r -- ","
      fi
      agents::print_skill_json_record "$artifact_id" "external" "$skill_status" "external" "$source_id" "$ref" "${revision:-unknown}" "$install_name" "$adapters" "$copy_policy" "$repo_url" "$source_path" "$target_dir"
      first_json=0
      continue
    fi

    human_record="$(agents::skill_human_record "$artifact_id" "external" "${skill_status//_/ }" "external" "$source_id" "$ref" "${revision:-unknown}" "$install_name" "$adapters" "$source_path" "$target_dir")"
    external_records+=("$human_record")
  done < <(catalog::external_skill_artifact_records)

  if [[ "$output_json" -eq 1 ]]; then
    if (( first_json == 0 )); then
      print -r -- ""
    fi
    print -r -- "]"
  fi

  if (( output_json == 0 && (${#internal_records[@]} > 0 || ${#external_records[@]} > 0) )); then
    printf '\n%s\n' "$(ui::section "Agent skills")"
    agents::print_skill_human_section "Internal" "${internal_records[@]}"
    agents::print_skill_human_section "External" "${external_records[@]}"
  fi

  if (( listed == 0 )); then
    dotfiles::log_warn "No agent skills configured."
    return 1
  fi
}

agents::install_adapter() {
  local adapter_id="$1"
  local failed=0

  case "$adapter_id" in
    codex)
      agents::upsert_managed_block codex "$(agents::codex_path)" || failed=1
      agents::install_codex_rules || failed=1
      agents::install_skills "$(agents::codex_skills_dir)" || failed=1
      agents::install_external_skills "$(agents::codex_skills_dir)" codex || failed=1
      ;;
    claude)
      agents::upsert_managed_block claude "$(agents::claude_path)" || failed=1
      agents::install_skills "$(agents::claude_skills_dir)" || failed=1
      agents::install_external_skills "$(agents::claude_skills_dir)" claude || failed=1
      ;;
    *)
      dotfiles::record_skipped "Unknown agent adapter: $adapter_id"
      dotfiles::log_warn "Skipping unknown agent adapter: $adapter_id"
      failed=1
      ;;
  esac

  return "$failed"
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
  local failed=0

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
    if ! agents::install_adapter "$adapter_id"; then
      failed=1
    fi
  done

  return "$failed"
}
