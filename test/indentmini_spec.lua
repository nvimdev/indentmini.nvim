require('indentmini').setup()

local channel, job_id

local function clean()
  vim.fn.jobstop(job_id)
  job_id = nil
  channel = nil
end

local function nvim_instance()
  local address = vim.fn.tempname()
  job_id = vim.fn.jobstart({ 'nvim', '--clean', '-n', '--listen', address }, { pty = true })
  vim.uv.sleep(200)
  return vim.fn.sockconnect('pipe', address, { rpc = true })
end

local function screen(lines)
  if not channel then
    channel = nvim_instance()
  end
  local current_dir = vim.uv.cwd()
  local rtp = vim.rpcrequest(channel, 'nvim_get_option_value', 'rtp', { scope = 'global' })
  rtp = ('%s,%s'):format(rtp, current_dir)
  vim.rpcrequest(channel, 'nvim_set_option_value', 'rtp', rtp, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_exec_lua', 'require("indentmini").setup({})', {})
  vim.rpcrequest(channel, 'nvim_set_option_value', 'columns', 26, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'lines', #lines + 2, { scope = 'global' })
  --indent set
  vim.rpcrequest(channel, 'nvim_set_option_value', 'expandtab', true, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'shiftwidth', 2, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'tabstop', 2, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'softtabstop', 2, { scope = 'global' })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'shiftwidth', 2, { buf = 0 })
  vim.rpcrequest(channel, 'nvim_set_option_value', 'expandtab', true, { buf = 0 })

  vim.rpcrequest(channel, 'nvim_buf_set_lines', 0, 0, -1, false, lines)
  local buf = vim.rpcrequest(channel, 'nvim_get_current_buf')
  vim.rpcrequest(channel, 'nvim_win_set_buf', 0, buf)
  local screenstring = function(row, col)
    return vim.rpcrequest(channel, 'nvim_exec_lua', 'return vim.fn.screenstring(...)', { row, col })
  end

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

describe('indent mini', function()
  after_each(function()
    clean()
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
    local screenstr = screen(lines)
    local expected = {
      'local function test()     ',
      '│ local a = 10            ',
      '│ local b = 20            ',
      '│ while true do           ',
      '│ │ if a > b then         ',
      '│ │ │ if b < a then       ',
      '│ │ │ │ print("test")     ',
      '│ │ │ end                 ',
      '│ │ end                   ',
      '│ end                     ',
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
      '│ while true do           ',
      '│ │ if true then          ',
      '│ │ │ if true then        ',
      '│ │ │ │                   ',
      '│ │ │ │                   ',
      '│ │ │ │                   ',
      '│ │ │ │ print("test")     ',
      '│ │ │ end                 ',
      '│ │ end                   ',
      '│ end                     ',
      'end                       ',
    }
    assert.same(expected, screenstr)
  end)
end)
