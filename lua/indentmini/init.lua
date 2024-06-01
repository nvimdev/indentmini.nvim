local api, UP, DOWN, INVALID = vim.api, -1, 1, -1
local buf_set_extmark, set_provider = api.nvim_buf_set_extmark, api.nvim_set_decoration_provider
local ns = api.nvim_create_namespace('IndentLine')
local ffi = require('ffi')
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
  int tabstop_first(colnr_T *ts);
]])

local C = ffi.C
local ml_get, ml_get_len, tabstop_first = C.ml_get, C.ml_get_len, C.tabstop_first
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

local function non_or_space(row, col)
  local line = ffi.string(ml_get(row + 1))
  local text = line:sub(col, col)
  return text and (#text == 0 or text == ' ' or text == '	') or false
end

local function find_in_snapshot(lnum)
  if not cache.snapshot[lnum] then
    cache.snapshot[lnum] = { get_indent_lnum(lnum), line_is_empty(lnum) }
  end
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

local function current_line_range(winid, step)
  local row = api.nvim_win_get_cursor(winid)[1] - 1
  local indent, _ = find_in_snapshot(row + 1)
  if indent == 0 then
    return INVALID, INVALID, INVALID
  end
  local top_row = find_row(row, indent, UP, false)
  local bot_row = find_row(row, indent, DOWN, false)
  return top_row, bot_row, math.floor(indent / step)
end

local function on_line(_, _, bufnr, row)
  local indent, is_empty = find_in_snapshot(row + 1)
  if is_empty == nil then
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
  for i = 1, indent - 1, cache.step do
    local col = i - 1
    local level = math.floor(col / cache.step) + 1
    local higroup = 'IndentLine'
    if row > cache.reg_srow and row < cache.reg_erow and level == cache.cur_inlevel then
      higroup = 'IndentLineCurrent'
    end
    if not vim.o.expandtab then
      col = level - 1
    end
    if col >= cache.leftcol and non_or_space(row, col) then
      opt.config.virt_text[1][2] = higroup
      if is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1
      end
      buf_set_extmark(bufnr, ns, row, col, opt.config)
      opt.config.virt_text_win_col = nil
    end
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
  cache.step = vim.o.expandtab and get_shiftw_value(bufnr) or tabstop_first(nil)
  cache.count = api.nvim_buf_line_count(bufnr)
  cache.reg_srow, cache.reg_erow, cache.cur_inlevel = current_line_range(winid, cache.step)
  for i = toprow, botrow do
    cache.snapshot[i + 1] = { get_indent_lnum(i + 1), line_is_empty(i + 1) }
  end
end

return {
  setup = function(conf)
    conf = conf or {}
    opt.exclude = vim.tbl_extend(
      'force',
      { 'dashboard', 'lazy', 'help', 'markdown', 'nofile', 'terminal', 'prompt' },
      conf.exclude or {}
    )
    opt.config.virt_text = { { conf.char or '│' } }
    set_provider(ns, { on_win = on_win, on_line = on_line })
  end,
}
