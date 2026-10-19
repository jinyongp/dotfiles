#!/usr/bin/env bash

set -euo pipefail

base="$(basename "$0")"
DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$DOTFILES_ROOT/scripts/lib/ui/help.sh"
source "$DOTFILES_ROOT/scripts/lib/ui/errors.sh"

usage() {
  ui::help_start "$base" "Stop a local service by port, domain, or URL through its reverse proxies."
  ui::help_usage "$base [options] <port|domain|url>"
  ui::help_options \
    $'-f, --force\t-f, --force\tSend KILL instead of TERM.' \
    $'--dry-run\t--dry-run\tShow the target without sending a signal.' \
    $'-h, --help\t-h, --help\tPrint this help and exit.'
  ui::help_examples \
    "$base 3000" \
    "$base --force 3000" \
    "$base --dry-run app.test" \
    "$base https://app.test/api"
}

die() {
  ui::validation_error "$1" "$2" $'usage\t'"$base [options] <port|domain|url>"
  exit 1
}

signal="TERM"
dry_run=0
port=""

while (($# > 0)); do
  case "$1" in
  -f|--force)
    signal="KILL"
    ;;
  --dry-run)
    dry_run=1
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
    [[ -z "$port" ]] || die "expected exactly one target" $'target\t'"$1"
    port="$1"
    ;;
  esac
  shift
done

if (($# > 0)); then
  [[ -z "$port" ]] || die "expected exactly one target" $'target\t'"$1"
  port="$1"
  shift
fi

(($# == 0)) || die "expected exactly one target" $'target\t'"$1"
[[ -n "$port" ]] || die "missing required target" $'target\tmissing'

command -v lsof >/dev/null 2>&1 || die "missing required command" $'command\tlsof'
if [[ ! "$port" =~ ^[0-9]+$ ]]; then
  command -v python3 >/dev/null 2>&1 || die "missing required command" $'command\tpython3'
  if trace_output="$(python3 -B "$DOTFILES_ROOT/cmd/kill-port/trace.py" "$port" "$signal" "$dry_run" 2>&1)"; then
    printf '%s\n' "$trace_output"
    exit 0
  fi
  die "cannot resolve local service" $'detail\t'"$trace_output"
fi

# Bound the input before shell arithmetic to avoid overflow on long numbers.
normalized_port="${port#"${port%%[!0]*}"}"
((${#normalized_port} <= 5)) || die "port must be between 1 and 65535" $'port\t'"$port"
port=$((10#${normalized_port:-0}))
((port >= 1 && port <= 65535)) || die "port must be between 1 and 65535" $'port\t'"$port"

pids="$({
  lsof -nP -t -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true
  lsof -nP -t -iUDP:"$port" 2>/dev/null || true
} | sort -u)"

if [[ -z "$pids" ]]; then
  printf '%s: no process bound to port %s\n' "$base" "$port"
  exit 0
fi

read -r -a pid_list <<<"$(tr '\n' ' ' <<<"$pids")"
if [[ "$dry_run" == 1 ]]; then
  printf '%s: dry run; port %s process(es): %s; no signal sent\n' "$base" "$port" "${pid_list[*]}"
  exit 0
fi
kill "-$signal" "${pid_list[@]}"

printf '%s: sent %s to port %s process(es): %s\n' \
  "$base" "$signal" "$port" "${pid_list[*]}"
