local api = vim.api
local nvim_create_autocmd, nvim_buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local mini = {}

local ns = api.nvim_create_namespace('IndentLine')

local function col_in_screen(col)
  local leftcol = vim.fn.winsaveview().leftcol
  return col >= leftcol
end

local function indentline()
  local function on_win(_, _, bufnr, _)
    if bufnr ~= vim.api.nvim_get_current_buf() then
      return false
    end
  end

  local ctx = {}
  local function on_line(_, _, bufnr, row)
    local indent = vim.fn.indent(row + 1)
    local text = api.nvim_buf_get_text(bufnr, row, 0, row, -1, {})[1]
    local prev = ctx[#ctx] or 0
    if indent == 0 and #text == 0 and prev > 0 then
      indent = prev > 20 and 4 or prev
    end

    ctx[#ctx + 1] = indent

    for i = 1, indent - 1, vim.bo[bufnr].sw do
      if #text == 0 and i - 1 > 0 and col_in_screen(i - 1) then
        nvim_buf_set_extmark(bufnr, ns, row, 0, {
          virt_text = { { mini.char, 'IndentLine' } },
          virt_text_pos = 'overlay',
          virt_text_win_col = i - 1,
          ephemeral = true,
        })
      elseif col_in_screen(i - 1) then
        nvim_buf_set_extmark(bufnr, ns, row, i - 1, {
          virt_text = { { mini.char, 'IndentLine' } },
          virt_text_pos = 'overlay',
          ephemeral = true,
        })
      end
    end

    if row + 1 == vim.fn.line('w$') then
      ctx = {}
    end
  end

  local function on_start(_, _)
    local bufnr = api.nvim_get_current_buf()
    if
      vim.bo[bufnr].buftype == 'nofile'
      or not vim.bo[bufnr].expandtab
      or vim.tbl_contains(mini.exclude, vim.bo[bufnr].ft)
    then
      return false
    end
  end

  api.nvim_set_decoration_provider(ns, {
    on_win = on_win,
    on_start = on_start,
    on_line = on_line,
  })
end

local function default_exclude()
  return { 'dashboard', 'lazy', 'help', 'markdown' }
end

local function setup(opt)
  mini = vim.tbl_extend('force', {
    char = '│',
    exclude = default_exclude(),
  }, opt or {})

  nvim_create_autocmd('BufEnter', {
    group = api.nvim_create_augroup('IndentMini', { clear = true }),
    callback = function()
      indentline()
    end,
  })
end

return {
  setup = setup,
}
