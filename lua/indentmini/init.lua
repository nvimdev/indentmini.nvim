local api, UP, DOWN, INVALID = vim.api, -1, 1, -1
local buf_set_extmark, set_provider = api.nvim_buf_set_extmark, api.nvim_set_decoration_provider
local ns = api.nvim_create_namespace('IndentLine')
local ffi = require('ffi')
local only_current = false
local opt = {
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
  colnr_T ml_get_len(linenr_T lnum);
  size_t strlen(const char *__s);
]])

local C = ffi.C
local ml_get, ml_get_len = C.ml_get, C.ml_get_len
local find_buffer_by_handle = C.find_buffer_by_handle
local get_sw_value, get_indent_lnum = C.get_sw_value, C.get_indent_lnum
local cache = { snapshot = {} }

--- check text only has space or tab
--- @param text string
--- @return boolean true only have space or tab
local function only_spaces_or_tabs(text)
  return text:match('^[ \t]*$') ~= nil
end

--- @param lnum integer
--- @return boolean true when is true line is empty
local function line_is_empty(lnum)
  return tonumber(ml_get_len(lnum)) == 0 or only_spaces_or_tabs(ffi.string(ml_get(lnum)))
end

--- @param bufnr integer
--- @return integer the shiftwidth value of bufnr
local function get_shiftw_value(bufnr)
  local handle = find_buffer_by_handle(bufnr, ffi.new('Error'))
  return get_sw_value(handle)
end

--- @param line string text of line
--- @param col integer column
--- @return boolean
local function non_or_space(line, col)
  local text = line:sub(col, col)
  return text and (#text == 0 or text == ' ' or text == '\t') or false
end

--- @param lnum integer
--- @return integer, boolean
local function find_in_snapshot(lnum)
  cache.snapshot[lnum] = cache.snapshot[lnum]
    or { get_indent_lnum(lnum), line_is_empty(lnum), ffi.string(ml_get(lnum)) }
  return unpack(cache.snapshot[lnum])
end

--- @param row integer
--- @param direction integer UP or DOWN
--- @return integer
--- @return integer
local function range_in_snapshot(row, direction, fn)
  while row >= 0 and row < cache.count do
    local indent, is_empty = find_in_snapshot(row + 1)
    if fn(indent, is_empty, row) then
      return indent, row
    end
    row = row + direction
  end
  return INVALID, INVALID
end

local function out_current_range(row)
  return only_current and cache.range_srow and (row < cache.range_srow or row > cache.range_erow)
end

local function update_cache_range(currow_indent)
  local range_fn = function(indent, empty, row)
    if not empty and indent < currow_indent then
      if row < cache.currow then
        cache.range_srow = row
      else
        cache.range_erow = row
      end
      return true
    end
  end
  range_in_snapshot(cache.currow - 1, UP, range_fn)
  range_in_snapshot(cache.currow + 1, DOWN, range_fn)
  cache.cur_inlevel = math.floor(currow_indent / cache.step)
end

--- @class Context
--- @field row integer
--- @field indent_above integer
--- @field indent_below integer
---
--- @param row integer
--- @return Context
local function init_context(row)
  return {
    row = row,
    indent_above = INVALID,
    indent_below = INVALID,
  }
end

--- @param ctx Context
--- @return boolean true the row in code block otherwise not
local function row_in_code_block(ctx)
  local function lookup_first_seen(_, empty)
    return not empty
  end
  ctx.indent_above = range_in_snapshot(ctx.row - 1, UP, lookup_first_seen)
  ctx.indent_below = range_in_snapshot(ctx.row + 1, DOWN, lookup_first_seen)
  return not (ctx.indent_above == 0 and ctx.indent_below == 0)
end

local function on_line(_, _, bufnr, row)
  local indent, is_empty, line_text = find_in_snapshot(row + 1)
  local ctx = init_context(row)
  if (is_empty and not row_in_code_block(ctx)) or out_current_range(row) then
    return
  end

  if is_empty and indent == 0 then
    indent = math.max(ctx.indent_above, ctx.indent_below)
    cache.snapshot[row + 1][1] = indent
  end

  for i = 1, indent - 1, cache.step do
    local col = i - 1
    local level = math.floor(col / cache.step) + 1
    if level < opt.minlevel or (only_current and level ~= cache.cur_inlevel) then
      goto continue
    end
    local row_in_curblock = cache.range_srow and (row > cache.range_srow and row < cache.range_erow)
    local higroup = row_in_curblock and level == cache.cur_inlevel and 'IndentLineCurrent'
      or 'IndentLine'
    if only_current and row_in_curblock and level ~= cache.cur_inlevel then
      higroup = 'IndentLineCurHide'
    end
    if not vim.o.expandtab or line_text:find('^\t') then
      col = level - 1
    end
    if col >= cache.leftcol and non_or_space(line_text, col + 1) then
      opt.config.virt_text[1][2] = higroup
      if is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1 - cache.leftcol
      end
      buf_set_extmark(bufnr, ns, row, col, opt.config)
      opt.config.virt_text_win_col = nil
    end
    ::continue::
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
  cache = { snapshot = {} }
  for i = toprow, botrow do
    cache.snapshot[i + 1] =
      { get_indent_lnum(i + 1), line_is_empty(i + 1), ffi.string(ml_get(i + 1)) }
  end
  api.nvim_win_set_hl_ns(winid, ns)
  cache.leftcol = vim.fn.winsaveview().leftcol
  cache.step = vim.o.expandtab and get_shiftw_value(bufnr) or vim.bo[bufnr].tabstop
  cache.count = api.nvim_buf_line_count(bufnr)
  cache.currow = api.nvim_win_get_cursor(winid)[1] - 1
  local currow_indent = find_in_snapshot(cache.currow + 1)
  update_cache_range(currow_indent)
end

return {
  setup = function(conf)
    conf = conf or {}
    only_current = conf.only_current or false
    opt.exclude = { 'dashboard', 'lazy', 'help', 'markdown', 'nofile', 'terminal', 'prompt' }
    vim.list_extend(opt.exclude, conf.exclude or {})
    opt.config.virt_text = { { conf.char or '│' } }
    opt.minlevel = conf.minlevel or 1
    set_provider(ns, { on_win = on_win, on_line = on_line })
    if only_current and vim.opt.cursorline then
      local bg = api.nvim_get_hl(0, { name = 'CursorLine' }).bg
      api.nvim_set_hl(0, 'IndentLineCurHide', { fg = bg })
    end
  end,
}
