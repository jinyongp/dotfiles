#!/bin/zsh

if type jq &>/dev/null; then
  mkdir -p $HOME/Library/KeyBindings
  default_keybindings=$HOME/Library/KeyBindings/DefaultKeyBinding.dict
  [ ! -f $default_keybindings ] && touch $default_keybindings

  echo -e "$(green Installing keybindings...)"
  cat <<EOF >$default_keybindings
{
  "₩" = ("insertText:", "\`");
  "~₩" = ("insertText:", "₩");
}
EOF
else
  echo -e "jq is not installed. Please install it first."
fi
