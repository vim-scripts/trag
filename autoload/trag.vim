" trag.vim
" @Author:      Thomas Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     http://www.vim.org/account/profile.php?user_id=4037
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Created:     2007-09-29.
" @Last Change: 2008-02-19.
" @Revision:    0.0.448

if &cp || exists("loaded_trag_autoload")
    finish
endif
let loaded_trag_autoload = 1


function! s:GetFiles() "{{{3
    if !exists('b:trag_files_')
        call trag#SetFiles()
    endif
    if empty(b:trag_files_)
        " echohl Error
        " echoerr 'TRag: No project files'
        " echohl NONE
        echom 'TRag: No project files ... use: '. g:trag_get_files
        let b:trag_files_ = eval(g:trag_get_files)
    endif
    " TLogVAR b:trag_files_
    return b:trag_files_
endf


function! trag#ClearFiles() "{{{3
    let b:trag_files_ = []
endf


function! trag#AddFiles(files) "{{{3
    if tlib#type#IsString(a:files)
        let files_ = eval(a:files)
    else
        let files_ = a:files
    endif
    if !tlib#type#IsList(files_)
        echoerr 'trag_files must result in a list: '. string(a:files)
    elseif exists('b:trag_files_')
        let b:trag_files_ += files_
    else
        let b:trag_files_ = files_
    endif
    unlet files_
endf


" :def: function! trag#SetFiles(?files=[])
function! trag#SetFiles(...) "{{{3
    TVarArg ['files', []]
    call trag#ClearFiles()
    if empty(files)
        unlet! files
        let files = tlib#var#Get('trag_files', 'bg', [])
        " TLogVAR files
        if empty(files)
            let glob = tlib#var#Get('trag_glob', 'bg', '')
            if !empty(glob)
                " TLogVAR glob
                let files = split(glob(glob), '\n')
            else
                let proj = tlib#var#Get('trag_proj_'. &filetype, 'bg', tlib#var#Get('trag_proj', 'bg', ''))
                if !empty(proj)
                    " let proj = fnamemodify(proj, ':p')
                    let proj = findfile(proj, '.;')
                    if filereadable(proj)
                        " TLogVAR proj
                        let files = readfile(proj)
                        let cwd   = getcwd()
                        try
                            call tlib#dir#CD(fnamemodify(proj, ':h'), 1)
                            call map(files, 'fnamemodify(v:val, ":p")')
                        finally
                            call tlib#dir#CD(cwd, 1)
                        endtry
                    endif
                endif
            endif
        endif
    endif
    " TLogVAR files
    if !empty(files)
        call map(files, 'fnamemodify(v:val, ":p")')
        " TLogVAR files
        call trag#AddFiles(files)
    endif
    " TLogVAR b:trag_files_
    if empty(b:trag_files_)
        let files0 = taglist('.')
        " Filter bogus entry?
        call filter(files0, '!empty(v:val.kind)')
        call map(files0, 'v:val.filename')
        call sort(files0)
        let last = ''
        try
            call tlib#progressbar#Init(len(files0), 'TRag: Collect files %s', 20)
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


" Edit a file from the project catalog. See |g:trag_proj| and 
" |:TRagfile|.
function! trag#Edit() "{{{3
    let w = tlib#World#New(copy(g:trag_edit_world))
    let w.base = s:GetFiles()
    call w.SetInitialFilter(matchstr(expand('%:t:r'), '^\w\+'))
    call w.Set_display_format('filename')
    " TLogVAR w.base
    call tlib#input#ListW(w)
endf


" Test j trag
" Test n tragfoo
" Test j trag(foo)
" Test n tragfoo(foo)
" Test j trag
" Test n tragfoo

" TODO:
" If the use of regular expressions alone doesn't meet your demands, you 
" can define the functions trag#Process_{kind}_{filesuffix} or 
" trag#Process_{kind}, which will be run on every line with the 
" arguments: match, line, quicklist, filename, lineno. This function 
" returns [match, line]. If match != -1, the line will be added to the 
" quickfix list.
" If such a function is defined, it will be called for every line.

" :def: function! trag#Grep(args, ?replace=1, ?files=[])
" args: A string with the format:
"   KIND REGEXP
"   KIND1,KIND2 REGEXP
"
" If the variables [bg]:trag_rxf_{kind}_{&filetype} or 
" [bg]:trag_rxf_{kind} exist, these will be taken as format string (see 
" |printf()|) to format REGEXP.
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
    let [kindspos, kindsneg, rx] = s:SplitArgs(a:args)
    if empty(rx)
        throw 'Malformed arguments (should be: "KIND REGEXP"): '. string(a:args)
    endif
    " TLogVAR kindspos, kindsneg, rx
    let qfl = []
    if empty(files)
        let files = s:GetFiles()
    endif
    call tlib#progressbar#Init(len(files), 'TRag: Grep %s', 20)
    if replace
        call setqflist([])
    endif
    let scratch = {}
    try
        let fidx = 0
        for f in files
            " TLogVAR f
            call tlib#progressbar#Display(fidx, ' '. f)
            let rxpos = s:GetRx(f, kindspos, rx, '.')
            let rxneg = s:GetRx(f, kindsneg, rx, '')
            " TLogVAR kindspos, kindsneg, rxpos, rxneg
            let fidx += 1
            if !filereadable(f) || empty(rxpos)
                " TLogDBG 'continue '.filereadable(f) .' '. empty(rxpos)
                continue
            endif
            let fext = fnamemodify(f, ':e')
            let prcacc = []
            " TODO: This currently doesn't work.
            " for kindand in kinds
            "     for kind in kindand
            "         let prc = 'trag#Process_'. kind .'_'. fext
            "         if exists('*'. prc)
            "             call add(prcacc, prc)
            "         else
            "             let prc = 'trag#Process_'. kind
            "             if exists('*'. prc)
            "                 call add(prcacc, prc)
            "             endif
            "         endif
            "     endfor
            " endfor
            " When we don't have to process every line, we slurp the file 
            " into a buffer and use search(), which should be faster than 
            " running match() on every line.
            if empty(prcacc)
                " TLogDBG 'vimgrepadd /'. escape(rxpos, '/') .'/g '. f
                " silent! exec 'vimgrepadd /'. escape(rxpos, '/') .'/gj '. tlib#arg#Ex(f)
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
                let si = search(rxpos, 'cW')
                while si
                    let lnum = line('.')
                    let line = getline(lnum)
                    " TLogVAR lnum, line
                    if empty(rxneg) || line !~ rxneg
                        call add(qfl, {
                                    \ 'filename': f,
                                    \ 'lnum': lnum,
                                    \ 'text': tlib#string#Strip(line),
                                    \ })
                    endif
                    silent! norm! j0
                    let si = search(rxpos, 'cW')
                endwh
                norm! ggdG
            else
                let lnum = 0
                for line in readfile(f)
                    let lnum += 1
                    let m = match(line, rxpos)
                    for prc in prcacc
                        let [m, line] = call(prc, [m, line, qfl, f, lnum])
                    endfor
                    if m != -1
                        call add(qfl, {
                                    \ 'filename': f,
                                    \ 'lnum': lnum,
                                    \ 'text': tlib#string#Strip(line),
                                    \ })
                    endif
                endfor
            endif
            " TLogVAR qfl, replace
            call setqflist(qfl, replace ? 'r' : 'a')
        endfor
    finally
        if !empty(scratch)
            call tlib#scratch#CloseScratch(scratch)
            let &lazyredraw = lazyredraw
        endif
        call tlib#progressbar#Restore()
    endtry
endf


function! s:SplitArgs(args) "{{{3
    let kind = matchstr(a:args, '^\S\+')
    if kind == '.' || kind == '*'
        let kind = ''
    endif
    let rx = matchstr(a:args, '\s\zs.*')
    if stridx(kind, '#') != -1
        let kind = substitute(kind, '#', '', 'g')
        let rx = tlib#rx#Escape(rx)
    endif
    let kinds = split(kind, '!', 1)
    let kindspos = s:SplitArgList(get(kinds, 0, ''), [['identity']])
    let kindsneg = s:SplitArgList(get(kinds, 1, ''), [])
    " TLogVAR a:args, kinds, kind, rx, kindspos, kindsneg
    return [kindspos, kindsneg, rx]
endf


function! s:SplitArgList(string, default) "{{{3
    let rv = map(split(a:string, ','), 'reverse(split(v:val, ''\.'', 1))')
    if empty(rv)
        return a:default
    else
        return rv
    endif
endf


function! trag#ClearCachedRx() "{{{3
    let s:rx_cache = {}
endf
call trag#ClearCachedRx()


function! s:GetRx(filename, kinds, rx, default) "{{{3
    if empty(a:kinds)
        return a:default
    endif
    let rxacc = []
    let ext   = fnamemodify(a:filename, ':e')
    if empty(ext)
        let ext = a:filename
    endif
    let filetype = get(g:trag_filenames, ext, '')
    let id = filetype .'*'.string(a:kinds).'*'.a:rx
    " TLogVAR ext, filetype, id
    if has_key(s:rx_cache, id)
        let rv = s:rx_cache[id]
    else
        for kindand in a:kinds
            let rx= a:rx
            for kind in kindand
                let rxf = tlib#var#Get('trag_rxf_'. kind, 'bg')
                " TLogVAR rxf
                if !empty(filetype)
                    let rxf = tlib#var#Get('trag_rxf_'. kind .'_'. filetype, 'bg', rxf)
                endif
                " TLogVAR rxf
                if empty(rxf)
                    if &verbose > 1
                        if empty(filetype)
                            echom 'Unknown kind '. kind .' for unregistered filetype; skip files like '. ext
                        else
                            echom 'Unknown kind '. kind .' for ft='. filetype .'; skip files like '. ext
                        endif
                    endif
                    return ''
                else
                    " TLogVAR rxf
                    " If the expression is no word, ignore word boundaries.
                    if rx =~ '\W$' && rxf =~ '%\@<!%s\\>'
                        let rxf = substitute(rxf, '%\@<!%s\\>', '%s', 'g')
                    endif
                    if rx =~ '^\W' && rxf =~ '\\<%s'
                        let rxf = substitute(rxf, '\\<%s', '%s', 'g')
                    endif
                    let rx = tlib#string#Printf1(rxf, rx)
                endif
            endfor
            call add(rxacc, rx)
        endfor
        let rv = s:Rx(rxacc, a:default)
        let s:rx_cache[id] = rv
    endif
    " TLogVAR rv
    return rv
endf


function! s:Rx(rxacc, default) "{{{3
    if empty(a:rxacc)
        let rx = a:default
    elseif len(a:rxacc) == 1
        let rx = a:rxacc[0]
    else
        let rx = '\('. join(a:rxacc, '\|') .'\)'
    endif
    return rx
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
    let w.qfl  = copy(getqflist())
    " TLogVAR w.qfl
    let w.base = map(copy(w.qfl), 's:FormatQFLE(v:val)')
    " TLogVAR w.base
    call tlib#input#ListW(w)
endf


function! trag#AgentEditQFE(world, selected, ...) "{{{3
    TVarArg ['cmd_edit', 'edit'], ['cmd_buffer', 'buffer']
    " TLogVAR a:selected
    if empty(a:selected)
        call a:world.RestoreOrigin()
        " call a:world.ResetSelected()
    else
        let idx = a:selected[0] - 1
        if idx >= 0
            let qfe = a:world.qfl[idx]
            " TLogVAR qfe
            call tlib#file#With(cmd_edit, cmd_buffer, [s:GetFilename(qfe)], a:world)
            call tlib#buffer#ViewLine(qfe.lnum)
            " call a:world.SetOrigin()
        endif
    endif
    return a:world
endf 


function! trag#AgentPreviewQFE(world, selected) "{{{3
    let back = a:world.SwitchWindow('win')
    call trag#AgentEditQFE(a:world, a:selected[0:0])
    exec back
    let a:world.state = 'redisplay'
    return a:world
endf


function! trag#AgentGotoQFE(world, selected) "{{{3
    if !empty(a:selected)
        if a:world.win_wnr != winnr()
            let world = tlib#agent#Suspend(a:world, a:selected)
            exec a:world.win_wnr .'wincmd w'
        endif
        call trag#AgentEditQFE(a:world, a:selected[0:0])
    endif
    return a:world
endf


function! trag#AgentWithSelected(world, selected) "{{{3
    let cmd = input('Ex command: ', '', 'command')
    if !empty(cmd)
        for entry in a:selected
            call trag#AgentEditQFE(a:world, [entry])
            exec cmd
        endfor
        call a:world.RestoreOrigin()
        let a:world.state = 'reset'
    else
        let a:world.state = 'redisplay'
    endif
    return a:world
endf


function! trag#AgentSplitBuffer(world, selected) "{{{3
    call a:world.CloseScratch()
    return trag#AgentEditQFE(a:world, a:selected, 'split', 'sbuffer')
endf


function! trag#AgentTabBuffer(world, selected) "{{{3
    call a:world.CloseScratch()
    return trag#AgentEditQFE(a:world, a:selected, 'tabedit', 'tab sbuffer')
endf


function! trag#AgentVSplitBuffer(world, selected) "{{{3
    call a:world.CloseScratch()
    return trag#AgentEditQFE(a:world, a:selected, 'vertical split', 'vertical sbuffer')
endf


" function! trag#AgentOpenBuffer(world, selected) "{{{3
" endf


function! trag#CWord() "{{{3
    if has_key(g:trag_keyword_chars, &filetype)
        let line  = getline('.')
        let chars = g:trag_keyword_chars[&filetype]
        let rx    = '['. chars .']\+'
        let pre   = matchstr(line[0 : col('.') - 2],  rx.'$')
        let post  = matchstr(line[col('.') - 1 : -1], '^'.rx)
        let word  = pre . post
        " TLogVAR word, pre, post, chars, line
    else
        let word  = expand('<cword>')
    endif
    " TLogVAR word
    return word
endf

