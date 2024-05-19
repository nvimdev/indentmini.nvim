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
local cache = {}

ffi.cdef([[
  typedef struct {} Error;
  typedef int colnr_T;
  typedef struct window_S win_T;
  typedef struct file_buffer buf_T;
  buf_T *find_buffer_by_handle(int buffer, Error *err);
  win_T *find_window_by_handle(int window, Error *err);
  int get_sw_value(buf_T *buf);
  typedef int32_t linenr_T;
  int get_indent_lnum(linenr_T lnum);
  char *ml_get_buf(buf_T *buf, linenr_T lnum, bool will_change);
]])

local function get_line_data(bufnr, lnum)
  local err = ffi.new('Error')
  local handle = ffi.C.find_buffer_by_handle(bufnr, err)
  if lnum > api.nvim_buf_line_count(bufnr) then
    return
  end
  local data = ffi.C.ml_get_buf(handle, lnum, false)
  return ffi.string(data)
end

local function get_sw_value(bufnr)
  local err = ffi.new('Error')
  local handle = ffi.C.find_buffer_by_handle(bufnr, err)
  return ffi.C.get_sw_value(handle)
end

local function get_indent(lnum)
  return ffi.C.get_indent_lnum(lnum)
end

local function col_in_screen(col)
  return col >= vim.fn.winsaveview().leftcol
end

local function non_or_space(row, col)
  local text = api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]
  return text and (#text == 0 or text == ' ') or false
end

local function find_row(bufnr, row, curindent, direction, render)
  local target_row = row + direction
  local count = api.nvim_buf_line_count(bufnr)
  while true do
    local line = get_line_data(bufnr, target_row + 1)
    if not line then
      return INVALID
    end
    local non_empty = #line > 0
    local target_indent = get_indent(target_row + 1)
    if target_indent == 0 and non_empty and render then
      break
    elseif non_empty and (render and target_indent > curindent or target_indent < curindent) then
      return target_row
    end
    target_row = target_row + direction
    if target_row < 0 or target_row > count - 1 then
      return INVALID
    end
  end
  return INVALID
end

local function current_line_range(winid, bufnr, shiftw)
  local row = api.nvim_win_get_cursor(winid)[1] - 1
  local indent = get_indent(row + 1)
  if indent == 0 then
    return INVALID, INVALID, INVALID
  end
  local top_row = find_row(bufnr, row, indent, UP, false)
  local bot_row = find_row(bufnr, row, indent, DOWN, false)
  return top_row, bot_row, math.floor(indent / shiftw)
end

local function on_line(_, _, bufnr, row)
  local line = get_line_data(bufnr, row + 1)
  if not line then
    return
  end
  local indent = get_indent(row + 1)
  local line_is_empty = #line == 0
  local shiftw = get_sw_value(bufnr)
  local top_row, bot_row
  if indent == 0 and line_is_empty then
    top_row = find_row(bufnr, row, indent, UP, true)
    bot_row = find_row(bufnr, row, indent, DOWN, true)
    local top_indent = top_row >= 0 and get_indent(top_row + 1) or 0
    local bot_indent = bot_row >= 0 and get_indent(bot_row + 1) or 0
    indent = math.max(top_indent, bot_indent)
  end
  for i = 1, indent - 1, shiftw do
    local col = i - 1
    local level = math.floor(col / shiftw) + 1
    local higroup = 'IndentLine'
    if row > cache.reg_srow and row < cache.reg_erow and level == cache.cur_inlevel then
      higroup = 'IndentLineCurrent'
    end
    if col_in_screen(col) and non_or_space(row, col) then
      opt.config.virt_text[1][2] = higroup
      if line_is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1
      end
      --TODO(glepnir): store id with changedtick then compare for performance
      buf_set_extmark(bufnr, ns, row, col, opt.config)
      opt.config.virt_text_win_col = nil
    end
  end
end

local function on_win(_, winid, bufnr, _)
  if
    bufnr ~= api.nvim_get_current_buf()
    or not api.nvim_get_option_value('expandtab', { buf = bufnr })
    or vim.iter(opt.exclude):find(function(v)
      return v == vim.bo[bufnr].ft or v == vim.bo[bufnr].buftype
    end)
  then
    return false
  end
  local reg_srow, reg_erow, cur_inlevel = current_line_range(winid, bufnr, vim.fn.shiftwidth())
  cache = { reg_srow = reg_srow, reg_erow = reg_erow, cur_inlevel = cur_inlevel }
  api.nvim_win_set_hl_ns(winid, ns)
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
