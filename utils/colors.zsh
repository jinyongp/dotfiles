#!/usr/bin/env bash

dotfiles_color_reset=$'\033[0m'

dotfiles__color_print() {
  local color_code="$1"
  shift || true

  printf '\033[%sm%s%s' "$color_code" "$*" "$dotfiles_color_reset"
}

while read -r color_name color_code; do
  [[ -n "$color_name" ]] || continue
  eval "${color_name}() { dotfiles__color_print '${color_code}' \"\$*\"; }"
done <<'EOF'
black 0;30
red 0;31
green 0;32
yellow 0;33
blue 0;34
purple 0;35
cyan 0;36
white 0;37
b_black 1;30
b_red 1;31
b_green 1;32
b_yellow 1;33
b_blue 1;34
b_purple 1;35
b_cyan 1;36
b_white 1;37
t_black 2;30
t_red 2;31
t_green 2;32
t_yellow 2;33
t_blue 2;34
t_purple 2;35
t_cyan 2;36
t_white 2;37
i_black 3;30
i_red 3;31
i_green 3;32
i_yellow 3;33
i_blue 3;34
i_purple 3;35
i_cyan 3;36
i_white 3;37
u_black 4;30
u_red 4;31
u_green 4;32
u_yellow 4;33
u_blue 4;34
u_purple 4;35
u_cyan 4;36
u_white 4;37
bg_black 40
bg_red 41
bg_green 42
bg_yellow 43
bg_blue 44
bg_purple 45
bg_cyan 46
bg_white 47
EOF
