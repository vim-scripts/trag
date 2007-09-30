" trag.vim -- Jump to a file registered in your tags
" @Author:      Thomas Link (micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2007-09-29.
" @Last Change: 2007-09-30.
" @Revision:    0.1.250
" GetLatestVimScripts: 0 1 trag.vim

if &cp || exists("loaded_trag")
    finish
endif
if !exists('g:loaded_tlib') || g:loaded_tlib < 15
    echoerr 'tlib >= 0.15 is required'
    finish
endif
let loaded_trag = 1

let s:save_cpo = &cpo
set cpo&vim


" :nodoc:
TLet g:trag_modes = {}

" :nodoc:
function! s:TRagDefMode(args) "{{{3
    " TLogVAR a:args
    " TLogDBG string(matchlist(a:args, '^\(\S\+\)\s\+\(\S\+\)\s\+/\(.\{-}\)/$'))
    let [match, mode, filetype, regexp; rest] = matchlist(a:args, '^\(\S\+\)\s\+\(\S\+\)\s\+/\(.\{-}\)/$')
    let var = ['g:trag_rxf', mode]
    if filetype != '*' && filetype != '.'
        call add(var, filetype)
    endif
    let varname = join(var, '_')
    let {varname} = regexp
    if has_key(g:trag_modes, mode)
        call add(g:trag_modes[mode], filetype)
    else
        let g:trag_modes[mode] = [filetype]
    endif
endf

" :display: :TRagDefMode MODE FILETYPE /REGEXP/
" Examples: >
"   TRagDefMode v * /\C\<%s\>\s*=[^=~<>]/
"   TRagDefMode v ruby /\C\<%s\>\(\s*,\s*[[:alnum:]_@$]\+\s*\)*\s*=[^=~<>]/
command! -nargs=1 TRagDefMode call s:TRagDefMode(<q-args>)


" A mostly general rx format string for variable definitions.
TRagDefMode v * /\C\<%s\>\s*=[^=~<>]/

" A mostly general rx format string for variable definitions that 
" contain a string.
TRagDefMode V * /\C%s\S*\s*=[^=~<>]/

" A mostly general rx format string for function calls.
TRagDefMode f * /\C\<%s\>\s*(/

" A mostly general rx format string for fuzzy function calls.
TRagDefMode F * /\C%s\S*\s*(/

" A mostly general rx format string for words.
TRagDefMode w * /\C\<%s\>/

TRagDefMode d ruby /\C\<\(def\s\+\(\u\w*\.\)*\|attr\(_\w\+\)\?\s\+\(:\w\+,\s\+\)*:\)%s\>/
TRagDefMode D ruby /\C\<\(def\s\+\(\u\w*\.\)*\|attr\(_\w\+\)\?\s\+\(:\w\+,\s\+\)*:\).\{-}%s/
TRagDefMode f ruby /\C\(\<def\s\+\(\u\w*\.\)*\|:\)\@<!\<%s\>\s*\([(;]\|$\)/
TRagDefMode c ruby /\C\<class\s\+\(\u\w*::\)*%s\>/
TRagDefMode m ruby /\C\<module\s\+\(\u\w*::\)*%s\>/
TRagDefMode v ruby /\C\<%s\>\(\s*,\s*[[:alnum:]_@$]\+\s*\)*\s*=[^=~<>]/


" :nodoc:
TLet g:trag_edit_world = {
            \ 'type': 's',
            \ 'query': 'Select file',
            \ 'pick_last_item': 1,
            \ 'scratch': '__TRagEdit__',
            \ 'return_agent': 'tlib#agent#ViewFile',
            \ }


" :nodoc:
TLet g:trag_qfl_world = {
            \ 'type': 'si',
            \ 'query': 'Select entry',
            \ 'pick_last_item': 0,
            \ 'resize_vertical': 0,
            \ 'resize': 20,
            \ 'scratch': '__TRagQFL__',
            \ 'tlib_UseInputListScratch': 'syn match TTagedFilesFilename / \zs.\{-}\ze|\d\+| / | syn match TTagedFilesLNum /|\d\+|/ | hi def link TTagedFilesFilename Directory | hi def link TTagedFilesLNum LineNr',
            \ 'key_handlers': [
                \ {'key': 16, 'agent': 'trag#PreviewQFE',  'key_name': '<c-p>', 'help': 'Preview'},
                \ {'key': 60, 'agent': 'trag#GotoQFE',     'key_name': '<',     'help': 'Jump (don''t close the list)'},
            \ ],
            \ 'return_agent': 'trag#EditQFE',
            \ }


" :display: :TRag[!] MODE REGEXP
" Run |:TRagsearch| and instantly display the result with |:TRagcw|.
" See |trag#Grep()| for help on the arguments.
" Examples: >
"   " Find any matches
"   TRag . foo
"
"   " Find as word
"   TRag w foo
"
"   " Find variable definitions like: foo = 1
"   TRag v foo
"
"   " Find function calls like: foo(a, b)
"   TRag f foo
command! -nargs=1 -bang -bar TRag TRagsearch<bang> <args> | TRagcw


" :display: :TRagfile
" Edit a file registered in your tag files.
command! TRagfile call trag#Edit()


" :display: :TRagcw
" Display a quick fix list using |tlib#input#ListD()|.
command! TRagcw call trag#QuickList()


" :display: :TRagsearch[!] MODE REGEXP
" Scan the files registered in your tag files for REGEXP. Generate a 
" quickfix list. With [!], append to the given list. The quickfix list 
" can be fewed with commands like |:cw| or |:TRagcw|.
"
" The REGEXP has to match a single line. This uses |readfile()| and the 
" scans the lines. This is an alternative to |:vimgrep|.
" If you choose your identifiers wisely, this should guide you well 
" through your sources.
" See |trag#Grep()| for help on the arguments.
command! -nargs=1 -bang -bar TRagsearch call trag#Grep(<q-args>, empty("<bang>"))


" :display: :TRaggrep MODE REGEXP GLOBPATTERN
" A 80%-replacement for grep.
"
" Example: >
"   :TRaggrep . foo *.vim
" < 
" Note: In comparison with |:vimgrep| or |:grep|, this comand still 
" takes an extra |trag-modes| argument.
command! -nargs=+ -bang -bar TRaggrep
            \ let g:trag_grepargs = [<f-args>]
            \ | call trag#Grep(g:trag_grepargs[0] .' '. g:trag_grepargs[1], empty("<bang>"), split(glob(g:trag_grepargs[2]), "\n"))
            \ | unlet g:trag_grepargs
            \ | TRagcw


" :display: :TRagsetfiles [FILELIST]
" The file list is set only once per buffer. If the list of the project 
" files has changed, you have to run this command on order to reset the 
" per-buffer list.
"
" If no filelist is given, collect the files in your tags files.
"
" Examples: >
"   :TRagsetfiles
"   :TRagsetfiles split(glob('foo*.txt'), '\n')
command! -nargs=? -bar TRagsetfiles call trag#SetFiles(<args>)


let &cpo = s:save_cpo
unlet s:save_cpo
