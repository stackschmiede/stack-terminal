-- nutzungs-bild (position 'bottom'): lädt die config, fährt den status-poll mit fake-fenster und
-- gemockter uhr und prüft die bild-dateien. invariante: das bild in den overrides existiert immer
-- (fehlt es beim laden, bleibt die anzeige leer, bis sich der inhalt ändert). je render ein neues bild,
-- abgelöste verschwinden nach CU_KEEP (60 s), reste früherer prozesse beim start (alte slots a/b
-- sofort, datierte nach einem tag). der renderer (powershell) ist ersetzt: der test schreibt das bild
-- selbst. aufruf über tests/verify.sh --full (setzt WEZTERM_CLAUDE_USAGE_DIR + _CACHE).
local wezterm = require 'wezterm'
local handlers = {}
local orig_on = wezterm.on
wezterm.on = function(name, fn)
  handlers[name] = handlers[name] or {}
  table.insert(handlers[name], fn)
  return orig_on(name, fn)
end
local jobs = {} -- ziel-pngs der renderer-aufrufe
wezterm.background_child_process = function(args)
  for i, a in ipairs(args) do
    if a == '-Out' then jobs[#jobs + 1] = args[i + 1] end
  end
end
local NOW = 1800000000
local real_time = os.time
os.time = function(t) if t then return real_time(t) end return NOW end

local DIR, CACHE = os.getenv('WEZTERM_CLAUDE_USAGE_DIR'), os.getenv('WEZTERM_CLAUDE_USAGE_CACHE')
local BASE = DIR .. '\\.wezterm-claude-usage'

local function exists(p)
  local f = p and io.open(p, 'rb')
  if f then f:close() return true end
  return false
end
local function touch(p)
  local f = assert(io.open(p, 'wb'))
  f:write('png')
  f:close()
end
local function write_cache(pct)
  local f = assert(io.open(CACHE, 'wb'))
  f:write(wezterm.json_encode {
    fetched_at = NOW,
    accounts = { { label = '', http = 200, updated_at = NOW, rows = {
      { kind = 'weekly_all', label = '7d', pct = pct, resets_at = NOW + 86400, severity = 'normal', active = true },
    } } },
  })
  f:close()
end

-- reste früherer prozesse, bevor die config das erste mal rendert
local LEGACY_A, LEGACY_B = BASE .. '.a.png', BASE .. '.b.png'
local OLD   = string.format('%s.%d-3.png', BASE, NOW - 2 * 86400)
local FRESH = string.format('%s.%d-9.png', BASE, NOW - 100) -- zweiter prozess, zeigt es evtl. gerade
for _, p in ipairs { LEGACY_A, LEGACY_B, OLD, FRESH } do touch(p) end
write_cache(10)

local cfg = dofile(os.getenv('WT_CFG'))
wezterm.mux.all_windows = function() return {} end

local overrides
local win = {
  window_id = function() return 1 end,
  get_appearance = function() return 'Dark' end,
  get_config_overrides = function() return overrides end,
  set_config_overrides = function(_, o) overrides = o end,
  set_left_status = function() end,
  set_right_status = function() end,
  get_dimensions = function() return { dpi = 96 } end,
}
local function shown() -- bild-layer der nutzung in den overrides
  for _, l in ipairs((overrides or {}).background or {}) do
    local f = l.source and l.source.File
    if f and f:find('claude%-usage') then return f end
  end
end

local out = assert(io.open(os.getenv('WT_OUT'), 'wb'))
local pass, total, broken = 0, 0, 0
local function check(name, ok, info)
  total = total + 1
  if ok then pass = pass + 1 end
  out:write(string.format('%s %s%s\n', ok and 'PASS' or 'FAIL', name, info and ('  (' .. info .. ')') or ''))
end
local function tick(dt)
  NOW = NOW + (dt or 1)
  for _, h in ipairs(handlers['update-status'] or {}) do pcall(h, win, nil) end
  if shown() and not exists(shown()) then broken = broken + 1 end
end

local ok_run, err_run = pcall(function()
-- 1) start: aufräumen + erster render
tick()
check('start: alte slots a/b gelöscht', not exists(LEGACY_A) and not exists(LEGACY_B))
check('start: rest älter als 1 tag gelöscht', not exists(OLD))
check('start: junges bild eines anderen prozesses bleibt', exists(FRESH))
check('erster render beauftragt, eigener dateiname', #jobs == 1 and jobs[1]:find('%.%d+%-%d+%.png$') ~= nil, jobs[1])
check('vor dem fertigen bild kein bild-layer', shown() == nil)

-- 2) bild fertig → angezeigt
touch(jobs[1]); tick(); tick()
check('bild 1 angezeigt', shown() == jobs[1], shown())

-- 3) inhalt ändert sich: neues bild, altes bleibt bis zur übernahme
write_cache(20); tick()
check('neuer inhalt → neue datei', #jobs == 2 and jobs[2] ~= jobs[1], jobs[2])
check('bis zur übernahme bleibt bild 1 angezeigt', shown() == jobs[1] and exists(jobs[1]))
touch(jobs[2]); tick(); tick()
check('bild 2 angezeigt', shown() == jobs[2], shown())
check('abgelöstes bild 1 liegt noch (< 60 s)', exists(jobs[1]))

-- 4) schnelles neu-rendern (fensterstart): nichts gerade übernommenes darf verschwinden
write_cache(30); tick(); touch(jobs[3]); tick(); tick()
check('bild 3 angezeigt', shown() == jobs[3], shown())
check('schnelles neu-rendern: bild 1 + 2 liegen noch', exists(jobs[1]) and exists(jobs[2]))

-- 5) nach CU_KEEP: abgelöste weg, angezeigtes bleibt
tick(61)
check('nach 60 s: abgelöste bilder gelöscht', not exists(jobs[1]) and not exists(jobs[2]))
check('nach 60 s: angezeigtes bild 3 bleibt', shown() == jobs[3] and exists(jobs[3]))
check('bild eines anderen prozesses bleibt (< 1 tag)', exists(FRESH))

-- 6) renderer hängt → fallback auf die tab-leiste, beide bilder werden später aufgeräumt
write_cache(40); tick()
local hung = jobs[4]
tick(21); tick()
check('renderer hängt: fallback ohne bild-layer', hung ~= nil and shown() == nil and not exists(hung), hung)
check('fallback: bild 3 liegt noch (< 60 s)', exists(jobs[3]))
touch(hung) -- renderer schreibt verspätet doch noch
tick(61)
check('fallback: bild 3 + verspätetes bild nach 60 s gelöscht', not exists(jobs[3]) and not exists(hung))

check('invariante: angezeigtes bild existierte in jedem tick', broken == 0, broken .. ' verstöße')
end)
if not ok_run then check('abbruch', false, tostring(err_run)) end

for _, p in ipairs(jobs) do os.remove(p) end
os.remove(FRESH)
os.remove(BASE .. '.spec')
out:write(string.format('RESULT %d/%d\n', pass, total))
out:close()
return cfg
