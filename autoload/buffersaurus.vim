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

" Compatibility Guard {{{1
" ============================================================================
let g:did_buffersaurus = 1
" avoid line continuation issues (see ':help user_41.txt')
let s:save_cpo = &cpo
set cpo&vim
" 1}}}

" Global Plugin Options {{{1
" =============================================================================
if !exists("g:buffersaurus_autodismiss_on_select")
    let g:buffersaurus_autodismiss_on_select = 1
endif
if !exists("g:buffersaurus_sort_regime")
    let g:buffersaurus_sort_regime = 'fl'
endif
if !exists("g:buffersaurus_show_context")
    let g:buffersaurus_show_context = 0
endif
if !exists("g:buffersaurus_context_size")
    let g:buffersaurus_context_size = [4, 4]
endif
if !exists("g:buffersaurus_viewport_split_policy")
    let g:buffersaurus_viewport_split_policy = "B"
endif
if !exists("g:buffersaurus_move_wrap")
    let g:buffersaurus_move_wrap  = 1
endif
if !exists("g:buffersaurus_flash_jumped_line")
    let g:buffersaurus_flash_jumped_line  = 1
endif
" 1}}}

" Script Data and Variables {{{1
" =============================================================================

"  Display column sizes {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" Display columns.
let s:buffersaurus_lnum_field_width = 6
let s:buffersaurus_entry_label_field_width = 4
" TODO: populate the following based on user setting, as well as allow
" abstraction from the actual Vim command (e.g., option "top" => "zt")
let s:buffersaurus_post_move_cmd = "normal! zz"

" 2}}}

" Split Modes {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
" Split modes are indicated by a single letter. Upper-case letters indicate
" that the SCREEN (i.e., the entire application "window" from the operating
" system's perspective) should be split, while lower-case letters indicate
" that the VIEWPORT (i.e., the "window" in Vim's terminology, referring to the
" various subpanels or splits within Vim) should be split.
" Split policy indicators and their corresponding modes are:
"   ``/`d`/`D'  : use default splitting mode
"   `n`/`N`     : NO split, use existing window.
"   `L`         : split SCREEN vertically, with new split on the left
"   `l`         : split VIEWPORT vertically, with new split on the left
"   `R`         : split SCREEN vertically, with new split on the right
"   `r`         : split VIEWPORT vertically, with new split on the right
"   `T`         : split SCREEN horizontally, with new split on the top
"   `t`         : split VIEWPORT horizontally, with new split on the top
"   `B`         : split SCREEN horizontally, with new split on the bottom
"   `b`         : split VIEWPORT horizontally, with new split on the bottom
let s:buffersaurus_viewport_split_modes = {
            \ "d"   : "sp",
            \ "D"   : "sp",
            \ "N"   : "buffer",
            \ "n"   : "buffer",
            \ "L"   : "topleft vert sbuffer",
            \ "l"   : "leftabove vert sbuffer",
            \ "R"   : "botright vert sbuffer",
            \ "r"   : "rightbelow vert sbuffer",
            \ "T"   : "topleft sbuffer",
            \ "t"   : "leftabove sbuffer",
            \ "B"   : "botright sbuffer",
            \ "b"   : "rightbelow sbuffer",
            \ }
" 2}}}

" Catalog Sort Regimes {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
let s:buffersaurus_catalog_sort_regimes = ['fl', 'fa', 'a']
let s:buffersaurus_catalog_sort_regime_desc = {
            \ 'fl' : ["F(L#)", "by filepath, then by line number"],
            \ 'fa' : ["F(A-Z)", "by filepath, then by line text"],
            \ 'a'  : ["A-Z", "by line text"],
            \ }
" 2}}}

" 1}}}

" Utilities {{{1
" ==============================================================================

" Text Formatting {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
function! s:Format_AlignLeft(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return a:text . l:fill
endfunction

function! s:Format_AlignRight(text, width, fill_char)
    let l:fill = repeat(a:fill_char, a:width-len(a:text))
    return l:fill . a:text
endfunction

function! s:Format_Time(secs)
    if exists("*strftime")
        return strftime("%Y-%m-%d %H:%M:%S", a:secs)
    else
        return (localtime() - a:secs) . " secs ago"
    endif
endfunction

function! s:Format_EscapedFilename(file)
  if exists('*fnameescape')
    return fnameescape(a:file)
  else
    return escape(a:file," \t\n*?[{`$\\%#'\"|!<")
  endif
endfunction

" trunc: -1 = truncate left, 0 = no truncate, +1 = truncate right
function! s:Format_Truncate(str, max_len, trunc)
    if len(a:str) > a:max_len
        if a:trunc > 0
            return strpart(a:str, a:max_len - 4) . " ..."
        elseif a:trunc < 0
            return '... ' . strpart(a:str, len(a:str) - a:max_len + 4)
        endif
    else
        return a:str
    endif
endfunction

" Pads/truncates text to fit a given width.
" align: -1/0 = align left, 0 = no align, 1 = align right
" trunc: -1 = truncate left, 0 = no truncate, +1 = truncate right
function! s:Format_Fill(str, width, align, trunc)
    let l:prepped = a:str
    if a:trunc != 0
        let l:prepped = s:Format_Truncate(a:str, a:width, a:trunc)
    endif
    if len(l:prepped) < a:width
        if a:align > 0
            let l:prepped = s:Format_AlignRight(l:prepped, a:width, " ")
        elseif a:align < 0
            let l:prepped = s:Format_AlignLeft(l:prepped, a:width, " ")
        endif
    endif
    return l:prepped
endfunction

" 2}}}

" Messaging {{{2
" ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function! s:NewMessenger(name)

    " allocate a new pseudo-object
    let messenger = {}
    let messenger["name"] = a:name
    if empty(a:name)
        let messenger["title"] = "buffersaurus"
    else
        let messenger["title"] = "buffersaurus (" . messenger["name"] . ")"
    endif

    function! messenger.format_message(leader, msg) dict
        return self.title . ": " . a:leader.a:msg
    endfunction

    function! messenger.format_exception( msg) dict
        return a:msg
    endfunction

    function! messenger.send_error(msg) dict
        redraw
        echohl ErrorMsg
        echomsg self.format_message("[ERROR] ", a:msg)
        echohl None
    endfunction

    function! messenger.send_warning(msg) dict
        redraw
        echohl WarningMsg
        echomsg self.format_message("[WARNING] ", a:msg)
        echohl None
    endfunction

    function! messenger.send_status(msg) dict
        redraw
        echohl None
        echomsg self.format_message("", a:msg)
    endfunction

    function! messenger.send_info(msg) dict
        redraw
        echohl None
        echo self.format_message("", a:msg)
    endfunction

    return messenger

endfunction
" 2}}}

" 1}}}

" BufferManager {{{1
" ==============================================================================

" Creates the script-wide buffer/window manager.
function! s:NewBufferManager()

    " initialize
    let buffer_manager = {}

    " Returns a list of all existing buffer numbers, excluding unlisted ones
    " unless `include_unlisted` is non-empty.
    function! buffer_manager.get_buf_nums(include_unlisted)
        let l:buf_num_list = []
        for l:idx in range(1, bufnr("$"))
            if bufexists(l:idx) && (empty(a:include_unlisted) || buflisted(l:idx))
                call add(l:buf_num_list, l:idx)
            endif
        endfor
        return l:buf_num_list
    endfunction

    " Returns a list of all existing buffer names, excluding unlisted ones
    " unless `include_unlisted` is non-empty.
    function! buffer_manager.get_buf_names(include_unlisted, expand_modifiers)
        let l:buf_name_list = []
        for l:idx in range(1, bufnr("$"))
            if bufexists(l:idx) && (empty(!a:include_unlisted) || buflisted(l:idx))
                call add(l:buf_name_list, expand(bufname(l:idx).a:expand_modifiers))
            endif
        endfor
        return l:buf_name_list
    endfunction

    " Searches for all windows that have a window-scoped variable `varname`
    " with value that matches the expression `expr`. Returns list of window
    " numbers that meet the criterion.
    function! buffer_manager.find_windows_with_var(varname, expr)
        let l:results = []
        for l:wni in range(1, winnr("$"))
            let l:wvar = getwinvar(l:wni, "")
            if empty(a:varname)
                call add(l:results, l:wni)
            elseif has_key(l:wvar, a:varname) && l:wvar[a:varname] =~ a:expr
                call add(l:results, l:wni)
            endif
        endfor
        return l:results
    endfunction

    " Searches for all buffers that have a buffer-scoped variable `varname`
    " with value that matches the expression `expr`. Returns list of buffer
    " numbers that meet the criterion.
    function! buffer_manager.find_buffers_with_var(varname, expr)
        let l:results = []
        for l:bni in range(1, bufnr("$"))
            if !bufexists(l:bni)
                continue
            endif
            let l:bvar = getbufvar(l:bni, "")
            if empty(a:varname)
                call add(l:results, l:bni)
            elseif has_key(l:bvar, a:varname) && l:bvar[a:varname] =~ a:expr
                call add(l:results, l:bni)
            endif
        endfor
        return l:results
    endfunction

    " Returns a dictionary with the buffer number as keys (if `key` is empty)
    " and the parsed information regarding each buffer as values. If `key` is
    " given (e.g. key='num'; key='name', key='filepath') then that field will
    " be used as the dictionary keys instead.
    function! buffer_manager.get_buffers_info(key) dict
        if empty(a:key)
            let l:key = "num"
        else
            let l:key = a:key
        endif
        redir => buffers_output
        execute('silent ls')
        redir END
        let l:buffers_info = {}
        let l:buffers_output_rows = split(l:buffers_output, "\n")
        for l:buffers_output_row in l:buffers_output_rows
            let l:parts = matchlist(l:buffers_output_row, '^\s*\(\d\+\)\(.....\) "\(.*\)"\s\+line \d\+$')
            let l:info = {}
            let l:info["num"] = l:parts[1] + 0
            if l:parts[2][0] == "u"
                let l:info["is_unlisted"] = 1
                let l:info["is_listed"] = 0
            else
                let l:info["is_unlisted"] = 0
                let l:info["is_listed"] = 1
            endif
            if l:parts[2][1] == "%"
                let l:info["is_current"] = 1
                let l:info["is_alternate"] = 0
            elseif l:parts[2][1] == "#"
                let l:info["is_current"] = 0
                let l:info["is_alternate"] = 1
            else
                let l:info["is_current"] = 0
                let l:info["is_alternate"] = 0
            endif
            if l:parts[2][2] == "a"
                let l:info["is_active"] = 1
                let l:info["is_loaded"] = 1
                let l:info["is_visible"] = 1
            elseif l:parts[2][2] == "h"
                let l:info["is_active"] = 0
                let l:info["is_loaded"] = 1
                let l:info["is_visible"] = 0
            else
                let l:info["is_active"] = 0
                let l:info["is_loaded"] = 0
                let l:info["is_visible"] = 0
            endif
            if l:parts[2][3] == "-"
                let l:info["is_modifiable"] = 0
                let l:info["is_readonly"] = 0
            elseif l:parts[2][3] == "="
                let l:info["is_modifiable"] = 1
                let l:info["is_readonly"] = 1
            else
                let l:info["is_modifiable"] = 1
                let l:info["is_readonly"] = 0
            endif
            if l:parts[2][4] == "+"
                let l:info["is_modified"] = 1
                let l:info["is_readerror"] = 0
            elseif l:parts[2][4] == "x"
                let l:info["is_modified"] = 0
                let l:info["is_readerror"] = 0
            else
                let l:info["is_modified"] = 0
                let l:info["is_readerror"] = 0
            endif
            let l:info["name"] = parts[3]
            let l:info["filepath"] = fnamemodify(l:info["name"], ":p")
            if !has_key(l:info, l:key)
                throw s:_buffersaurus_messenger.format_exception("Invalid key requested: '" . l:key . "'")
            endif
            let l:buffers_info[l:info[l:key]] = l:info
        endfor
        return l:buffers_info
    endfunction

    " Returns split mode to use for a new Buffersaurus viewport.
    function! buffer_manager.get_split_mode() dict
        if has_key(s:buffersaurus_viewport_split_modes, g:buffersaurus_viewport_split_policy)
            return s:buffersaurus_viewport_split_modes[g:buffersaurus_viewport_split_policy]
        else
            call s:_buffersaurus_messenger.send_error("Unrecognized split mode specified by 'g:buffersaurus_viewport_split_policy': " . g:buffersaurus_viewport_split_policy)
        endif
    endfunction

    " Detect filetype. From the 'taglist' plugin.
    " Copyright (C) 2002-2007 Yegappan Lakshmanan
    function! buffer_manager.detect_filetype(fname)
        " Ignore the filetype autocommands
        let old_eventignore = &eventignore
        set eventignore=FileType
        " Save the 'filetype', as this will be changed temporarily
        let old_filetype = &filetype
        " Run the filetypedetect group of autocommands to determine
        " the filetype
        exe 'doautocmd filetypedetect BufRead ' . a:fname
        " Save the detected filetype
        let ftype = &filetype
        " Restore the previous state
        let &filetype = old_filetype
        let &eventignore = old_eventignore
        return ftype
    endfunction

    return buffer_manager
endfunction

" 1}}}

" Indexer {{{1
" =============================================================================

" create and return the an Indexer pseudo-object, which is a Catalog factory
function! s:NewIndexer()

    " create/clear
    let indexer = {}

    " set up filetype vocabulary
    let indexer["filetype_term_map"] = {
        \   'bib'         : '^@\w\+\s*{\s*\zs\S\{-}\ze\s*,'
        \ , 'c'           : '^[[:alnum:]#].*'
        \ , 'cpp'         : '^[[:alnum:]#].*'
        \ , 'html'        : '\(<h\d.\{-}</h\d>\|<\(html\|head\|body\|div\|script\|a\s\+name=\).\{-}>\|<.\{-}\<id=.\{-}>\)'
        \ , 'java'        : '^\s*\(\(package\|import\|private\|public\|protected\|void\|int\|boolean\)\s\+\|\u\).*'
        \ , 'javascript'  : '^\(var\s\+.\{-}\|\s*\w\+\s*:\s*\S.\{-}[,{]\)\s*$'
        \ , 'perl'        : '^\([$%@]\|\s*\(use\|sub\)\>\).*'
        \ , 'php'         : '^\(\w\|\s*\(class\|function\|var\|require\w*\|include\w*\)\>\).*'
        \ , 'python'      : '^\s*\(import\|class\|def\)\s\+[A-Za-z_]\i\+(.*'
        \ , 'ruby'        : '\C^\(if\>\|\s*\(class\|module\|def\|require\|private\|public\|protected\|module_functon\|alias\|attr\(_reader\|_writer\|_accessor\)\?\)\>\|\s*[[:upper:]_]\+\s*=\).*'
        \ , 'scheme'      : '^\s*(define.*'
        \ , 'sh'          : '^\s*\(\(export\|function\|while\|case\|if\)\>\|\w\+\s*()\s*{\).*'
        \ , 'tcl'         : '^\s*\(source\|proc\)\>.*'
        \ , 'tex'         : '\C\\\(label\|\(sub\)*\(section\|paragraph\|part\)\)\>.*'
        \ , 'vim'         : '\C^\(fu\%[nction]\|com\%[mand]\|if\|wh\%[ile]\)\>.*'
        \ }
    if exists("g:buffersaurus_filetype_term_map")
        " User-defined patterns have higher priority
        call extend(indexer["filetype_term_map"], g:buffersaurus_filetype_term_map, 'force')
    endif

    " set up element vocabulary
    let indexer["element_term_map"] = {
        \   'PyClass'     : '^\s*class\s\+[A-Za-z_]\i\+(.*'
        \ , 'PyDef'       : '^\s*def\s\+[A-Za-z_]\i\+(.*'
        \ , 'VimFunction' : '^\C[:[:space:]]*fu\%[nction]\>!\=\s*\S\+\s*('
        \ , 'VimMapping'  : '^\C[:[:space:]]*[nvxsoilc]\=\(\%(nore\|un\)\=map\>\|mapclear\)\>'
        \ , 'VimCommand'  : '^\C[:[:space:]]*com\%[mand]\>'
        \ , 'CppClass'    : '^\s*\(\(public\|private\|protected\)\s*:\)\=\s*\(class\|struct\)\s\+\w\+\>\(\s*;\)\@!'
        \ , 'CppTypedef'  : '^\s*\(\(public\|private\|protected\)\s*:\)\=\s*typedef\>'
        \ , 'CppEnum'     : '^\s*\(\(public\|private\|protected\)\s*:\)\=\s*enum\>'
        \ , 'CppTemplate' : '^\s*template\($\|<\)'
        \ , 'CppPreproc'  : '^#'
        \ }

    if exists("g:buffersaurus_element_term_map")
        " User-defined patterns have higher priority
        call extend(indexer["element_term_map"], g:buffersaurus_element_term_map, 'force')
    endif

    " Indexes all files given by the list `filepaths` for the regular
    " expression(s) defined in the element vocabulary for `term_id`. If
    " `term_id` is empty, the default filetype pattern is used. If
    " `filepaths` is empty, then all
    " listed buffers are indexed.
    function! indexer.index_terms(filepaths, term_id, sort_regime) dict
        let l:old_hidden = &hidden
        set hidden
        let l:worklist = self.ensure_buffers(a:filepaths)
        let l:desc = "Catalog of"
        if !empty(a:term_id)
            let l:desc .= "'" . a:term_id . "'"
        endif
        let l:desc .= " terms"
        if empty(a:filepaths)
            let l:desc .= " (in all buffers)"
        elseif len(a:filepaths) == 1
            let l:desc .= ' (in "' . expand(a:filepaths[0]) . '")'
        else
            let l:desc .= " (in multiple files)"
        endif
        let catalog = s:NewCatalog("term", l:desc, a:sort_regime)
        for buf_ref in l:worklist
            let l:pattern = self.get_buffer_term_pattern(buf_ref, a:term_id)
            call catalog.map_buffer(buf_ref, l:pattern)
        endfor
        let &hidden=l:old_hidden
        return catalog
    endfunction

    " Indexes all files given by the list `filepaths` for tags.
    function! indexer.index_tags(filepaths) dict
        let l:old_hidden = &hidden
        set hidden
        let l:worklist = self.ensure_buffers(a:filepaths)
        let l:desc = "Catalog of tags"
        if empty(a:filepaths)
            let l:desc .= " (in all buffers)"
        elseif len(a:filepaths) == 1
            let l:desc .= ' (in "' . a:filepaths[0] . '")'
        else
            let l:desc .= " (in multiple files)"
        endif
        let catalog = s:NewTagCatalog("tag", l:desc)
        for buf_ref in l:worklist
            call catalog.map_buffer(buf_ref)
        endfor
        let &hidden=l:old_hidden
        return catalog
    endfunction

    " Indexes all files given by the list `filepaths` for the regular
    " expression given by `pattern`. If `filepaths` is empty, then all
    " listed buffers are indexed.
    function! indexer.index_pattern(filepaths, pattern, sort_regime) dict
        let l:old_hidden = &hidden
        set hidden
        let l:worklist = self.ensure_buffers(a:filepaths)

        let l:desc = "Catalog of pattern '" . a:pattern . "'"
        if empty(a:filepaths)
            let l:desc .= " (in all buffers)"
        elseif len(a:filepaths) == 1
            let l:desc .= ' (in "' . a:filepaths[0] . '")'
        else
            let l:desc .= " (in multiple files)"
        endif
        let catalog = s:NewCatalog("pattern", l:desc, a:sort_regime)
        for buf_ref in l:worklist
            call catalog.map_buffer(buf_ref, a:pattern)
        endfor
        let &hidden=l:old_hidden
        return catalog
    endfunction

    " returns pattern to be used when indexing terms for a particular buffer
    function! indexer.get_buffer_term_pattern(buf_num, term_id) dict
        let l:pattern = ""
        if !empty(a:term_id)
            try
                let l:term_id_matches = filter(keys(self.element_term_map),
                            \ "v:val =~ '" . a:term_id . ".*'")
            catch /E15:/
                throw s:_buffersaurus_messenger.format_exception("Invalid name: '" . a:term_id . "': ".v:exception)
            endtry
            if len(l:term_id_matches) > 1
                throw s:_buffersaurus_messenger.format_exception("Multiple matches for index pattern name starting with '".a:term_id."': ".join(l:term_id_matches, ", "))
            elseif len(l:term_id_matches) == 0
                throw s:_buffersaurus_messenger.format_exception("Index pattern with name '" . a:term_id . "' not found")
            end
            let l:pattern = self.element_term_map[l:term_id_matches[0]]
        else
            let l:pattern = get(self.filetype_term_map, getbufvar(a:buf_num, "&filetype"), "")
            if empty(l:pattern)
                let l:pattern = '^\w.*'
            endif
        endif
        return l:pattern
    endfunction

    " Given a list of buffer references, `buf_refs` this will ensure than
    " all the files/buffers are loaded and return a list of the buffer names.
    " If `buf_refs` is empty, then all listed buffers are loaded.
    function! indexer.ensure_buffers(buf_refs)
        let l:cur_pos = getpos(".")
        let l:cur_buf_num = bufnr("%")
        if empty(a:buf_refs)
            let l:req_buf_list = s:_buffersaurus_buffer_manager.get_buf_nums(0)
        else
            let l:req_buf_list = []
            for l:buf_ref in a:buf_refs
                if type(l:buf_ref) == type(0)
                    let l:buf_num = l:buf_ref
                else
                    let l:buf_num = bufnr(l:buf_ref)
                endif
                call add(l:req_buf_list, l:buf_num)
            endfor
        endif
        let l:work_list = []
        for l:buf_num in l:req_buf_list
            if !bufexists(l:buf_num)
                " throw s:_buffersaurus_messenger.format_exception('Buffer does not exist: "' . l:buf_num . '"')
            elseif !buflisted(l:buf_num)
                " call s:_buffersaurus_messenger.send_warning('Skipping unlisted buffer: [' . l:buf_num . '] "' . bufname(l:buf_num) . '"')
            elseif !empty(getbufvar(l:buf_num, "is_buffersaurus_buffer"))
                " call s:_buffersaurus_messenger.send_warning('Skipping buffersaurus buffer: [' . l:buf_num . '] "' . bufname(l:buf_num) . '"')
            else
                call add(l:work_list, l:buf_num)
                if !bufloaded(l:buf_num)
                    execute("silent keepjumps keepalt buffer " . l:buf_num)
                endif
            endif
        endfor
        " execute("silent keepjumps keepalt e ".l:cur_buf_name)
        execute("silent keepjumps keepalt buffer ".l:cur_buf_num)
        call setpos(".", l:cur_pos)
        return l:work_list
    endfunction

    return indexer

endfunction

" 1}}}

" Catalog {{{1
" ==============================================================================

" The main workhorse pseudo-object is created here ...
function! s:NewCatalog(catalog_domain, catalog_desc, default_sort)

    " increment catalog counter, creating it if it does not already exist
    if !exists("s:buffersaurus_catalog_count")
        let s:buffersaurus_catalog_count = 1
    else
        let s:buffersaurus_catalog_count += 1
    endif

    " initialize fields
    let l:var_name = a:catalog_domain
    let catalog = {
                \ "catalog_id"          : s:buffersaurus_catalog_count,
                \ "catalog_domain"      : a:catalog_domain,
                \ "catalog_desc"        : a:catalog_desc,
                \ "show_context"        : exists("g:buffersaurus_" . l:var_name . "_show_context") ? g:buffersaurus_{l:var_name}_show_context : g:buffersaurus_show_context,
                \ "context_size"        : exists("g:buffersaurus_" . l:var_name . "_context_size") ? g:buffersaurus_{l:var_name}_context_size : g:buffersaurus_context_size,
                \ "search_profile"      : [],
                \ "matched_lines"       : [],
                \ "search_history"      : [],
                \ "searched_files"      : {},
                \ "last_search_time"    : 0,
                \ "last_search_hits"    : 0,
                \ "entry_indexes"       : [],
                \ "entry_labels"        : {},
                \ "last_compile_time"   : 0,
                \ "sort_regime"         : empty(a:default_sort) ? g:buffersaurus_sort_regime : a:default_sort,
                \}

    " sets the display context
    function! catalog.set_context_size(...) dict
        let l:context = self.context_size
        for l:carg in range(a:0)
            if a:000[l:carg] == ""
                return
            endif
            if a:000[l:carg] =~ '\d\+'
                let l:context[0] = str2nr(a:000[l:carg])
                let l:context[1] = str2nr(a:000[l:carg])
            elseif a:000[l:carg] =~ '-\d\+'
                let l:context[0] = str2nr(a:000[l:carg][1:])
            elseif a:000[l:carg] =! '+\d\+'
                let l:context[1] = str2nr(a:000[l:carg][1:])
            else
                call s:_buffersaurus_messenger.send_error("Invalid argument ".l:carg.": ".a:000[l:carg])
                return
            endif
        endfor
        let self.context_size = l:context
        return self.context_size
    endfunction

    " determine whether or not context should be shown
    function! catalog.is_show_context() dict
        if !self.show_context
            return 0
        else
            if self.context_size[0] == 0 && self.context_size[1] == 0
                return 0
            else
                return 1
            endif
        endif
    endfunction

    " clears all items
    function! catalog.clear() dict
        let self.matched_lines = []
        let self.search_history = []
        let self.searched_files = {}
        let self.last_search_time = 0
        let self.last_search_hits = 0
        let self.entry_indexes = []
        let self.entry_labels = {}
        let self.last_compile_time = 0
    endfunction

    " number of entries in the catalog
    function! catalog.size() dict
        return len(self.matched_lines)
    endfunction

    " carry out search given in the search profile
    function catalog.build(...) dict
        call self.clear()
        if a:0 >= 1
            let self.search_profile = a:1
        endif
        for l:search in self.search_profile
            call self.map_buffer(l:search.filepath, l:search.pattern)
        endfor
    endfunction

    " repeat last search
    function catalog.rebuild() dict
        if empty(self.search_history)
            raise s:_buffersaurus_messenger.format_exception("Search history is empty")
        endif
        let self.search_profile = []
        for search in self.search_history
            call add(self.search_profile, search)
        endfor
        call self.clear()
        call self.build()
        call self.compile_entry_indexes()
    endfunction

    " index all occurrences of `pattern` in buffer `buf_ref`
    function! catalog.map_buffer(buf_ref, pattern) dict
        if type(a:buf_ref) == type(0)
            let l:buf_num = a:buf_ref
            let l:buf_name = bufname(l:buf_num)
        else
            let l:buf_name = expand(a:buf_ref)
            let l:buf_num = bufnr(l:buf_name) + 0
        endif
        let l:filepath = fnamemodify(expand(l:buf_name), ":p")
        let l:buf_search_log = {
                    \ "buf_name" : l:buf_name,
                    \ 'buf_num': l:buf_num,
                    \ "filepath" : l:filepath,
                    \ "pattern" : a:pattern,
                    \ "num_lines_searched" : 0,
                    \ "num_lines_matched" : 0,
                    \ "last_searched" : 0,
                    \ }
        let self.last_search_hits = 0
        let l:lnum = 1
        while 1
            let l:buf_lines = getbufline(l:buf_num, l:lnum)
            if empty(l:buf_lines)
                break
            endif
            let l:pos = match(l:buf_lines[0], a:pattern)
            let l:buf_search_log["num_lines_searched"] += 1
            if l:pos >= 0
                let self.last_search_hits += 1
                let l:search_order = len(self.matched_lines) + 1
                call add(self.matched_lines, {
                            \ 'buf_name': l:buf_name,
                            \ 'buf_num': l:buf_num,
                            \ 'filepath' : l:filepath,
                            \ 'lnum': l:lnum,
                            \ 'col': l:pos + 1,
                            \ 'sort_text' : substitute(l:buf_lines[0], '^\s*', '', 'g'),
                            \ 'search_order' : l:search_order,
                            \ 'entry_label' : string(l:search_order),
                            \ })
                let l:buf_search_log["num_lines_matched"] += 1
            endif
            let l:lnum += 1
        endwhile
        let l:buf_search_log["last_searched"] = localtime()
        let self.last_search_time = l:buf_search_log["last_searched"]
        call add(self.search_history, l:buf_search_log)
        if has_key(self.searched_files, l:filepath)
            let self.searched_files[l:filepath] += self.last_search_hits
        else
            let self.searched_files[l:filepath] = self.last_search_hits
        endif
    endfunction

    " open the catalog for viewing
    function! catalog.open() dict
        if !has_key(self, "catalog_viewer") || empty(self.catalog_viewer)
            let self["catalog_viewer"] = s:NewCatalogViewer(self, self.catalog_desc)
        endif
        call self.catalog_viewer.open()
        return self.catalog_viewer
    endfunction

    " returns indexes of matched lines, compiling them if
    " needed
    function! catalog.get_index_groups() dict
        if self.last_compile_time < self.last_search_time
            call self.compile_entry_indexes()
        endif
        return self.entry_indexes
    endfunction

    " returns true if sort regime dictates that indexes are grouped
    function! catalog.is_sort_grouped() dict
        if self.sort_regime == 'a'
            return 0
        else
            return 1
        endif
    endfunction

    " apply a sort regime
    function! catalog.apply_sort(regime) dict
        if index(s:buffersaurus_catalog_sort_regimes, a:regime) == - 1
            throw s:_buffersaurus_messenger.format_exception("Unrecognized sort regime: '" . a:regime . "'")
        endif
        let self.sort_regime = a:regime
        return self.compile_entry_indexes()
    endfunction

    " cycle through sort regimes
    function! catalog.cycle_sort_regime() dict
        let l:cur_regime = index(s:buffersaurus_catalog_sort_regimes, self.sort_regime)
        let l:cur_regime += 1
        if l:cur_regime < 0 || l:cur_regime >= len(s:buffersaurus_catalog_sort_regimes)
            let self.sort_regime = s:buffersaurus_catalog_sort_regimes[0]
        else
            let self.sort_regime = s:buffersaurus_catalog_sort_regimes[l:cur_regime]
        endif
        return self.compile_entry_indexes()
    endfunction

    " compiles matches into index
    function! catalog.compile_entry_indexes() dict
        let self.entry_indexes = []
        let self.entry_labels = {}
        if self.sort_regime == 'fl'
            call sort(self.matched_lines, "s:compare_matched_lines_fl")
        elseif self.sort_regime == 'fa'
            call sort(self.matched_lines, "s:compare_matched_lines_fa")
        elseif self.sort_regime == 'a'
            call sort(self.matched_lines, "s:compare_matched_lines_a")
        else
            throw s:_buffersaurus_messenger.format_exception("Unrecognized sort regime: '" . self.sort_regime . "'")
        endif
        if self.sort_regime == 'a'
            call add(self.entry_indexes, ['', []])
            for l:matched_line_idx in range(0, len(self.matched_lines) - 1)
                call add(self.entry_indexes[-1][1], l:matched_line_idx)
                let self.entry_labels[l:matched_line_idx] = self.matched_lines[l:matched_line_idx].entry_label
            endfor
        else
            let l:cur_group = ""
            for l:matched_line_idx in range(0, len(self.matched_lines) - 1)
                if self.matched_lines[l:matched_line_idx].filepath != l:cur_group
                    let l:cur_group = self.matched_lines[l:matched_line_idx].filepath
                    call add(self.entry_indexes, [l:cur_group, []])
                endif
                call add(self.entry_indexes[-1][1], l:matched_line_idx)
                let self.entry_labels[l:matched_line_idx] = self.matched_lines[l:matched_line_idx].entry_label
            endfor
        endif
        let self.last_compile_time = localtime()
        return self.entry_indexes
    endfunction

    " Describes catalog status.
    function! catalog.describe() dict
        call s:_buffersaurus_messenger.send_info(self.format_status_message() . " (sorted " . self.format_sort_status() . ")")
    endfunction

    " Describes catalog status in detail.
    function! catalog.describe_detail() dict
        echon self.format_status_message() . ":\n"
        let l:rows = []
        let l:header = self.format_describe_detail_row([
                    \ "#",
                    \ "File",
                    \ "Found",
                    \ "Total",
                    \ "Pattern",
                    \])
        echohl Title
        echo l:header "\n"
        echohl None
        for search_log in self.search_history
            let l:row = self.format_describe_detail_row([
                        \ bufnr(search_log.filepath),
                        \ bufname(search_log.filepath),
                        \ string(search_log.num_lines_matched),
                        \ string(search_log.num_lines_searched),
                        \ search_log.pattern,
                        \])
            call add(l:rows, row)
        endfor
        echon join(l:rows, "\n")
    endfunction

    " Formats a single row in the detail catalog description
    function! catalog.format_describe_detail_row(fields)
        let l:row = join([
                    \ s:Format_Fill(a:fields[0], 3, 2, 1),
                    \ s:Format_Fill(a:fields[1], ((&columns - 14) / 3), -1, -1),
                    \ s:Format_Fill(a:fields[2], 6, 1, 0),
                    \ s:Format_Fill(a:fields[3], 6, 1, 0),
                    \ a:fields[4],
                    \ ], "  ")
        return l:row
    endfunction

    " Composes message indicating size of catalog.
    function! catalog.format_status_message() dict
        let l:message = ""
        let catalog_size = self.size()
        let l:num_searched_files = len(self.searched_files)
        if catalog_size == 0
            let l:message .= "no entries"
        elseif catalog_size == 1
            let l:message .= "1 entry"
        else
            let l:message .= catalog_size . " entries"
        endif
        let l:message .= " in "
        if l:num_searched_files == 0
            let l:message .= "no files"
        elseif l:num_searched_files == 1
            let l:message .= "1 file"
        else
            let l:message .= l:num_searched_files . " files"
        endif
        return l:message
    endfunction

    " Composes message indicating sort regime of catalog.
    function! catalog.format_sort_status() dict
        let l:message = get(s:buffersaurus_catalog_sort_regime_desc, self.sort_regime, ["??", "in unspecified order"])[1]
        return l:message
    endfunction

    " return pseudo-object
    return catalog

endfunction

" comparison function used for sorting matched lines: sort first by
" filepath, then by line number
function! s:compare_matched_lines_fl(m1, m2)
    if a:m1.filepath < a:m2.filepath
        return -1
    elseif a:m1.filepath > a:m2.filepath
        return 1
    else
        if a:m1.lnum < a:m2.lnum
            return -1
        elseif a:m1.lnum > a:m2.lnum
            return 1
        else
            return 0
        endif
    endif
endfunction

" comparison function used for sorting matched lines: sort first by
" filepath, then by text
function! s:compare_matched_lines_fa(m1, m2)
    if a:m1.filepath < a:m2.filepath
        return -1
    elseif a:m1.filepath > a:m2.filepath
        return 1
    else
        return s:compare_matched_lines_a(a:m1, a:m2)
    endif
endfunction

" comparison function used for sorting matched lines: sort by
" text
function! s:compare_matched_lines_a(m1, m2)
    if a:m1.sort_text < a:m2.sort_text
        return -1
    elseif a:m1.sort_text > a:m2.sort_text
        return 1
    else
        return 0
    endif
endfunction

" 1}}}

" NewMarksCatalog {{{1
" ============================================================================

" The main workhorse pseudo-object is created here ...
function! s:NewMarksCatalog(catalog_domain, catalog_desc)
    let catalog = s:NewCatalog(a:catalog_domain, a:catalog_desc, "")

    " Returns dictionary of marks. If `global` is true then upper-case marks
    " will be included as well. Otherwise, only lower-case marks.
    function! catalog.get_mark_list(global) dict
        if !empty(a:global) && a:global == "!"
            let l:marks = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        else
            let l:marks = "abcdefghijklmnopqrstuvwxyz"
        endif
        let l:markstr = ""
        try
            redir => l:markstr | execute("silent marks ".l:marks) | redir END
        catch /E283:/
            return {}
        endtry
        let l:markstr_rows = split(l:markstr, "\n")
        let l:mark_list = []
        for l:row in l:markstr_rows[1:]
            let l:mark_parts = matchlist(l:row, '^\s\{-1,}\(\a\)\s\{-1,}\(\d\{-1,}\)\s\{-1,}\(\d\{-1,}\)\s\{-1,}\(.*\)$')
            if len(l:mark_parts) < 4
                continue
            endif
            if l:mark_parts[1] =~ '[a-z]'
                let l:fpath = expand("%:p")
            else
                let l:fpath = l:mark_parts[4]
            endif
            call add(l:mark_list, [l:mark_parts[1], l:fpath, str2nr(l:mark_parts[2]), str2nr(l:mark_parts[3])])
        endfor
        return l:mark_list
    endfunction

    return catalog
endfunction

" 1}}}

" CatalogViewer {{{1
" ==============================================================================

" Display the catalog.
function! s:NewCatalogViewer(catalog, desc, ...)

    " abort if catalog is empty
    " if len(a:catalog.matched_lines) == 0
    "     throw s:_buffersaurus_messenger.format_exception("CatalogViewer() called on empty catalog")
    " endif

    " initialize
    let catalog_viewer = {}

    " Initialize object state.
    let catalog_viewer["catalog"] = a:catalog
    let catalog_viewer["description"] = a:desc
    let catalog_viewer["buf_num"] = -1
    let catalog_viewer["buf_name"] = "[[buffersaurus]]"
    let catalog_viewer["title"] = "buffersaurus"
    let l:buffersaurus_bufs = s:_buffersaurus_buffer_manager.find_buffers_with_var("is_buffersaurus_buffer", 1)
    if len(l:buffersaurus_bufs) > 0
        let catalog_viewer["buf_num"] = l:buffersaurus_bufs[0]
    endif
    let catalog_viewer["jump_map"] = {}
    let catalog_viewer["split_mode"] = s:_buffersaurus_buffer_manager.get_split_mode()
    let catalog_viewer["filter_regime"] = 0
    let catalog_viewer["filter_pattern"] = ""
    let catalog_viewer["match_highlight_id"] = 0

    " Opens the buffer for viewing, creating it if needed. If non-empty first
    " argument is given, forces re-rendering of buffer.
    function! catalog_viewer.open(...) dict
        " get buffer number of the catalog view buffer, creating it if neccessary
        if self.buf_num < 0 || !bufexists(self.buf_num)
            " create and render a new buffer
            call self.create_buffer()
        else
            " buffer exists: activate a viewport on it according to the
            " spawning mode, re-rendering the buffer with the catalog if needed
            call self.activate_viewport()
            if b:buffersaurus_last_render_time < self.catalog.last_search_time || (a:0 > 0 && a:1) || b:buffersaurus_catalog_viewer != self
                call self.render_buffer()
            endif
        endif
    endfunction

    " Creates a new buffer, renders and opens it.
    function! catalog_viewer.create_buffer() dict
        " get a new buf reference
        let self.buf_num = bufnr(self.buf_name, 1)
        " get a viewport onto it
        call self.activate_viewport()
        " initialize it (includes "claiming" it)
        call self.initialize_buffer()
        " render it
        call self.render_buffer()
    endfunction

    " Opens a viewport on the buffer according, creating it if neccessary
    " according to the spawn mode. Valid buffer number must already have been
    " obtained before this is called.
    function! catalog_viewer.activate_viewport() dict
        let l:bfwn = bufwinnr(self.buf_num)
        if l:bfwn == winnr()
            " viewport wth buffer already active and current
            return
        elseif l:bfwn >= 0
            " viewport with buffer exists, but not current
            execute(l:bfwn . " wincmd w")
        else
            " create viewport
            let self.split_mode = s:_buffersaurus_buffer_manager.get_split_mode()
            execute("silent keepalt keepjumps " . self.split_mode . " " . self.buf_num)
        endif
    endfunction

    " Sets up buffer environment.
    function! catalog_viewer.initialize_buffer() dict
        call self.claim_buffer()
        call self.setup_buffer_opts()
        call self.setup_buffer_syntax()
        call self.setup_buffer_commands()
        call self.setup_buffer_keymaps()
        call self.setup_buffer_folding()
        call self.setup_buffer_statusline()
    endfunction

    " 'Claims' a buffer by setting it to point at self.
    function! catalog_viewer.claim_buffer() dict
        call setbufvar("%", "is_buffersaurus_buffer", 1)
        call setbufvar("%", "buffersaurus_catalog_domain", self.catalog.catalog_domain)
        call setbufvar("%", "buffersaurus_catalog_viewer", self)
        call setbufvar("%", "buffersaurus_last_render_time", 0)
        call setbufvar("%", "buffersaurus_cur_line", 0)
    endfunction

    " 'Unclaims' a buffer by stripping all buffersaurus vars
    function! catalog_viewer.unclaim_buffer() dict
        for l:var in ["is_buffersaurus_buffer",
                    \ "buffersaurus_catalog_domain",
                    \ "buffersaurus_catalog_viewer",
                    \ "buffersaurus_last_render_time",
                    \ "buffersaurus_cur_line"
                    \ ]
            if exists("b:" . l:var)
                unlet b:{l:var}
            endif
        endfor
    endfunction

    " Sets buffer options.
    function! catalog_viewer.setup_buffer_opts() dict
        setlocal buftype=nofile
        setlocal noswapfile
        setlocal nowrap
        set bufhidden=hide
        setlocal nobuflisted
        setlocal nolist
        setlocal noinsertmode
        " setlocal nonumber
        setlocal cursorline
        setlocal nospell
    endfunction

    " Sets buffer syntax.
    function! catalog_viewer.setup_buffer_syntax() dict
        if has("syntax")
            syntax clear
            if self.catalog.is_show_context()
                syn region BuffersaurusSyntaxFileGroup       matchgroup=BuffersaurusSyntaxFileGroupTitle start='^[^ ]'   keepend       end='\(^[^ ]\)\@=' fold
                syn region BuffersaurusSyntaxContextedEntry  start='^  \['  end='\(^  \[\|^[^ ]\)\@=' fold containedin=BuffersaurusSyntaxFileGroup
                syn region BuffersaurusSyntaxContextedKeyRow start='^  \[\s\{-}.\{-1,}\s\{-}\]' keepend oneline end='$' containedin=BuffersaurusSyntaxContextedEntry
                syn region BuffersaurusSyntaxContextLines    start='^  \s*\d\+ :'  oneline end='$' containedin=BuffersaurusSyntaxContextedEntry
                syn region BuffersaurusSyntaxMatchedLines    start='^  \s*\d\+ >'  oneline end='$'  containedin=BuffersaurusSyntaxContextedEntry

                syn match BuffersaurusSyntaxFileGroupTitle            ':: .\+ :::'                          containedin=BuffersaurusSyntaxFileGroup
                syn match BuffersaurusSyntaxKey                       '^  \zs\[\s\{-}.\{-1,}\s\{-}\]\ze'    containedin=BuffersaurusSyntaxcOntextedKeyRow
                syn match BuffersaurusSyntaxContextedKeyFilename      '  \zs".\+"\ze, L\d\+-\d\+:'          containedin=BuffersaurusSyntaxContextedKeyRow
                syn match BuffersaurusSyntaxContextedKeyLines         ', \zsL\d\+-\d\+\ze:'                 containedin=BuffersaurusSyntaxContextedKeyRow
                syn match BuffersaurusSyntaxContextedKeyDesc          ': .*$'                               containedin=BuffersaurusSyntaxContextedKeyRow

                syn match BuffersaurusSyntaxContextLineNum            '^  \zs\s*\d\+\s*\ze:'                containedin=BuffersaurusSyntaxContextLines
                syn match BuffersaurusSyntaxContextLineText           ': \zs.*\ze'                          containedin=BuffersaurusSyntaxContextLines

                syn match BuffersaurusSyntaxMatchedLineNum            '^  \zs\s*\d\+\s*\ze>'                containedin=BuffersaurusSyntaxMatchedLines
                syn match BuffersaurusSyntaxMatchedLineText           '> \zs.*\ze'                          containedin=BuffersaurusSyntaxMatchedLines
            else
                syn match BuffersaurusSyntaxFileGroupTitle             '^\zs::: .* :::\ze.*$'                   nextgroup=BuffersaurusSyntaxKey
                syn match BuffersaurusSyntaxKey                        '^  \zs\[\s\{-}.\{-1,}\s\{-}\]\ze'       nextgroup=BuffersaurusSyntaxUncontextedLineNum
                syn match BuffersaurusSyntaxUncontextedLineNum         '\s\+\s*\zs\d\+\ze:'                nextgroup=BuffersaurusSyntaxUncontextedLineText
            endif
            highlight! link BuffersaurusSyntaxFileGroupTitle       Title
            highlight! link BuffersaurusSyntaxKey                  Identifier
            highlight! link BuffersaurusSyntaxContextedKeyFilename Comment
            highlight! link BuffersaurusSyntaxContextedKeyLines    Comment
            highlight! link BuffersaurusSyntaxContextedKeyDesc     Comment
            highlight! link BuffersaurusSyntaxContextLineNum       Normal
            highlight! link BuffersaurusSyntaxContextLineText      Normal
            highlight! link BuffersaurusSyntaxMatchedLineNum       Question
            highlight! link BuffersaurusSyntaxMatchedLineText      Question
            highlight! link BuffersaurusSyntaxUncontextedLineNum   Question
            highlight! link BuffersaurusSyntaxUncontextedLineText  Normal
            highlight! def BuffersaurusCurrentEntry gui=reverse cterm=reverse term=reverse
        endif
    endfunction

    " Sets buffer commands.
    function! catalog_viewer.setup_buffer_commands() dict
        command! -buffer -bang -nargs=* Bsfilter     :call b:buffersaurus_catalog_viewer.set_filter('<bang>', <q-args>)
        command! -buffer -bang -nargs=* Bssubstitute :call b:buffersaurus_catalog_viewer.search_and_replace('<bang>', <q-args>, 0)
        augroup BuffersaurusCatalogViewer
            au!
            autocmd CursorHold,CursorHoldI,CursorMoved,CursorMovedI,BufEnter,BufLeave <buffer> call b:buffersaurus_catalog_viewer.highlight_current_line()
            autocmd BufLeave <buffer> let s:_buffersaurus_last_catalog_viewed = b:buffersaurus_catalog_viewer
        augroup END
    endfunction

    " Sets buffer key maps.
    function! catalog_viewer.setup_buffer_keymaps() dict

        """" Disabling of unused modification keys
        for key in [".", "p", "P", "C", "x", "X", "r", "R", "i", "I", "a", "A", "D", "S", "U"]
            try
                execute "nnoremap <buffer> " . key . " <NOP>"
            catch //
            endtry
        endfor

        if !exists("g:buffersaurus_use_new_keymap") || !g:buffergator_use_new_keymap

            """" Index buffer management
            noremap <buffer> <silent> cc      :call b:buffersaurus_catalog_viewer.toggle_context()<CR>
            noremap <buffer> <silent> C       :call b:buffersaurus_catalog_viewer.toggle_context()<CR>
            noremap <buffer> <silent> cs      :call b:buffersaurus_catalog_viewer.cycle_sort_regime()<CR>
            noremap <buffer> <silent> cq      :call b:buffersaurus_catalog_viewer.cycle_autodismiss_modes()<CR>
            noremap <buffer> <silent> f       :call b:buffersaurus_catalog_viewer.toggle_filter()<CR>
            noremap <buffer> <silent> F       :call b:buffersaurus_catalog_viewer.prompt_and_apply_filter()<CR>
            noremap <buffer> <silent> r       :call b:buffersaurus_catalog_viewer.rebuild_catalog()<CR>
            noremap <buffer> <silent> <C-G>   :call b:buffersaurus_catalog_viewer.catalog.describe()<CR>
            noremap <buffer> <silent> g<C-G>  :call b:buffersaurus_catalog_viewer.catalog.describe_detail()<CR>
            noremap <buffer> <silent> q       :call b:buffersaurus_catalog_viewer.close(1)<CR>
            noremap <buffer> <silent> <ESC>   :call b:buffersaurus_catalog_viewer.close(1)<CR>

            """" Movement within buffer

            " flash matched line
            noremap <buffer> <silent> P      :let g:buffersaurus_flash_jumped_line = !g:buffersaurus_flash_jumped_line<CR>

            " jump to next/prev key entry
            noremap <buffer> <silent> <C-N>  :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("n", 0, 1)<CR>
            noremap <buffer> <silent> <C-P>  :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 0, 1)<CR>

            " jump to next/prev file entry
            noremap <buffer> <silent> ]f     :<C-U>call b:buffersaurus_catalog_viewer.goto_file_start("n", 0, 1)<CR>
            noremap <buffer> <silent> [f     :<C-U>call b:buffersaurus_catalog_viewer.goto_file_start("p", 0, 1)<CR>

            """"" Selection: show target and switch focus
            noremap <buffer> <silent> <CR>  :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "")<CR>
            noremap <buffer> <silent> o     :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "")<CR>
            noremap <buffer> <silent> s     :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "vert sb")<CR>
            noremap <buffer> <silent> <C-v> :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "vert sb")<CR>
            noremap <buffer> <silent> i     :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "sb")<CR>
            noremap <buffer> <silent> <C-s> :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "sb")<CR>
            noremap <buffer> <silent> t     :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "tab sb")<CR>
            noremap <buffer> <silent> <C-t> :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "tab sb")<CR>

            """"" Selection: show target and switch focus, preserving the catalog regardless of the autodismiss setting
            noremap <buffer> <silent> po          :<C-U>call b:buffersaurus_catalog_viewer.visit_target(1, 0, "")<CR>
            noremap <buffer> <silent> ps          :<C-U>call b:buffersaurus_catalog_viewer.visit_target(1, 0, "vert sb")<CR>
            noremap <buffer> <silent> pi          :<C-U>call b:buffersaurus_catalog_viewer.visit_target(1, 0, "sb")<CR>
            noremap <buffer> <silent> pt          :<C-U>call b:buffersaurus_catalog_viewer.visit_target(1, 0, "tab sb")<CR>

            """"" Preview: show target , keeping focus on catalog
            noremap <buffer> <silent> O          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "")<CR>
            noremap <buffer> <silent> go         :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "")<CR>
            noremap <buffer> <silent> S          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "vert sb")<CR>
            noremap <buffer> <silent> gs         :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "vert sb")<CR>
            noremap <buffer> <silent> I          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "sb")<CR>
            noremap <buffer> <silent> gi         :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "sb")<CR>
            noremap <buffer> <silent> T          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "tab sb")<CR>
            noremap <buffer> <silent> <SPACE>     :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("n", 1, 1)<CR>
            noremap <buffer> <silent> <C-SPACE>   :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 1, 1)<CR>
            noremap <buffer> <silent> <C-@>       :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 1, 1)<CR>
            noremap <buffer> <silent> <C-N>       :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("n", 1, 1)<CR>
            noremap <buffer> <silent> <C-P>       :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 1, 1)<CR>

            """"" Special operations
            nnoremap <buffer> <silent> x        :call b:buffersaurus_catalog_viewer.execute_command("", 0, 1)<CR>
            nnoremap <buffer> <silent> X        :call b:buffersaurus_catalog_viewer.execute_command("", 1, 1)<CR>
            nnoremap <buffer> <silent> R        :call b:buffersaurus_catalog_viewer.search_and_replace("", 0, 1)<CR>
            nnoremap <buffer> <silent> <C-R>    :call b:buffersaurus_catalog_viewer.search_and_replace("", 0, 1)<CR>
            nnoremap <buffer> <silent> &        :call b:buffersaurus_catalog_viewer.search_and_replace("", 0, 1)<CR>

        else

            """" Index buffer management
            noremap <buffer> <silent> c       :call b:buffersaurus_catalog_viewer.toggle_context()<CR>
            noremap <buffer> <silent> s       :call b:buffersaurus_catalog_viewer.cycle_sort_regime()<CR>
            noremap <buffer> <silent> f       :call b:buffersaurus_catalog_viewer.toggle_filter()<CR>
            noremap <buffer> <silent> F       :call b:buffersaurus_catalog_viewer.prompt_and_apply_filter()<CR>
            noremap <buffer> <silent> u       :call b:buffersaurus_catalog_viewer.rebuild_catalog()<CR>
            noremap <buffer> <silent> <C-G>   :call b:buffersaurus_catalog_viewer.catalog.describe()<CR>
            noremap <buffer> <silent> g<C-G>  :call b:buffersaurus_catalog_viewer.catalog.describe_detail()<CR>
            noremap <buffer> <silent> q       :call b:buffersaurus_catalog_viewer.close(1)<CR>

            """" Selection
            noremap <buffer> <silent> <CR>  :call b:buffersaurus_catalog_viewer.visit_target(!g:buffersaurus_autodismiss_on_select, 0, "")<CR>

            """" Movement within buffer

            " jump to next/prev key entry
            noremap <buffer> <silent> <C-N>  :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("n", 0, 1)<CR>
            noremap <buffer> <silent> <C-P>  :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 0, 1)<CR>

            " jump to next/prev file entry
            noremap <buffer> <silent> ]f     :<C-U>call b:buffersaurus_catalog_viewer.goto_file_start("n", 0, 1)<CR>
            noremap <buffer> <silent> [f     :<C-U>call b:buffersaurus_catalog_viewer.goto_file_start("p", 0, 1)<CR>

            """" Movement within buffer that updates the other window

            " show target line in other window, keeping catalog open and in focus
            noremap <buffer> <silent> .           :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "")<CR>
            noremap <buffer> <silent> po          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "")<CR>
            noremap <buffer> <silent> ps          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "sb")<CR>
            noremap <buffer> <silent> pv          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "vert sb")<CR>
            noremap <buffer> <silent> pt          :call b:buffersaurus_catalog_viewer.visit_target(1, 1, "tab sb")<CR>
            noremap <buffer> <silent> <SPACE>     :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("n", 1, 1)<CR>
            noremap <buffer> <silent> <C-SPACE>   :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 1, 1)<CR>
            noremap <buffer> <silent> <C-@>       :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 1, 1)<CR>
            noremap <buffer> <silent> <C-N>       :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("n", 1, 1)<CR>
            noremap <buffer> <silent> <C-P>       :<C-U>call b:buffersaurus_catalog_viewer.goto_index_entry("p", 1, 1)<CR>

            """" Movement that moves to the current search target

            " go to target line in other window, keeping catalog open
            noremap <buffer> <silent> o     :call b:buffersaurus_catalog_viewer.visit_target(1, 0, "")<CR>
            noremap <buffer> <silent> ws    :call b:buffersaurus_catalog_viewer.visit_target(1, 0, "sb")<CR>
            noremap <buffer> <silent> wv    :call b:buffersaurus_catalog_viewer.visit_target(1, 0, "vert sb")<CR>
            noremap <buffer> <silent> t     :call b:buffersaurus_catalog_viewer.visit_target(1, 0, "tab sb")<CR>

            " open target line in other window, closing catalog
            noremap <buffer> <silent> O     :call b:buffersaurus_catalog_viewer.visit_target(0, 0, "")<CR>
            noremap <buffer> <silent> wS    :call b:buffersaurus_catalog_viewer.visit_target(0, 0, "sb")<CR>
            noremap <buffer> <silent> wV    :call b:buffersaurus_catalog_viewer.visit_target(0, 0, "vert sb")<CR>
            noremap <buffer> <silent> T     :call b:buffersaurus_catalog_viewer.visit_target(0, 0, "tab sb")<CR>

        endif

    endfunction

    " Sets buffer folding.
    function! catalog_viewer.setup_buffer_folding() dict
        if has("folding")
            "setlocal foldcolumn=3
            setlocal foldmethod=syntax
            setlocal foldlevel=4
            setlocal foldenable
            setlocal foldtext=BuffersaurusFoldText()
            " setlocal fillchars=fold:\ "
            setlocal fillchars=fold:.
        endif
    endfunction

    " Search and replace
    function! catalog_viewer.search_and_replace(bang, sr_pattern, assume_last_search_pattern) dict
        if a:bang
            let l:include_context_lines = 1
        else
            let l:include_context_lines = 0
        endif
        if empty(a:sr_pattern)
            if a:assume_last_search_pattern
                let l:pattern = s:last_searched_pattern
            else
                let l:pattern = input("Search for: ", s:last_searched_pattern)
                if empty(l:pattern)
                    return
                endif
            endif
            let l:replace = input("Replace with: ", l:pattern)
            if empty(l:replace)
                return
            endif
            for separator in ["/", "@", "'", "|", "!", "#", "$", "%", "^", "&", "*", "(", ")", "_", "-", "+", "=", ":"]
                if !(l:pattern =~ '\'.separator || l:replace =~ '\'.separator)
                    break
                endif
            endfor
            let l:command = "s" . l:separator . l:pattern . l:separator . l:replace . l:separator . "ge"
        else
            let l:command = "s" . a:sr_pattern
        endif
        call self.execute_command(l:command, l:include_context_lines, 1)
    endfunction

    " Applies filter.
    function! catalog_viewer.set_filter(regime, pattern) dict
        if (type(a:regime) == type(0) && a:regime != 0) || (type(a:regime) == type("") && a:regime != "!")
            if a:pattern == "*" || a:pattern == ".*"
                let self.filter_pattern = ""
                let self.filter_regime = 0
                call s:_buffersaurus_messenger.send_info("clearing filter")
            else
                if !empty(a:pattern)
                    let self.filter_pattern = a:pattern
                endif
                if !empty(self.filter_pattern)
                    let self.filter_regime = 1
                    call s:_buffersaurus_messenger.send_info("filtering for: " . self.filter_pattern)
                else
                    let l:ipattern = input("Enter filter pattern: ")
                    if empty(l:ipattern)
                        return
                    else
                        let self.filter_pattern = l:ipattern
                        let self.filter_regime = 1
                    endif
                endif
            endif
        else
            if a:pattern == "*" || a:pattern == ".*"
                let self.filter_pattern = ""
                let self.filter_regime = 0
                call s:_buffersaurus_messenger.send_info("clearing filter")
            else
                let self.filter_regime = 0
                if empty(self.filter_pattern)
                    call s:_buffersaurus_messenger.send_info("filter pattern not set")
                else
                    call s:_buffersaurus_messenger.send_info("removing filter")
                endif
            endif
        endif
        call self.render_buffer()
    endfunction

    " Toggles filter.
    function! catalog_viewer.toggle_filter() dict
        call self.set_filter(!self.filter_regime, "")
    endfunction

    " Ask user for filter pattern, and, if given, set and apply it.
    function! catalog_viewer.prompt_and_apply_filter()
        let l:ipattern = input("Enter filter pattern: ")
        if empty(l:ipattern)
            return
        else
            call self.set_filter(1, l:ipattern)
        endif
    endfunction

    " Return true if the line is NOT to be filtered out.
    function! catalog_viewer.is_pass_filter(text) dict
        if !self.filter_regime || empty(self.filter_pattern) || a:text =~ self.filter_pattern
            return 1
        else
            return 0
        endif
    endfunction

    " Sets buffer status line.
    function! catalog_viewer.setup_buffer_statusline() dict
        " setlocal statusline=\-buffersaurus\-\|\ %{BuffersaurusStatusLineCurrentLineInfo()}%<%=\|%{BuffersaurusStatusLineSortRegime()}\|%{BuffersaurusStatusLineFilterRegime()}
        setlocal statusline=[[buffersaurus]]%{BuffersaurusStatusLineCurrentLineInfo()}%<%=\|%{BuffersaurusStatusLineSortRegime()}
    endfunction

    " Populates the buffer with the catalog index.
    function! catalog_viewer.render_buffer() dict
        setlocal modifiable
        call self.claim_buffer()
        call self.clear_buffer()
        let self.jump_map = {}
        let l:show_context = self.catalog.is_show_context()
        let l:context_size = self.catalog.context_size
        call self.setup_buffer_syntax()
        let catalog_index_groups = self.catalog.get_index_groups()
        let prev_entry_index_group_label = ''
        for l:entry_index_group in catalog_index_groups
            let [l:entry_index_group_label, l:entry_indexes] = l:entry_index_group
            if prev_entry_index_group_label != l:entry_index_group_label
                call self.append_line('::: ' . l:entry_index_group_label . ' :::',
                            \ -1,
                            \ self.catalog.matched_lines[l:entry_indexes[0]].buf_num,
                            \ 1,
                            \ 1,
                            \ 0,
                            \ 0,
                            \ {"proxy_entry_index": l:entry_indexes[0]})
            endif
            for l:entry_index in l:entry_indexes
                if self.catalog.is_show_context()
                    call self.render_contexted_entry(l:entry_index, self.catalog.matched_lines[l:entry_index], l:context_size)
                else
                    call self.render_uncontexted_entry(l:entry_index, self.catalog.matched_lines[l:entry_index])
                endif
            endfor
        endfor
        let b:buffersaurus_last_render_time = localtime()
        try
            " remove extra last line
            execute('normal! GV"_X')
        catch //
        endtry
        setlocal nomodifiable
        call cursor(1, 1)
        call self.goto_index_entry("n", 0, 1)
    endfunction

    " Renders contexted entry.
    function! catalog_viewer.render_contexted_entry(index, entry, context_size) dict
        let l:lnum = a:entry.lnum
        let l:buf_num = a:entry.buf_num
        let l:matched_line = self.fetch_buf_line(l:buf_num, l:lnum)
        if self.is_pass_filter(l:matched_line)
            let l:buf_name = a:entry.buf_name
            let l:col = a:entry.col
            let l:ln1 = max([1, l:lnum - a:context_size[0]])
            let l:ln2 = l:lnum + a:context_size[1]
            let l:src_lines = self.fetch_buf_lines(l:buf_num, l:ln1, l:ln2)
            let l:indexed_line_summary = substitute(l:matched_line, '^\s*', '', 'g')
            let l:index_row = self.render_entry_index(a:index) . ' "' . l:buf_name . '", L' . l:ln1 . '-' . l:ln2 . ": " . l:indexed_line_summary
            call self.append_line(l:index_row, a:index, l:buf_num, l:lnum, l:col, 0, 0)
            for l:lnx in range(0, len(l:src_lines)-1)
                let l:src_lnum = l:lnx + l:ln1
                let l:rendered = "  "
                " let l:rendered .= repeat(" ", s:buffersaurus_entry_label_field_width + 1)
                if l:src_lnum == l:lnum
                    let l:lborder = ">"
                    let l:rborder = ">"
                    let l:is_matched_line = 1
                else
                    let l:lborder = ":"
                    let l:rborder = ":"
                    let l:is_matched_line = 0
                endif
                let l:rendered .= s:Format_AlignRight(l:src_lnum, s:buffersaurus_lnum_field_width, " ") . " " . l:rborder
                let l:rendered .= " ".l:src_lines[l:lnx]
                call self.append_line(l:rendered, a:index, l:buf_num, l:src_lnum, l:col, 1, l:is_matched_line)
            endfor
        endif
    endfunction

    " Renders an uncontexted entry.
    function! catalog_viewer.render_uncontexted_entry(index, entry) dict
        let l:index_field = self.render_entry_index(a:index)
        let l:lnum_field = s:Format_AlignRight(a:entry.lnum, 14 - len(l:index_field), " ")
        let l:src_line = self.fetch_buf_line(a:entry.buf_num, a:entry.lnum)
        if self.is_pass_filter(l:src_line)
            let l:rendered_line = "" . l:index_field . " ".l:lnum_field . ":   " . l:src_line
            call self.append_line(l:rendered_line, a:index, a:entry.buf_num, a:entry.lnum, a:entry.col, 1, 1)
        endif
    endfunction

    " Renders the index.
    function! catalog_viewer.render_entry_index(index) dict
        return "  [" . get(self.catalog.entry_labels, a:index, string(a:index)) . "] "
    endfunction

    " Appends a line to the buffer and registers it in the line log.
    function! catalog_viewer.append_line(text, entry_index, jump_to_buf_num, jump_to_lnum, jump_to_col, is_matched_line, is_content_line, ...) dict
        let l:line_map = {
                    \ "entry_index" : a:entry_index,
                    \ "entry_label" : get(self.catalog.entry_labels, a:entry_index, string(a:entry_index)),
                    \ "target" : [a:jump_to_buf_num, a:jump_to_lnum, a:jump_to_col, 0],
                    \ "is_matched_line" : a:is_matched_line,
                    \ "is_content_line" : a:is_content_line,
                    \ }
        if a:0 > 0
            call extend(l:line_map, a:1)
        endif
        let self.jump_map[line("$")] = l:line_map
        call append(line("$")-1, a:text)
    endfunction

    " Close and quit the viewer.
    function! catalog_viewer.close(restore_prev_window) dict
        if self.buf_num < 0 || !bufexists(self.buf_num)
            return
        endif
        if a:restore_prev_window
            if !self.is_usable_viewport(winnr("#")) && self.first_usable_viewport() ==# -1
            else
                try
                    if !self.is_usable_viewport(winnr("#"))
                        execute(self.first_usable_viewport() . "wincmd w")
                    else
                        execute('wincmd p')
                    endif
                catch //
                endtry
            endif
        endif
        execute("bwipe " . self.buf_num)
    endfunction

    function! catalog_viewer.highlight_current_line()
        " if line(".") != b:buffersaurus_cur_line
            let l:prev_line = b:buffersaurus_cur_line
            let b:buffersaurus_cur_line = line(".")
            if exists("self.match_highlight_id") && self.match_highlight_id != 0
                try
                    call matchdelete(self.match_highlight_id)
                catch // " 803: ID not found
                endtry
            endif
            let self.match_highlight_id = matchadd("BuffersaurusCurrentEntry", '\%'. b:buffersaurus_cur_line .'l')
        " endif
    endfunction

    " Clears the buffer contents.
    function! catalog_viewer.clear_buffer() dict
        call cursor(1, 1)
        exec 'silent! normal! "_dG'
    endfunction

    " Returns a string corresponding to line `ln1` from buffer ``buf``.
    " If the line is unavailable, then "#INVALID#LINE#" is returned.
    function! catalog_viewer.fetch_buf_line(buf, ln1)
        let l:lines = getbufline(a:buf, a:ln1)
        if len(l:lines) > 0
            return l:lines[0]
        else
            return "#INVALID#LINE#"
        endif
    endfunction

    " Returns a list of strings corresponding to the contents of lines from
    " `ln1` to `ln2` from buffer `buf`. If lines are not available, returns a
    " list with (ln2-ln1+1) elements consisting of copies of the string
    " "#INVALID LINE#".
    function! catalog_viewer.fetch_buf_lines(buf, ln1, ln2)
        let l:lines = getbufline(a:buf, a:ln1, a:ln2)
        if len(l:lines) > 0
            return l:lines
        else
            let l:lines = []
            for l:idx in range(a:ln1, a:ln2)
                call add(l:lines, "#INVALID#LINE#")
            endfor
            return l:lines
        endif
    endfunction

    " from NERD_Tree, via VTreeExplorer: determine the number of windows open
    " to this buffer number.
    function! catalog_viewer.num_viewports_on_buffer(bnum) dict
        let cnt = 0
        let winnum = 1
        while 1
            let bufnum = winbufnr(winnum)
            if bufnum < 0
                break
            endif
            if bufnum ==# a:bnum
                let cnt = cnt + 1
            endif
            let winnum = winnum + 1
        endwhile
        return cnt
    endfunction

    " from NERD_Tree: find the window number of the first normal window
    function! catalog_viewer.first_usable_viewport() dict
        let i = 1
        while i <= winnr("$")
            let bnum = winbufnr(i)
            if bnum != -1 && getbufvar(bnum, '&buftype') ==# ''
                        \ && !getwinvar(i, '&previewwindow')
                        \ && (!getbufvar(bnum, '&modified') || &hidden)
                return i
            endif

            let i += 1
        endwhile
        return -1
    endfunction

    " from NERD_Tree: returns 0 if opening a file from the tree in the given
    " window requires it to be split, 1 otherwise
    function! catalog_viewer.is_usable_viewport(winnumber) dict
        "gotta split if theres only one window (i.e. the NERD tree)
        if winnr("$") ==# 1
            return 0
        endif
        let oldwinnr = winnr()
        execute(a:winnumber . "wincmd p")
        let specialWindow = getbufvar("%", '&buftype') != '' || getwinvar('%', '&previewwindow')
        let modified = &modified
        execute(oldwinnr . "wincmd p")
        "if its a special window e.g. quickfix or another explorer plugin then we
        "have to split
        if specialWindow
            return 0
        endif
        if &hidden
            return 1
        endif
        return !modified || self.num_viewports_on_buffer(winbufnr(a:winnumber)) >= 2
    endfunction

    " Acquires a viewport to show the source buffer. Returns the split command
    " to use when switching to the buffer.
    function! catalog_viewer.acquire_viewport(split_cmd)
        if self.split_mode == "buffer" && empty(a:split_cmd)
            " buffersaurus used original buffer's viewport,
            " so the the buffersaurus viewport is the viewport to use
            return ""
        endif
        if !self.is_usable_viewport(winnr("#")) && self.first_usable_viewport() ==# -1
            " no appropriate viewport is available: create new using default
            " split mode
            " TODO: maybe use g:buffersaurus_viewport_split_policy?
            if empty(a:split_cmd)
                return "sb"
            else
                return a:split_cmd
            endif
        else
            try
                if !self.is_usable_viewport(winnr("#"))
                    execute(self.first_usable_viewport() . "wincmd w")
                else
                    execute('wincmd p')
                endif
            catch /^Vim\%((\a\+)\)\=:E37/
                echo v:exception
                " call s:putCursorInTreeWin()
                " throw "NERDTree.FileAlreadyOpenAndModifiedError: ". self.path.str() ." is already open and modified."
            catch /^Vim\%((\a\+)\)\=:/
                echo v:exception
            endtry
            return a:split_cmd
        endif
    endfunction

    " Perform run command on all lines in the catalog
    function! catalog_viewer.execute_command(command_text, include_context_lines, rebuild_catalog) dict
        if a:command_text == ""
            let l:command_text = input("Command: ")
        else
            let l:command_text = a:command_text
        endif
        let catalog_buf_num = bufnr("%")
        let catalog_buf_pos = getpos(".")
        let working_buf_num = catalog_buf_num
        let start_pos = getpos(".")
        for l:cur_line in range(1, line("$"))
            if !has_key(l:self.jump_map, l:cur_line)
                continue
            endif
            let l:jump_entry = self.jump_map[l:cur_line]
            if (!l:jump_entry.is_matched_line) && !(a:include_context_lines && l:jump_entry.is_content_line)
                continue
            endif
            let [l:jump_to_buf_num, l:jump_to_lnum, l:jump_to_col, l:dummy] = l:jump_entry.target
            if l:jump_to_buf_num != working_buf_num
                if working_buf_num != catalog_buf_num
                    call setpos('.', start_pos)
                endif
            endif
            try
                execute("silent! keepalt keepjumps buffer " . l:jump_to_buf_num)
            catch //
                continue
            endtry
            let working_buf_num = l:jump_to_buf_num
            let start_pos = getpos(".")
            " execute "silent! " . l:jump_to_lnum . command_text
            execute "" . l:jump_to_lnum . command_text
        endfor
        if working_buf_num != catalog_buf_num
            call setpos('.', start_pos)
        endif
        execute("silent! keepalt keepjumps buffer " . catalog_buf_num)
        if a:rebuild_catalog
            call self.rebuild_catalog()
        endif
        call setpos('.', catalog_buf_pos)
    endfunction

    " Visits the specified buffer in the previous window, if it is already
    " visible there. If not, then it looks for the first window with the
    " buffer showing and visits it there. If no windows are showing the
    " buffer, ... ?
    function! catalog_viewer.visit_buffer(buf_num, split_cmd) dict
        " acquire window
        let l:split_cmd = self.acquire_viewport(a:split_cmd)
        " switch to buffer in acquired window
        let l:old_switch_buf = &switchbuf
        if empty(l:split_cmd)
            " explicit split command not given: switch to buffer in current
            " window
            let &switchbuf="useopen"
            execute("silent keepalt keepjumps buffer " . a:buf_num)
        else
            " explcit split command given: split current window
            let &switchbuf="split"
            execute("silent keepalt keepjumps " . l:split_cmd . " " . a:buf_num)
        endif
        let &switchbuf=l:old_switch_buf
    endfunction

    " Go to the line mapped to by the current line/index of the catalog
    " viewer.
    function! catalog_viewer.visit_target(keep_catalog, refocus_catalog, split_cmd) dict
        let l:cur_line = line(".")
        if !has_key(l:self.jump_map, l:cur_line)
            call s:_buffersaurus_messenger.send_info("Not a valid navigation line")
            return 0
        endif
        let [l:jump_to_buf_num, l:jump_to_lnum, l:jump_to_col, l:dummy] = self.jump_map[l:cur_line].target
        let l:cur_tab_num = tabpagenr()
        if !a:keep_catalog
            call self.close(0)
        endif
        call self.visit_buffer(l:jump_to_buf_num, a:split_cmd)
        call setpos('.', [l:jump_to_buf_num, l:jump_to_lnum, l:jump_to_col, l:dummy])
        execute(s:buffersaurus_post_move_cmd)
        if g:buffersaurus_flash_jumped_line
            exec 'silent! match BuffersaurusFlashMatchedLineHighlight1 /\%'. line('.') .'l.*/'
            redraw
            sleep 75m
            exec 'silent! match BuffersaurusFlashMatchedLineHighlight2 /\%'. line('.') .'l.*/'
            redraw
            sleep 75m
            exec 'silent! match BuffersaurusFlashMatchedLineHighlight1 /\%'. line('.') .'l.*/'
            redraw
            sleep 75m
            exec 'silent! match BuffersaurusFlashMatchedLineHighlight2 /\%'. line('.') .'l.*/'
            redraw
            sleep 75m
            match none
        endif
        if a:keep_catalog && a:refocus_catalog
            execute("tabnext " . l:cur_tab_num)
            execute(bufwinnr(self.buf_num) . "wincmd w")
        endif
        let l:report = ""
        if self.jump_map[l:cur_line].entry_index >= 0
            let l:report .= "(" . string(self.jump_map[l:cur_line].entry_index + 1). " of " . self.catalog.size() . "): "
            let l:report .= '"' . expand(bufname(l:jump_to_buf_num)) . '", Line ' . l:jump_to_lnum
        else
            let l:report .= 'File: "'  . expand(bufname(l:jump_to_buf_num)) . '"'
        endif

        call s:_buffersaurus_messenger.send_info(l:report)
    endfunction

    " Finds next line with occurrence of a rendered index
    function! catalog_viewer.goto_index_entry(direction, visit_target, refocus_catalog) dict
        let l:ok = self.goto_pattern("^  \[", a:direction)
        execute("normal! zz")
        if l:ok && a:visit_target
            call self.visit_target(1, a:refocus_catalog, "")
        endif
    endfunction

    " Finds next line with occurrence of a file pattern.
    function! catalog_viewer.goto_file_start(direction, visit_target, refocus_catalog) dict
        let l:ok = self.goto_pattern("^:::", a:direction)
        execute("normal! zz")
        if l:ok && a:visit_target
            call self.visit_target(1, a:refocus_catalog, "")
        endif
    endfunction

    " Finds next occurrence of specified pattern.
    function! catalog_viewer.goto_pattern(pattern, direction) dict range
        if a:direction == "b" || a:direction == "p"
            let l:flags = "b"
            " call cursor(line(".")-1, 0)
        else
            let l:flags = ""
            " call cursor(line(".")+1, 0)
        endif
        if g:buffersaurus_move_wrap
            let l:flags .= "W"
        else
            let l:flags .= "w"
        endif
        let l:flags .= "e"
        let l:lnum = -1
        for i in range(v:count1)
            if search(a:pattern, l:flags) < 0
                break
            else
                let l:lnum = 1
            endif
        endfor
        if l:lnum < 0
            if l:flags[0] == "b"
                call s:_buffersaurus_messenger.send_info("No previous results")
            else
                call s:_buffersaurus_messenger.send_info("No more results")
            endif
            return 0
        else
            return 1
        endif
    endfunction

    " Toggles context on/off.
    function! catalog_viewer.toggle_context() dict
        let self.catalog.show_context = !self.catalog.show_context
        let l:line = line(".")
        if has_key(b:buffersaurus_catalog_viewer.jump_map, l:line)
            let l:jump_line = b:buffersaurus_catalog_viewer.jump_map[l:line]
            if l:jump_line.entry_index > 0
                let l:entry_index = l:jump_line.entry_index
            elseif has_key(l:jump_line, "proxy_key")
                let l:entry_index = l:jump_line.proxy_key
            else
                let l:entry_index = ""
            endif
        else
            let l:entry_index = ""
        endif
        call self.open(1)
        if !empty(l:entry_index)
            let l:rendered_entry_index = self.render_entry_index(l:entry_index)
            let l:lnum = search('^'.escape(l:rendered_entry_index, '[]'), "e")
            if l:lnum > 0
                call setpos(".", [bufnr("%"), l:lnum, 0, 0])
                execute("normal! zz")
            endif
        endif
    endfunction

    " Cycles sort regime.
    function! catalog_viewer.cycle_sort_regime() dict
        call self.catalog.cycle_sort_regime()
        call self.open(1)
        call s:_buffersaurus_messenger.send_info("sorted " . self.catalog.format_sort_status())
    endfunction

    " Rebuilds catalog.
    function! catalog_viewer.rebuild_catalog() dict
        call self.catalog.rebuild()
        call s:_buffersaurus_messenger.send_info("updated index: found " . self.catalog.format_status_message())
        call self.open(1)
    endfunction

    " Cycles autodismiss modes
    function! catalog_viewer.cycle_autodismiss_modes() dict
        if (g:buffersaurus_autodismiss_on_select)
            let g:buffersaurus_autodismiss_on_select = 0
        call s:_buffersaurus_messenger.send_info("will stay open on selection (autodismiss-on-select: OFF)")
        else
            let g:buffersaurus_autodismiss_on_select = 1
        call s:_buffersaurus_messenger.send_info("will close on selection (autodismiss-on-select: ON)")
        endif
    endfunction

    " return object
    return catalog_viewer

endfunction

" 1}}}

" Command Interface {{{1
" =============================================================================

function! s:ComposeBufferTargetList(bang)
    if (exists('g:buffersaurus_default_single_file') && g:buffersaurus_default_single_file && empty(a:bang))
                \ || !empty(a:bang)
        return ["%"]
    else
        return ""
    endif
endfunction

function! s:ActivateCatalog(domain, catalog)
    let s:_buffersaurus_last_catalog_built = a:catalog
    let s:_buffersaurus_last_catalog_viewed = a:catalog.open()
    if a:catalog.size() > 0
        call a:catalog.describe()
    else
        call s:_buffersaurus_messenger.send_status("no matches")
    endif
endfunction

function! s:GetLastActiveCatalog()
    if !exists("s:_buffersaurus_last_catalog_viewed") && !exists("s:_buffersaurus_last_catalog_built")
        return 0
    endif
    if exists("s:_buffersaurus_last_catalog_viewed")
        let catalog = s:_buffersaurus_last_catalog_viewed.catalog
    elseif exists("s:_buffersaurus_last_catalog_built")
        let catalog = s:_buffersaurus_last_catalog_built.catalog
    endif
    return catalog
endfunction

function! buffersaurus#IndexTerms(term_name, bang, sort_regime)
    let l:worklist = s:ComposeBufferTargetList(a:bang)
    let catalog = s:_buffersaurus_indexer.index_terms(l:worklist, a:term_name, a:sort_regime)
    call s:ActivateCatalog("term", catalog)
endfunction

function! buffersaurus#IndexTags(bang)
    let l:worklist = s:ComposeBufferTargetList(a:bang)
    let catalog = s:_buffersaurus_indexer.index_tags(l:worklist)
    call s:ActivateCatalog("tags", catalog)
endfunction

function! buffersaurus#GlobalSearchAndReplace()
    let l:pattern = input("Search for: ", s:last_searched_pattern)
    if empty(l:pattern)
        return
    endif
    let l:worklist = s:ComposeBufferTargetList(0)
    let catalog = s:_buffersaurus_indexer.index_pattern(l:worklist, l:pattern, '')
    let s:last_searched_pattern = l:pattern
    let s:_buffersaurus_last_catalog_built = catalog
    let s:_buffersaurus_last_catalog_viewed = catalog.open()
    if catalog.size() > 0
        call catalog.describe()
        call s:_buffersaurus_last_catalog_viewed.search_and_replace(0, "", 1)
    else
        call s:_buffersaurus_messenger.send_status("no matches")
    endif
endfunction

function! buffersaurus#IndexPatterns(pattern, bang, sort_regime)
    if empty(a:pattern)
        call s:_buffersaurus_messenger.send_error("search pattern must be specified")
        return
    endif
    let l:worklist = s:ComposeBufferTargetList(a:bang)
    let catalog = s:_buffersaurus_indexer.index_pattern(l:worklist, a:pattern, a:sort_regime)
    let s:last_searched_pattern = a:pattern
    call s:ActivateCatalog("pattern", catalog)
    if !exists("g:buffersaurus_set_search_register") || g:buffersaurus_set_search_register
        let @/=a:pattern
    endif
    " if !exists("g:buffersaurus_set_search_highlight") || g:buffersaurus_set_search_highlight
    "     set hlsearch
    " endif
endfunction

function! buffersaurus#OpenLastActiveCatalog()
    if !exists("s:_buffersaurus_last_catalog_viewed") && !exists("s:_buffersaurus_last_catalog_built")
        call s:_buffersaurus_messenger.send_error("No index available for viewing")
        return 0
    elseif exists("s:_buffersaurus_last_catalog_viewed")
        call s:_buffersaurus_last_catalog_viewed.open()
    elseif exists("s:_buffersaurus_last_catalog_built")
        let s:_buffersaurus_last_catalog_viewed = s:_buffersaurus_last_catalog_built.open()
    endif
    return 1
endfunction

function! buffersaurus#GotoEntry(direction)
    if buffersaurus#OpenLastActiveCatalog()
        call s:_buffersaurus_last_catalog_viewed.goto_index_entry(a:direction, 1, 0)
    endif
endfunction

function! buffersaurus#ShowCatalogStatus(full)
    let catalog = s:GetLastActiveCatalog()
    if type(catalog) == type(0) && catalog == 0
        call s:_buffersaurus_messenger.send_error("No index available")
    elseif empty(a:full)
        call catalog.describe()
    else
        call catalog.describe_detail()
    endif
endfunction

" 1}}}

" Global Functions {{{1
" ==============================================================================

function! BuffersaurusStatusLineCurrentLineInfo()
    if !exists("b:buffersaurus_catalog_viewer")
        return "[not a valid catalog]"
    endif
    let l:line = line(".")
    let l:status_line = " | "
    if b:buffersaurus_catalog_viewer.filter_regime && !empty(b:buffersaurus_catalog_viewer.filter_pattern)
        let l:status_line .= "*filtered* | "
    endif
    if has_key(b:buffersaurus_catalog_viewer.jump_map, l:line)
        let l:jump_line = b:buffersaurus_catalog_viewer.jump_map[l:line]
        if l:jump_line.entry_index >= 0
            let l:status_line .= string(l:jump_line.entry_index + 1) . " of " . b:buffersaurus_catalog_viewer.catalog.size()
            let l:status_line .= " | "
            let l:status_line .= 'File: "' . expand(bufname(l:jump_line.target[0]))
            let l:status_line .= '" (L:' . l:jump_line.target[1] . ', C:' . l:jump_line.target[2] . ')'
        else
            let l:status_line .= '(Indexed File) | "' . expand(bufname(l:jump_line.target[0])) . '"'
        endif
    else
        let l:status_line .= "(not a valid indexed line)"
    endif
    return l:status_line
endfunction

function! BuffersaurusStatusLineSortRegime()
    if exists("b:buffersaurus_catalog_viewer")
        let l:sort_desc = get(s:buffersaurus_catalog_sort_regime_desc, b:buffersaurus_catalog_viewer.catalog.sort_regime, ["??", "invalid sort"])
        return "sort: " . l:sort_desc[0] . ""
    else
        return ""
    endif
endfunction

function! BuffersaurusStatusLineFilterRegime()
    if exists("b:buffersaurus_catalog_viewer")
        if b:buffersaurus_catalog_viewer.filter_regime && !empty(b:buffersaurus_catalog_viewer.filter_pattern)
            return "filter: /" . b:buffersaurus_catalog_viewer.filter_pattern . "/"
        else
            return "filter: OFF"
        endif
    else
        return ""
    endif
endfunction

function! BuffersaurusFoldText()
    return substitute(getline(v:foldstart), '^\s\{-1,}\(\[\s*\d\+\s*\]\) .\{-1,}, L\d\+-\d\+: ', '\1 ', "g")
endfunction
" 1}}}

" Global Initialization {{{1
" ==============================================================================
if exists("s:_buffersaurus_buffer_manager")
    unlet s:_buffersaurus_buffer_manager
endif
let s:_buffersaurus_buffer_manager = s:NewBufferManager()
let s:last_searched_pattern = ""
if exists("s:_buffersaurus_messenger")
    unlet s:_buffersaurus_messenger
endif
let s:_buffersaurus_messenger = s:NewMessenger("")
if exists("s:_buffersaurus_indexer")
    unlet s:_buffersaurus_indexer
endif
let s:_buffersaurus_indexer = s:NewIndexer()
hi! BuffersaurusFlashMatchedLineHighlight1 guifg=#000000 guibg=#ff00ff ctermfg=0 ctermbg=164 term=reverse
hi! BuffersaurusFlashMatchedLineHighlight2 guifg=#ff00ff guibg=#000000 ctermfg=164 ctermbg=0 term=reverse
" 1}}}

" Completion {{{1
" ==============================================================================
function! buffersaurus#Complete_bsterm(A,L,P)
    let l:possible_matchs = sort(keys(s:_buffersaurus_indexer["element_term_map"]))
    if len(a:A) == 0
        return l:possible_matchs
    endif
    call filter(l:possible_matchs, 'v:val[:' . (len(a:A)-1) . '] ==? ''' . substitute(a:A, "'", "''", 'g') . '''')
    return possible_matchs
endfunction
" 1}}}

" Restore State {{{1
" ============================================================================
" restore options
let &cpo = s:save_cpo
" 1}}}

" vim:foldlevel=4:
