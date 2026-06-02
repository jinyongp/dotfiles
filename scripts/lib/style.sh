#!/usr/bin/env bash

if [[ -z "${DOTFILES_STYLE_LIB_DIR:-}" ]]; then
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    DOTFILES_STYLE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  elif [[ -n "${ZSH_VERSION:-}" ]]; then
    DOTFILES_STYLE_LIB_DIR="$(eval 'cd -- "$(dirname -- "${(%):-%x}")" && pwd')"
  fi
fi

if [[ -n "${DOTFILES_ROOT:-}" && -f "$DOTFILES_ROOT/scripts/lib/ui/tokens.sh" ]]; then
  # shellcheck disable=SC1090
  source "$DOTFILES_ROOT/scripts/lib/ui/tokens.sh"
else
  # shellcheck disable=SC1090
  source "$DOTFILES_STYLE_LIB_DIR/ui/tokens.sh"
fi

while read -r color_name style_tokens; do
  [[ -n "$color_name" ]] || continue
  eval "${color_name}() { dotfiles_style \"\$*\" ${style_tokens}; }"
done <<'EOF'
black black
red red
green green
yellow yellow
blue blue
purple purple
cyan cyan
white white
b_black bold black
b_red bold red
b_green bold green
b_yellow bold yellow
b_blue bold blue
b_purple bold purple
b_cyan bold cyan
b_white bold white
t_black dim black
t_red dim red
t_green dim green
t_yellow dim yellow
t_blue dim blue
t_purple dim purple
t_cyan dim cyan
t_white dim white
i_black italic black
i_red italic red
i_green italic green
i_yellow italic yellow
i_blue italic blue
i_purple italic purple
i_cyan italic cyan
i_white italic white
u_black underline black
u_red underline red
u_green underline green
u_yellow underline yellow
u_blue underline blue
u_purple underline purple
u_cyan underline cyan
u_white underline white
bg_black bg-black
bg_red bg-red
bg_green bg-green
bg_yellow bg-yellow
bg_blue bg-blue
bg_purple bg-purple
bg_cyan bg-cyan
bg_white bg-white
EOF
