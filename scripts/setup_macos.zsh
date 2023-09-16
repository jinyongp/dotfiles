#!/bin/zsh

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
