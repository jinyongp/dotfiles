#!/usr/bin/env bash

PROMPT__LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/style.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/style.sh"
fi

# shellcheck disable=SC1090
source "$PROMPT__LIB_DIR/prompt/style.bash"
# shellcheck disable=SC1090
source "$PROMPT__LIB_DIR/prompt/layout.bash"

PROMPT__SESSION_OPEN=0
PROMPT__RAW_MODE=0
PROMPT__CURSOR_HIDDEN=0
PROMPT__RENDERED_LINES=0
PROMPT__STTY_STATE=""
PROMPT__CANCELLED=0
PROMPT__UI_MODE="${DOTFILES_INSTALL_UI_MODE:-compact}"

case "$PROMPT__UI_MODE" in
  plain|compact|rich) ;;
  *) PROMPT__UI_MODE="compact" ;;
esac

prompt::ui_mode() {
  printf '%s' "$PROMPT__UI_MODE"
}

prompt::is_plain_mode() {
  [[ "$PROMPT__UI_MODE" == "plain" ]]
}

prompt::is_rich_mode() {
  [[ "$PROMPT__UI_MODE" == "rich" ]]
}

prompt::uses_inline_status() {
  [[ "$PROMPT__UI_MODE" != "rich" ]]
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
  fi
}

prompt::render_block() {
  local line

  prompt::clear_rendered_block

  for line in "$@"; do
    printf '%s\n' "$line"
  done

  PROMPT__RENDERED_LINES=$#
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
  local key rendered_lines current_description_line rendered_option
  local status_align_width=0
  local header_line footer_line blank_line
  local rich_mode=0 inline_status=0

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

  prompt::is_rich_mode && rich_mode=1
  prompt::uses_inline_status && inline_status=1

  header_line="$(prompt::question_header "$question")"
  footer_line="$(prompt::footer_line "$hint")"
  blank_line="$(prompt::blank_line)"

  index=0
  while [[ "$index" -lt "${#labels[@]}" ]]; do
    if [[ -n "${descriptions[$index]}" ]]; then
      description_lines[index]="$(prompt::description_line "${descriptions[$index]}")"
    else
      description_lines[index]=""
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
    rendered_lines[${#rendered_lines[@]}]="$header_line"
    current_description_line="${description_lines[$current_index]}"
    [[ -n "$current_description_line" ]] && rendered_lines[${#rendered_lines[@]}]="$current_description_line"

    if [[ "$rich_mode" -eq 1 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$blank_line"
    fi

    index=0
    while [[ "$index" -lt "${#labels[@]}" ]]; do
      if [[ "$index" -eq "$current_index" ]]; then
        rendered_lines[${#rendered_lines[@]}]="${option_current_lines[$index]}"
      else
        rendered_lines[${#rendered_lines[@]}]="${option_lines[$index]}"
      fi
      index=$((index + 1))
    done

    if [[ "$rich_mode" -eq 1 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$blank_line"
    fi
    rendered_lines[${#rendered_lines[@]}]="$footer_line"

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
  local key rendered_lines current_description_line rendered_option
  local selected_ids="" selected_labels=""
  local total_lines reserved_lines visible_count
  local window_start window_end remaining_above remaining_below
  local status_align_width=0
  local header_line footer_line blank_line
  local rich_mode=0 inline_status=0

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

  prompt::is_rich_mode && rich_mode=1
  prompt::uses_inline_status && inline_status=1

  header_line="$(prompt::question_header "$question")"
  footer_line="$(prompt::footer_line "$hint")"
  blank_line="$(prompt::blank_line)"
  total_lines="$(prompt::terminal_lines)"

  index=0
  while [[ "$index" -lt "${#labels[@]}" ]]; do
    if [[ -n "${descriptions[$index]}" ]]; then
      description_lines[index]="$(prompt::description_line "${descriptions[$index]}")"
    else
      description_lines[index]=""
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
    rendered_lines[${#rendered_lines[@]}]="$header_line"
    current_description_line="${description_lines[$current_index]}"
    [[ -n "$current_description_line" ]] && rendered_lines[${#rendered_lines[@]}]="$current_description_line"

    if [[ "$rich_mode" -eq 1 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$blank_line"
    fi

    reserved_lines=7
    [[ -n "$hint" ]] && reserved_lines=$((reserved_lines + 1))
    [[ -n "$current_description_line" ]] && reserved_lines=$((reserved_lines + 1))
    visible_count=$((total_lines - reserved_lines))
    if [[ "$visible_count" -lt 1 ]]; then
      visible_count=1
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

    if [[ "$remaining_above" -gt 0 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::scroll_indicator_line "↑" "$remaining_above")"
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

    if [[ "$remaining_below" -gt 0 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::scroll_indicator_line "↓" "$remaining_below")"
    fi

    if [[ "$rich_mode" -eq 1 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$blank_line"
    fi
    rendered_lines[${#rendered_lines[@]}]="$footer_line"

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

  prompt::select answer "$question" "$hint" "${options[@]}"
  prompt::set_result "$result_var" "$answer"
}
