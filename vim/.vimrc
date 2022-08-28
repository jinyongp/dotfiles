" ============================= "
" author: jinyongp              "
" email: dev.jinyongp@gmail.com "
" ============================= "

" ------------------- "
" Indentation Options "
" ------------------- "

set autoindent
set expandtab
set shiftround
set cindent
set tabstop=2
set softtabstop=2
set shiftwidth=2
set smarttab
set smartindent

" -------------- "
" Search Options "
" -------------- "

set hlsearch
set ignorecase
set incsearch
set smartcase

" ---------------------- "
" Text Rendering Options "
" ---------------------- "

set encoding=utf-8
set termencoding=utf-8
set linebreak
set wrap
set scrolloff=1
set sidescrolloff=1
if has("syntax")
  syntax enable
endif

" ---------------------- "
" User Interface Options "
" ---------------------- "

set ruler
set laststatus=2
set showcmd
set wildmenu
set background=dark
"set term=xterm-256color
"set t_Co=256
set history=300
set number
"set relativenumber
set cursorline
highlight clear CursorLine
highlight CursorLineNr term=bold cterm=NONE ctermfg=cyan ctermbg=NONE
highlight LineNr term=bold cterm=NONE ctermfg=DarkGrey ctermbg=NONE
highlight MatchParen ctermbg=NONE
highlight Pmenu ctermbg=white ctermfg=black
highlight PmenuSel ctermbg=darkgrey ctermfg=white
set list listchars=tab:»\ ,trail:•
set noerrorbells
set mouse=nicr
set title

" Cursor Shape
let &t_SI = "\<Esc>]50;CursorShape=1\x7"
let &t_SR = "\<Esc>]50;CursorShape=2\x7"
let &t_EI = "\<Esc>]50;CursorShape=0\x7"

" Cursor Blinking
set ttimeout
set ttimeoutlen=1
set ttyfast

" -------------------- "
" Code Folding Options "
" -------------------- "

"set foldmethod=indent
"set foldnestmax=5

" --------------------- "
" Miscellaneous Options "
" --------------------- "

set langmap=ㅁㅠㅊㅇㄷㄹㅎㅗㅑㅓㅏㅣㅡㅜㅐㅔㅂㄱㄴㅅㅕㅍㅈㅌㅛㅋ;abcdefghijklmnopqrstuvwxyz
set nocompatible
set autoread
set backspace=indent,eol,start
"set nobackup
"set noswapfile
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undodir=~/.vim/undo//
"set spell
"set spellfile=~/.vim/spell/en.utf-8.add
set clipboard=unnamedplus
set viminfo=

" ------- "
" Plugins "
" ------- "

filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'
Plugin 'shougo/neocomplete.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'baskerville/bubblegum'
Plugin 'Rainbow-Parenthesis'


call vundle#end()
filetype plugin indent on

" --------------- "
" Plugin Settings "
" --------------- "

nmap <D-1> :NERDTreeToggle<cr>
let NERDTreeShowHidden=1

let g:airline_theme='bubblegum'
let g:airline_powerline_fonts=1
let g:airline_left_sep= ''
let g:airline_right_sep= ''

let g:airline#extensions#tabline#enabled=1
let g:airline#extensions#tablin#fnamemod= '.:t'
