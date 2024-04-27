local api = vim.api
local au, nvim_buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local mini = {}
local ns = api.nvim_create_namespace('IndentLine')

local function col_in_screen(col)
  local leftcol = vim.fn.winsaveview().leftcol
  return col >= leftcol
end

local function can_set(row, col)
  local text = api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]
  return text ~= '\t' and not not text:find('%s')
end

local function on_win(_, _, bufnr, _)
  if bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end
end

local function on_start(_, _)
  local bufnr = api.nvim_get_current_buf()
  local exclude_buftype = { 'nofile', 'terminal' }
  if
    vim.tbl_contains(exclude_buftype, vim.bo[bufnr].buftype)
    or not vim.bo[bufnr].expandtab
    or vim.tbl_contains(mini.exclude, vim.bo[bufnr].ft)
  then
    return false
  end
end

local function indentline()
  local config = {
    virt_text_pos = 'overlay',
    hl_mode = 'combine',
    ephemeral = true,
  }
  local function on_line(_, _, bufnr, row)
    local indent = vim.fn.indent(row + 1)
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, row, 0, row, -1, {})
    if not ok then
      return
    end
    local text = lines[1]
    local prev = vim.fn.indent(row)
    if indent == 0 and #text == 0 and prev > 0 then
      indent = prev > 20 and 4 or prev
    end

    local shiftw = vim.fn.shiftwidth()
    local last_defined_level = 0
    for i = 1, indent - 1, shiftw do
      local col = i - 1
      local indent_level = math.floor((i - 1) / shiftw) + 1
      local hi_name = ('IndentLine%d'):format(indent_level)
      -- Attempt to fetch highlight details for the current level
      local hl_details = api.nvim_get_hl(0, { name = hi_name })

      -- If no custom highlight details are found, use the last defined level for looping back
      if next(hl_details) == nil then
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
      api.nvim_set_hl(0, hi_name, { link = 'IndentLine', default = true })

      if col_in_screen(col) and can_set(row, col) then
        config.virt_text = { { mini.char, hi_name } }
        if #text == 0 and col > 0 then
          config.virt_text_win_col = i - 1
          nvim_buf_set_extmark(bufnr, ns, row, col, config)
        else
          nvim_buf_set_extmark(bufnr, ns, row, col, config)
        end
      end
    end
  end

  api.nvim_set_decoration_provider(ns, {
    on_win = on_win,
    on_start = on_start,
    on_line = on_line,
  })
end

local function setup(opt)
  mini = vim.tbl_extend('force', {
    char = '┇',
    exclude = { 'dashboard', 'lazy', 'help', 'markdown' },
  }, opt or {})
  au('BufEnter', {
    group = api.nvim_create_augroup('IndentMini', { clear = true }),
    callback = function()
      indentline()
    end,
  })
end

return {
  setup = setup,
}
