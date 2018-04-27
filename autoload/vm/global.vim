""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Global class
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

let s:Global = {}

fun! vm#global#init()
    let s:V       = b:VM_Selection

    let s:v       = s:V.Vars

    let s:Funcs   = s:V.Funcs
    let s:Search  = s:V.Search
    let s:Edit    = s:V.Edit

    let s:X       = { -> g:VM.extend_mode }
    let s:R       = { -> s:V.Regions      }
    let s:B       = { -> s:v.block_mode && g:VM.extend_mode }

    "make a bytes map of the file, where 0 is unselected, 1 is selected
    call s:Global.reset_byte_map()
    return s:Global
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.get_region() dict
    """Get the region under cursor, or create a new one if there is none."""

    let R = self.is_region_at_pos('.')
    if empty(R) | let R = vm#region#new(0) | endif

    let s:v.matches = getmatches()
    if !s:v.eco
        call self.select_region(R.index)
        call s:Search.check_pattern()
        call s:Funcs.restore_reg() | endif
    return R
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.new_cursor(...) dict
    """Create a new cursor if there is't already a region."""

    let R = self.is_region_at_pos('.')
    if empty(R) | let R = vm#region#new(1) | endif

    let s:v.matches = getmatches()
    return R
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.erase_regions() dict
    """Clear all regions, but stay in visual-multi mode.

    let s:V.Regions = []
    call clearmatches()
    let s:v.index = -1
    let s:v.block = [0,0,0]
    call s:Funcs.count_msg(1)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Change mode
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.change_mode(silent) dict
    let g:VM.extend_mode = !s:X()
    let s:v.silence = a:silent

    if s:X()
        call s:Funcs.count_msg(0, ['Switched to Extend Mode. ', 'WarningMsg'])
        call self.update_regions()
    else
        call s:Funcs.count_msg(0, ['Switched to Cursor Mode. ', 'WarningMsg'])
        call self.collapse_regions()
        call self.select_region(s:v.index)
    endif
endfun


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Highlight
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.update_highlight(...) dict
    """Update highlight for all regions."""

    for r in s:R()
        call r.update_highlight()
    endfor

    call setmatches(s:v.matches)
    call self.update_cursor_highlight()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.update_cursor_highlight(...) dict
    """Set cursor highlight, depending on extending mode."""

    highlight clear MultiCursor

    if s:V.Insert.is_active
        exe "highlight link MultiCursor ".g:VM_Ins_Mode_hl

    elseif !s:X() && self.all_empty()
        exe "highlight link MultiCursor ".g:VM_Mono_Cursor_hl

    else
        exe "highlight link MultiCursor ".g:VM_Normal_Cursor_hl
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Regions functions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.all_empty() dict
    """If not all regions are empty, turn on extend mode, if not already active.

    for r in s:R()
        if r.a != r.b
            if !s:X() | call self.change_mode(0) | endif
            return 0  | endif
    endfor
    return 1
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.update_regions() dict
    """Force regions update."""

    if s:X()
        for r in s:R() | call r.update_region() | endfor
    else
        for r in s:R() | call r.update_cursor() | endfor
    endif
    call self.update_highlight()
    call s:Funcs.restore_reg()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.collapse_regions() dict
    """Collapse regions to cursors and turn off extend mode."""

    call self.reset_byte_map()

    for r in s:R() | call r.update_cursor([r.l, (r.dir? r.a : r.b)]) | endfor
    let g:VM.extend_mode = 0
    call self.update_highlight()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.select_region(i) dict
    """Adjust cursor position of the region at index, then return the region."""
    if !len(s:R()) | return | endif

    let i = a:i >= len(s:R())? 0 : a:i

    let R = s:R()[i]
    call cursor(R.cur_ln(), R.cur_col())
    let s:v.index = R.index
    return R
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.select_region_at_pos(pos) dict
    """Try to select a region at the given position."""

    let r = self.is_region_at_pos(a:pos)
    if !empty(r)
        return self.select_region(r.index)
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.is_region_at_pos(pos) dict
    """Find if the cursor is on a highlighted region.
    "Return an empty dict otherwise."""

    let pos = s:Funcs.pos2byte(a:pos)

    for r in s:R()
        if pos >= r.A && pos <= r.B
            return r | endif | endfor
    return {}
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.overlapping_regions(R) dict
    """Check if two regions are overlapping."""
    let B = s:V.Bytes[a:R.A:a:R.B]
    for b in B | if b > 1 | return 1 | endif | endfor
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.reset_byte_map() dict
    let self.A = line2byte(line('$') + 1) + 1
    let self.B = 0
    let s:V.Bytes = map(range(self.A), 0)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.remove_last_region(...) dict
    """Remove last region and reselect the previous one."""

    for r in s:R()
        if r.id == ( a:0? a:1 : s:v.IDs_list[-1] )
            call r.remove()
            break
        endif
    endfor

    if !len(s:R()) | call s:Funcs.count_msg(1) | return | endif
    call self.select_region(s:v.index)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.update_indices() dict
    """Adjust region indices."""

    let i = 0 | let ix = s:v.index | let nr = len(s:R())
    if !nr    | let s:v.index = -1 | return | endif

    for r in s:R()
        let r.index = i
        let i += 1
    endfor

    if ix >= nr
        let s:v.index = nr - 1
    elseif ix == -1
        let s:v.index = 0
    endif
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.update_region_patterns(pat) dict
    """Update the patterns for the appropriate regions."""

    for r in s:R()
        if a:pat =~ r.pat || r.pat =~ a:pat
            let r.pat = a:pat
        endif
    endfor
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.lines_with_regions(reverse, ...) dict
    """Find lines with regions.""

    let lines = {}
    for r in s:R()
        let sort_list = 0

        "called for a specific line
        if a:0 && r.l != a:1 | continue | endif

        "add region index to indices for that line
        let lines[r.l] = get(lines, r.l, [])

        "mark for sorting if not empty
        if !empty(lines[r.l]) | let sort_list = 1 | endif
        call add(lines[r.l], r.index)

        "sort list so that lower indices are put farther in the list
        if sort_list
            if a:reverse | call reverse(sort(lines[r.l], 'n'))
            else         | call sort(lines[r.l], 'n')            | endif
        endif
    endfor
    return lines
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.reorder_regions() dict
    """Reorder regions, so that their byte offsets are consecutive.

    let As = sort(map(copy(s:R()), 'v:val.A'), 'n')
    let Regions = []
    while 1
        for r in s:R()
            if r.A == As[0]
                call add(Regions, r)
                call remove(As, 0)
                break
            endif
        endfor
        if !len(As) | break | endif
    endwhile
    let s:V.Regions = Regions
    call s:Global.update_indices()
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.split_lines() dict
    """When switching off multiline, split selections, so that each is
    "contained in a single line."""

    let prev = s:v.index

    "make a list of regions to split
    let lts = filter(copy(s:R()), 'v:val.h')

    for r in lts
        let R = s:R()[r.index].remove()

        for n in range(R.h+1)
            if n == 0  "first line
                call vm#region#new(0, R.l, R.l, R.a, len(getline(R.l)))
            elseif n < R.h
                call vm#region#new(0, R.l+n, R.l+n, 1, len(getline(R.l+n)))
            else
                call vm#region#new(0, R.L, R.L, 1, R.b)
            endif
            let s:v.matches = getmatches()
        endfor
    endfor

    "reorder regions when done
    call self.update_highlight()
    call s:Funcs.count_msg(1)
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Merging regions
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.merge_cursors()
    """Merge overlapping cursors."""

    let cursors_pos = map(copy(s:R()), 'v:val.A')
    let cursors_pos = map(cursors_pos, 'count(cursors_pos, v:val) == 1')
    let cursors_ids = map(copy(s:R()), 'v:val.id')

    let i = 0
    for c in cursors_pos
        if !c | call s:Funcs.region_with_id(cursors_ids[i]).remove() | endif
        let i += 1
    endfor
    call self.update_regions()
    let R = self.select_region_at_pos('.')
    call s:Funcs.count_msg(1, ["\n", 'None'])
    return R
endfun

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

fun! s:Global.merge_regions(...) dict
    ""Merge overlapping regions."""
    if !s:X() | call self.merge_cursors() | return | endif

    let storepos = getpos('.')    | let s:v.eco = 1
    let A = self.A                | let B = self.B+1
    let By = copy(s:V.Bytes[A:B]) | let a = 0

    call self.erase_regions()

    for i in range(len(By))
        if By[i] && !a     | let a = i+A
        elseif a && !By[i] | call vm#region#new(0, a, i+A-1) | let a = 0 | endif
    endfor

    call setpos('.', storepos)
    let s:v.eco = 0
    call self.update_regions()
    let R = self.select_region_at_pos('.')
    call s:Funcs.restore_reg()
    call s:Funcs.count_msg(1)
    return R
endfun


