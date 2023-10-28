" ------------------- "
" Indentation Options "
" ------------------- "

set autoindent
" 새로운 줄을 생성할 때 현재 줄의 들여쓰기를 자동으로 다음 줄에도 적용합니다.

set expandtab
" 탭 문자 대신 공백 문자로 들여쓰기를 합니다. 예를 들면, 탭을 누르면 공백 2개 (tabstop에 따라 다름)로 변환됩니다.

set shiftround
" 들여쓰기와 탭 사이즈를 shiftwidth 값의 배수로 맞춥니다.

set tabstop=2
" 탭 문자를 2개의 공백 문자로 보여줍니다.

set softtabstop=2
" 탭 키를 누르거나 백스페이스 키를 누를 때 2개의 공백 문자로 들여쓰기 또는 들여쓰기를 제거합니다.

set shiftwidth=2
" 자동 들여쓰기 및 명령어를 사용하여 들여쓸 때 사용되는 공백 문자의 수입니다.

set smarttab
" 탭 키를 누를 때 들여쓰기 수준을 smartly 조정합니다. 처음 위치에서는 tabstop을 사용하고, 그 외의 경우 shiftwidth를 사용합니다.

set smartindent
" 다양한 프로그래밍 언어에 대한 기본 들여쓰기를 제공합니다.

set backspace=indent,eol,start
" backspace 키의 동작을 설정합니다.
" 이 설정을 통해 들여쓰기, 줄의 끝, 줄의 시작에서 백스페이스를 사용할 수 있게 됩니다.

" -------------- "
" Search Options "
" -------------- "

set hlsearch
" 검색 결과를 강조 표시합니다. 즉, 검색한 단어나 패턴이 문서 내에서 어디에 있는지 쉽게 확인할 수 있습니다.

set ignorecase
" 검색 시 대소문자를 무시하고 결과를 반환합니다.

set incsearch
" 검색어를 입력하는 즉시 일치하는 결과를 강조 표시하며, 사용자가 검색어를 입력할 때마다 즉시 갱신됩니다.

set smartcase
" 'ignorecase'가 활성화된 경우, 검색어에 대문자가 포함되어 있으면 대소문자를 구분하여 검색합니다.


" ---------------------- "
" Text Rendering Options "
" ---------------------- "

set encoding=utf-8
" Vim에서 사용되는 내부 문자 인코딩을 UTF-8로 설정합니다.

set termencoding=utf-8
" 터미널과 Vim 사이의 인코딩을 UTF-8로 설정합니다.

set linebreak
" 화면에 표시되는 텍스트가 윈도우의 너비를 넘어갈 때, 단어 사이에서만 줄바꿈을 합니다 (단어가 쪼개지지 않습니다).

set wrap
" 긴 행을 화면 너비에 맞게 자동으로 줄바꿈합니다.

set scrolloff=1
" 화면의 상단과 하단에서 1줄만큼의 여백을 유지하며 스크롤합니다. 즉, 커서가 화면의 가장자리에 있을 때도 항상 주변의 텍스트를 볼 수 있습니다.

set sidescrolloff=1
" 화면의 좌우 가장자리에서 1줄만큼의 여백을 유지하며 수평으로 스크롤합니다.

if has("syntax")
  syntax enable
  " Vim이 구문 강조 기능을 지원하는 경우 구문 강조를 활성화합니다.
endif


" ---------------------- "
" User Interface Options "
" ---------------------- "

set ruler
" 화면의 오른쪽 하단에 현재 커서 위치(행, 열)를 표시합니다.

set laststatus=2
" 항상 상태 표시 줄을 보여줍니다.

set showcmd
" 명령어를 입력할 때, 현재까지 입력된 명령어를 화면 하단에 표시합니다.

set wildmenu
" 명령 줄에서 파일 이름이나 명령어를 자동 완성할 때, 가능한 모든 선택 항목을 보여주는 횡단 메뉴를 사용합니다.

set background=dark
" Vim의 색상 설정을 어두운 배경에 적합하게 조정합니다.

" set term=xterm-256color
" 256색 터미널을 사용한다고 알립니다.

" set t_Co=256
" Vim에게 터미널이 256색을 지원한다고 알립니다.

set history=300
" Vim이 기억하는 명령어의 히스토리 수를 300개로 설정합니다.

set number
" 행 번호를 표시합니다.

" set relativenumber
" 현재 커서 위치를 기준으로 상대적인 행 번호를 표시합니다.

set cursorline
" 현재 커서가 있는 줄을 강조 표시합니다.

hi CursorLine   cterm=none ctermfg=none ctermbg=none
" 현재 커서가 위치한 줄의 강조 표시 설정을 변경합니다.

hi CursorLineNr cterm=bold ctermfg=darkblue ctermbg=none
" 현재 커서가 위치한 줄의 번호의 강조 표시 설정을 변경합니다.

hi LineNr       cterm=none ctermfg=darkgrey ctermbg=none
" 모든 줄 번호의 강조 표시 설정을 변경합니다.

hi MatchParen   ctermbg=none
" 괄호를 일치시킬 때의 강조 표시 설정을 변경합니다.

hi Pmenu        ctermbg=white ctermfg=black
" 팝업 메뉴의 강조 표시 설정을 변경합니다.

hi PmenuSel     ctermbg=darkgrey ctermfg=white
" 선택된 항목의 팝업 메뉴 강조 설정을 변경합니다.

set list listchars=tab:»\ ,trail:•
" 탭과 라인 끝에 있는 공백을 특별한 문자로 표시합니다.

set background=light
" Vim의 색상 설정을 밝은 배경에 적합하게 조정합니다.

set noerrorbells
" 오류 발생 시 벨 소리를 끕니.

set mouse=nicr
" 마우스 지원을 활성화하며, insert mode에서도 클릭과 드래그를 사용할 수 있게 합니다.

set title
" 터미널의 제목 표시 줄을 현재 편집 중인 파일의 이름으로 변경합니다.

let &t_SI = "\<Esc>]50;CursorShape=1\x7"
" Insert mode에서 커서 모양을 선 (I-beam)으로 변경합니다.

let &t_SR = "\<Esc>]50;CursorShape=2\x7"
" Replace mode에서 커서 모양을 밑줄 (underline)로 변경합니다.

let &t_EI = "\<Esc>]50;CursorShape=0\x7"
" Normal mode로 돌아왔을 때 커서 모양을 블록 (block)으로 변경합니다.

set ttimeout
" 키 시퀀스 감지 시간 제한을 1밀리초로 설정합니다. 이는 Vim이 키보드에서의 연속된 입력을 얼마나 빠르게 감지할지 결정합니다.

set ttyfast
" 현재 터미널 연결이 빠르다고 가정하며, 이로 인해 커서의 깜빡임 속도나 키 입력 감지 속도가 빨라집니다.


" -------------------- "
" Code Folding Options "
" -------------------- "

" set foldmethod=indent   " 코드의 들여쓰기 레벨에 따라 폴딩 구역을 결정합니다.
" set foldnestmax=5       " 최대 5 레벨까지 폴딩을 허용합니다.
" set foldcolumn=2        " 폴딩을 표시할 컬럼의 너비를 4칸으로 설정합니다.
" hi FoldColumn ctermfg=white ctermbg=none                  " 폴딩 컬럼의 강조 표시 설정을 변경합니다.
" hi Folded     ctermfg=blue ctermbg=none  " 폴딩된 코드의 강조 표시 설정을 변경합니다.

" --------------------- "
" Miscellaneous Options "
" --------------------- "

set langmap=ㅁㅠㅊㅇㄷㄹㅎㅗㅑㅓㅏㅣㅡㅜㅐㅔㅂㄱㄴㅅㅕㅍㅈㅌㅛㅋ;abcdefghijklmnopqrstuvwxyz
" 해당 설정은 키보드 레이아웃의 변경 없이 다른 언어의 문자와 키를 매핑합니다.
" 이 경우, 한글과 영어 알파벳 간의 매핑이 설정되어 있습니다.

set nocompatible
" Vim이 Vi 호환 모드에서 동작하는 것을 방지합니다.
" 이 설정을 사용하면 Vim의 고급 기능들을 사용할 수 있게 됩니다.

set autoread
" 다른 프로그램에서 파일이 변경될 경우 자동으로 해당 변경사항을 읽어옵니다.

"set nobackup
"set noswapfile
" 백업 파일과 스왑 파일 생성을 방지합니다.

set backupdir=~/.vim/backup/
set directory=~/.vim/swap/
set undodir=~/.vim/undo/
" 백업, 스왑, undo 파일의 저장 경로를 지정합니다.

" set spell
" set spellfile=~/.vim/spell/en.utf-8.add
" 철자 검사 기능을 활성화하고 철자 파일의 위치를 지정합니다.

set clipboard=unnamedplus
" 시스템의 클립보드를 Vim의 기본 클립보드로 사용하게 설정합니다.

" set viminfo=
" viminfo 파일을 생성합니다. Vim 세션 간의 정보를 저장하는 데 사용됩니다.