local function test()
  local a = 10
  local b = 20
  while true do
    if a > b then
      if b < a then
        print('test')
      end
    end
  end
end
