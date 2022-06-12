set showmatch
set ignorecase
set hlsearch
set number
set tabstop=2
set smartindent
set shiftwidth=2
set cursorline
set belloff=all
set nobackup

filetype plugin indent on

syntax on
syntax enable

nnoremap 1 ^
nnoremap 2 $
nnoremap <silent><C-e> :NERDTreeToggle<CR>

call plug#begin("~/.vim/plugged")
 Plug 'dracula/vim'
 Plug 'scrooloose/nerdtree'
 Plug 'ryanoasis/vim-devicons'
call plug#end()

if(has("termguicolors"))
  set termguicolors
endif

colorscheme dracula