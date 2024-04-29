local api = vim.api
local au, nvim_buf_set_extmark = api.nvim_create_autocmd, api.nvim_buf_set_extmark
local ns = api.nvim_create_namespace('IndentLine')
local g = api.nvim_create_augroup('IndentMini', { clear = true })
local indent_fn = vim.fn.indent

---check column in screen
local function col_in_screen(col)
  return col >= vim.fn.winsaveview().leftcol
end

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

local config = {
  virt_text_pos = 'overlay',
  hl_mode = 'combine',
  ephemeral = true,
}

local function indentline(opt)
  local invalid_buf = function(bufnr)
    if
      not vim.bo[bufnr].expandtab
      or vim.tbl_contains({ 'nofile', 'terminal' }, vim.bo[bufnr].buftype)
      or vim.tbl_contains(opt.exclude, vim.bo[bufnr].ft)
    then
      return true
    end
  end
  config.virt_text = { { opt.char } }
  local function on_line(_, _, bufnr, row)
    if invalid_buf(bufnr) then
      return
    end

    local indent = indent_fn(row + 1)
    local ok, lines = pcall(api.nvim_buf_get_text, bufnr, row, 0, row, -1, {})
    if not ok then
      return
    end
    local line_is_empty = #lines[1] == 0
    local shiftw = vim.fn.shiftwidth()
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
        elseif #lines[1] ~= 0 and prev_indent > 0 then
          indent = prev_indent + shiftw
          break
        end
        prev_row = prev_row - 1
      end
    end

    for i = 1, indent - 1, shiftw do
      local col = i - 1
      local indent_level = math.floor(col / shiftw) + 1
      local hi_name = ('IndentLine%d'):format(indent_level)
      if col_in_screen(col) and is_space(row, col) then
        config.virt_text[1][2] = hi_name
        if line_is_empty and col > 0 then
          config.virt_text_win_col = i - 1
        end
        nvim_buf_set_extmark(bufnr, ns, row, col, config)
        config.virt_text_win_col = nil
        api.nvim_set_hl(ns, hi_name, { link = 'IndentLine', default = true })
      end
    end
  end

  local function on_start(_, _)
    local bufnr = api.nvim_get_current_buf()
    if invalid_buf(bufnr) then
      return false
    end
  end

  api.nvim_set_decoration_provider(ns, {
    on_win = on_win,
    on_start = on_start,
    on_line = on_line,
  })
end

return {
  setup = function(opt)
    opt = vim.tbl_extend('force', {
      char = '┇',
      current = true,
      exclude = { 'dashboard', 'lazy', 'help', 'markdown' },
    }, opt or {})

    au('BufEnter', {
      group = g,
      callback = function(args)
        indentline(opt)
        if not opt.current then
          return
        end

        au('CursorMoved', {
          group = g,
          buffer = args.buf,
          callback = function()
            local line, _ = unpack(vim.api.nvim_win_get_cursor(0))
            local level = math.floor(indent_fn(line) / vim.fn.shiftwidth())
            local hls = api.nvim_get_hl(ns, {})
            if level < 1 then
              for k, _ in pairs(hls) do
                api.nvim_set_hl(ns, k, { link = 'IndentLine' })
              end
              return
            end
            local name = ('IndentLine%d'):format(level)
            if hls[name] and hls[name].link and hls[name].link == 'IndentLineCurrent' then
              return
            end
            api.nvim_set_hl(ns, name, { link = 'IndentLineCurrent' })
            for k, _ in pairs(hls) do
              if k ~= name then
                api.nvim_set_hl(ns, k, { link = 'IndentLine' })
              end
            end
          end,
        })
      end,
    })
  end,
}
