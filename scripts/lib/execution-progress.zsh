#!/usr/bin/env zsh

if ! typeset -f ui::status >/dev/null 2>&1; then
  if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ui/message.sh" ]]; then
    source "$DOTFILES_ROOT/scripts/lib/ui/message.sh"
  fi
fi

typeset -g DOTFILES_EXECUTION_TTY_FD="${DOTFILES_EXECUTION_TTY_FD:-}"
typeset -g DOTFILES_EXECUTION_TTY_ERR_FD="${DOTFILES_EXECUTION_TTY_ERR_FD:-}"
typeset -g DOTFILES_EXECUTION_STEP_ID=""
typeset -g DOTFILES_EXECUTION_STEP_LABEL=""
typeset -g DOTFILES_EXECUTION_STEP_LOG_FILE=""
typeset -gi DOTFILES_EXECUTION_STEP_ACTIVE=0
typeset -gi DOTFILES_EXECUTION_STEP_INDEX=0
typeset -gi DOTFILES_EXECUTION_STEP_INSTALLED_COUNT=0
typeset -gi DOTFILES_EXECUTION_STEP_REUSED_COUNT=0
typeset -gi DOTFILES_EXECUTION_STEP_SKIPPED_COUNT=0
typeset -gi DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT=0
typeset -gi DOTFILES_EXECUTION_STEP_EXTRA_COUNT=0
typeset -gi DOTFILES_EXECUTION_STEP_WARNING_COUNT=0

dotfiles::execution_ui_mode() {
  ui::mode
}

dotfiles::execution_is_plain_mode() {
  ui::is_plain
}

dotfiles::execution_is_json_mode() {
  ui::is_json
}

dotfiles::execution_init_output() {
  if [[ -z "$DOTFILES_EXECUTION_TTY_FD" ]]; then
    exec {DOTFILES_EXECUTION_TTY_FD}>&1
  fi

  if [[ -z "$DOTFILES_EXECUTION_TTY_ERR_FD" ]]; then
    exec {DOTFILES_EXECUTION_TTY_ERR_FD}>&2
  fi
}

dotfiles::execution_write() {
  local stream="${1:-stdout}"
  local text="${2:-}"
  local fd=""

  dotfiles::execution_init_output

  if [[ "$stream" == "stderr" ]]; then
    fd="$DOTFILES_EXECUTION_TTY_ERR_FD"
  else
    fd="$DOTFILES_EXECUTION_TTY_FD"
  fi

  print -u "$fd" -r -- "$text"
}

dotfiles::execution_run_foreground() {
  if [[ "$DOTFILES_EXECUTION_STEP_ACTIVE" -eq 1 ]] \
    && ! dotfiles::execution_is_json_mode \
    && [[ -n "$DOTFILES_EXECUTION_TTY_FD" && -n "$DOTFILES_EXECUTION_TTY_ERR_FD" ]]; then
    "$@" >&$DOTFILES_EXECUTION_TTY_FD 2>&$DOTFILES_EXECUTION_TTY_ERR_FD
    return $?
  fi

  "$@"
}

dotfiles::execution_header_marker() {
  ui::symbol question
}

dotfiles::execution_path_text() {
  local path_text="$1"

  if dotfiles::execution_is_plain_mode; then
    print -r -- "$path_text"
    return 0
  fi

  dotfiles::style_path "$path_text"
}

dotfiles::execution_status_label() {
  ui::status_label "$1"
}

dotfiles::execution_status_line() {
  ui::status "$1" "$2"
}

dotfiles::execution_json_counts_data() {
  printf '"installed":%d,"reused":%d,"skipped":%d,"fileChanges":%d,"extraActions":%d,"warnings":%d' \
    "$DOTFILES_EXECUTION_STEP_INSTALLED_COUNT" \
    "$DOTFILES_EXECUTION_STEP_REUSED_COUNT" \
    "$DOTFILES_EXECUTION_STEP_SKIPPED_COUNT" \
    "$DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT" \
    "$DOTFILES_EXECUTION_STEP_EXTRA_COUNT" \
    "$DOTFILES_EXECUTION_STEP_WARNING_COUNT"
}

dotfiles::execution_json_event() {
  local type="$1"
  local stream="${2:-stdout}"
  local data="$3"
  local event=""

  event="$(ui::json_event "$type" install "$data")"
  dotfiles::execution_write "$stream" "$event"
}

dotfiles::execution_reset_step_counts() {
  DOTFILES_EXECUTION_STEP_INSTALLED_COUNT=0
  DOTFILES_EXECUTION_STEP_REUSED_COUNT=0
  DOTFILES_EXECUTION_STEP_SKIPPED_COUNT=0
  DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT=0
  DOTFILES_EXECUTION_STEP_EXTRA_COUNT=0
  DOTFILES_EXECUTION_STEP_WARNING_COUNT=0
}

dotfiles::execution_step_log_dir() {
  local log_dir="${DOTFILES_EXECUTION_LOG_DIR:-${TMPDIR:-/tmp}}"

  dotfiles::ensure_dir "$log_dir"
  print -r -- "$log_dir"
}

dotfiles::execution_step_log_file() {
  local step_id="$1"
  local safe_id="${step_id//[^A-Za-z0-9._-]/-}"

  mktemp "$(dotfiles::execution_step_log_dir)/dotfiles-install-${safe_id}.XXXXXX"
}

dotfiles::execution_start_step() {
  local step_id="$1"
  local step_label="$2"

  dotfiles::execution_init_output

  DOTFILES_EXECUTION_STEP_ID="$step_id"
  DOTFILES_EXECUTION_STEP_LABEL="$step_label"
  DOTFILES_EXECUTION_STEP_LOG_FILE="$(dotfiles::execution_step_log_file "$step_id")"
  DOTFILES_EXECUTION_STEP_ACTIVE=1
  DOTFILES_EXECUTION_STEP_INDEX=$((DOTFILES_EXECUTION_STEP_INDEX + 1))
  dotfiles::execution_reset_step_counts

  if dotfiles::execution_is_json_mode; then
    dotfiles::execution_json_event progress_start stdout "{\"stepId\":\"$(ui::json_escape "$step_id")\",\"label\":\"$(ui::json_escape "$step_label")\"}"
    return 0
  fi

  dotfiles::execution_write stdout "$(dotfiles_accent "$(dotfiles::execution_header_marker)")  $(dotfiles_heading "$step_label")"
}

dotfiles::execution_summary_text() {
  local -a parts=()

  if [[ "$DOTFILES_EXECUTION_STEP_INSTALLED_COUNT" -gt 0 ]]; then
    parts+=("$DOTFILES_EXECUTION_STEP_INSTALLED_COUNT installed")
  fi

  if [[ "$DOTFILES_EXECUTION_STEP_REUSED_COUNT" -gt 0 ]]; then
    parts+=("$DOTFILES_EXECUTION_STEP_REUSED_COUNT reused")
  fi

  if [[ "$DOTFILES_EXECUTION_STEP_SKIPPED_COUNT" -gt 0 ]]; then
    parts+=("$DOTFILES_EXECUTION_STEP_SKIPPED_COUNT skipped")
  fi

  if [[ "$DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT" -gt 0 ]]; then
    parts+=("$DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT file changes")
  fi

  if [[ "$DOTFILES_EXECUTION_STEP_EXTRA_COUNT" -gt 0 ]]; then
    parts+=("$DOTFILES_EXECUTION_STEP_EXTRA_COUNT extra actions")
  fi

  if [[ "$DOTFILES_EXECUTION_STEP_WARNING_COUNT" -gt 0 ]]; then
    parts+=("$DOTFILES_EXECUTION_STEP_WARNING_COUNT warnings")
  fi

  if (( ${#parts[@]} == 0 )); then
    print -r -- "no item changes"
    return 0
  fi

  print -r -- "${(j:, :)parts}"
}

dotfiles::execution_finish_step() {
  local exit_status="$1"
  local log_file="$DOTFILES_EXECUTION_STEP_LOG_FILE"
  local log_path_display=""
  local summary_text=""

  if [[ "$exit_status" -eq 0 ]]; then
    summary_text="$(dotfiles::execution_summary_text)"
    if dotfiles::execution_is_json_mode; then
      dotfiles::execution_json_event progress_finish stdout "{\"stepId\":\"$(ui::json_escape "$DOTFILES_EXECUTION_STEP_ID")\",\"status\":\"completed\",\"summary\":\"$(ui::json_escape "$summary_text")\",\"counts\":{$(dotfiles::execution_json_counts_data)}}"
    else
      dotfiles::execution_write stdout "$(dotfiles::execution_status_line "completed" "$summary_text")"
    fi
    rm -f "$log_file"
  else
    log_path_display="$(dotfiles::display_path "$log_file")"
    if dotfiles::execution_is_json_mode; then
      dotfiles::execution_json_event progress_finish stderr "{\"stepId\":\"$(ui::json_escape "$DOTFILES_EXECUTION_STEP_ID")\",\"status\":\"failed\",\"exitStatus\":$exit_status,\"rawLog\":\"$(ui::json_escape "$log_path_display")\",\"counts\":{$(dotfiles::execution_json_counts_data)}}"
    else
      dotfiles::execution_write stderr "$(dotfiles::execution_status_line "failed" "exited with status $exit_status")"
      dotfiles::execution_write stderr "$(dotfiles::execution_status_line "failed" "raw log: $(dotfiles::execution_path_text "$log_path_display")")"
    fi
  fi

  DOTFILES_EXECUTION_STEP_ID=""
  DOTFILES_EXECUTION_STEP_LABEL=""
  DOTFILES_EXECUTION_STEP_LOG_FILE=""
  DOTFILES_EXECUTION_STEP_ACTIVE=0

  return "$exit_status"
}

dotfiles::execution_record_event() {
  local kind="$1"
  local message="$2"
  local state="$kind"
  local stream="stdout"

  if [[ "$DOTFILES_EXECUTION_STEP_ACTIVE" -ne 1 ]]; then
    return 0
  fi

  dotfiles::execution_record_event_quiet "$kind" "$message"

  case "$kind" in
    file_change)
      state="completed"
      ;;
    completed_work)
      state="completed"
      ;;
    error)
      state="failed"
      stream="stderr"
      ;;
    *)
      ;;
  esac

  if dotfiles::execution_is_json_mode; then
    dotfiles::execution_json_event progress_event "$stream" "{\"stepId\":\"$(ui::json_escape "$DOTFILES_EXECUTION_STEP_ID")\",\"kind\":\"$(ui::json_escape "$kind")\",\"state\":\"$(ui::json_escape "$state")\",\"message\":\"$(ui::json_escape "$message")\"}"
    return 0
  fi

  dotfiles::execution_write "$stream" "$(dotfiles::execution_status_line "$state" "$message")"
}

dotfiles::execution_record_event_quiet() {
  local kind="$1"

  if [[ "$DOTFILES_EXECUTION_STEP_ACTIVE" -ne 1 ]]; then
    return 0
  fi

  case "$kind" in
    installed)
      DOTFILES_EXECUTION_STEP_INSTALLED_COUNT=$((DOTFILES_EXECUTION_STEP_INSTALLED_COUNT + 1))
      ;;
    reused)
      DOTFILES_EXECUTION_STEP_REUSED_COUNT=$((DOTFILES_EXECUTION_STEP_REUSED_COUNT + 1))
      ;;
    skipped)
      DOTFILES_EXECUTION_STEP_SKIPPED_COUNT=$((DOTFILES_EXECUTION_STEP_SKIPPED_COUNT + 1))
      ;;
    file_change)
      DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT=$((DOTFILES_EXECUTION_STEP_FILE_CHANGE_COUNT + 1))
      ;;
    completed_work)
      DOTFILES_EXECUTION_STEP_EXTRA_COUNT=$((DOTFILES_EXECUTION_STEP_EXTRA_COUNT + 1))
      ;;
    warning)
      DOTFILES_EXECUTION_STEP_WARNING_COUNT=$((DOTFILES_EXECUTION_STEP_WARNING_COUNT + 1))
      ;;
    *)
      ;;
  esac
}

dotfiles::execution_run_step() {
  local step_id="$1"
  local step_label="$2"
  shift 2 || true

  local exit_status=0
  local log_file=""
  local had_errexit=0

  [[ -o errexit ]] && had_errexit=1

  dotfiles::execution_start_step "$step_id" "$step_label"
  log_file="$DOTFILES_EXECUTION_STEP_LOG_FILE"

  set +e
  {
    "$@"
  } >>"$log_file" 2>&1
  exit_status=$?

  dotfiles::execution_finish_step "$exit_status"
  if [[ "$had_errexit" -eq 1 ]]; then
    set -e
  fi
  return "$exit_status"
}
