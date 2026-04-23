# Prompt line layout and visible block composition helpers.

prompt::line() {
  printf '   %s' "$1"
}

prompt::question_marker() {
  if prompt::is_plain_mode; then
    printf '>'
  else
    printf '◆'
  fi
}

prompt::completed_marker() {
  if prompt::is_plain_mode; then
    printf '='
  else
    printf '◇'
  fi
}

prompt::intro_line() {
  local title="$1"
  local meta="${2:-}"
  local left_text=""

  left_text="$(prompt::title "$title")"

  if [[ -z "$meta" ]]; then
    printf '%s' "$left_text"
    return 0
  fi

  printf '%s  %s' "$left_text" "$(prompt::intro_meta "$meta")"
}

prompt::branch() {
  printf ''
}

prompt::branch_line() {
  printf '   %s' "$1"
}

prompt::blank_line() {
  printf ''
}

prompt::question_header() {
  printf '%s  %s' "$(prompt::accent "$(prompt::question_marker)")" "$(prompt::title "$1")"
}

prompt::completed_header() {
  printf '%s  %s' "$(prompt::success "$(prompt::completed_marker)")" "$(prompt::title "$1")"
}

prompt::hint_line() {
  prompt::line "$(prompt::hint "$1")"
}

prompt::description_line() {
  prompt::line "$(prompt::description "$1")"
}

prompt::default_line() {
  prompt::line "$(prompt::muted "Default:") $(prompt::subtle "$1")"
}

prompt::error_line() {
  prompt::line "$(prompt::danger "$1")"
}

prompt::input_prompt() {
  printf '   %s' "$(prompt::accent ">")"
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
    output="${output}$(prompt::keycap "$(prompt::display_hint_token "$best_token")")"
    remaining="${remaining#*"$best_token"}"
  done

  printf '%s' "$output"
}

prompt::footer_line() {
  local hint="${1:-}"

  if [[ -n "$hint" ]]; then
    prompt::branch_line "$(prompt::shortcut_text "$hint")"
  else
    prompt::branch_line ""
  fi
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
  if prompt::uses_inline_status; then
    printf '%s %s' "$left_text" "$rendered_status"
    return 0
  fi

  visible_status="$(prompt::badge_text "$status_text")"
  columns="$(prompt::terminal_columns)"
  padding_width=$((columns - ${#visible_left} - ${#visible_status}))
  if [[ "$padding_width" -lt 1 ]]; then
    padding_width=1
  fi

  printf -v padding '%*s' "$padding_width" ''
  printf '%s%s%s' "$left_text" "$padding" "$rendered_status"
}

prompt::select_option_line() {
  local label="$1"
  local is_current="$2"
  local is_disabled="$3"
  local status_text="${4:-}"
  local option_prefix option_label

  if prompt::is_plain_mode; then
    if [[ "$is_disabled" == "1" ]]; then
      option_prefix="$(prompt::disabled "o")"
      option_label="$(prompt::disabled "$label")"
    elif [[ "$is_current" == "1" ]]; then
      option_prefix="$(prompt::accent "*")"
      option_label="$(prompt::active_label "$label")"
    else
      option_prefix="$(prompt::subtle "o")"
      option_label="$(prompt::body "$label")"
    fi
  else
    if [[ "$is_disabled" == "1" ]]; then
      option_prefix="$(prompt::disabled "○")"
      option_label="$(prompt::disabled "$label")"
    elif [[ "$is_current" == "1" ]]; then
      option_prefix="$(prompt::accent "●")"
      option_label="$(prompt::active_label "$label")"
    else
      option_prefix="$(prompt::subtle "○")"
      option_label="$(prompt::body "$label")"
    fi
  fi

  prompt::render_option_line "$(prompt::line "$option_prefix $option_label")" "$status_text"
}

prompt::multiselect_option_line() {
  local label="$1"
  local is_current="$2"
  local is_selected="$3"
  local is_disabled="$4"
  local status_text="${5:-}"
  local prefix marker option_label

  if prompt::is_plain_mode; then
    if [[ "$is_disabled" == "1" ]]; then
      marker="$(prompt::disabled "[ ]")"
      option_label="$(prompt::disabled "$label")"
    elif [[ "$is_selected" == "1" ]]; then
      marker="$(prompt::success "[x]")"
      if [[ "$is_current" == "1" ]]; then
        option_label="$(prompt::selected_active_label "$label")"
      else
        option_label="$(prompt::selected_label "$label")"
      fi
    else
      marker="$(prompt::subtle "[ ]")"
      if [[ "$is_current" == "1" ]]; then
        option_label="$(prompt::active_label "$label")"
      else
        option_label="$(prompt::body "$label")"
      fi
    fi

    if [[ "$is_current" == "1" ]]; then
      prefix="$(prompt::accent ">")"
    else
      prefix="$(prompt::frame " ")"
    fi
  else
    if [[ "$is_disabled" == "1" ]]; then
      marker="$(prompt::disabled "◻")"
      option_label="$(prompt::disabled "$label")"
    elif [[ "$is_selected" == "1" ]]; then
      marker="$(prompt::success "◼")"
      if [[ "$is_current" == "1" ]]; then
        option_label="$(prompt::selected_active_label "$label")"
      else
        option_label="$(prompt::selected_label "$label")"
      fi
    else
      marker="$(prompt::subtle "◻")"
      if [[ "$is_current" == "1" ]]; then
        option_label="$(prompt::active_label "$label")"
      else
        option_label="$(prompt::body "$label")"
      fi
    fi

    if [[ "$is_current" == "1" ]]; then
      prefix="$(prompt::accent "›")"
    else
      prefix="$(prompt::frame " ")"
    fi
  fi

  prompt::render_option_line "$(prompt::line "$prefix $marker $option_label")" "$status_text"
}

prompt::scroll_indicator_line() {
  local direction="$1"
  local count="$2"
  local indicator="$direction"

  if prompt::is_plain_mode; then
    case "$direction" in
      "↑") indicator="^" ;;
      "↓") indicator="v" ;;
    esac
  fi

  prompt::line "$(prompt::muted "$indicator $count more")"
}

prompt::print_completed() {
  local question="$1"
  shift || true
  local line

  printf '%s\n' "$(prompt::completed_header "$question")"
  if [[ "$#" -eq 0 ]]; then
    printf '%s\n' "$(prompt::blank_line)"
    return 0
  fi

  for line in "$@"; do
    printf '%s\n' "$(prompt::line "$(prompt::format_completed_line "$line")")"
  done
  printf '%s\n' "$(prompt::blank_line)"
}
