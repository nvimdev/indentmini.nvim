local api = vim.api
local au, nvim_buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local ns = api.nvim_create_namespace('IndentLine')
local g = api.nvim_create_augroup('IndentMini', { clear = true })
local indent_fn = vim.fn.indent
local UP, DOWN, opt = -1, 1, {}

---check column in screen
local function col_in_screen(col)
  return col >= vim.fn.winsaveview().leftcol
end

---check text in current column is space
local function is_space(row, col)
  local text = api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]
  return text and (#text == 0 or text == ' ') or false
end

local function on_win(_, winid, bufnr, _)
  if bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end
  api.nvim_win_set_hl_ns(winid, ns)
end

local function find_row(bufnr, row, direction, render)
  local target_row = row + direction
  local count = api.nvim_buf_line_count(bufnr)
  local curindent = indent_fn(row + 1)
  while true do
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, target_row, 0, target_row, -1, {})
    if not ok or target_row < 0 or target_row > count - 1 then
      break
    end
    local non_empty = #lines[1] ~= 0
    local target_indent = indent_fn(target_row + 1)
    if target_indent == 0 and non_empty and render then
      break
    elseif non_empty and (render and target_indent > curindent or target_indent < curindent) then
      return target_row
    end
    target_row = target_row + direction
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
    not vim.bo[bufnr].expandtab
    or vim.tbl_contains({ 'nofile', 'terminal' }, vim.bo[bufnr].buftype)
    or vim.tbl_contains(opt.exclude, vim.bo[bufnr].ft)
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
    local target_row = find_row(bufnr, row, DOWN, true)
    if row == 1 then
      print(target_row)
    end
    if target_row then
      indent = indent_fn(target_row + 1)
    end
  end

  for i = 1, indent - 1, shiftw do
    local col = i - 1
    local hi_name = ('IndentLine%d%d'):format(row + 1, col + 1)
    if col_in_screen(col) and is_space(row, col) then
      opt.config.virt_text[1][2] = hi_name
      if line_is_empty and col > 0 then
        opt.config.virt_text_win_col = i - 1
      end
      nvim_buf_set_extmark(bufnr, ns, row, col, opt.config)
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
        local srow = find_row(data.buf, line - 1, UP, false) or 0
        local erow = find_row(data.buf, line - 1, DOWN, false) or 0
        local hls = api.nvim_get_hl(ns, {})
        --TODO(glepnir): can there use w0 or w$ for clear the visible screen indent highlight ?
        for k, v in pairs(hls) do
          if v.link and v.link == cur_hi then
            api.nvim_set_hl(ns, k, { link = 'IndentLine', force = true })
          end
        end
        if erow < 1 then
          return
        end
        for i = srow, erow, 1 do
          local hi_name = ('IndentLine%d%d'):format(i + 1, curindent - 1)
          api.nvim_set_hl(ns, hi_name, { link = cur_hi })
        end
      end,
    })
  end
end

return {
  setup = function(conf)
    opt = {
      current = conf.current or true,
      exclude = vim.tbl_extend(
        'force',
        { 'dashboard', 'lazy', 'help', 'markdown' },
        conf.exclude or {}
      ),
      config = {
        virt_text = { { conf.char or '┇' } },
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
        ephemeral = true,
      },
    }
    api.nvim_set_decoration_provider(ns, {
      on_win = on_win,
      on_line = on_line,
    })
  end,
}
