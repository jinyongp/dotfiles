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
  local id label description selected disabled

  IFS=$'\t' read -r id label description selected disabled <<<"$record"

  case "$field_index" in
    1) printf '%s' "$id" ;;
    2) printf '%s' "$label" ;;
    3) printf '%s' "$description" ;;
    4) printf '%s' "$selected" ;;
    5) printf '%s' "$disabled" ;;
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

  prompt::join_by ", " "${labels[@]}"
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

  local details=("$@")
  local lines=()
  local rendered_lines=()
  local response=""
  local error_message=""
  local detail

  lines[${#lines[@]}]="◆  $question"
  for detail in "${details[@]}"; do
    [[ -n "$detail" ]] || continue
    lines[${#lines[@]}]="│  $detail"
  done
  if [[ -n "$initial_value" ]]; then
    lines[${#lines[@]}]="│  Default: $initial_value"
  fi
  lines[${#lines[@]}]="│"
  lines[${#lines[@]}]="│  > "

  while true; do
    rendered_lines=("${lines[@]}")
    if [[ -n "$error_message" ]]; then
      rendered_lines[${#rendered_lines[@]}]="│  $error_message"
    fi

    prompt::render_block "${rendered_lines[@]}"
    read -r response

    if [[ -z "$response" ]]; then
      response="$initial_value"
    fi

    if [[ -n "$response" || "$allow_empty" == "yes" ]]; then
      break
    fi

    error_message="Value is required."
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
  local current_index=0
  local index=0
  local record id label description is_selected is_disabled
  local key rendered_lines option_prefix current_description

  for record in "${records[@]}"; do
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    is_selected="$(prompt::record_field "$record" 4)"
    is_disabled="$(prompt::record_field "$record" 5)"

    ids[${#ids[@]}]="$id"
    labels[${#labels[@]}]="$label"
    descriptions[${#descriptions[@]}]="$description"
    disabled[${#disabled[@]}]="$is_disabled"

    if [[ "$is_selected" == "1" && "$is_disabled" != "1" ]]; then
      current_index="$index"
    fi

    index=$((index + 1))
  done

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

      rendered_lines[${#rendered_lines[@]}]="│  $option_prefix ${labels[$index]}"
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
  local current_index=0
  local index=0
  local record id label description is_selected is_disabled
  local key rendered_lines current_description marker prefix
  local selected_ids="" selected_labels=""

  for record in "${records[@]}"; do
    id="$(prompt::record_field "$record" 1)"
    label="$(prompt::record_field "$record" 2)"
    description="$(prompt::record_field "$record" 3)"
    is_selected="$(prompt::record_field "$record" 4)"
    is_disabled="$(prompt::record_field "$record" 5)"

    ids[${#ids[@]}]="$id"
    labels[${#labels[@]}]="$label"
    descriptions[${#descriptions[@]}]="$description"
    selected[${#selected[@]}]="$is_selected"
    disabled[${#disabled[@]}]="$is_disabled"

    if [[ "$is_selected" == "1" && "$is_disabled" != "1" ]]; then
      current_index="$index"
    fi

    index=$((index + 1))
  done

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

      rendered_lines[${#rendered_lines[@]}]="│  $prefix $marker ${labels[$index]}"
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
      space)
        if [[ "${disabled[$current_index]}" != "1" ]]; then
          if [[ "${selected[$current_index]}" == "1" ]]; then
            selected[$current_index]=0
          else
            selected[$current_index]=1
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
