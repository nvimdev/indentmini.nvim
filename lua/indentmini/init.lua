local api, UP, DOWN, INVALID = vim.api, -1, 1, -1
local buf_set_extmark, set_provider = api.nvim_buf_set_extmark, api.nvim_set_decoration_provider
local ns = api.nvim_create_namespace('IndentLine')
local ffi = require('ffi')
local opt = {
  only_current = false,
  config = {
    virt_text_pos = 'overlay',
    hl_mode = 'combine',
    ephemeral = true,
  },
}

ffi.cdef([[
  typedef struct {} Error;
  typedef int colnr_T;
  typedef struct window_S win_T;
  typedef struct file_buffer buf_T;
  buf_T *find_buffer_by_handle(int buffer, Error *err);
  int get_sw_value(buf_T *buf);
  typedef int32_t linenr_T;
  int get_indent_lnum(linenr_T lnum);
  char *ml_get(linenr_T lnum);
]])
local C = ffi.C
local ml_get = C.ml_get
local find_buffer_by_handle = C.find_buffer_by_handle
local get_sw_value, get_indent_lnum = C.get_sw_value, C.get_indent_lnum

--- @class Snapshot
--- @field indent? integer
--- @field is_empty? boolean
--- @field is_tab? boolean
--- @field indent_cols? integer
--- @field line_text? string

--- @class Context
--- @field snapshot table<integer, Snapshot>
local context = { snapshot = {} }

--- check text only has space or tab
--- @param text string
--- @return boolean true only have space or tab
local function only_spaces_or_tabs(text)
  return text:match('^[ \t]*$') ~= nil
end

--- @param bufnr integer
--- @return integer the shiftwidth value of bufnr
local function get_shiftw_value(bufnr)
  local handle = find_buffer_by_handle(bufnr, ffi.new('Error'))
  return get_sw_value(handle)
end

--- store the line data in snapshot and update the blank line indent
--- @param lnum integer
--- @return Snapshot
local function make_snapshot(lnum)
  local line_text = ffi.string(ml_get(lnum))
  local is_empty = #line_text == 0 or only_spaces_or_tabs(line_text)
  local indent = is_empty and 0 or get_indent_lnum(lnum)
  if is_empty then
    local prev_lnum = lnum - 1
    while prev_lnum >= 1 do
      if not context.snapshot[prev_lnum] then
        context.snapshot[prev_lnum] = make_snapshot(prev_lnum)
      end
      local sp = context.snapshot[prev_lnum]
      if (not sp.is_empty and sp.indent == 0) or (sp.indent > 0) then
        if sp.indent > 0 then
          indent = sp.indent
        end
        break
      end
      prev_lnum = prev_lnum - 1
    end
  end

  local prev = context.snapshot[lnum - 1]
  if prev and prev.is_empty and prev.indent < indent then
    local prev_lnum = lnum - 1
    while prev_lnum >= 1 do
      local sp = context.snapshot[prev_lnum]
      if not sp or not sp.is_empty or sp.indent >= indent then
        break
      end
      sp.indent = indent
      sp.indent_cols = indent
      prev_lnum = prev_lnum - 1
    end
  end
  local indent_cols = line_text:find('[^ \t]')
  indent_cols = indent_cols and indent_cols - 1 or INVALID
  if is_empty then
    indent_cols = indent
  end
  local snapshot = {
    indent = indent,
    is_empty = is_empty,
    is_tab = line_text:find('^\t') and true or false,
    indent_cols = indent_cols,
  }

  context.snapshot[lnum] = snapshot
  return snapshot
end

--- @param lnum integer
--- @return Snapshot
local function find_in_snapshot(lnum)
  context.snapshot[lnum] = context.snapshot[lnum] or make_snapshot(lnum)
  return context.snapshot[lnum]
end

--- @param row integer
--- @param direction integer UP or DOWN
--- @return integer
--- @return integer
local function range_in_snapshot(row, direction, fn)
  while row >= 0 and row < context.count do
    local sp = find_in_snapshot(row + 1)
    if fn(sp.indent, sp.is_empty, row) then
      return sp.indent, row
    end
    row = row + direction
  end
  return INVALID, INVALID
end

local function out_current_range(row)
  return opt.only_current
    and context.range_srow
    and context.range_erow
    and (row < context.range_srow or row > context.range_erow)
end

local function find_current_range(currow_indent)
  local range_fn = function(indent, empty, row)
    if not empty and indent < currow_indent then
      if row < context.currow then
        context.range_srow = row
      else
        context.range_erow = row
      end
      return true
    end
  end
  range_in_snapshot(context.currow - 1, UP, range_fn)
  range_in_snapshot(context.currow + 1, DOWN, range_fn)
  if context.range_srow and not context.range_erow then
    context.range_erow = context.count - 1
  end
  context.cur_inlevel = math.floor(currow_indent / context.step)
end

local function on_line(_, _, bufnr, row)
  local sp = find_in_snapshot(row + 1)
  if sp.indent == 0 or out_current_range(row) then
    return
  end
  for i = 1, sp.indent - 1, context.step do
    local col = i - 1
    local level = math.floor(col / context.step) + 1
    if level < opt.minlevel or (opt.only_current and level ~= context.cur_inlevel) then
      goto continue
    end
    local row_in_curblock = context.range_srow
      and (row > context.range_srow and row < context.range_erow)
    local higroup = row_in_curblock and level == context.cur_inlevel and 'IndentLineCurrent'
      or 'IndentLine'
    if opt.only_current and row_in_curblock and level ~= context.cur_inlevel then
      higroup = 'IndentLineCurHide'
    end
    if not vim.o.expandtab or sp.is_tab then
      col = level - 1
    end
    if col >= context.leftcol and col < sp.indent_cols then
      opt.config.virt_text[1][2] = higroup
      if sp.is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1 - context.leftcol
      end
      buf_set_extmark(bufnr, ns, row, col, opt.config)
      opt.config.virt_text_win_col = nil
    end
    ::continue::
  end
  if row == context.botrow then
    context = { snapshot = {} }
  end
end

local function on_win(_, winid, bufnr, toprow, botrow)
  if
    bufnr ~= api.nvim_get_current_buf()
    or vim.iter(opt.exclude):find(function(v)
      return v == vim.bo[bufnr].ft or v == vim.bo[bufnr].buftype
    end)
  then
    return false
  end
  context = { snapshot = {} }
  context.step = vim.o.expandtab and get_shiftw_value(bufnr) or vim.bo[bufnr].tabstop
  for i = toprow, botrow do
    context.snapshot[i + 1] = make_snapshot(i + 1)
  end
  api.nvim_win_set_hl_ns(winid, ns)
  context.leftcol = vim.fn.winsaveview().leftcol
  context.count = api.nvim_buf_line_count(bufnr)
  context.currow = api.nvim_win_get_cursor(winid)[1] - 1
  context.botrow = botrow
  local currow_indent = find_in_snapshot(context.currow + 1).indent
  find_current_range(currow_indent)
end

return {
  setup = function(conf)
    conf = conf or {}
    opt.only_current = conf.only_current or false
    opt.exclude = { 'dashboard', 'lazy', 'help', 'markdown', 'nofile', 'terminal', 'prompt' }
    vim.list_extend(opt.exclude, conf.exclude or {})
    opt.config.virt_text = { { conf.char or '│' } }
    opt.minlevel = conf.minlevel or 1
    set_provider(ns, { on_win = on_win, on_line = on_line })
    if opt.only_current and vim.opt.cursorline then
      local bg = api.nvim_get_hl(0, { name = 'CursorLine' }).bg
      api.nvim_set_hl(0, 'IndentLineCurHide', { fg = bg })
    end
  end,
}
