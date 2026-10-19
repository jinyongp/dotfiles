#!/usr/bin/env bash

set -euo pipefail

base="$(basename "$0")"
DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$DOTFILES_ROOT/scripts/lib/ui/help.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"

usage() {
  ui::help_start "$base" "Stop processes bound to a local port."
  ui::help_usage "$base [options] <port>"
  ui::help_options \
    $'-f, --force\t-f, --force\tSend KILL instead of TERM.' \
    $'-h, --help\t-h, --help\tPrint this help and exit.'
  ui::help_examples \
    "$base 3000" \
    "$base --force 3000"
}

die() {
  ui::validation_error "$1" "$2" $'usage\t'"$base [options] <port>"
  exit 1
}

signal="TERM"
port=""

while (($# > 0)); do
  case "$1" in
  -f|--force)
    signal="KILL"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  -*)
    die "unknown option" $'option\t'"$1"
    ;;
  *)
    [[ -z "$port" ]] || die "expected exactly one port" $'port\t'"$1"
    port="$1"
    ;;
  esac
  shift
done

if (($# > 0)); then
  [[ -z "$port" ]] || die "expected exactly one port" $'port\t'"$1"
  port="$1"
  shift
fi

(($# == 0)) || die "expected exactly one port" $'port\t'"$1"
[[ -n "$port" ]] || die "missing required port" $'port\tmissing'
[[ "$port" =~ ^[0-9]+$ ]] || die "port must be a number" $'port\t'"$port"
port=$((10#$port))
((port >= 1 && port <= 65535)) || die "port must be between 1 and 65535" $'port\t'"$port"

command -v lsof >/dev/null 2>&1 || die "missing required command" $'command\tlsof'

pids="$({
  lsof -nP -t -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
  lsof -nP -t -iUDP:"$port" 2>/dev/null || true
} | sort -u)"

if [[ -z "$pids" ]]; then
  printf '%s: no process bound to port %s\n' "$base" "$port"
  exit 0
fi

read -r -a pid_list <<<"$(tr '\n' ' ' <<<"$pids")"
kill "-$signal" "${pid_list[@]}"

printf '%s: sent %s to port %s process(es): %s\n' \
  "$base" "$signal" "$port" "${pid_list[*]}"
