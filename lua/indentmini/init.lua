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

local function line_is_empty(lnum)
  return tonumber(ml_get_len(lnum)) == 0
end

local function get_shiftw_value(bufnr)
  local handle = find_buffer_by_handle(bufnr, ffi.new('Error'))
  return get_sw_value(handle)
end

local function non_or_space(line, col)
  local text = line:sub(col, col)
  return text and (#text == 0 or text == ' ' or text == '\t') or false
end

local function find_in_snapshot(lnum)
  cache.snapshot[lnum] = cache.snapshot[lnum] or { get_indent_lnum(lnum), line_is_empty(lnum) }
  return unpack(cache.snapshot[lnum])
end

local function find_row(row, curindent, direction, render)
  local target_row = row + direction
  while true do
    if target_row < 0 or target_row > cache.count - 1 then
      return INVALID
    end
    local target_indent, empty = find_in_snapshot(target_row + 1)
    if empty == nil then
      return INVALID
    end
    if target_indent == 0 and not empty and render then
      break
    elseif not empty and (render and target_indent > curindent or target_indent < curindent) then
      return target_row
    end
    target_row = target_row + direction
  end
  return INVALID
end

local function current_line_range(row, step)
  local indent, _ = find_in_snapshot(row + 1)
  if indent == 0 then
    return INVALID, INVALID, INVALID
  end
  local top_row = find_row(row, indent, UP, false)
  local bot_row = find_row(row, indent, DOWN, false)
  return top_row, bot_row, math.floor(indent / step)
end

local function out_current_range(row)
  return only_current and (row < cache.range_srow or row > cache.range_erow)
end

local function on_line(_, _, bufnr, row)
  local indent, is_empty = find_in_snapshot(row + 1)
  if is_empty == nil or out_current_range(row) then
    return
  end
  local top_row, bot_row
  if indent == 0 and is_empty then
    top_row = find_row(row, indent, UP, true)
    bot_row = find_row(row, indent, DOWN, true)
    local top_indent = top_row >= 0 and find_in_snapshot(top_row + 1) or 0
    local bot_indent = bot_row >= 0 and find_in_snapshot(bot_row + 1) or 0
    indent = math.max(top_indent, bot_indent)
  end
  local line = ffi.string(ml_get(row + 1))
  for i = 1, indent - 1, cache.step do
    local col = i - 1
    local level = math.floor(col / cache.step) + 1
    if level < opt.minlevel or (only_current and level ~= cache.cur_inlevel) then
      goto continue
    end
    local higroup = 'IndentLine'
    if row > cache.range_srow and row < cache.range_erow then
      higroup = level == cache.cur_inlevel and 'IndentLineCurrent' or 'IndentLineCurHide'
    end
    if not vim.o.expandtab or line:find('^\t') then
      col = level - 1
    end
    if col >= cache.leftcol and non_or_space(line, col + 1) then
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
  api.nvim_win_set_hl_ns(winid, ns)
  cache.leftcol = vim.fn.winsaveview().leftcol
  cache.step = vim.o.expandtab and get_shiftw_value(bufnr) or vim.bo[bufnr].tabstop
  cache.count = api.nvim_buf_line_count(bufnr)
  cache.currow = api.nvim_win_get_cursor(winid)[1] - 1
  cache.range_srow, cache.range_erow, cache.cur_inlevel =
    current_line_range(cache.currow, cache.step)
  if only_current then
    toprow, botrow = cache.currow, cache.currow
  end
  for i = toprow, botrow do
    cache.snapshot[i + 1] = { get_indent_lnum(i + 1), line_is_empty(i + 1) }
  end
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
