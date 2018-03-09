
if (exists('g:loaded_cflags') || &cp)
    finish
endif

let g:loaded_cflags = 1

if (!exists('g:cxcflags_debug'))
    let g:cxcflags_debug = 0
endif

if !( has('python') || has('python3') )
    finish
endif

if (!exists('g:cxcflags_path'))
    if (!exists('g:cxcflags_project_dir'))
"         echom 'can not find cxcflags_path and cxflags_project_dir'
        finish
    endif
    let g:cxcflags_path = g:cxcflags_project_dir . '/BuildOutput/Modules/flags.h'
endif


" Function: s:CheckProject() {{{2
"
" Quit if no porject defined
"
" function! s:CheckProject()
"     if !exists("g:cxcflags_project_dir")
"         return 0
"     else
"         return 1
"     endif
" endfunction

" Function: s:BuildTags() {{{2
"
" Build cscope tags and connect it
"
" function! s:BuildTags()
"     if s:CheckProject()
"         call s:CXCflagsDebug(0, 'close cs')
"         exec 'cs kill -1'
"         call s:CXCflagsDebug(0, 'bulding tags...')
"         let s:cmd="!cd ".g:cxcflags_project_dir." && find . -name '*.[ch]' -o -name '*.[ch]pp' > source_list.txt && sed -i '/ /d' source_list.txt && cscope -qbR -i source_list.txt && cd -"
"         call s:CXCflagsDebug(0, 'cmd: '.s:cmd)
"         exec s:cmd
"         call s:ConnectScope()
"     else
"         call s:CXCflagsDebug(0, "No Project Root defined!")
"     endif
" endfunction
" }}}

" Function: s:ConnectScope() {{{2
"
" Connect cscope.out
"
" function! s:ConnectScope()
"     if s:CheckProject()
"         let s:cscope_fn = g:cxcflags_project_dir . '/cscope.out'
"         if filereadable(s:cscope_fn)
"             exec 'cs add ' . s:cscope_fn
"             call s:CXCflagsDebug(0, 'cscope.out connected.')
"         else
"             call s:CXCflagsDebug(0, 'cscope.out not found.')
"         endif
"     endif
" endfunction
" }}}

" Function: s:CXCflagsDebug(level, text) {{{2
"
" output debug message, if this message has high enough importance
"
function! s:CXCflagsDebug(level, text)
  if (g:cxcflags_debug >= a:level)
    echom "cxcflags: " . a:text
  endif
endfunction

" command! CXTagsBuild call s:BuildTags()





python << EOF
import vim
import os
import sys
import re

if 'g_last_flag_file_stat' not in globals():
    g_last_flag_file_stat = {}

g_flag_file_path = vim.eval('g:cxcflags_path')
g_showed_err = False

def pyFindFlag(flagfn, flagstr='', ret_dict=False):
    # Check flagfn exists
    global g_showed_err
    if not os.path.isfile(flagfn):
        if not g_showed_err:
            print "File [%s] does NOT exist!" % flagfn
            g_showed_err = True
        if ret_dict:
            return {}
        return None

    # Check size and time changed
    global g_last_flag_file_stat
    stat = os.stat(flagfn)
    need_update = False
    if 'fn' not in g_last_flag_file_stat:
        need_update = True
    elif g_last_flag_file_stat['fn'] != flagfn:
        need_update = True
    elif g_last_flag_file_stat['size'] != stat.st_size:
        need_update = True
    elif g_last_flag_file_stat['mtime'] != stat.st_mtime:
        need_update = True

    if need_update:
        print("Update flags ...")
        # Parse all flag files
        flag_dict = {}
        #print("Parse file: %s" % f)
        with open(flagfn, 'r') as fh:
            for line in fh:
                ll = line.strip().split()
                if len(ll) != 3:
                    continue
                if not ll[0] == '#define':
                    continue
                flag_dict[ll[1]] = ll[2]
        # save all info
        g_last_flag_file_stat = {'fn': flagfn, 'size': stat.st_size, 'mtime': stat.st_mtime, 'flag_dict': flag_dict}
    else:
        # print("No need to update flags")
        flag_dict = g_last_flag_file_stat['flag_dict']

    if ret_dict:
        return flag_dict

    # Search flag in dat
    if flagstr in flag_dict.keys():
        ret = flag_dict[flagstr]
        print("%s : %s" % (flagstr, ret))
    else:
        ret = None
        print("%s : Not Found!" % (flagstr))


ORIG_STR = r'''
syn region cCppOutWrapper start="^\s*\(%:\|#\)\s*if\s\+__0KEY__\s*\($\|//\|/\*\|&\)" end=".\@=\|$" contains=cCppOutIf,cCppOutElse,@NoSpell fold
syn region cCppOutIf contained start="__0KEY__" matchgroup=cCppOutWrapper end="^\s*\(%:\|#\)\s*endif\>" contains=cCppOutIf2,cCppOutElse
syn region cCppOutIf2 contained matchgroup=cCppOutWrapper start="__0KEY__" end="^\s*\(%:\|#\)\s*\(else\>\|elif\s\+\(__0KEY__\s*\($\|//\|/\*\|&\)\)\@!\|endif\>\)"me=s-1 contains=cSpaceError,cCppOutSkip,@Spell fold
syn region cCppOutElse contained matchgroup=cCppOutWrapper start="^\s*\(%:\|#\)\s*\(else\|elif\)" end="^\s*\(%:\|#\)\s*endif\>"me=s-1 contains=TOP,cPreCondit
syn region cCppInWrapper start="^\s*\(%:\|#\)\s*if\s\+__1KEY__\s*\($\|//\|/\*\||\)" end=".\@=\|$" contains=cCppInIf,cCppInElse fold
syn region cCppInIf contained matchgroup=cCppInWrapper start="__01KEY__" end="^\s*\(%:\|#\)\s*endif\>" contains=TOP,cPreCondit
syn region cCppInElse contained start="^\s*\(%:\|#\)\s*\(else\>\|elif\s\+\(__1KEY__\s*\($\|//\|/\*\||\)\)\@!\)" end=".\@=\|$" containedin=cCppInIf contains=cCppInElse2 fold
syn region cCppInElse2 contained matchgroup=cCppInWrapper start="^\s*\(%:\|#\)\s*\(else\|elif\)\([^/]\|/[^/*]\)*" end="^\s*\(%:\|#\)\s*endif\>"me=s-1 contains=cSpaceError,cCppOutSkip,@Spell
syn region cCppOutSkip contained start="^\s*\(%:\|#\)\s*\(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\(%:\|#\)\s*endif\>" contains=cSpaceError,cCppOutSkip
syn region cCppInSkip contained matchgroup=cCppInWrapper start="^\s*\(%:\|#\)\s*\(if\s\+\(__01KEY__\s*\($\|//\|/\*\||\|&\)\)\@!\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\(%:\|#\)\s*endif\>" containedin=cCppOutElse,cCppInIf,cCppInSkip contains=TOP,cPreProc
'''


class ClassDefines():
    def __init__(self):
        self._0key = []
        self._1key = []
        self._key_dict = None

    def add_define(self, flagfn, flagstr):
        if self._key_dict is None:
            self._key_dict = pyFindFlag(flagfn, ret_dict=True)
            if self._key_dict is None:
                return
        val = self._eval_expr(flagstr)
        if val is None:
            return
        if val:
            self._1key.append(flagstr)
        else:
            self._0key.append(flagstr)
        
    def exec_defines(self):
        str0key = '\(' + '\|'.join(self._0key) + '\)'
        str1key = '\(' + '\|'.join(self._1key) + '\)'
        str01key = '\(' + '\|'.join(self._0key + self._1key) + '\)'

        cmdl = []
        for line in ORIG_STR.split('\n'):
            line = line.strip()
            if line.find('__0KEY__') != -1:
                cmdl.append(line.replace('__0KEY__', str0key))
            elif line.find('__1KEY__') != -1:
                cmdl.append(line.replace('__1KEY__', str1key))
            elif line.find('__01KEY__') != -1:
                cmdl.append(line.replace('__01KEY__', str01key))

        for cmd in cmdl:
            cmd = cmd.replace('!', '\!')
            vim.command(cmd)

    def _eval_expr(self, expr):
        left = expr.replace('&&', ' and ').replace('||', ' or ').replace('!', ' not ').replace('(', ' ( ').replace(')', ' ) ')
        new = []
        for x in left.split():
            if x in self._key_dict:
                new.append(self._key_dict[x])
            else:
                new.append(x)
        try:
            eret = eval(' '.join(new))
        except:
            return None
        else:
            return eret

LINE_DEF_M = re.compile(r'^\s*#\s*(if|elif)\s+(?P<flag>.+)\s*')
def pyAddDefinesFromBuffer():
    defines = ClassDefines()
    b = vim.current.buffer
    for i in range(len(b)):
        line = b[i].strip()
        pos = line.find(r'//')
        if pos != -1:
            line = line[:pos]
        pos = line.find(r'/*')
        if pos != -1:
            line = line[:pos]
        ret = LINE_DEF_M.match(line)
        if ret:
            flagstr = ret.group('flag')
            defines.add_define(g_flag_file_path, flagstr)

    defines.exec_defines()
EOF


function! FindFlag(flagstr)
python << EOF
    flagstr = vim.eval("a:flagstr")
    pyFindFlag(g_flag_file_path, flagstr)
EOF
endfunction


function! AddDefinesFromBuffer()
python <<EOF
    pyAddDefinesFromBuffer()
EOF
endfunction

" function! AddDefines()
" python <<EOF
"     defines = ClassDefines()
"     flagfn = g_flag_file_path
" # defines.add_define(flagfn, '!MEGACACHE')
" # defines.add_define(flagfn, 'WRONG_FLAG')
" # defines.add_define(flagfn, 'DRIVE_TRUST')
" # defines.add_define(flagfn, 'QNR_BOOT_FIRMWARE')
" # defines.add_define(flagfn, 'SCSI_CMD_SET')
" # defines.add_define(flagfn, 'SSI_COMMON && ALLOW_16_BYTE_CDB && DRIVE_TRUST')
" defines.exec_defines()
" EOF
" endfunction
" " }}}



nnoremap <silent> <C-K> : call FindFlag(expand("<cword>"))<cr>
nnoremap <silent> <C-J> : call AddDefinesFromBuffer()<cr>
" nnoremap <silent> <C-H> : call AddDefines()<cr>
augroup test_group1
    autocmd!
" autocmd BufWinLeave * exec 'echom "  -> hidden:' . escape(expand("%:p"), '\') . '"'
    autocmd BufWinEnter * call AddDefinesFromBuffer()
augroup END


