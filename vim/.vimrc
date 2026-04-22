" Minimal Vim compatibility layer.
" Use Neovim for the full editor experience from this dotfiles repo.

set nocompatible
set encoding=utf-8
set number
set hidden
set mouse=a
set clipboard=unnamedplus
set ignorecase
set smartcase
set incsearch
set hlsearch
set expandtab
set shiftwidth=2
set tabstop=2
set softtabstop=2
set smartindent
set splitright
set splitbelow
set scrolloff=4
set sidescrolloff=8
set signcolumn=yes
set termguicolors
set updatetime=250
set wildmenu
set backspace=indent,eol,start
set undofile
set undodir=~/.vim/undo
set backupdir=~/.vim/backup
set directory=~/.vim/swap
let mapleader = ' '

if has('syntax')
  syntax enable
endif

filetype plugin indent on

if !isdirectory(expand('~/.vim/undo'))
  call mkdir(expand('~/.vim/undo'), 'p')
endif

if !isdirectory(expand('~/.vim/backup'))
  call mkdir(expand('~/.vim/backup'), 'p')
endif

if !isdirectory(expand('~/.vim/swap'))
  call mkdir(expand('~/.vim/swap'), 'p')
endif

if executable('nvim')
  command! -bar Nvim execute '!nvim' shellescape(expand('%:p'))
  nnoremap <leader>en :Nvim<CR>
endif
