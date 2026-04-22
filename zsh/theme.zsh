dotfiles_configure_theme() {
  case "${DOTFILES_THEME:-starship}" in
    powerlevel10k)
      source "$DOTFILES/zsh/themes/powerlevel10k.zsh"
      ;;
    default)
      export ZSH_THEME="robbyrussell"
      ;;
    starship|none)
      export ZSH_THEME=""
      ;;
    *)
      export DOTFILES_THEME="starship"
      export ZSH_THEME=""
      ;;
  esac
}

dotfiles_init_theme() {
  dotfiles_configure_theme

  case "${DOTFILES_THEME:-starship}" in
    starship)
      if dotfiles_has_terminal_ui && dotfiles_has_command starship; then
        source "$DOTFILES/zsh/themes/starship.zsh"
      fi
      ;;
  esac
}
