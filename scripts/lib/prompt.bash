#!/usr/bin/env bash

PROMPT__LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/style.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/style.sh"
fi

if ! declare -F ui::input_required >/dev/null 2>&1 && [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ui/errors.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"
fi

# shellcheck disable=SC1090
source "$PROMPT__LIB_DIR/prompt/style.bash"
# shellcheck disable=SC1090
source "$PROMPT__LIB_DIR/prompt/layout.bash"

PROMPT__SESSION_OPEN=0
PROMPT__RAW_MODE=0
PROMPT__CURSOR_HIDDEN=0
PROMPT__RENDERED_LINES=0
PROMPT__RENDERED_BLOCK_LINES=()
PROMPT__STTY_STATE=""
PROMPT__CANCELLED=0
PROMPT__UI_MODE="auto"

if declare -F ui::mode >/dev/null 2>&1; then
  PROMPT__UI_MODE="$(ui::mode)"
elif [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ui/environment.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/ui/environment.sh"
  PROMPT__UI_MODE="$(ui::env_mode)"
elif [[ -f "$PROMPT__LIB_DIR/ui/environment.sh" ]]; then
  # shellcheck disable=SC1090
  source "$PROMPT__LIB_DIR/ui/environment.sh"
  PROMPT__UI_MODE="$(ui::env_mode)"
else
  PROMPT__UI_MODE="auto"
fi

prompt::ui_mode() {
  printf '%s' "$PROMPT__UI_MODE"
}

prompt::is_plain_mode() {
  if declare -F ui::is_plain >/dev/null 2>&1; then
    ui::is_plain
  elif declare -F ui::env_plain_symbols_enabled >/dev/null 2>&1; then
    ui::env_plain_symbols_enabled
  else
    [[ "$PROMPT__UI_MODE" == "plain" ]]
  fi
}

prompt::uses_inline_status() {
  return 0
}

prompt::is_json_mode() {
  if declare -F ui::is_json >/dev/null 2>&1; then
    ui::is_json
  elif declare -F ui::env_mode >/dev/null 2>&1; then
    [[ "$(ui::env_mode)" == "json" ]]
  else
    [[ "$PROMPT__UI_MODE" == "json" ]]
  fi
}

prompt::require_human_input() {
  local component="$1"
  local question="${2:-}"

  if ! prompt::is_json_mode; then
    return 0
  fi

  if declare -F ui::input_required >/dev/null 2>&1; then
    ui::input_required "JSON mode requires ${component} input in the request document." \
      "component	$component" \
      "question	$question" >&2
  else
    printf 'input required: %s: %s\n' "$component" "$question" >&2
  fi
  return 1
}

prompt::display_hint_token() {
  local token="$1"

  case "$PROMPT__UI_MODE:$token" in
    plain:↑/↓)
      printf 'Up/Down'
      ;;
    *)
      printf '%s' "$token"
      ;;
  esac
}

prompt::strip_ansi() {
  local text="$1"
  local prefix suffix

  if declare -F ui::strip_ansi >/dev/null 2>&1; then
    ui::strip_ansi "$text"
    return 0
  fi

  while [[ "$text" == *$'\033['*m* ]]; do
    prefix="${text%%$'\033['*}"
    suffix="${text#*$'\033['}"
    suffix="${suffix#*m}"
    text="${prefix}${suffix}"
  done

  printf '%s' "$text"
}

prompt::intro() {
  local title="$1"
  local meta="${2:-}"

  if [[ "$PROMPT__SESSION_OPEN" -eq 1 ]]; then
    return 0
  fi

  PROMPT__SESSION_OPEN=1
  trap 'prompt::cleanup_terminal' EXIT
  trap 'prompt::handle_interrupt' INT TERM

  printf '%s\n' "$(prompt::intro_line "$title" "$meta")"
  printf '%s\n' "$(prompt::blank_line)"
}

prompt::outro() {
  prompt::cleanup_terminal
  printf '%s\n' "$(prompt::success "$1")"
}

prompt::cancel() {
  local message="${1:-Operation cancelled.}"

  prompt::cleanup_terminal

  if [[ "$PROMPT__CANCELLED" -eq 0 ]]; then
    PROMPT__CANCELLED=1
    printf '%s\n' "$(prompt::danger "$message")" >&2
  fi
}

prompt::handle_interrupt() {
  prompt::cancel "Operation cancelled."
  exit 130
}

prompt::cleanup_terminal() {
  prompt::clear_rendered_block
  prompt::leave_raw_mode
}

prompt::hide_cursor() {
  if [[ "$PROMPT__CURSOR_HIDDEN" -eq 0 ]]; then
    printf '\033[?25l'
    PROMPT__CURSOR_HIDDEN=1
  fi
}

prompt::show_cursor() {
  if [[ "$PROMPT__CURSOR_HIDDEN" -eq 1 ]]; then
    printf '\033[?25h'
    PROMPT__CURSOR_HIDDEN=0
  fi
}

prompt::enter_raw_mode() {
  if [[ "$PROMPT__RAW_MODE" -eq 1 ]]; then
    return 0
  fi

  PROMPT__STTY_STATE="$(stty -g)"
  stty -echo -icanon min 1 time 0
  PROMPT__RAW_MODE=1
  prompt::hide_cursor
}

prompt::leave_raw_mode() {
  if [[ "$PROMPT__RAW_MODE" -eq 1 ]]; then
    stty "$PROMPT__STTY_STATE"
    PROMPT__RAW_MODE=0
    PROMPT__STTY_STATE=""
  fi

  prompt::show_cursor
}

prompt::clear_rendered_block() {
  local line_count remaining

  if [[ "${PROMPT__RENDERED_LINES:-0}" -gt 0 ]]; then
    line_count="$PROMPT__RENDERED_LINES"
    remaining="$line_count"

    printf '\033[%dA' "$line_count"
    while [[ "$remaining" -gt 0 ]]; do
      printf '\r\033[K'
      remaining=$((remaining - 1))
      if [[ "$remaining" -gt 0 ]]; then
        printf '\033[B'
      fi
    done

    if [[ "$line_count" -gt 1 ]]; then
      printf '\033[%dA' $((line_count - 1))
    fi
    printf '\r'
    PROMPT__RENDERED_LINES=0
    PROMPT__RENDERED_BLOCK_LINES=()
  fi
}

prompt::render_block() {
  local next_lines=("$@")
  local previous_count="${PROMPT__RENDERED_LINES:-0}"
  local next_count="$#"
  local max_count=0
  local index=0
  local previous_line=""
  local next_line=""
  local cursor_delta=0
  local common_prefix=0
  local common_suffix=0
  local previous_middle_count=0
  local next_middle_count=0

  if [[ "$previous_count" -le 0 ]]; then
    for next_line in "${next_lines[@]}"; do
      printf '%s\n' "$next_line"
    done

    PROMPT__RENDERED_BLOCK_LINES=("${next_lines[@]}")
    PROMPT__RENDERED_LINES="$next_count"
    return 0
  fi

  max_count="$previous_count"
  if [[ "$next_count" -gt "$max_count" ]]; then
    max_count="$next_count"
  fi

  if [[ "$max_count" -le 0 ]]; then
    PROMPT__RENDERED_BLOCK_LINES=()
    PROMPT__RENDERED_LINES=0
    return 0
  fi

  while [[ "$common_prefix" -lt "$previous_count" && "$common_prefix" -lt "$next_count" ]]; do
    if [[ "${PROMPT__RENDERED_BLOCK_LINES[$common_prefix]-}" != "${next_lines[$common_prefix]-}" ]]; then
      break
    fi
    common_prefix=$((common_prefix + 1))
  done

  while [[ $((common_prefix + common_suffix)) -lt "$previous_count" && $((common_prefix + common_suffix)) -lt "$next_count" ]]; do
    if [[ "${PROMPT__RENDERED_BLOCK_LINES[$((previous_count - common_suffix - 1))]-}" != "${next_lines[$((next_count - common_suffix - 1))]-}" ]]; then
      break
    fi
    common_suffix=$((common_suffix + 1))
  done

  previous_middle_count=$((previous_count - common_prefix - common_suffix))
  next_middle_count=$((next_count - common_prefix - common_suffix))

  if [[ "$previous_middle_count" -eq 0 && "$next_middle_count" -gt 0 ]]; then
    if [[ $((previous_count - common_prefix)) -gt 0 ]]; then
      printf '\033[%dA' "$((previous_count - common_prefix))"
    fi
    if [[ "$common_prefix" -lt "$previous_count" ]]; then
      printf '\033[%dL' "$next_middle_count"
    fi

    index=0
    while [[ "$index" -lt "$next_middle_count" ]]; do
      printf '\r\033[K%s' "${next_lines[$((common_prefix + index))]}"
      index=$((index + 1))
      if [[ "$index" -lt "$next_middle_count" ]]; then
        printf '\033[B'
      fi
    done

    if [[ "$common_suffix" -ge 0 ]]; then
      printf '\033[%dB' "$((common_suffix + 1))"
    fi
    printf '\r'
    PROMPT__RENDERED_BLOCK_LINES=("${next_lines[@]}")
    PROMPT__RENDERED_LINES="$next_count"
    return 0
  fi

  if [[ "$previous_middle_count" -gt 0 && "$next_middle_count" -eq 0 ]]; then
    if [[ $((previous_count - common_prefix)) -gt 0 ]]; then
      printf '\033[%dA' "$((previous_count - common_prefix))"
    fi
    printf '\033[%dM' "$previous_middle_count"
    if [[ "$common_suffix" -gt 0 ]]; then
      printf '\033[%dB' "$common_suffix"
    fi
    printf '\r'
    PROMPT__RENDERED_BLOCK_LINES=("${next_lines[@]}")
    PROMPT__RENDERED_LINES="$next_count"
    return 0
  fi

  printf '\033[%dA' "$previous_count"

  while [[ "$index" -lt "$max_count" ]]; do
    previous_line="${PROMPT__RENDERED_BLOCK_LINES[$index]-}"
    next_line="${next_lines[$index]-}"

    if [[ "$index" -ge "$next_count" ]]; then
      printf '\r\033[K'
    elif [[ "$index" -ge "$previous_count" || "$previous_line" != "$next_line" ]]; then
      printf '\r\033[K%s' "$next_line"
    fi

    index=$((index + 1))
    if [[ "$index" -lt "$max_count" ]]; then
      printf '\033[B'
    fi
  done

  cursor_delta=$((next_count - max_count + 1))
  if [[ "$cursor_delta" -gt 0 ]]; then
    printf '\033[%dB' "$cursor_delta"
  elif [[ "$cursor_delta" -lt 0 ]]; then
    printf '\033[%dA' "$((-cursor_delta))"
  fi
  printf '\r'

  PROMPT__RENDERED_BLOCK_LINES=("${next_lines[@]}")
  PROMPT__RENDERED_LINES="$next_count"
}

prompt::set_result() {
  local result_name="$1"
  local result_value="$2"

  printf -v "$result_name" '%s' "$result_value"
}

prompt::record_field() {
  local record="$1"
  local field_index="$2"
  local id label description selected disabled status

  IFS=$'\t' read -r id label description selected disabled status <<<"$record"

  case "$field_index" in
    1) printf '%s' "$id" ;;
    2) printf '%s' "$label" ;;
    3) printf '%s' "$description" ;;
    4) printf '%s' "$selected" ;;
    5) printf '%s' "$disabled" ;;
    6) printf '%s' "$status" ;;
  esac
}

prompt::join_by() {
  local delimiter="$1"
  shift || true

  local output=""
  local part=""

  for part in "$@"; do
    if [[ -z "$output" ]]; then
      output="$part"
    else
      output="${output}${delimiter}${part}"
    fi
  done

  printf '%s' "$output"
}

prompt::terminal_lines() {
  local lines=""
  local stty_size=""

  if command -v tput >/dev/null 2>&1; then
    lines="$(tput lines 2>/dev/null || true)"
  fi

  if [[ ! "$lines" =~ ^[0-9]+$ ]] || [[ "$lines" -le 0 ]]; then
    stty_size="$(stty size 2>/dev/null || true)"
    if [[ "$stty_size" =~ ^[0-9]+[[:space:]][0-9]+$ ]]; then
      lines="${stty_size%% *}"
    fi
  fi

  if [[ ! "$lines" =~ ^[0-9]+$ ]] || [[ "$lines" -le 0 ]]; then
    lines=24
  fi

  printf '%s' "$lines"
}

prompt::terminal_columns() {
  local columns=""
  local stty_size=""

  if command -v tput >/dev/null 2>&1; then
    columns="$(tput cols 2>/dev/null || true)"
  fi

  if [[ ! "$columns" =~ ^[0-9]+$ ]] || [[ "$columns" -le 0 ]]; then
    stty_size="$(stty size 2>/dev/null || true)"
    if [[ "$stty_size" =~ ^[0-9]+[[:space:]][0-9]+$ ]]; then
      columns="${stty_size##* }"
    fi
  fi

  if [[ ! "$columns" =~ ^[0-9]+$ ]] || [[ "$columns" -le 0 ]]; then
    columns=80
  fi

  printf '%s' "$columns"
}

prompt::selected_labels_from_records() {
  local selected_ids="$1"
  shift || true

  local record id label
  local labels=()

  for record in "$@"; do
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"

    case " $selected_ids " in
      *" $id "*) labels[${#labels[@]}]="$label" ;;
    esac
  done

  if [[ "${#labels[@]}" -eq 0 ]]; then
    return 0
  fi

  prompt::join_by ", " "${labels[@]}"
}

prompt::move_index() {
  local direction="$1"
  local current_index="$2"
  local count="$3"

  local next_index="$current_index"

  if [[ "$count" -eq 0 ]]; then
    printf '%s' "$current_index"
    return 0
  fi

  case "$direction" in
    up)
      if [[ "$next_index" -le 0 ]]; then
        next_index=$((count - 1))
      else
        next_index=$((next_index - 1))
      fi
      ;;
    down)
      if [[ "$next_index" -ge $((count - 1)) ]]; then
        next_index=0
      else
        next_index=$((next_index + 1))
      fi
      ;;
    *)
      printf '%s' "$current_index"
      return 0
      ;;
  esac

  printf '%s' "$next_index"
}

prompt::read_key() {
  local key rest

  IFS= read -rsn1 key

  if [[ -z "$key" ]]; then
    printf 'enter'
    return 0
  fi

  case "$key" in
    $'\x03')
      printf 'ctrl_c'
      return 0
      ;;
    ' ')
      printf 'space'
      return 0
      ;;
    $'\x1b')
      if IFS= read -rsn2 rest; then
        case "$rest" in
          '[A') printf 'up' ;;
          '[B') printf 'down' ;;
          '[C') printf 'right' ;;
          '[D') printf 'left' ;;
          *) printf 'unknown' ;;
        esac
      else
        printf 'unknown'
      fi
      return 0
      ;;
    *)
      printf '%s' "$key"
      return 0
      ;;
  esac
}

prompt::summary() {
  local title="$1"
  shift || true
  prompt::print_completed "$title" "$@"
}

prompt::text() {
  local result_var="$1"
  local question="$2"
  local initial_value="${3:-}"
  local allow_empty="${4:-no}"
  shift 4 || true

  local validator_callback=""
  local validator_error_message="Value is invalid."
  local details=()
  local lines=()
  local rendered_lines=()
  local response=""
  local error_message=""
  local detail

  prompt::require_human_input text "$question" || return 64

  if [[ "$#" -gt 0 ]] && declare -F "$1" >/dev/null 2>&1; then
    validator_callback="$1"
    shift || true
    if [[ "$#" -gt 0 ]]; then
      validator_error_message="$1"
      shift || true
    fi
  fi

  details=("$@")

  lines[${#lines[@]}]="$(prompt::question_header "$question")"
  for detail in "${details[@]}"; do
    [[ -n "$detail" ]] || continue
    lines[${#lines[@]}]="$(prompt::hint_line "$detail")"
  done
  if [[ -n "$initial_value" ]]; then
    lines[${#lines[@]}]="$(prompt::default_line "$initial_value")"
  fi

  while true; do
    rendered_lines=("${lines[@]}")
    if [[ -n "$error_message" ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::error_line "$error_message")"
    fi

    prompt::render_block "${rendered_lines[@]}"
    printf '%s' "$(prompt::input_prompt)"
    PROMPT__RENDERED_LINES=$((PROMPT__RENDERED_LINES + 1))
    read -r response

    if [[ -z "$response" ]]; then
      response="$initial_value"
    fi

    if [[ -z "$response" && "$allow_empty" != "yes" ]]; then
      error_message="Value is required."
      continue
    fi

    if [[ -n "$validator_callback" ]] && ! "$validator_callback" "$response"; then
      error_message="$validator_error_message"
      continue
    fi

    break
  done

  prompt::clear_rendered_block
  prompt::set_result "$result_var" "$response"
  prompt::print_completed "$question" "$response"
}

prompt::select() {
  local result_var="$1"
  local question="$2"
  local hint="$3"
  shift 3 || true

  local records=("$@")
  local ids=()
  local labels=()
  local descriptions=()
  local description_lines=()
  local disabled=()
  local statuses=()
  local option_left_lines=()
  local option_current_left_lines=()
  local option_lines=()
  local option_current_lines=()
  local current_index=0
  local index=0
  local record id label description is_selected is_disabled status
  local key rendered_lines current_description_lines description_line rendered_option
  local header_lines footer_lines block_line
  local description_padding_line description_line_count max_description_line_count=0
  local status_align_width=0
  local inline_status=0

  prompt::require_human_input select "$question" || return 64

  for record in "${records[@]}"; do
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    is_selected="$(prompt::record_field "$record" 4)"
    is_disabled="$(prompt::record_field "$record" 5)"
    status="$(prompt::record_field "$record" 6)"

    ids[${#ids[@]}]="$id"
    labels[${#labels[@]}]="$label"
    descriptions[${#descriptions[@]}]="$description"
    disabled[${#disabled[@]}]="$is_disabled"
    statuses[${#statuses[@]}]="$status"

    if [[ "$is_selected" == "1" && "$is_disabled" != "1" ]]; then
      current_index="$index"
    fi

    index=$((index + 1))
  done

  prompt::uses_inline_status && inline_status=1

  header_lines="$(prompt::question_block "$question")"
  footer_lines="$(prompt::footer_block "$hint")"
  description_padding_line=""

  index=0
  while [[ "$index" -lt "${#labels[@]}" ]]; do
    if [[ -n "${descriptions[$index]}" ]]; then
      description_lines[index]="$(prompt::description_block "${descriptions[$index]}")"
    else
      description_lines[index]=""
    fi
    description_line_count=0
    if [[ -n "${description_lines[$index]}" ]]; then
      while IFS= read -r description_line; do
        description_line_count=$((description_line_count + 1))
      done <<<"${description_lines[$index]}"
    fi
    if [[ "$description_line_count" -gt "$max_description_line_count" ]]; then
      max_description_line_count="$description_line_count"
    fi

    option_left_lines[index]="$(prompt::select_option_left_text "${labels[$index]}" 0 "${disabled[$index]}")"
    option_current_left_lines[index]="$(prompt::select_option_left_text "${labels[$index]}" 1 "${disabled[$index]}")"

    if [[ "$inline_status" -eq 1 && -n "${statuses[$index]}" ]]; then
      rendered_option="$(prompt::strip_ansi "${option_left_lines[$index]}")"
      if [[ "${#rendered_option}" -gt "$status_align_width" ]]; then
        status_align_width="${#rendered_option}"
      fi
    fi

    index=$((index + 1))
  done

  index=0
  while [[ "$index" -lt "${#labels[@]}" ]]; do
    option_lines[index]="$(prompt::render_option_line "${option_left_lines[$index]}" "${statuses[$index]}" "$status_align_width")"
    option_current_lines[index]="$(prompt::render_option_line "${option_current_left_lines[$index]}" "${statuses[$index]}" "$status_align_width")"
    index=$((index + 1))
  done

  prompt::enter_raw_mode

  while true; do
    rendered_lines=()
    while IFS= read -r block_line; do
      rendered_lines[${#rendered_lines[@]}]="$block_line"
    done <<<"$header_lines"
    current_description_lines="${description_lines[$current_index]}"
    description_line_count=0
    if [[ -n "$current_description_lines" ]]; then
      while IFS= read -r description_line; do
        rendered_lines[${#rendered_lines[@]}]="$description_line"
        description_line_count=$((description_line_count + 1))
      done <<<"$current_description_lines"
    fi
    while [[ "$description_line_count" -lt "$max_description_line_count" ]]; do
      rendered_lines[${#rendered_lines[@]}]="$description_padding_line"
      description_line_count=$((description_line_count + 1))
    done

    index=0
    while [[ "$index" -lt "${#labels[@]}" ]]; do
      if [[ "$index" -eq "$current_index" ]]; then
        rendered_lines[${#rendered_lines[@]}]="${option_current_lines[$index]}"
      else
        rendered_lines[${#rendered_lines[@]}]="${option_lines[$index]}"
      fi
      index=$((index + 1))
    done

    while IFS= read -r block_line; do
      rendered_lines[${#rendered_lines[@]}]="$block_line"
    done <<<"$footer_lines"

    prompt::render_block "${rendered_lines[@]}"
    key="$(prompt::read_key)"

    case "$key" in
      up)
        current_index="$(prompt::move_index up "$current_index" "${#labels[@]}")"
        ;;
      down)
        current_index="$(prompt::move_index down "$current_index" "${#labels[@]}")"
        ;;
      enter)
        if [[ "${disabled[$current_index]}" == "1" ]]; then
          continue
        fi
        prompt::leave_raw_mode
        prompt::clear_rendered_block
        prompt::set_result "$result_var" "${ids[$current_index]}"
        prompt::print_completed "$question" "${labels[$current_index]}"
        return 0
        ;;
      ctrl_c)
        prompt::handle_interrupt
        ;;
    esac
  done
}

prompt::multiselect() {
  local result_var="$1"
  local question="$2"
  local hint="$3"
  shift 3 || true

  local records=("$@")
  local ids=()
  local labels=()
  local descriptions=()
  local description_lines=()
  local selected=()
  local disabled=()
  local statuses=()
  local option_left_unselected=()
  local option_left_unselected_current=()
  local option_left_selected=()
  local option_left_selected_current=()
  local option_line_unselected=()
  local option_line_unselected_current=()
  local option_line_selected=()
  local option_line_selected_current=()
  local current_index=0
  local index=0
  local record id label description is_selected is_disabled status
  local key rendered_lines current_description_lines description_line rendered_option
  local header_lines footer_lines block_line
  local description_padding_line max_description_line_count=0
  local selected_ids="" selected_labels=""
  local total_lines reserved_lines visible_count description_line_count footer_line_count
  local window_start window_end remaining_above remaining_below
  local scroll_indicator_slots=0
  local status_align_width=0
  local inline_status=0

  prompt::require_human_input multiselect "$question" || return 64

  for record in "${records[@]}"; do
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    is_selected="$(prompt::record_field "$record" 4)"
    is_disabled="$(prompt::record_field "$record" 5)"
    status="$(prompt::record_field "$record" 6)"

    ids[${#ids[@]}]="$id"
    labels[${#labels[@]}]="$label"
    descriptions[${#descriptions[@]}]="$description"
    selected[${#selected[@]}]="$is_selected"
    disabled[${#disabled[@]}]="$is_disabled"
    statuses[${#statuses[@]}]="$status"

    if [[ "$is_selected" == "1" && "$is_disabled" != "1" ]]; then
      current_index="$index"
    fi

    index=$((index + 1))
  done

  prompt::uses_inline_status && inline_status=1

  header_lines="$(prompt::question_block "$question")"
  footer_lines="$(prompt::footer_block "$hint")"
  description_padding_line=""
  total_lines="$(prompt::terminal_lines)"
  footer_line_count=0
  while IFS= read -r block_line; do
    footer_line_count=$((footer_line_count + 1))
  done <<<"$footer_lines"

  index=0
  while [[ "$index" -lt "${#labels[@]}" ]]; do
    if [[ -n "${descriptions[$index]}" ]]; then
      description_lines[index]="$(prompt::description_block "${descriptions[$index]}")"
    else
      description_lines[index]=""
    fi
    description_line_count=0
    if [[ -n "${description_lines[$index]}" ]]; then
      while IFS= read -r description_line; do
        description_line_count=$((description_line_count + 1))
      done <<<"${description_lines[$index]}"
    fi
    if [[ "$description_line_count" -gt "$max_description_line_count" ]]; then
      max_description_line_count="$description_line_count"
    fi

    option_left_unselected[index]="$(prompt::multiselect_option_left_text "${labels[$index]}" 0 0 "${disabled[$index]}")"
    option_left_unselected_current[index]="$(prompt::multiselect_option_left_text "${labels[$index]}" 1 0 "${disabled[$index]}")"
    option_left_selected[index]="$(prompt::multiselect_option_left_text "${labels[$index]}" 0 1 "${disabled[$index]}")"
    option_left_selected_current[index]="$(prompt::multiselect_option_left_text "${labels[$index]}" 1 1 "${disabled[$index]}")"

    if [[ "$inline_status" -eq 1 && -n "${statuses[$index]}" ]]; then
      rendered_option="$(prompt::strip_ansi "${option_left_unselected[$index]}")"
      if [[ "${#rendered_option}" -gt "$status_align_width" ]]; then
        status_align_width="${#rendered_option}"
      fi
    fi

    index=$((index + 1))
  done

  index=0
  while [[ "$index" -lt "${#labels[@]}" ]]; do
    option_line_unselected[index]="$(prompt::render_option_line "${option_left_unselected[$index]}" "${statuses[$index]}" "$status_align_width")"
    option_line_unselected_current[index]="$(prompt::render_option_line "${option_left_unselected_current[$index]}" "${statuses[$index]}" "$status_align_width")"
    option_line_selected[index]="$(prompt::render_option_line "${option_left_selected[$index]}" "${statuses[$index]}" "$status_align_width")"
    option_line_selected_current[index]="$(prompt::render_option_line "${option_left_selected_current[$index]}" "${statuses[$index]}" "$status_align_width")"
    index=$((index + 1))
  done

  prompt::enter_raw_mode

  while true; do
    rendered_lines=()
    while IFS= read -r block_line; do
      rendered_lines[${#rendered_lines[@]}]="$block_line"
    done <<<"$header_lines"
    current_description_lines="${description_lines[$current_index]}"
    description_line_count=0
    if [[ -n "$current_description_lines" ]]; then
      while IFS= read -r description_line; do
        rendered_lines[${#rendered_lines[@]}]="$description_line"
        description_line_count=$((description_line_count + 1))
      done <<<"$current_description_lines"
    fi
    while [[ "$description_line_count" -lt "$max_description_line_count" ]]; do
      rendered_lines[${#rendered_lines[@]}]="$description_padding_line"
      description_line_count=$((description_line_count + 1))
    done

    reserved_lines=7
    [[ -n "$hint" ]] && reserved_lines=$((reserved_lines + footer_line_count))
    reserved_lines=$((reserved_lines + max_description_line_count))
    visible_count=$((total_lines - reserved_lines))
    if [[ "$visible_count" -lt 1 ]]; then
      visible_count=1
    fi
    scroll_indicator_slots=0
    if [[ "${#labels[@]}" -gt "$visible_count" ]]; then
      scroll_indicator_slots=1
    fi

    window_start=$((current_index - (visible_count / 2)))
    if [[ "$window_start" -lt 0 ]]; then
      window_start=0
    fi

    window_end=$((window_start + visible_count - 1))
    if [[ "$window_end" -ge "${#labels[@]}" ]]; then
      window_end=$((${#labels[@]} - 1))
      window_start=$((window_end - visible_count + 1))
      if [[ "$window_start" -lt 0 ]]; then
        window_start=0
      fi
    fi

    remaining_above="$window_start"
    remaining_below=$((${#labels[@]} - window_end - 1))

    if [[ "$scroll_indicator_slots" -eq 1 ]]; then
      if [[ "$remaining_above" -gt 0 ]]; then
        rendered_lines[${#rendered_lines[@]}]="$(prompt::scroll_indicator_line "↑" "$remaining_above")"
      else
        rendered_lines[${#rendered_lines[@]}]="$description_padding_line"
      fi
    fi

    index="$window_start"
    while [[ "$index" -le "$window_end" ]]; do
      if [[ "${selected[$index]}" == "1" ]]; then
        if [[ "$index" -eq "$current_index" ]]; then
          rendered_lines[${#rendered_lines[@]}]="${option_line_selected_current[$index]}"
        else
          rendered_lines[${#rendered_lines[@]}]="${option_line_selected[$index]}"
        fi
      else
        if [[ "$index" -eq "$current_index" ]]; then
          rendered_lines[${#rendered_lines[@]}]="${option_line_unselected_current[$index]}"
        else
          rendered_lines[${#rendered_lines[@]}]="${option_line_unselected[$index]}"
        fi
      fi
      index=$((index + 1))
    done

    if [[ "$scroll_indicator_slots" -eq 1 ]]; then
      if [[ "$remaining_below" -gt 0 ]]; then
        rendered_lines[${#rendered_lines[@]}]="$(prompt::scroll_indicator_line "↓" "$remaining_below")"
      else
        rendered_lines[${#rendered_lines[@]}]="$description_padding_line"
      fi
    fi

    while IFS= read -r block_line; do
      rendered_lines[${#rendered_lines[@]}]="$block_line"
    done <<<"$footer_lines"

    prompt::render_block "${rendered_lines[@]}"
    key="$(prompt::read_key)"

    case "$key" in
      up)
        current_index="$(prompt::move_index up "$current_index" "${#labels[@]}")"
        ;;
      down)
        current_index="$(prompt::move_index down "$current_index" "${#labels[@]}")"
        ;;
      space)
        if [[ "${disabled[$current_index]}" != "1" ]]; then
          if [[ "${selected[$current_index]}" == "1" ]]; then
            selected[current_index]=0
          else
            selected[current_index]=1
          fi
        fi
        ;;
      enter)
        prompt::leave_raw_mode
        prompt::clear_rendered_block

        index=0
        while [[ "$index" -lt "${#labels[@]}" ]]; do
          if [[ "${selected[$index]}" == "1" ]]; then
            if [[ -n "$selected_ids" ]]; then
              selected_ids="$selected_ids ${ids[$index]}"
              selected_labels="$selected_labels, ${labels[$index]}"
            else
              selected_ids="${ids[$index]}"
              selected_labels="${labels[$index]}"
            fi
          fi
          index=$((index + 1))
        done

        prompt::set_result "$result_var" "$selected_ids"

        if [[ -n "$selected_labels" ]]; then
          prompt::print_completed "$question" "$selected_labels"
        else
          prompt::print_completed "$question" "No selections"
        fi
        return 0
        ;;
      ctrl_c)
        prompt::handle_interrupt
        ;;
    esac
  done
}

prompt::confirm() {
  local result_var="$1"
  local question="$2"
  local default_answer="${3:-yes}"
  shift 3 || true
  local details=("$@")
  local hint answer
  local options=()

  hint="Use ↑/↓ to choose, Enter to confirm."
  [[ "${#details[@]}" -gt 0 ]] && hint="$(prompt::join_by ' ' "${details[@]}")"

  if [[ "$default_answer" == "yes" ]]; then
    options[0]=$'yes\tYes\tProceed with this step.\t1\t0'
    options[1]=$'no\tNo\tSkip or cancel this step.\t0\t0'
  else
    options[0]=$'yes\tYes\tProceed with this step.\t0\t0'
    options[1]=$'no\tNo\tSkip or cancel this step.\t1\t0'
  fi

  prompt::select answer "$question" "$hint" "${options[@]}" || return $?
  prompt::set_result "$result_var" "$answer"
}
