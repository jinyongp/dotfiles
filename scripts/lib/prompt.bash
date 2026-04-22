#!/usr/bin/env bash

if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/style.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/style.sh"
fi

PROMPT__SESSION_OPEN=0
PROMPT__RAW_MODE=0
PROMPT__CURSOR_HIDDEN=0
PROMPT__RENDERED_LINES=0
PROMPT__STTY_STATE=""
PROMPT__CANCELLED=0

prompt::style() {
  local text="$1"
  shift || true

  if declare -F dotfiles_style >/dev/null 2>&1; then
    dotfiles_style "$text" "$@"
  else
    printf '%s' "$text"
  fi
}

prompt::frame() {
  if declare -F dotfiles_frame >/dev/null 2>&1; then
    dotfiles_frame "$1"
  else
    prompt::style "$1" dim fg=245
  fi
}

prompt::title() {
  if declare -F dotfiles_heading >/dev/null 2>&1; then
    dotfiles_heading "$1"
  else
    prompt::style "$1" bold bright-white
  fi
}

prompt::body() {
  if declare -F dotfiles_body >/dev/null 2>&1; then
    dotfiles_body "$1"
  else
    prompt::style "$1" bright-white
  fi
}

prompt::value() {
  if declare -F dotfiles_value >/dev/null 2>&1; then
    dotfiles_value "$1"
  else
    prompt::style "$1" bold bright-cyan
  fi
}

prompt::accent() {
  if declare -F dotfiles_accent >/dev/null 2>&1; then
    dotfiles_accent "$1"
  else
    prompt::style "$1" bold blue
  fi
}

prompt::success() {
  if declare -F dotfiles_success >/dev/null 2>&1; then
    dotfiles_success "$1"
  else
    prompt::style "$1" bold green
  fi
}

prompt::warning() {
  if declare -F dotfiles_warning >/dev/null 2>&1; then
    dotfiles_warning "$1"
  else
    prompt::style "$1" bold magenta
  fi
}

prompt::danger() {
  if declare -F dotfiles_error >/dev/null 2>&1; then
    dotfiles_error "$1"
  else
    prompt::style "$1" bold red
  fi
}

prompt::muted() {
  if declare -F dotfiles_muted >/dev/null 2>&1; then
    dotfiles_muted "$1"
  else
    prompt::style "$1" dim fg=245
  fi
}

prompt::subtle() {
  if declare -F dotfiles_subtle >/dev/null 2>&1; then
    dotfiles_subtle "$1"
  else
    prompt::style "$1" fg=246
  fi
}

prompt::hint() {
  if declare -F dotfiles_hint >/dev/null 2>&1; then
    dotfiles_hint "$1"
  else
    prompt::style "$1" dim italic fg=245
  fi
}

prompt::description() {
  if declare -F dotfiles_description >/dev/null 2>&1; then
    dotfiles_description "$1"
  else
    prompt::style "$1" fg=248
  fi
}

prompt::disabled() {
  if declare -F dotfiles_disabled >/dev/null 2>&1; then
    dotfiles_disabled "$1"
  else
    prompt::style "$1" dim fg=242
  fi
}

prompt::active_label() {
  if declare -F dotfiles_active >/dev/null 2>&1; then
    dotfiles_active "$1"
  else
    prompt::style "$1" bold underline bright-white
  fi
}

prompt::selected_label() {
  if declare -F dotfiles_selected >/dev/null 2>&1; then
    dotfiles_selected "$1"
  else
    prompt::style "$1" bold bright-green
  fi
}

prompt::selected_active_label() {
  if declare -F dotfiles_selected_active >/dev/null 2>&1; then
    dotfiles_selected_active "$1"
  else
    prompt::style "$1" bold underline green
  fi
}

prompt::line() {
  printf '%s  %s' "$(prompt::frame "│")" "$1"
}

prompt::branch() {
  printf '%s' "$(prompt::frame "╰")"
}

prompt::branch_line() {
  printf '%s  %s' "$(prompt::branch)" "$1"
}

prompt::blank_line() {
  printf '%s' "$(prompt::frame "│")"
}

prompt::keycap() {
  if declare -F dotfiles_code >/dev/null 2>&1; then
    dotfiles_code "$1"
  else
    prompt::accent "$1"
  fi
}

prompt::shortcut_text() {
  local hint="$1"
  local remaining="$hint"
  local output=""
  local token="" prefix="" best_token="" best_prefix=""
  local best_index=-1
  local current_index=0
  local tokens=(
    "Ctrl+C"
    "↑/↓"
    "Space"
    "Enter"
    "Tab"
    "Esc"
  )

  while [[ -n "$remaining" ]]; do
    best_token=""
    best_prefix=""
    best_index=-1

    for token in "${tokens[@]}"; do
      if [[ "$remaining" != *"$token"* ]]; then
        continue
      fi

      prefix="${remaining%%"$token"*}"
      current_index=${#prefix}

      if [[ "$best_index" -lt 0 || "$current_index" -lt "$best_index" ]]; then
        best_index="$current_index"
        best_token="$token"
        best_prefix="$prefix"
      fi
    done

    if [[ -z "$best_token" ]]; then
      output="${output}$(prompt::hint "$remaining")"
      break
    fi

    if [[ -n "$best_prefix" ]]; then
      output="${output}$(prompt::hint "$best_prefix")"
    fi
    output="${output}$(prompt::keycap "$best_token")"
    remaining="${remaining#*"$best_token"}"
  done

  printf '%s' "$output"
}

prompt::badge_text() {
  printf '[%s]' "$1"
}

prompt::badge() {
  local text="$1"
  local badge_text=""

  badge_text="$(prompt::badge_text "$text")"

  case "$text" in
    current) prompt::accent "$badge_text" ;;
    installed) prompt::disabled "$badge_text" ;;
    *) prompt::warning "$badge_text" ;;
  esac
}

prompt::format_completed_line() {
  local line="$1"
  local label value

  case "$line" in
    Auto:\ *)
      printf '%s %s' "$(prompt::warning "Auto:")" "$(prompt::body "${line#Auto: }")"
      return 0
      ;;
    Reuse:\ *)
      printf '%s %s' "$(prompt::accent "Reuse:")" "$(prompt::body "${line#Reuse: }")"
      return 0
      ;;
    Skip:\ *)
      printf '%s %s' "$(prompt::muted "Skip:")" "$(prompt::body "${line#Skip: }")"
      return 0
      ;;
  esac

  if [[ "$line" == *": "* ]]; then
    label="${line%%:*}:"
    value="${line#*: }"
    printf '%s %s' "$(prompt::muted "$label")" "$(prompt::value "$value")"
    return 0
  fi

  printf '%s' "$(prompt::body "$line")"
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

  if [[ "$PROMPT__SESSION_OPEN" -eq 1 ]]; then
    return 0
  fi

  PROMPT__SESSION_OPEN=1
  trap 'prompt::cleanup_terminal' EXIT
  trap 'prompt::handle_interrupt' INT TERM

  printf '%s  %s\n' "$(prompt::frame "┌")" "$(prompt::title "$title")"
  printf '%s\n' "$(prompt::blank_line)"
}

prompt::outro() {
  prompt::cleanup_terminal
  printf '%s  %s\n' "$(prompt::frame "└")" "$(prompt::success "$1")"
}

prompt::cancel() {
  local message="${1:-Operation cancelled.}"

  prompt::cleanup_terminal

  if [[ "$PROMPT__CANCELLED" -eq 0 ]]; then
    PROMPT__CANCELLED=1
    printf '%s  %s\n' "$(prompt::frame "└")" "$(prompt::danger "$message")" >&2
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
  local columns padding_width padding=""
  local visible_left visible_status rendered_status=""

  visible_left="$(prompt::strip_ansi "$left_text")"

  if [[ -z "$status_text" ]]; then
    printf '%s' "$left_text"
    return 0
  fi

  rendered_status="$(prompt::badge "$status_text")"
  visible_status="$(prompt::badge_text "$status_text")"
  columns="$(prompt::terminal_columns)"
  padding_width=$((columns - ${#visible_left} - ${#visible_status}))
  if [[ "$padding_width" -lt 1 ]]; then
    padding_width=1
  fi

  printf -v padding '%*s' "$padding_width" ''
  printf '%s%s%s' "$left_text" "$padding" "$rendered_status"
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

  printf '%s  %s\n' "$(prompt::success "◇")" "$(prompt::title "$question")"
  if [[ "$#" -eq 0 ]]; then
    printf '%s\n' "$(prompt::blank_line)"
    return 0
  fi

  for line in "$@"; do
    printf '%s\n' "$(prompt::line "$(prompt::format_completed_line "$line")")"
  done
  printf '%s\n' "$(prompt::blank_line)"
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

  lines[${#lines[@]}]="$(prompt::accent "◆")  $(prompt::title "$question")"
  for detail in "${details[@]}"; do
    [[ -n "$detail" ]] || continue
    lines[${#lines[@]}]="$(prompt::line "$(prompt::hint "$detail")")"
  done
  if [[ -n "$initial_value" ]]; then
    lines[${#lines[@]}]="$(prompt::line "$(prompt::muted "Default:") $(prompt::subtle "$initial_value")")"
  fi

  while true; do
    rendered_lines=("${lines[@]}")
    if [[ -n "$error_message" ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::line "$(prompt::danger "$error_message")")"
    fi

    prompt::render_block "${rendered_lines[@]}"
    printf '%s  %s ' "$(prompt::branch)" "$(prompt::accent ">")"
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
  local key rendered_lines option_prefix current_description rendered_option option_label
  local metadata_lines=()

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
    rendered_lines[${#rendered_lines[@]}]="$(prompt::accent "◆")  $(prompt::title "$question")"
    metadata_lines=()
    current_description="${descriptions[$current_index]}"
    [[ -n "$current_description" ]] && metadata_lines[${#metadata_lines[@]}]="$(prompt::description "$current_description")"
    index=0
    while [[ "$index" -lt "${#metadata_lines[@]}" ]]; do
      rendered_lines[${#rendered_lines[@]}]="$(prompt::line "${metadata_lines[$index]}")"
      index=$((index + 1))
    done

    rendered_lines[${#rendered_lines[@]}]="$(prompt::blank_line)"

    index=0
    while [[ "$index" -lt "${#labels[@]}" ]]; do
      if [[ "${disabled[$index]}" == "1" ]]; then
        option_prefix="$(prompt::disabled "○")"
        option_label="$(prompt::disabled "${labels[$index]}")"
      elif [[ "$index" -eq "$current_index" ]]; then
        option_prefix="$(prompt::accent "●")"
        option_label="$(prompt::active_label "${labels[$index]}")"
      else
        option_prefix="$(prompt::subtle "○")"
        option_label="$(prompt::body "${labels[$index]}")"
      fi

      rendered_option="$(prompt::render_option_line "$(prompt::line "$option_prefix $option_label")" "${statuses[$index]}")"
      rendered_lines[${#rendered_lines[@]}]="$rendered_option"
      index=$((index + 1))
    done

    rendered_lines[${#rendered_lines[@]}]="$(prompt::blank_line)"
    if [[ -n "$hint" ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::branch_line "$(prompt::shortcut_text "$hint")")"
    else
      rendered_lines[${#rendered_lines[@]}]="$(prompt::branch_line "")"
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
  local key rendered_lines current_description marker prefix rendered_option option_label
  local selected_ids="" selected_labels=""
  local total_lines reserved_lines visible_count
  local window_start window_end remaining_above remaining_below
  local metadata_lines=()

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
    rendered_lines[${#rendered_lines[@]}]="$(prompt::accent "◆")  $(prompt::title "$question")"
    metadata_lines=()
    current_description="${descriptions[$current_index]}"
    [[ -n "$current_description" ]] && metadata_lines[${#metadata_lines[@]}]="$(prompt::description "$current_description")"
    index=0
    while [[ "$index" -lt "${#metadata_lines[@]}" ]]; do
      rendered_lines[${#rendered_lines[@]}]="$(prompt::line "${metadata_lines[$index]}")"
      index=$((index + 1))
    done

    rendered_lines[${#rendered_lines[@]}]="$(prompt::blank_line)"

    total_lines="$(prompt::terminal_lines)"
    reserved_lines=7
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
      rendered_lines[${#rendered_lines[@]}]="$(prompt::line "$(prompt::muted "↑ $remaining_above more")")"
    fi

    index="$window_start"
    while [[ "$index" -le "$window_end" ]]; do
      if [[ "${disabled[$index]}" == "1" ]]; then
        marker="$(prompt::disabled "◻")"
        option_label="$(prompt::disabled "${labels[$index]}")"
      elif [[ "${selected[$index]}" == "1" ]]; then
        marker="$(prompt::success "◼")"
        if [[ "$index" -eq "$current_index" ]]; then
          option_label="$(prompt::selected_active_label "${labels[$index]}")"
        else
          option_label="$(prompt::selected_label "${labels[$index]}")"
        fi
      else
        marker="$(prompt::subtle "◻")"
        if [[ "$index" -eq "$current_index" ]]; then
          option_label="$(prompt::active_label "${labels[$index]}")"
        else
          option_label="$(prompt::body "${labels[$index]}")"
        fi
      fi

      if [[ "$index" -eq "$current_index" ]]; then
        prefix="$(prompt::accent "›")"
      else
        prefix="$(prompt::frame " ")"
      fi

      rendered_option="$(prompt::render_option_line "$(prompt::line "$prefix $marker $option_label")" "${statuses[$index]}")"
      rendered_lines[${#rendered_lines[@]}]="$rendered_option"
      index=$((index + 1))
    done

    if [[ "$remaining_below" -gt 0 ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::line "$(prompt::muted "↓ $remaining_below more")")"
    fi

    rendered_lines[${#rendered_lines[@]}]="$(prompt::blank_line)"
    if [[ -n "$hint" ]]; then
      rendered_lines[${#rendered_lines[@]}]="$(prompt::branch_line "$(prompt::shortcut_text "$hint")")"
    else
      rendered_lines[${#rendered_lines[@]}]="$(prompt::branch_line "")"
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
