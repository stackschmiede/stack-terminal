-- lädt die config per pcall(dofile) und schreibt OK oder den lua-fehler nach WT_OUT.
-- aufruf über tests/verify.sh (WSLENV=WT_CFG/p:WT_OUT/p … wezterm.exe --config-file load_test.lua show-keys)
local wezterm = require 'wezterm'
wezterm.background_child_process = function() end

local ok, res = pcall(dofile, os.getenv('WT_CFG'))
local f = assert(io.open(os.getenv('WT_OUT'), 'wb'))
if ok and type(res) == 'table' then
  f:write('OK\n')
else
  f:write('ERR ' .. tostring(res) .. '\n')
end
f:close()
if ok and type(res) == 'table' then return res end
return {}
