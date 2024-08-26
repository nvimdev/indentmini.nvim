local function only_spaces_or_tabs(text)
  for i = 1, #text do
    local c = text:sub(i, i)
    if c ~= ' ' and c ~= '\t' then
      return false
    end
  end
  return true
end

local function only_spaces_or_tabs_regex(text)
  return not text:find('[^ \t]')
end

local function benchmark(func, text, iterations)
  local start_time = os.clock()
  for _ = 1, iterations do
    func(text)
  end
  local end_time = os.clock()
  return end_time - start_time
end

local text = '    \t\t    ' -- Example text to test
local iterations = 1000000 -- Number of iterations for the benchmark

local time1 = benchmark(only_spaces_or_tabs, text, iterations)
local time2 = benchmark(only_spaces_or_tabs_regex, text, iterations)

print('Time for only_spaces_or_tabs:', time1)
print('Time for only_spaces_or_tabs_regex:', time2)

-- Time for only_spaces_or_tabs: 0.07258
-- Time for only_spaces_or_tabs_regex: 0.093389
