local api = vim.api
local au, nvim_buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local ns = api.nvim_create_namespace('IndentLine')
local indent_fn = vim.fn.indent

---check column in screen
local function col_in_screen(col)
  return col >= vim.fn.winsaveview().leftcol
end

local function is_space(row, col)
  local text = api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]
  return text and (#text == 0 or text == ' ') or false
end

local function on_win(_, _, bufnr, _)
  return bufnr ~= vim.api.nvim_get_current_buf() and false or true
end

local config = {
  virt_text_pos = 'overlay',
  hl_mode = 'combine',
  ephemeral = true,
}

local function indentline(opt)
  config.virt_text = { { opt.char } }
  local function on_line(_, _, bufnr, row)
    local indent = indent_fn(row + 1)
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, row, 0, row, -1, {})
    if not ok then
      return
    end
    local line_is_empty = #lines[1] == 0
    if indent == 0 and line_is_empty then
      local prev_row = row - 1
      while true do
        ok, lines = pcall(api.nvim_buf_get_text, bufnr, prev_row, 0, prev_row, -1, {})
        if not ok then
          break
        end
        local prev_indent = indent_fn(prev_row + 1)
        if prev_indent == 0 and #lines[1] ~= 0 then
          break
        else
          indent = prev_indent
          break
        end
        prev_row = prev_row - 1
      end
    end

    local shiftw = vim.fn.shiftwidth()
    local last_defined_level = 0
    for i = 1, indent - 1, shiftw do
      local col = i - 1
      local indent_level = math.floor(col / shiftw) + 1
      local hi_name = ('IndentLine%d'):format(indent_level)
      -- Attempt to fetch highlight details for the current level
      local hl_details = api.nvim_get_hl(0, { name = hi_name })
      -- If no custom highlight details are found, use the last defined level for looping back
      if vim.tbl_isempty(hl_details) then
        if last_defined_level > 0 then
          local looped_level = ((indent_level - 1) % last_defined_level) + 1
          hi_name = ('IndentLine%d'):format(looped_level)
        else
          hi_name = 'IndentLine'
          -- If no last_defined_level is set yet, just set it as the current one
          last_defined_level = indent_level
        end
      else
        -- If highlight details are found, update last_defined_level
        last_defined_level = indent_level
      end

      if col_in_screen(col) and is_space(row, col) then
        config.virt_text[1][2] = hi_name
        if line_is_empty and col > 0 then
          config.virt_text_win_col = i - 1
        end
        nvim_buf_set_extmark(bufnr, ns, row, col, config)
        config.virt_text_win_col = nil
        api.nvim_set_hl(0, hi_name, { link = 'IndentLine', default = true })
      end
    end
  end

  local function on_start(_, _)
    local bufnr = api.nvim_get_current_buf()
    if
      not vim.bo[bufnr].expandtab
      or vim.tbl_contains({ 'nofile', 'terminal' }, vim.bo[bufnr].buftype)
      or vim.tbl_contains(opt.exclude, vim.bo[bufnr].ft)
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

local function setup(opt)
  opt = vim.tbl_extend('force', {
    char = '┇',
    exclude = { 'dashboard', 'lazy', 'help', 'markdown' },
  }, opt or {})

  au('BufEnter', {
    group = api.nvim_create_augroup('IndentMini', { clear = true }),
    callback = function()
      indentline(opt)
    end,
  })
end

return {
  setup = setup,
}
