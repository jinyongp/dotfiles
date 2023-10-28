filetype off
" Vim의 파일 타입 자동 감지 기능을 끕니다.
" 플러그인 설정을 할 때에는 이 기능을 꺼두고, 모든 플러그인 설정이 끝난 후 다시 켜주는 것이 권장됩니다.

set runtimepath+=~/.vim/bundle/Vundle.vim
" rtp (runtimepath)에 Vundle의 경로를 추가합니다. Vundle은 해당 경로에서 작동합니다.

call vundle#begin()
" Vundle의 설정을 시작합니다.

Plugin 'VundleVim/Vundle.vim'
Plugin 'shougo/neocomplete.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'baskerville/bubblegum'
Plugin 'Rainbow-Parenthesis'


call vundle#end()
" Vundle의 설정을 종료합니다.

filetype plugin indent on
" Vim의 파일 타입 자동 감지 기능을 다시 켭니다.

" --------------- "
" Plugin Settings "
" --------------- "

function! NerdtreeInit()
  nmap <D-1> :NERDTreeToggle<cr>

  let NERDTreeShowHidden=1
  let g:NERDTreeDirArrowExpandable = '▸'
  let g:NERDTreeDirArrowCollapsible = '▾'
  let g:NERDTreeDirArrowCollapsed = '▸'
endfunction
call NerdtreeInit()

function! AirlineInit()
  let g:airline_theme='bubblegum'
  let g:airline_powerline_fonts=1
  let g:airline_left_sep= ''
  let g:airline_right_sep= ''

  let g:airline#extensions#tabline#enabled=1
  let g:airline#extensions#tablin#fnamemod= '.:t'
endfunction
call AirlineInit()
