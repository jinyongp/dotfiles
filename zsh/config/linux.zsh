if dotfiles_has_command fdfind && ! dotfiles_has_command fd; then
  alias fd="fdfind"
fi

if dotfiles_has_command batcat && ! dotfiles_has_command bat; then
  alias bat="batcat"
  export BAT_THEME="ansi"
fi

if [[ -d "$HOME/Android/Sdk" ]]; then
  export ANDROID_HOME="$HOME/Android/Sdk"
  dotfiles_prepend_path "$ANDROID_HOME/platform-tools"
  dotfiles_prepend_path "$ANDROID_HOME/emulator"
fi
