#!/bin/zsh

prompt::yes_no() {
  local question="$1"
  local default_answer="${2:-yes}"
  shift 2

  local prompt_suffix=""
  local reply=""
  local detail=""

  case "$default_answer" in
    yes) prompt_suffix="[Y/n]" ;;
    no) prompt_suffix="[y/N]" ;;
    *)
      dotfiles::log_error "Invalid default answer: $default_answer"
      return 1
      ;;
  esac

  echo >&2
  echo "$question" >&2

  for detail in "$@"; do
    [[ -n "$detail" ]] || continue
    echo "  - $detail" >&2
  done

  while true; do
    read -r "reply?$prompt_suffix "

    if [[ -z "$reply" ]]; then
      reply="$default_answer"
    fi

    case "$reply:l" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
    esac

    echo "Please answer yes or no." >&2
  done
}

prompt::choose_one() {
  local question="$1"
  local default_index="$2"
  shift 2

  local options=("$@")
  local reply=""
  local option_index=1

  while true; do
    echo >&2
    echo "$question" >&2

    option_index=1
    for reply in "${options[@]}"; do
      echo "  $option_index) $reply" >&2
      (( option_index++ ))
    done

    printf "Select an option [%s]: " "$default_index" >&2
    read -r reply

    if [[ -z "$reply" ]]; then
      reply="$default_index"
    fi

    if [[ "$reply" == <-> && "$reply" -ge 1 && "$reply" -le "${#options[@]}" ]]; then
      print -r -- "${options[$reply]}"
      return 0
    fi

    echo "Invalid selection." >&2
  done
}

prompt::choose_one_described() {
  local question="$1"
  local default_index="$2"
  shift 2

  local raw_options=("$@")
  local labels=()
  local descriptions=()
  local raw_option=""
  local reply=""
  local option_index=1

  for raw_option in "${raw_options[@]}"; do
    labels+=("${raw_option%%::*}")
    descriptions+=("${raw_option#*::}")
  done

  while true; do
    echo >&2
    echo "$question" >&2

    for (( option_index = 1; option_index <= ${#labels[@]}; option_index++ )); do
      echo "  $option_index) ${labels[$option_index]}" >&2
      echo "     ${descriptions[$option_index]}" >&2
    done

    printf "Select an option [%s]: " "$default_index" >&2
    read -r reply

    if [[ -z "$reply" ]]; then
      reply="$default_index"
    fi

    if [[ "$reply" == <-> && "$reply" -ge 1 && "$reply" -le "${#labels[@]}" ]]; then
      print -r -- "${labels[$reply]}"
      return 0
    fi

    echo "Invalid selection." >&2
  done
}

prompt::read_string() {
  local question="$1"
  local default_value="${2:-}"
  local allow_empty="${3:-no}"
  shift 3

  local reply=""
  local detail=""
  local prompt_suffix="> "

  echo >&2
  echo "$question" >&2

  for detail in "$@"; do
    [[ -n "$detail" ]] || continue
    echo "  - $detail" >&2
  done

  if [[ -n "$default_value" ]]; then
    prompt_suffix="[$default_value] "
  fi

  while true; do
    read -r "reply?$prompt_suffix "

    if [[ -z "$reply" ]]; then
      reply="$default_value"
    fi

    if [[ -n "$reply" || "$allow_empty" == "yes" ]]; then
      print -r -- "$reply"
      return 0
    fi

    echo "A value is required." >&2
  done
}
