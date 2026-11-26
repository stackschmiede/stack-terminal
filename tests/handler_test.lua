-- open-uri-handler: lädt die config, mockt background_child_process und prüft das gestartete argv.
-- aufruf über tests/verify.sh --full (WT_CFG = substituierte config, WT_ED = FILE_LINK_EDITOR der config)
local wezterm = require 'wezterm'
local calls = {}
wezterm.background_child_process = function(argv) calls[#calls + 1] = argv end

local cfg = dofile(os.getenv('WT_CFG'))

local CWD = '/home/user/projects/demo'
local pane = {
  get_current_working_dir = function() return { file_path = CWD } end,
}
local window = {}

local SH = 'wsl.exe -d Ubuntu -e sh -c <OPEN_SH>'
local ED = os.getenv('WT_ED')
local RUN = 'rundll32.exe | url.dll,FileProtocolHandler | '
local cases = {
  -- dokumente → standardprogramm (linux via OPEN_SH ohne editor, windows direkt)
  { '/home/user/projects/demo/Handout.pdf', SH .. " | '' | /home/user/projects/demo/Handout.pdf | ''" },
  { [[C:\Users\user\Downloads\Handout.pdf]], RUN .. [[C:\Users\user\Downloads\Handout.pdf]] },
  { 'D:/data/Plan.PDF', RUN .. [[D:\data\Plan.PDF]] },
  { 'file:///home/user/a%20b.pdf', SH .. " | '' | /home/user/a b.pdf | ''" },
  { '/home/user/x.pdf.', SH .. " | '' | /home/user/x.pdf | ''" },
  { 'docs/Liste.xlsx:3', SH .. " | '' | " .. CWD .. "/docs/Liste.xlsx | ''" },
  -- text/code → editor mit zeile/spalte
  { 'config/wezterm.lua:42', SH .. ' | <ED> | ' .. CWD .. '/config/wezterm.lua | :42' },
  { [[C:\Users\user\.wezterm.lua:12:3]], SH .. [[ | <ED> | C:\Users\user\.wezterm.lua | :12:3]] },
  { '~/notes/x.md', SH .. " | <ED> | ~/notes/x.md | ''" },
  { 'README.md,', SH .. ' | <ED> | ' .. CWD .. "/README.md | ''" },
  { '/home/user/projects/', SH .. " | <ED> | /home/user/projects/ | ''" },
  -- urls → browser
  { 'https://example.com/?a=1&b=2', RUN .. 'https://example.com/?a=1&b=2' },
  { 'mailto:x@example.com', RUN .. 'mailto:x@example.com' },
}

local function show(argv)
  local out = {}
  for i, a in ipairs(argv) do
    if i == 7 and argv[1] == 'wsl.exe' then
      out[#out + 1] = '<OPEN_SH>'
    elseif i == 8 and argv[1] == 'wsl.exe' and a == ED then
      out[#out + 1] = '<ED>'
    elseif a == '' then
      out[#out + 1] = "''"
    else
      out[#out + 1] = a
    end
  end
  if argv[1] == 'wsl.exe' then
    return table.concat(out, ' ', 1, 7) .. ' | ' .. table.concat(out, ' | ', 8)
  end
  return table.concat(out, ' | ')
end

local f = assert(io.open(os.getenv('WT_OUT'), 'wb'))
local pass = 0
for _, c in ipairs(cases) do
  calls = {}
  wezterm.emit('open-uri', window, pane, c[1])
  local got = (#calls == 1) and show(calls[1]) or ('#calls=' .. #calls)
  local ok = got == c[2]
  if ok then pass = pass + 1 end
  f:write((ok and 'PASS ' or 'FAIL ') .. c[1] .. '\n')
  if not ok then f:write('  want: ' .. c[2] .. '\n  got:  ' .. got .. '\n') end
end
f:write(string.format('RESULT %d/%d\n', pass, #cases))
f:close()
return cfg
