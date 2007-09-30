" trag.vim
" @Author:      Thomas Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2007-09-29.
" @Last Change: 2007-09-30.
" @Revision:    0.0.172

if &cp || exists("loaded_trag_autoload")
    finish
endif
let loaded_trag_autoload = 1


function! s:GetFiles() "{{{3
    if !exists('b:trag_files_')
        call trag#SetFiles()
    endif
    return b:trag_files_
endf


" :def: function! trag#SetFiles(?files=[])
function! trag#SetFiles(...) "{{{3
    TVarArg ['files', []]
    if empty(files)
        unlet files
        let files = tlib#var#Get('trag_files', 'wbg', [])
    endif
    if !empty(files)
        if tlib#type#IsString(files)
            let b:trag_files_ = eval(files)
        else
            let b:trag_files_ = files
        endif
        if !tlib#type#IsList(b:trag_files_)
            echoerr 'trag_files must result in a list: '. string(files)
            unlet b:trag_files_
            let b:trag_files_ = []
        endif
    else
        let b:trag_files_ = []
    endif
    if empty(b:trag_files_)
        let files0 = taglist('.')
        " Filter bogus entry?
        call filter(files0, '!empty(v:val.kind)')
        call map(files0, 'v:val.filename')
        call sort(files0)
        let last = ''
        call tlib#progressbar#Init(len(files0), 'TRag: Collect files %s', 20)
        try
            let fidx = 0
            for f in files0
                call tlib#progressbar#Display(fidx)
                let fidx += 1
                " if f != last && filereadable(f)
                if f != last
                    call add(b:trag_files_, f)
                    let last = f
                endif
            endfor
        finally
            call tlib#progressbar#Restore()
        endtry
    endif
endf


function! trag#Edit() "{{{3
    let w = tlib#World#New(copy(g:trag_edit_world))
    let w.base = s:GetFiles()
    call w.Set_display_format('filename')
    " TLogVAR w.base
    call tlib#input#ListW(w)
endf


function! s:SplitArgs(args) "{{{3
    let mode = matchstr(a:args, '^\S\+')
    if mode == '.' || mode == '*'
        let mode = ''
    endif
    let rx = matchstr(a:args, '\s\zs.*')
    if stridx(mode, '#') != -1
        let mode = substitute(mode, '#', '', 'g')
        let rx = tlib#rx#Escape(rx)
    endif
    return [mode, rx]
endf


" :def: function! trag#Grep(args, ?replace=1, ?files=[])
" args: A string with the format: MODE REGEXP
"
" If the variables [bg]:trag_rxf_{mode}_{&filetype} or 
" [bg]:trag_rxf_{mode} exist, these will be taken as format string (see 
" |printf()|) to format REGEXP.
" 
" If the use of regular expressions alone doesn't meet your demands, you 
" can define the functions trag#Process_{mode}_{filesuffix} or 
" trag#Process_{mode}, which will be run on every line with the 
" arguments: match, line, quicklist, filename, lineno. This function 
" returns [match, line]. If match != -1, the line will be added to the 
" quickfix list.
" If such a function is defined, it will be called for every line.
"
" EXAMPLE:
" trag#Grep('v foo') will find by default take g:trag_rxf_v and find 
" lines that looks like "\<foo\>\s*=[^=~]", which most likely is a 
" variable definition in many programming languages. I.e. it will find 
" lines like: >
"   foo = 1
" < but not: >
"   def foo(bar)
"   call foo(bar)
"   if foo == 1
function! trag#Grep(args, ...) "{{{3
    TVarArg ['replace', 1], ['files', []]
    let [mode, rx] = s:SplitArgs(a:args)
    if empty(rx)
        echoerr 'Malformed arguments (should be: "MODE REGEXP"): '. string(a:args)
    endif
    let rxf = tlib#var#Get('trag_rxf_'. mode .'_'. &filetype, 'bg', tlib#var#Get('trag_rxf_'. mode, 'bg'))
    if !empty(rxf)
        " If the expression is no word, ignore word boundaries.
        if rx =~ '\W$' && rxf =~ '%\@<!%s\\>'
            let rxf = substitute(rxf, '%\@<!%s\\>', '%s', 'g')
        endif
        if rx =~ '^\W' && rxf =~ '\\<%s'
            let rxf = substitute(rxf, '\\<%s', '%s', 'g')
        endif
        let rx = printf(rxf, rx)
    endif
    if !empty(mode) && empty(rxf)
        echoerr 'Mode '. mode .' is defined for: '. join(get(g:trag_modes, mode, []), ', ')
        throw 'Unknown mode '. mode .' for ft='. &filetype .': '. a:args
    endif
    " TLogVAR mode, prc, rxf, rx
    let qfl = []
    if empty(files)
        let files = s:GetFiles()
    endif
    call tlib#progressbar#Init(len(files), 'TRag: Grep %s', 20)
    let scratch = {}
    try
        let fidx = 0
        for f in files
            call tlib#progressbar#Display(fidx, ' '. f)
            let fidx += 1
            if !filereadable(f)
                continue
            endif
            let prc = 'trag#Process_'. mode .'_'. fnamemodify(f, ':e')
            if !exists('*'. prc)
                let prc = 'trag#Process_'. mode
                if !exists('*'. prc)
                    let prc = ''
                endif
            endif
            " When we don't have to process every line, we slurp the file 
            " into a buffer and use search(), which should be faster than 
            " running match() on every line.
            if empty(prc)
                if empty(scratch)
                    let scratch = {'scratch': '__TRagFileScratch__'}
                    call tlib#scratch#UseScratch(scratch)
                    resize 1
                    let lazyredraw = &lazyredraw
                    set lazyredraw
                endif
                norm! ggdG
                exec 'silent 0read '. tlib#arg#Ex(f)
                norm! gg
                let si = search(rx, 'cW')
                while si
                    let lnum = line('.')
                    call add(qfl, {
                                \ 'filename': f,
                                \ 'lnum': lnum,
                                \ 'text': tlib#string#Strip(getline(lnum)),
                                \ })
                    let si = search(rx, 'W')
                endwh
                norm! ggdG
            else
                let lnum = 0
                for line in readfile(f)
                    let lnum += 1
                    let m = match(line, rx)
                    if !empty(prc)
                        let [m, line] = call(prc, [m, line, qfl, f, lnum])
                    endif
                    if m != -1
                        call add(qfl, {
                                    \ 'filename': f,
                                    \ 'lnum': lnum,
                                    \ 'text': tlib#string#Strip(line),
                                    \ })
                        " \ 'pattern': rx,
                        " \ 'col': m + 1,
                    endif
                endfor
            endif
        endfor
    finally
        if !empty(scratch)
            call tlib#scratch#CloseScratch(scratch)
            let &lazyredraw = lazyredraw
        endif
        call tlib#progressbar#Restore()
    endtry
    call setqflist(qfl, replace ? 'r' : 'a')
endf


function! s:GetFilename(qfe) "{{{3
    let filename = get(a:qfe, 'filename')
    if empty(filename)
        let filename = bufname(get(a:qfe, 'bufnr'))
    endif
    return filename
endf

function! s:FormatQFLE(qfe) "{{{3
    let filename = s:GetFilename(a:qfe)
    " let err = get(v:val, "type") . get(v:val, "nr")
    " return printf("%20s|%d|%s: %s", filename, v:val.lnum, err, get(v:val, "text"))
    return printf("%s|%d| %s", filename, a:qfe.lnum, get(a:qfe, "text"))
endf


function! trag#QuickList() "{{{3
    let w = tlib#World#New(copy(g:trag_qfl_world))
    let w.qfl  = getqflist()
    let w.base = map(copy(w.qfl), 's:FormatQFLE(v:val)')
    " TLogVAR w.base
    call tlib#input#ListW(w)
endf


function! trag#EditQFE(world, selected) "{{{3
    if !empty(a:selected)
        let idx = a:world.GetBaseIdx(a:selected[0]) - 1
        if idx >= 0
            let qfe = a:world.qfl[idx]
            " TLogVAR qfe, a:selected[0]
            call tlib#file#With('edit', 'buffer', [s:GetFilename(qfe)], a:world)
            call tlib#buffer#ViewLine(qfe.lnum)
        endif
    endif
endf 


function! trag#PreviewQFE(world, selected) "{{{3
    let back = a:world.SwitchWindow('win')
    call trag#EditQFE(a:world, a:selected[0:0])
    exec back
    let a:world.state = 'redisplay'
    return a:world
endf


function! trag#GotoQFE(world, selected) "{{{3
    if !empty(a:selected)
        if a:world.win_wnr != winnr()
            let world = tlib#agent#Suspend(a:world, a:selected)
            exec a:world.win_wnr .'wincmd w'
        endif
        call trag#EditQFE(a:world, a:selected[0:0])
    endif
    return a:world
endf


