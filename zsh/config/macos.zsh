if [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  dotfiles_prepend_path "$ANDROID_HOME/platform-tools"
  dotfiles_prepend_path "$ANDROID_HOME/emulator"
fi
