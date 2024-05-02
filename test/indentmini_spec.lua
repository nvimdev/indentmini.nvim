local api = vim.api
require('indentmini').setup({})

local channel, job_id

local function clean()
  vim.fn.jobstop(job_id)
  job_id = nil
  channel = nil
end

local function nvim_instance()
  local address = vim.fn.tempname()
  job_id = vim.fn.jobstart({ 'nvim', '--clean', '-n', '--listen', address }, { pty = true })
  vim.loop.sleep(200)
  return vim.fn.sockconnect('pipe', address, { rpc = true })
end

local function nvim_set_cursor(line, col)
  vim.rpcrequest(channel, 'nvim_win_set_cursor', 0, {line, col})
end

local function get_indent_ns()
  local t = vim.rpcrequest(channel, 'nvim_get_namespaces' )
  for k, v in pairs(t) do
    if k:find('Indent') then
      return  v
    end
  end
end

local function nvim_get_hl(ns)
  return vim.rpcrequest(channel, 'nvim_get_hl', ns, {})
end

local function match_current_hl(srow, erow ,col)
  local cur_hi = 'IndentLineCurrent'
  local ns = get_indent_ns()
  local t = {}
  for k, v in pairs(nvim_get_hl(ns) or {}) do
    if v.link and v.link == cur_hi then
      t[#t + 1] = k:match('IndentLine(%d+)5')
    end
  end
  return #t
end

local function screen(lines)
  if not channel then
    channel = nvim_instance()
  end
  local current_dir = vim.fn.getcwd()
  vim.rpcrequest(channel, 'nvim_set_option_value', 'rtp', current_dir, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_exec_lua', 'require("indentmini").setup({})', {})
  vim.rpcrequest(channel, 'nvim_set_option_value', 'columns', 26, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'lines', #lines + 2, { scope = 'global' })
  --indent set
  vim.rpcrequest(channel, 'nvim_set_option_value', 'expandtab', true, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'shiftwidth', 2, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'tabstop', 2, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'softtabstop', 2, { scope = 'global' })

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
    -- for _, line in ipairs(screenstr) do
    --   print(vim.inspect(line))
    -- end
    local expected = {
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

    assert.same(expected, screenstr)
  end)

  it('not work when line has tab character', function()
    local lines = {
      'functio test_tab()',
      '\tprint("hello")',
      '\tprint("world")',
      'end',
    }
    local screenstr = screen(lines)
    local expected = {
      'functio test_tab()        ',
      '        print("hello")    ',
      '        print("world")    ',
      'end                       ',
    }
    assert.same(expected, screenstr)
  end)

  it('works on blank line', function()
    local lines = {
      'local function test()',
      '  while true do',
      '    if true then',
      '      if true then',
      '',
      '',
      '',
      '        print("test")',
      '      end',
      '    end',
      '  end',
      'end',
    }

    local screenstr = screen(lines)
    local expected = {
      'local function test()     ',
      '┇ while true do           ',
      '┇ ┇ if true then          ',
      '┇ ┇ ┇ if true then        ',
      '┇ ┇ ┇ ┇                   ',
      '┇ ┇ ┇ ┇                   ',
      '┇ ┇ ┇ ┇                   ',
      '┇ ┇ ┇ ┇ print("test")     ',
      '┇ ┇ ┇ end                 ',
      '┇ ┇ end                   ',
      '┇ end                     ',
      'end                       ',
    }
    assert.same(expected, screenstr)
  end)

  it('works on highlight current level', function ()
    local lines= {
      'local function test_b()',
      '  local a = 10         ',
      '                       ',
      '  if true then         ',
      '    if true then       ',
      '      local b = 20     ',
      '                       ',
      '      while true do    ',
      '        print("hello") ',
      '      end              ',
      '                       ',
      '      print("here")    ',
      '    end                ',
      '  end                  ',
      'end                    ',
      '                       ',
      'local function test()  ',
      '  local a = 10         ',
      '                       ',
      '  if true then         ',
      '    if true then       ',
      '      local b = 20     ',
      '                       ',
      '      while true do    ',
      '        print("hello") ',
      '      end              ',
      '                       ',
      '      print("here")    ',
      '    end                ',
      '  end                  ',
      'end                    ',
    }
    screen(lines)
    nvim_set_cursor(6, 8)
    local ns = get_indent_ns()
    assert.same(9, match_current_hl(6, 12, 5))
  end)
end)
