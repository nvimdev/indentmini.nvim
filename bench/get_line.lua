local ffi = require('ffi')
local api = vim.api

-- FFI definition for ml_get
ffi.cdef([[
  typedef int32_t linenr_T;
  char *ml_get(linenr_T lnum);
]])

local C = ffi.C

-- Function to get line using ml_get
local function get_line_with_ml_get(lnum)
  return ffi.string(C.ml_get(lnum))
end

-- Function to get line using api.nvim_buf_get_lines
local function get_line_with_api(bufnr, lnum)
  return api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
end

-- Benchmark function
local function benchmark(func, bufnr, lnum, iterations)
  local start_time = vim.uv.hrtime()
  for _ = 1, iterations do
    func(bufnr, lnum)
  end
  local end_time = vim.uv.hrtime()
  return (end_time - start_time) / iterations
end

-- Example usage
local bufnr = api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { ('text '):rep(100) })
local lnum = 1
local iterations = 10000

-- Warm up
get_line_with_ml_get(lnum)
get_line_with_api(bufnr, lnum)

-- Run benchmarks
local time_ml_get = benchmark(function(_, lnum)
  return get_line_with_ml_get(lnum)
end, bufnr, lnum, iterations)
local time_api = benchmark(get_line_with_api, bufnr, lnum, iterations)

print(string.format('ml_get: %.3f ns per call', time_ml_get))
print(string.format('api.nvim_buf_get_lines: %.3f ns per call', time_api))
