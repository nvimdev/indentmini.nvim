local api = vim.api
local nvim_create_autocmd, nvim_buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local mini = {}

local ns = api.nvim_create_namespace('IndentLine')

local function col_in_screen(col)
  local leftcol = vim.fn.winsaveview().leftcol
  return col >= leftcol
end

local function indent_step(bufnr)
  if vim.fn.exists('*shiftwidth') == 1 then
    return vim.fn.shiftwidth()
  elseif vim.fn.exists('&shiftwidth') == 1 then
    -- implementation of shiftwidth builtin
    if vim.bo[bufnr].shiftwidth ~= 0 then
      return vim.bo[bufnr].shiftwidth
    elseif vim.bo[bufnr].tabstop ~= 0 then
      return vim.bo[bufnr].tabstop
    end
  end
end

local function indentline(opts)
  local function on_win(_, _, bufnr, _)
    if bufnr ~= vim.api.nvim_get_current_buf() then
      return false
    end
  end

  local ctx = {}
  local function on_line(_, _, bufnr, row)
    local indent = vim.fn.indent(row + 1)
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, row, 0, row, -1, {})
    if not ok then
      return
    end
    local text = lines[1]
    local prev = ctx[row - 1] or 0
    if indent == 0 and #text == 0 and prev > 0 then
      indent = prev > 20 and 4 or prev
    end

    ctx[row] = indent

    local shiftw = indent_step(bufnr)
    for i = 1, indent - 1, shiftw do
      local hi_name = 'IndentLine'
      if opts.hi_colors and #opts.hi_colors ~= 0 then
        local iteration = math.floor((i - 1) / shiftw) + 1
        local idx = (iteration - 1) % #opts.hi_colors + 1
        hi_name = string.format('%s%d', hi_name, iteration)

        vim.cmd.highlight('default link ' .. hi_name .. ' ' .. opts.hi_colors[idx])
      end

      if col_in_screen(i - 1) then
        local param, col = {}, 0
        if #text == 0 and i - 1 > 0 then
          param = {
            virt_text = { { mini.char, hi_name } },
            virt_text_pos = 'overlay',
            virt_text_win_col = i - 1,
            hl_mode = 'combine',
            ephemeral = true,
          }
        else
          param = {
            virt_text = { { mini.char, hi_name } },
            virt_text_pos = 'overlay',
            hl_mode = 'combine',
            ephemeral = true,
          }
          col = i - 1
        end

        nvim_buf_set_extmark(bufnr, ns, row, col, param)
      end
    end
  end

  local function on_end()
    ctx = {}
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

  api.nvim_set_decoration_provider(ns, {
    on_win = on_win,
    on_start = on_start,
    on_line = on_line,
    on_end = on_end,
  })
end

local function default_exclude()
  return { 'dashboard', 'lazy', 'help', 'markdown' }
end

local function setup(opt)
  mini = vim.tbl_extend('force', {
    char = '┇',
    exclude = default_exclude(),
  }, opt or {})

  local group = api.nvim_create_augroup('IndentMini', { clear = true })
  nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function()
      indentline({ hi_colors = opt.hi_colors })
    end,
  })
end

return {
  setup = setup,
}
