for i = 1, #arg do
  local f, err = loadfile(arg[i])
  if not f then error(arg[i] .. ': ' .. err) end
end
print('syntax passed for '..#arg..' files')
