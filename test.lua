local function test_b()
  local a = 10

  if true then
    if true then
      local b = 20

      while true do
        print('hello')
      end

      print('here')
    end
  end
end

local function test()
  local a = 10

  if true then
    if true then
      local b = 20

      while true do
        print('hello')
      end

      print('here')
    end
  end
end

local function test_a()
  while true do
    if true then
      if true then
        print('test')
      end
    end
  end
end
