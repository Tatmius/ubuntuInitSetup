" Show matching brackets
set showmatch
" Ignore case when searching
set ignorecase
" Highlight search results
set hlsearch
" Show line numbers
set number
" Set tab width to 2 spaces
set tabstop=2
" Enable smart indent
set smartindent
" Set shift width to 2 spaces
set shiftwidth=2
" Highlight the current line
set cursorline
" Turn off the bell
set belloff=all
" Do not create backup files
set nobackup

" Enable filetype detection, plugins and indentation
filetype plugin indent on

" Enable syntax highlighting
syntax on
syntax enable

" --- Key mappings ---
" Map 1 to go to the beginning of the line
nnoremap 1 ^
" Map 2 to go to the end of the line
nnoremap 2 $
" Map Ctrl-e to toggle NERDTree
nnoremap <silent><C-e> :NERDTreeToggle<CR>

" --- Plugins ---
" Initialize vim-plug
call plug#begin("~/.vim/plugged")
 " Dracula theme
 Plug 'dracula/vim'
 " File explorer
 Plug 'scrooloose/nerdtree'
 " Icons for NERDTree
 Plug 'ryanoasis/vim-devicons'
call plug#end()

" Enable true color support
if(has("termguicolors"))
  set termguicolors
endif

" Set color scheme
colorscheme dracula
" Open NERDTree on startup
autocmd VimEnter * NERDTree