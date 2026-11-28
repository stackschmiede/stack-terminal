-- startet den test aus WT_TEST per pcall. ein lua-fehler beim laden eines tests stünde sonst nirgends:
-- `show-keys` endet auch dann mit exit 0 und leerem stderr. aufruf über tests/verify.sh (run_lua).
local ok, res = pcall(dofile, os.getenv('WT_TEST'))
if ok then return res end
local f = io.open(os.getenv('WT_OUT'), 'ab')
if f then
  f:write('FAIL test bricht beim laden ab\n  ' .. tostring(res) .. '\nRESULT 0/1\n')
  f:close()
end
return {}
