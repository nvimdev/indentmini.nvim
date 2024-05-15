local api, UP, DOWN, INVALID, indent_fn = vim.api, -1, 1, -1, vim.fn.indent
local buf_set_extmark, set_provider = api.nvim_buf_set_extmark, api.nvim_set_decoration_provider
local ns = api.nvim_create_namespace('IndentLine')
local opt = {
  config = {
    virt_text_pos = 'overlay',
    hl_mode = 'combine',
    ephemeral = true,
  },
}

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
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, target_row, 0, target_row, -1, {})
    if not ok then
      return INVALID
    end
    local non_empty = #lines[1] > 0
    local target_indent = indent_fn(target_row + 1)
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
  local indent = indent_fn(row + 1)
  if indent == 0 then
    return INVALID, INVALID, INVALID
  end
  local top_row = find_row(bufnr, row, indent, UP, false)
  local bot_row = find_row(bufnr, row, indent, DOWN, false)
  return top_row, bot_row, math.floor(indent / shiftw)
end

local function on_line(_, winid, bufnr, row)
  if
    not api.nvim_get_option_value('expandtab', { buf = bufnr })
    or vim.tbl_contains(opt.exclude, function(v)
      return v == vim.bo[bufnr].ft or v == vim.bo[bufnr].buftype
    end, { predicate = true })
  then
    return false
  end
  local ok, lines = pcall(api.nvim_buf_get_text, bufnr, row, 0, row, -1, {})
  if not ok then
    return
  end
  local indent = indent_fn(row + 1)
  local line_is_empty = #lines[1] == 0
  local shiftw = vim.fn.shiftwidth()
  local top_row, bot_row
  if indent == 0 and line_is_empty then
    top_row = find_row(bufnr, row, indent, UP, true)
    bot_row = find_row(bufnr, row, indent, DOWN, true)
    local top_indent = top_row >= 0 and indent_fn(top_row + 1) or 0
    local bot_indent = bot_row >= 0 and indent_fn(bot_row + 1) or 0
    indent = math.max(top_indent, bot_indent)
  end
  local reg_srow, reg_erow, cur_inlevel = current_line_range(winid, bufnr, shiftw)
  for i = 1, indent - 1, shiftw do
    local col = i - 1
    local level = math.floor(col / shiftw) + 1
    local higroup = 'IndentLine'
    if row > reg_srow and row < reg_erow and level == cur_inlevel then
      higroup = 'IndentLineCurrent'
    end
    local hi_name = (higroup .. '%d%d'):format(row + 1, level)
    if col_in_screen(col) and non_or_space(row, col) then
      opt.config.virt_text[1][2] = hi_name
      if line_is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1
      end
      buf_set_extmark(bufnr, ns, row, col, opt.config)
      opt.config.virt_text_win_col = nil
      api.nvim_set_hl(ns, hi_name, { link = higroup, default = true, force = true })
    end
  end
end

local function on_win(_, winid, bufnr, _)
  if bufnr ~= api.nvim_get_current_buf() then
    return false
  end
  api.nvim_win_set_hl_ns(winid, ns)
end

return {
  setup = function(conf)
    conf = conf or {}
    opt.current = conf.current or true
    opt.exclude = vim.tbl_extend(
      'force',
      { 'dashboard', 'lazy', 'help', 'markdown', 'nofile', 'terminal' },
      conf.exclude or {}
    )
    opt.config.virt_text = { { conf.char or '│' } }
    set_provider(ns, { on_win = on_win, on_line = on_line })
  end,
}
