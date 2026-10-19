#!/usr/bin/env bash

set -euo pipefail

name="${0##*/}"
cmd_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

source "$cmd_dir/$name/main.sh"
