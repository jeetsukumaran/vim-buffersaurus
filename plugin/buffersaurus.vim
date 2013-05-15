""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

""  Buffersaurus
""
""  Vim document buffer indexing and navigation utility
""
""  Copyright 2010 Jeet Sukumaran.
""
""  This program is free software; you can redistribute it and/or modify
""  it under the terms of the GNU General Public License as published by
""  the Free Software Foundation; either version 3 of the License, or
""  (at your option) any later version.
""
""  This program is distributed in the hope that it will be useful,
""  but WITHOUT ANY WARRANTY; without even the implied warranty of
""  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
""  GNU General Public License <http://www.gnu.org/licenses/>
""  for more details.
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Reload and Compatibility Guard {{{1
" ============================================================================
" Reload protection.
if (exists('g:did_buffersaurus') && g:did_buffersaurus) || &cp || version < 700
    finish
endif
let g:did_buffersaurus = 1
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim
" 1}}}

" Public Command and Key Maps {{{1
" ==============================================================================
command! -bang -nargs=*                                           Bsgrep          :call buffersaurus#IndexPatterns(<q-args>, '<bang>', '')
command! -bang -nargs=0                                           Bstoc           :call buffersaurus#IndexTerms('<args>', '<bang>', 'fl')
command! -bang -nargs=1 -complete=customlist,buffersaurus#Complete_bsterm Bsterm          :call buffersaurus#IndexTerms('<args>', '<bang>', 'fl')
command! -nargs=0                                                 Bsopen          :call buffersaurus#OpenLastActiveCatalog()
command! -range -bang -nargs=0                                    Bsnext          :call buffersaurus#GotoEntry("n")
command! -range -bang -nargs=0                                    Bsprev          :call buffersaurus#GotoEntry("p")
command! -bang -nargs=0                                           Bsinfo          :call buffersaurus#ShowCatalogStatus('<bang>')
command!       -nargs=0                                           Bsreplace       :call buffersaurus#GlobalSearchAndReplace()

" (development/debugging) "
let g:buffersaurus_plugin_path = expand('<sfile>:p')
" command! -nargs=0               Bsreboot        :let g:did_buffersaurus = 0  | :execute("so " . g:buffersaurus_plugin_path)

nnoremap <silent><Leader>[ :<C-U>Bsprev<CR>
nnoremap <silent><Leader>] :<C-U>Bsnext<CR>
nnoremap <silent><Leader>\| :<C-U>Bsopen<CR>
" 1}}}

" Restore State {{{1
" ============================================================================
" restore options
let &cpo = s:save_cpo
" 1}}}

" vim:foldlevel=4:
