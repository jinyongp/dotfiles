source "$DOTFILES/zsh/config/common.zsh"

case "$DOTFILES_PLATFORM" in
  macos)
    source "$DOTFILES/zsh/config/macos.zsh"
    ;;
  linux|wsl)
    source "$DOTFILES/zsh/config/linux.zsh"
    ;;
esac

if [[ "$DOTFILES_PLATFORM" == "wsl" ]]; then
  source "$DOTFILES/zsh/config/wsl.zsh"
fi
