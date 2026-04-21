" Shared dotfiles Vim entrypoint.

let DOTFILES = expand('~/.dotfiles')

source $DOTFILES/vim/basic.vim
source $DOTFILES/vim/plugin.vim
