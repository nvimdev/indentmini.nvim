local api = vim.api
require('indentmini').setup({})

local function screen(lines)
  local address = vim.fn.tempname()
  vim.fn.jobstart({ 'nvim', '--clean', '-n', '--listen', address }, { pty = true })
  vim.loop.sleep(200)

  local channel = vim.fn.sockconnect('pipe', address, { rpc = true })

  local current_dir = vim.fn.getcwd()

  vim.rpcrequest(channel, 'nvim_set_option_value', 'rtp', current_dir, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_exec_lua', 'require("indentmini").setup({})', {})
  vim.rpcrequest(channel, 'nvim_set_option_value', 'columns', 26, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'lines', #lines + 2, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_exec_autocmds', 'BufEnter', { group = 'IndentMini' })

  vim.rpcrequest(channel, 'nvim_set_option_value', 'shiftwidth', 2, { buf = 0 })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'expandtab', true, { buf = 0 })

  vim.rpcrequest(channel, 'nvim_buf_set_lines', 0, 0, -1, false, lines)

  local screenstring = function(row, col)
    return vim.rpcrequest(channel, 'nvim_exec_lua', 'return vim.fn.screenstring(...)', { row, col })
  end

  local screen = function()
    local cols = vim.rpcrequest(channel, 'nvim_get_option', 'columns')
    local res = {}
    for i = 1, #lines do
      local line = ''
      for j = 1, cols do
        line = line .. screenstring(i, j)
      end
      res[#res + 1] = line
    end

    return res
  end

  return screen()
end

describe('indent mini', function()
  local bufnr
  before_each(function()
    bufnr = api.nvim_create_buf(true, true)
    api.nvim_win_set_buf(0, bufnr)
  end)

  it('work as expect', function()
    local lines = {
      'local function test()',
      '  local a = 10',
      '  local b = 20',
      '  while true do',
      '    if a > b then',
      '      if b < a then',
      '        print("test")',
      '      end',
      '    end',
      '  end',
      'end',
    }
    local char = '┇'
    local screenstr = screen(lines)
    for _,line in ipairs(screenstr) do
      print(vim.inspect(line))
    end

    local expect = {
      'local function test()     ',
      '┇ local a = 10            ',
      '┇ local b = 20            ',
      '┇ while true do           ',
      '┇ ┇ if a > b then         ',
      '┇ ┇ ┇ if b < a then       ',
      '┇ ┇ ┇ ┇ print("test")     ',
      '┇ ┇ ┇ end                 ',
      '┇ ┇ end                   ',
      '┇ end                     ',
      'end                       ',
    }

    assert.same(expect, screenstr)
  end)
end)
