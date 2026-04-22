#!/usr/bin/env bash

PROMPT__SESSION_OPEN=0
PROMPT__RAW_MODE=0
PROMPT__CURSOR_HIDDEN=0
PROMPT__RENDERED_LINES=0
PROMPT__STTY_STATE=""
PROMPT__CANCELLED=0

prompt::intro() {
  local title="$1"

  if [[ "$PROMPT__SESSION_OPEN" -eq 1 ]]; then
    return 0
  fi

  PROMPT__SESSION_OPEN=1
  trap 'prompt::cleanup_terminal' EXIT
  trap 'prompt::handle_interrupt' INT TERM

  printf '┌   %s\n' "$title"
  printf '│\n'
}

prompt::outro() {
  prompt::cleanup_terminal
  printf '└  %s\n' "$1"
}

prompt::cancel() {
  local message="${1:-Operation cancelled.}"

  prompt::cleanup_terminal

  if [[ "$PROMPT__CANCELLED" -eq 0 ]]; then
    PROMPT__CANCELLED=1
    printf '└  %s\n' "$message" >&2
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
  if [[ "${PROMPT__RENDERED_LINES:-0}" -gt 0 ]]; then
    printf '\033[%dA' "$PROMPT__RENDERED_LINES"
    printf '\r\033[J'
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

prompt::render_option_line() {
  local left_text="$1"
  local status_text="${2:-}"
  local dim_line="${3:-0}"
  local columns padding_width padding=""

  if [[ -z "$status_text" ]]; then
    if [[ "$dim_line" == "1" ]]; then
      printf '\033[2m%s\033[0m' "$left_text"
    else
      printf '%s' "$left_text"
    fi
    return 0
  fi

  columns="$(prompt::terminal_columns)"
  padding_width=$((columns - ${#left_text} - ${#status_text}))
  if [[ "$padding_width" -lt 1 ]]; then
    padding_width=1
  fi

  printf -v padding '%*s' "$padding_width" ''

  if [[ "$dim_line" == "1" ]]; then
    printf '\033[2m%s%s%s\033[0m' "$left_text" "$padding" "$status_text"
  else
    printf '%s%s\033[2m%s\033[0m' "$left_text" "$padding" "$status_text"
  fi
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

prompt::first_selectable_index() {
  local index=0
  local is_disabled

  for is_disabled in "$@"; do
    if [[ "$is_disabled" != "1" ]]; then
      printf '%s' "$index"
      return 0
    fi
    index=$((index + 1))
  done

  return 1
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

prompt::print_completed() {
  local question="$1"
  shift || true
  local line

  printf '◇  %s\n' "$question"
  if [[ "$#" -eq 0 ]]; then
    printf '│\n'
    return 0
  fi

  for line in "$@"; do
    printf '│  %s\n' "$line"
  done
  printf '│\n'
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

  lines[${#lines[@]}]="◆  $question"
  for detail in "${details[@]}"; do
    [[ -n "$detail" ]] || continue
    lines[${#lines[@]}]="│  $detail"
  done
  if [[ -n "$initial_value" ]]; then
    lines[${#lines[@]}]="│  Default: $initial_value"
  fi
  lines[${#lines[@]}]="│"

  while true; do
    rendered_lines=("${lines[@]}")
    if [[ -n "$error_message" ]]; then
      rendered_lines[${#rendered_lines[@]}]="│  $error_message"
    fi

    prompt::render_block "${rendered_lines[@]}"
    printf '│  > '
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
  local disabled=()
  local statuses=()
  local current_index=0
  local index=0
  local record id label description is_selected is_disabled status
  local key rendered_lines option_prefix current_description rendered_option

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

  if [[ "${#disabled[@]}" -gt 0 && "${disabled[$current_index]}" == "1" ]]; then
    current_index="$(prompt::first_selectable_index "${disabled[@]}" || printf '0')"
  fi

  prompt::enter_raw_mode

  while true; do
    rendered_lines=()
    rendered_lines[${#rendered_lines[@]}]="◆  $question"
    [[ -n "$hint" ]] && rendered_lines[${#rendered_lines[@]}]="│  $hint"
    current_description="${descriptions[$current_index]}"
    [[ -n "$current_description" ]] && rendered_lines[${#rendered_lines[@]}]="│  $current_description"
    rendered_lines[${#rendered_lines[@]}]="│"

    index=0
    while [[ "$index" -lt "${#labels[@]}" ]]; do
      if [[ "${disabled[$index]}" == "1" ]]; then
        option_prefix="○"
      elif [[ "$index" -eq "$current_index" ]]; then
        option_prefix="●"
      else
        option_prefix="○"
      fi

      rendered_option="$(prompt::render_option_line "│  $option_prefix ${labels[$index]}" "${statuses[$index]}" "${disabled[$index]}")"
      rendered_lines[${#rendered_lines[@]}]="$rendered_option"
      index=$((index + 1))
    done

    prompt::render_block "${rendered_lines[@]}"
    key="$(prompt::read_key)"

    case "$key" in
      up)
        while [[ "$current_index" -gt 0 ]]; do
          current_index=$((current_index - 1))
          [[ "${disabled[$current_index]}" != "1" ]] && break
        done
        ;;
      down)
        while [[ "$current_index" -lt $((${#labels[@]} - 1)) ]]; do
          current_index=$((current_index + 1))
          [[ "${disabled[$current_index]}" != "1" ]] && break
        done
        ;;
      enter)
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
  local selected=()
  local disabled=()
  local statuses=()
  local current_index=0
  local index=0
  local record id label description is_selected is_disabled status
  local key rendered_lines current_description marker prefix rendered_option
  local selected_ids="" selected_labels=""
  local total_lines reserved_lines visible_count
  local window_start window_end remaining_above remaining_below

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

  if [[ "${#disabled[@]}" -gt 0 && "${disabled[$current_index]}" == "1" ]]; then
    current_index="$(prompt::first_selectable_index "${disabled[@]}" || printf '0')"
  fi

  prompt::enter_raw_mode

  while true; do
    rendered_lines=()
    rendered_lines[${#rendered_lines[@]}]="◆  $question"
    [[ -n "$hint" ]] && rendered_lines[${#rendered_lines[@]}]="│  $hint"
    current_description="${descriptions[$current_index]}"
    [[ -n "$current_description" ]] && rendered_lines[${#rendered_lines[@]}]="│  $current_description"
    rendered_lines[${#rendered_lines[@]}]="│"

    total_lines="$(prompt::terminal_lines)"
    reserved_lines=6
    [[ -n "$hint" ]] && reserved_lines=$((reserved_lines + 1))
    [[ -n "$current_description" ]] && reserved_lines=$((reserved_lines + 1))
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
      rendered_lines[${#rendered_lines[@]}]="│  ↑ $remaining_above more"
    fi

    index="$window_start"
    while [[ "$index" -le "$window_end" ]]; do
      if [[ "${selected[$index]}" == "1" ]]; then
        marker="◼"
      else
        marker="◻"
      fi

      if [[ "$index" -eq "$current_index" ]]; then
        prefix="›"
      else
        prefix=" "
      fi

      rendered_option="$(prompt::render_option_line "│  $prefix $marker ${labels[$index]}" "${statuses[$index]}" "${disabled[$index]}")"
      rendered_lines[${#rendered_lines[@]}]="$rendered_option"
      index=$((index + 1))
    done

    if [[ "$remaining_below" -gt 0 ]]; then
      rendered_lines[${#rendered_lines[@]}]="│  ↓ $remaining_below more"
    fi

    prompt::render_block "${rendered_lines[@]}"
    key="$(prompt::read_key)"

    case "$key" in
      up)
        while [[ "$current_index" -gt 0 ]]; do
          current_index=$((current_index - 1))
          [[ "${disabled[$current_index]}" != "1" ]] && break
        done
        ;;
      down)
        while [[ "$current_index" -lt $((${#labels[@]} - 1)) ]]; do
          current_index=$((current_index + 1))
          [[ "${disabled[$current_index]}" != "1" ]] && break
        done
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
