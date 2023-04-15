local api = vim.api
local treesitter = vim.treesitter
local nvim_create_autocmd = api.nvim_create_autocmd
local mini = {}

local function has_treesitter(bufnr)
  local ok = pcall(require, 'nvim-treesitter')
  if not ok then
    return ok
  end
  local lang = pcall(treesitter.language.get_lang, vim.bo[bufnr].filetype)
  local has, parser = pcall(treesitter.get_parser, bufnr, lang)
  if not parser or not has then
    return false
  end
  return true
end

local function check_inblock()
  local type = {
    'function_definition',
    'for_statement',
    'if_statement',
    'while_statement',
    'call_expression',
  }
  return function(bufnr, row)
    if not has_treesitter(bufnr) then
      return false
    end
    local node = treesitter.get_node({ bufnr = bufnr, pos = { row, 0 } })
    if not node then
      return false
    end
    local parent = node:parent()
    if parent and vim.tbl_contains(type, parent:type()) then
      return true
    end
    return false
  end
end

local function indentline()
  local ns = api.nvim_create_namespace('IndentLine')

  local function on_win(_, _, bufnr, _)
    if bufnr ~= vim.api.nvim_get_current_buf() then
      return false
    end
  end

  local ctx = {}
  local function on_line(_, _, bufnr, row)
    local indent = vim.fn.indent(row + 1)
    local text = api.nvim_buf_get_text(bufnr, row, 0, row, -1, {})[1]
    local inblock = check_inblock()
    local prev = ctx[#ctx] or 0
    if indent == 0 and #text == 0 and (prev > 0 or inblock(bufnr, row)) then
      indent = prev > 20 and 4 or prev
    end

    ctx[#ctx + 1] = indent

    local fill = vim.bo.sw / 2
    for i = 1, indent - 1, vim.bo[bufnr].sw do
      local pos = 'overlay'
      local symbol = mini.char
      if #text == 0 and i - 1 > 0 then
        pos = 'eol'
        symbol = (i == 1 + vim.bo[bufnr].sw and (' '):rep(vim.bo[bufnr].sw - 1) or '') .. '│'
        if i > 1 + vim.bo[bufnr].sw and fill > 1 then
          symbol = (' '):rep(fill) .. symbol
        end
      end

      api.nvim_buf_set_extmark(bufnr, ns, row, i - 1, {
        virt_text = { { symbol, 'IndentLine' } },
        virt_text_pos = pos,
        ephemeral = true,
      })
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
