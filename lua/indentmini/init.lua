local api = vim.api
local au, buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local set_decoration_provider = api.nvim_set_decoration_provider
local ns = api.nvim_create_namespace('IndentLine')
local g = api.nvim_create_augroup('IndentMini', { clear = true })
local indent_fn = vim.fn.indent
local UP, DOWN = -1, 1
local opt = {
  config = {
    virt_text_pos = 'overlay',
    hl_mode = 'combine',
    ephemeral = true,
  },
}

---check column in screen
local function col_in_screen(col)
  return col >= vim.fn.winsaveview().leftcol
end

---check text in current column is space
local function non_or_space(row, col)
  local text = api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]
  return text and (#text == 0 or text == ' ') or false
end

local function on_win(_, winid, bufnr, _)
  if bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end
  api.nvim_win_set_hl_ns(winid, ns)
end

local function find_row(bufnr, row, curindent, direction, render)
  local target_row = row + direction
  local count = api.nvim_buf_line_count(bufnr)
  while true do
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, target_row, 0, target_row, -1, {})
    if not ok then
      return
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
      return
    end
  end
end

local function event_created(e, bufnr)
  return not vim.tbl_isempty(api.nvim_get_autocmds({
    group = g,
    event = e,
    buffer = bufnr,
  }))
end

local function on_line(_, _, bufnr, row)
  if
    not api.nvim_get_option_value('expandtab', { buf = bufnr })
    or vim.tbl_contains(opt.exclude, function(v)
      return v == vim.bo[bufnr].ft or v == vim.bo[bufnr].buftype
    end, { predicate = true })
  then
    return false
  end
  local indent = indent_fn(row + 1)
  local ok, lines = pcall(api.nvim_buf_get_text, bufnr, row, 0, row, -1, {})
  if not ok then
    return
  end
  local line_is_empty = #lines[1] == 0
  local shiftw = vim.fn.shiftwidth()
  if indent == 0 and line_is_empty then
    local target_row = find_row(bufnr, row, indent, DOWN, true)
    if target_row then
      indent = indent_fn(target_row + 1)
    end
  end

  for i = 1, indent - 1, shiftw do
    local col = i - 1
    local level = math.floor(col / shiftw) + 1
    local hi_name = ('IndentLine%d%d'):format(row + 1, level)
    if col_in_screen(col) and non_or_space(row, col) then
      opt.config.virt_text[1][2] = hi_name
      if line_is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1
      end
      buf_set_extmark(bufnr, ns, row, col, opt.config)
      opt.config.virt_text_win_col = nil
      api.nvim_set_hl(ns, hi_name, { link = 'IndentLine', default = true })
    end
  end

  if opt.current and not event_created('CursorMoved', bufnr) then
    au('CursorMoved', {
      group = g,
      buffer = bufnr,
      callback = function(data)
        local cur_hi = 'IndentLineCurrent'
        local line, _ = unpack(api.nvim_win_get_cursor(0))
        local curindent = indent_fn(line)
        local srow = find_row(data.buf, line - 1, curindent, UP, false) or 0
        local erow = find_row(data.buf, line - 1, curindent, DOWN, false) or 0
        for k, v in pairs(api.nvim_get_hl(ns, {}) or {}) do
          if v.link and v.link == cur_hi then
            api.nvim_set_hl(ns, k, { link = 'IndentLine', force = true })
          end
        end
        if erow < 1 then
          return
        end
        -- only render visible part of screen
        local toprow = vim.fn.line('w0') - 2
        local botrow = vim.fn.line('w$') - 1
        srow = math.max(math.max(toprow, srow), 0)
        erow = math.max(math.min(botrow, erow), api.nvim_buf_line_count(data.buf) - 1)
        local level = math.floor(curindent / shiftw)
        for i = srow + 1, erow, 1 do
          api.nvim_set_hl(
            ns,
            ('IndentLine%d%d'):format(i + 1, level),
            { link = cur_hi, force = true }
          )
        end
      end,
    })
  end
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
    set_decoration_provider(ns, { on_win = on_win, on_line = on_line })
  end,
}
