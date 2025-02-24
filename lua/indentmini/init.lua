local api, UP, DOWN, INVALID = vim.api, -1, 1, -1
local buf_set_extmark, set_provider = api.nvim_buf_set_extmark, api.nvim_set_decoration_provider
local ns = api.nvim_create_namespace('IndentLine')
local ffi, treesitter = require('ffi'), vim.treesitter
local opt = {
  only_current = false,
  exclude = { 'dashboard', 'lazy', 'help', 'nofile', 'terminal', 'prompt' },
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

--- @class Context
--- @field snapshot table<integer, integer>
local context = { snapshot = {} }

--- check text only has space or tab see bench/space_or_tab.lua
--- @param text string
--- @return boolean true only have space or tab
local function only_spaces_or_tabs(text)
  for i = 1, #text do
    local byte = string.byte(text, i)
    if byte ~= 32 and byte ~= 9 then -- 32 is space, 9 is tab
      return false
    end
  end
  return true
end

--- @param bufnr integer
--- @return integer the shiftwidth value of bufnr
local function get_shiftw_value(bufnr)
  local handle = find_buffer_by_handle(bufnr, ffi.new('Error'))
  return get_sw_value(handle)
end

---@paren node TSNode
---@return TSNode?
local function ts_find_indentation_node(node)
  local cur_row = node:range()
  local current = node

  while current do
    current = current:parent()
    if current then
      local row = current:range()
      if row < cur_row then
        return current
      end
    end
  end
  return nil
end

---@paren lnum integer
---@return integer?
local function ts_get_indent(lnum)
  local node = treesitter.get_node({ pos = { lnum - 1, 0 } })
  if not node then
    return
  end
  local srow = node:range()
  if lnum - 1 > srow then
    local count = node:named_child_count()
    local last_valid_child = nil
    for i = 0, count - 1 do
      local child = node:named_child(i)
      if child then
        local child_row = child:range()
        if child_row < lnum - 1 then
          last_valid_child = child
        else
          break
        end
      end
    end
    if last_valid_child then
      return get_indent_lnum(last_valid_child:range() + 1)
    end
  end
  local parent = ts_find_indentation_node(node)
  if not parent then
    return
  end
  return get_indent_lnum(parent:range() + 1)
end

-- Bit operations for snapshot packing/unpacking
-- empty(1) | indent(6) | indent_cols(9)
local function pack_snapshot(empty, indent, indent_cols)
  return bit.bor(
    bit.lshift(empty and 1 or 0, 15),
    bit.lshift(bit.band(indent, 0x3F), 9),
    bit.band(indent_cols, 0x1FF)
  )
end

---@param packed integer
---@return table
local function unpack_snapshot(packed)
  return {
    is_empty = bit.band(bit.rshift(packed, 15), 1) == 1,
    indent = bit.band(bit.rshift(packed, 9), 0x3F),
    indent_cols = bit.band(packed, 0x1FF),
  }
end

--- store the line data in snapshot and update the blank line indent
--- @param lnum integer
--- @return table
local function make_snapshot(lnum)
  local line_text = ffi.string(ml_get(lnum))
  local is_empty = #line_text == 0 or only_spaces_or_tabs(line_text)
  if is_empty and context.has_ts then
    local indent = ts_get_indent(lnum)
    if indent then
      local packed = pack_snapshot(true, indent, indent)
      context.snapshot[lnum] = packed
      return unpack_snapshot(packed)
    end
  end

  local indent = is_empty and 0 or get_indent_lnum(lnum)
  if is_empty then
    local prev_lnum = lnum - 1
    while prev_lnum >= 1 do
      local prev_packed = context.snapshot[prev_lnum]
      local sp = prev_packed and unpack_snapshot(prev_packed) or make_snapshot(prev_lnum)
      if (not sp.is_empty and sp.indent == 0) or (sp.indent > 0) then
        if sp.indent > 0 then
          indent = sp.indent
        end
        break
      end
      prev_lnum = prev_lnum - 1
    end
  end

  local prev_packed = context.snapshot[lnum - 1]
  if prev_packed then
    local prev = unpack_snapshot(prev_packed)
    if prev.is_empty and prev.indent < indent then
      local prev_lnum = lnum - 1
      while prev_lnum >= 1 do
        local sp_packed = context.snapshot[prev_lnum]
        if not sp_packed then
          break
        end
        local sp = unpack_snapshot(sp_packed)
        if not sp.is_empty or sp.indent >= indent then
          break
        end
        context.snapshot[prev_lnum] = pack_snapshot(sp.is_empty, indent, indent)
        prev_lnum = prev_lnum - 1
      end
    end
  end

  local indent_cols = line_text:find('[^ \t]')
  indent_cols = indent_cols and indent_cols - 1 or INVALID
  if is_empty then
    indent_cols = indent
  end

  local packed = pack_snapshot(is_empty, indent, indent_cols)
  context.snapshot[lnum] = packed
  return unpack_snapshot(packed)
end

local function find_in_snapshot(lnum)
  local packed = context.snapshot[lnum]
  if not packed then
    return make_snapshot(lnum)
  end
  return unpack_snapshot(packed)
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
  local curlevel = math.ceil(currow_indent / context.tabstop) -- for mixup
  local range_fn = function(indent, empty, row)
    local level = math.ceil(indent / context.tabstop)
    if
      ((not empty and not context.mixup) and indent < currow_indent)
      or (context.mixup and level < curlevel)
    then
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
  context.cur_inlevel = context.mixup and math.ceil(currow_indent / context.tabstop)
    or math.floor(currow_indent / context.step)
end

local function on_line(_, _, bufnr, row)
  local sp = find_in_snapshot(row + 1)
  if sp.indent == 0 or out_current_range(row) then
    return
  end
  local currow_insert = api.nvim_get_mode().mode == 'i' and context.currow == row
  -- mixup like vim code has modeline vi:set ts=8 sts=4 sw=4 noet:
  -- 4 8 12 16 20 24
  -- 1 1 2  2  3  3
  local total = context.mixup and math.ceil(sp.indent / context.tabstop) or sp.indent - 1
  local step = context.mixup and 1 or context.step
  for i = 1, total, step do
    local col = i - 1
    local level = context.mixup and i or math.floor(col / context.step) + 1
    if context.is_tab and not context.mixup then
      col = level - 1
    end
    if
      col >= context.leftcol
      and level >= opt.minlevel
      and (not opt.only_current or level == context.cur_inlevel)
      and col < sp.indent_cols
      and (not currow_insert or col ~= context.curcol)
    then
      local row_in_curblock = context.range_srow
        and (row > context.range_srow and row < context.range_erow)
      local higroup = row_in_curblock and level == context.cur_inlevel and 'IndentLineCurrent'
        or 'IndentLine'
      opt.config.virt_text[1][2] = higroup
      if sp.is_empty and col > 0 then
        opt.config.virt_text_win_col = not context.mixup and i - 1 - context.leftcol
          or (i - 1) * context.tabstop
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
  opt.config.virt_text_repeat_linebreak = vim.wo[winid].wrap and vim.wo[winid].breakindent
  ---@diagnostic disable-next-line: missing-fields
  context = { snapshot = {} }
  context.is_tab = not vim.bo[bufnr].expandtab
  context.step = get_shiftw_value(bufnr)
  context.tabstop = vim.bo[bufnr].tabstop
  context.softtabstop = vim.bo[bufnr].softtabstop
  context.win_width = api.nvim_win_get_width(winid)
  context.mixup = context.is_tab and context.tabstop > context.softtabstop
  for i = toprow, botrow do
    make_snapshot(i + 1)
  end
  api.nvim_win_set_hl_ns(winid, ns)
  context.leftcol = vim.fn.winsaveview().leftcol
  context.count = api.nvim_buf_line_count(bufnr)
  local pos = api.nvim_win_get_cursor(winid)
  context.currow = pos[1] - 1
  context.curcol = pos[2]
  local ok = pcall(treesitter.get_paser, bufnr)
  context.has_ts = ok
  find_current_range(find_in_snapshot(context.currow + 1).indent)
end

return {
  setup = function(conf)
    conf = conf or {}
    opt.only_current = conf.only_current or false
    opt.exclude = vim.list_extend(opt.exclude, conf.exclude or {})
    opt.config.virt_text = { { conf.char or '│' } }
    opt.minlevel = conf.minlevel or 1
    set_provider(ns, { on_win = on_win, on_line = on_line })
  end,
}
