-- selbstheilung der hintergrundbilder (bh_*): wezterm lagert dekodierte hintergrundbilder nach
-- %TEMP%\wezterm-blob-lease-* aus; fehlen die dateien, scheitert jeder paint (`paint_pass failed:
-- render_backgrounds: … BlobLease`). die config liest das eigene log, hängt logo + nutzungs-bild als
-- kopie mit zusätzlichem tEXt-chunk neu ein (anderer datei-inhalt → wezterm dekodiert neu) und gibt
-- nach BH_MAX erfolglosen heilungen auf (bilder aus). der test fährt den status-poll mit fake-fenster,
-- gemockter uhr und einem log, das er selbst schreibt; ob wezterm danach wirklich neu dekodiert, kann
-- nur ein echter gui-prozess zeigen (WORKNOTES 2026-11-28). aufruf über tests/verify.sh --full
-- (setzt WEZTERM_CLAUDE_USAGE_DIR, _CACHE und WEZTERM_BG_HEAL_LOG).
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
local logged = {} -- meldungen der config (nicht ins echte log)
wezterm.log_error = function(...) logged[#logged + 1] = table.concat({ ... }, ' ') end
wezterm.log_warn = wezterm.log_error
local NOW = 1800000000
local real_time = os.time
os.time = function(t) if t then return real_time(t) end return NOW end
-- eigene pid fest; 5151 = anderes laufendes wezterm, 6161 = pid inzwischen an ein fremdes programm vergeben
local PID = 4242
wezterm.procinfo.pid = function() return PID end
wezterm.procinfo.get_info_for_pid = function(pid)
  if pid == 5151 then return { name = 'wezterm-gui.exe' } end
  if pid == 6161 then return { name = 'notepad.exe' } end
  return nil
end

local DIR, CACHE = os.getenv('WEZTERM_CLAUDE_USAGE_DIR'), os.getenv('WEZTERM_CLAUDE_USAGE_CACHE')
local LOG = os.getenv('WEZTERM_BG_HEAL_LOG')
local HEAL = DIR .. '\\.wezterm-bg-heal'
local SIG, IEND = '\x89PNG\r\n\x1a\n', '\0\0\0\0IEND\xAE\x42\x60\x82'
-- echte zeile aus dem vorfall vom 2026-11-28 (deutsches windows)
local ERR = '01:39:02.804  ERROR  wezterm_gui::termwindow::render::paint > paint_pass failed: render_backgrounds: '
  .. 'frames.current_frame.lease.get_data: Io error in BlobLease: Das System kann die angegebene Datei nicht finden. '
  .. '(os error 2): Das System kann die angegebene Datei nicht finden. (os error 2)\r\n'
local PATTERN = 'render_backgrounds[^\r\n]*BlobLease'

local function slurp(p)
  local f = p and io.open(p, 'rb')
  if not f then return nil end
  local d = f:read('*a')
  f:close()
  return d
end
local function spit(p, data, mode)
  local f = assert(io.open(p, mode or 'wb'))
  f:write(data)
  f:close()
end
local function exists(p) return slurp(p) ~= nil end
local function write_cache(pct)
  spit(CACHE, wezterm.json_encode {
    fetched_at = NOW,
    accounts = { { label = '', http = 200, updated_at = NOW, rows = {
      { kind = 'weekly_all', label = '7d', pct = pct, resets_at = NOW + 86400, severity = 'normal', active = true },
    } } },
  })
end

-- crc32 unabhängig von der config (tabelle statt bit-schleife), geprüft am festen IEND-chunk
local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do c = (c & 1 == 1) and (0xEDB88320 ~ (c >> 1)) or (c >> 1) end
  CRC[i] = c
end
local function crc32(s)
  local c = 0xFFFFFFFF
  for i = 1, #s do c = CRC[(c ~ s:byte(i)) & 0xFF] ~ (c >> 8) end
  return c ~ 0xFFFFFFFF
end
-- png in chunks zerlegen: { {type, data, ok = crc stimmt} … } oder nil bei kaputter struktur
local function chunks(data)
  if not data or data:sub(1, 8) ~= SIG then return nil end
  local pos, list = 9, {}
  while pos <= #data do
    if pos + 11 > #data then return nil end
    local len, typ = string.unpack('>I4c4', data, pos)
    local body = data:sub(pos + 8, pos + 7 + len)
    if #body ~= len or pos + 11 + len > #data then return nil end
    list[#list + 1] = { type = typ, data = body, ok = string.unpack('>I4', data, pos + 8 + len) == crc32(typ .. body) }
    pos = pos + 12 + len
  end
  return list
end
-- stempel = letzter chunk vor IEND; gibt (text, datei ohne diesen chunk) zurück
local function stamp_of(data)
  local list = chunks(data)
  if not list or #list < 2 or list[#list].type ~= 'IEND' then return nil end
  for _, c in ipairs(list) do if not c.ok then return nil end end
  local t = list[#list - 1]
  if t.type ~= 'tEXt' then return nil end
  return t.data, data:sub(1, #data - 12 - (12 + #t.data)) .. IEND
end

-- reste früherer prozesse, bevor die config das erste mal aufräumt
local DEAD, ALIVE, REUSED = HEAL .. '.9999999-1.png', HEAL .. '.5151-2.png', HEAL .. '.6161-1.png'
for _, p in ipairs { DEAD, ALIVE, REUSED } do spit(p, SIG .. IEND) end
os.remove(LOG)
write_cache(10)

local cfg = dofile(os.getenv('WT_CFG'))
wezterm.mux.all_windows = function() return {} end

local overrides
local actions = 0
local win = {
  window_id = function() return 1 end,
  get_appearance = function() return 'Dark' end,
  get_config_overrides = function() return overrides end,
  set_config_overrides = function(_, o) overrides = o end,
  set_left_status = function() end,
  set_right_status = function() end,
  get_dimensions = function() return { dpi = 96 } end,
  perform_action = function() actions = actions + 1 end,
}
local function files() -- bild-layer in den overrides: logo, nutzung, anzahl
  local logo, usage, n = nil, nil, 0
  for _, l in ipairs((overrides or {}).background or {}) do
    local f = l.source and l.source.File
    if f then
      n = n + 1
      if f:find('claude%-usage') then usage = f else logo = f end
    end
  end
  return logo, usage, n
end
local function layers() return #((overrides or {}).background or {}) end

local out = assert(io.open(os.getenv('WT_OUT'), 'wb'))
local pass, total, broken = 0, 0, 0
local function check(name, ok, info)
  total = total + 1
  if ok then pass = pass + 1 end
  -- stempel enthalten ein NUL: als text ausgeben, sonst hält grep die ergebnisdatei für binär
  info = info ~= nil and ('  (' .. tostring(info):gsub('%c', '␀') .. ')') or ''
  out:write(string.format('%s %s%s\n', ok and 'PASS' or 'FAIL', name, info))
end
local function tick(dt)
  NOW = NOW + (dt or 1)
  for _, h in ipairs(handlers['update-status'] or {}) do pcall(h, win, nil) end
  local logo, usage = files()
  if (logo and not exists(logo)) or (usage and not exists(usage)) then broken = broken + 1 end
end
local function f5() -- taste F5: event der config, danach lädt wezterm neu und meldet window-config-reloaded
  for _, h in ipairs(handlers['stack-reload'] or {}) do pcall(h, win, nil) end
  for _, h in ipairs(handlers['window-config-reloaded'] or {}) do pcall(h, win, nil) end
end
local function render_done(i) spit(jobs[i], SIG .. IEND) end

local ok_run, err_run = pcall(function()
check('test-crc stimmt am IEND-chunk', crc32('IEND') == 0xAE426082)

-- 1) start: reste aufräumen, bilder wie immer (kein log, keine heilung)
tick()
check('start: logo-kopie eines beendeten prozesses gelöscht', not exists(DEAD))
check('start: logo-kopie eines laufenden wezterm bleibt', exists(ALIVE))
check('start: pid gehört einem fremden programm → kopie gelöscht', not exists(REUSED))
render_done(1); tick(); tick()
local LOGO, usage1 = files()
local LOGO_DATA = slurp(LOGO)
check('ohne fehler im log: original-logo + unveränderte nutzung',
  LOGO ~= nil and not LOGO:find('bg%-heal') and usage1 == jobs[1] and slurp(usage1) == SIG .. IEND, LOGO)
check('logo-quelle ist ein lesbares png', LOGO_DATA ~= nil and chunks(LOGO_DATA) ~= nil, LOGO)

-- 2) fremde fehlerzeilen lösen nichts aus
spit(LOG, '01:00:00.000  ERROR  wezterm_gui::termwindow::render::paint > paint_pass failed: frames.current_frame.lease.get_data: '
  .. 'Io error in BlobLease: nicht gefunden (os error 2)\r\n'
  .. '01:00:01.000  ERROR  wezterm_gui::termwindow::background > render_backgrounds: etwas anderes\r\n', 'ab')
tick(5); tick(5)
check('BlobLease-fehler außerhalb der hintergründe: keine heilung', (files()) == LOGO)

-- 3) fehler der hintergrundbilder → heilung beim nächsten blick ins log
spit(LOG, ERR, 'ab')
tick(5)
local logo1, usage2 = files()
check('fehler im log: logo zeigt auf eine kopie mit pid + stand', logo1 == HEAL .. '.' .. PID .. '-1.png' and exists(logo1), logo1)
local text, rest = stamp_of(slurp(logo1))
check('logo-kopie: gültiges png, alle crc stimmen, tEXt-stempel vor IEND', text == 'Comment\0wezterm-bg-heal 1', text)
check('logo-kopie: ohne stempel identisch mit dem original (gleiche pixel)', rest == LOGO_DATA)
check('logo-kopie: anderer datei-inhalt als das original', slurp(logo1) ~= LOGO_DATA)
check('nutzung zeigt auf eine neue datei', usage2 ~= nil and usage2 ~= usage1 and exists(usage2), usage2)
text, rest = stamp_of(slurp(usage2))
check('nutzungs-kopie: stempel, sonst identisch mit dem bisherigen bild', text == 'Comment\0wezterm-bg-heal 1' and rest == SIG .. IEND, text)
check('abgelöstes nutzungs-bild liegt noch (< 60 s)', exists(usage1))

-- 4) ruhezeit: fehler in den 10 s nach der heilung zählen nicht (fenster übernehmen nacheinander)
spit(LOG, ERR, 'ab')
tick(5)
check('fehler in der ruhezeit: keine zweite heilung', (files()) == logo1)
tick(5); tick(5)
check('abgehakte fehler lösen später nichts aus', (files()) == logo1)

-- 5) neuer fehler nach der ruhezeit → nächster stand; log wurde inzwischen kürzer (neu angelegt)
spit(LOG, ERR)
tick(5)
local logo2 = files()
check('neuer fehler (log neu angelegt): zweiter stand', logo2 == HEAL .. '.' .. PID .. '-2.png' and exists(logo2), logo2)
check('abgelöste logo-kopie liegt noch (< 60 s)', exists(logo1))
tick(61)
check('nach 60 s: abgelöste kopien gelöscht', not exists(logo1) and not exists(usage1) and not exists(usage2))
local _, usage3 = files()
check('nach 60 s: angezeigte bilder bleiben', exists(logo2) and usage3 ~= nil and exists(usage3))

-- 6) nach einer heilung bekommt jedes neu gerenderte bild den stempel des stands
write_cache(55); tick()
local n = #jobs
check('neuer inhalt → renderer beauftragt', n >= 2 and jobs[n] ~= jobs[1], jobs[n])
spit(jobs[n], SIG) -- renderer noch nicht fertig: kein vollständiges png
tick()
check('unvollständige datei wird nicht übernommen', select(2, files()) == usage3)
render_done(n); tick(); tick()
local _, usage4 = files()
text, rest = stamp_of(slurp(usage4))
check('fertiges bild übernommen und gestempelt', usage4 == jobs[n] and text == 'Comment\0wezterm-bg-heal 2' and rest == SIG .. IEND, text)

-- 7) F5 heilt von hand (auch ohne fehler im log), lädt neu und rendert die nutzung neu
tick(301) -- neues zeitfenster für den zähler der heilungen
local before = #jobs
f5()
local logo3, usage5 = files()
check('F5: neuer stand ohne fehler im log', logo3 == HEAL .. '.' .. PID .. '-3.png' and exists(logo3), logo3)
check('F5: genau ein reload ausgelöst', actions == 1, actions)
text = stamp_of(slurp(usage5))
check('F5: angezeigte nutzung sofort als kopie mit neuem stempel', usage5 ~= usage4 and text == 'Comment\0wezterm-bg-heal 3', text)
tick()
check('F5: nutzung wird neu gerendert', #jobs == before + 1, #jobs - before)
render_done(#jobs); tick(); tick()

-- 8) heilen hilft nicht (fehler kommen immer wieder) → nach BH_MAX heilungen bilder aus, einmal gemeldet
tick(301)
local heals = 0
for _ = 1, 3 do
  local was = files()
  spit(LOG, ERR, 'ab'); tick(11)
  if (files()) ~= was and (files()) ~= nil then heals = heals + 1 end
end
check('drei fehler-runden: drei heilungen, bilder noch da', heals == 3 and select(3, files()) == 2, heals)
spit(LOG, ERR, 'ab'); tick(11)
check('vierte runde im selben zeitfenster: nur noch die farbfläche', select(3, files()) == 0 and layers() == 1, layers())
local off_msgs = 0
for _, m in ipairs(logged) do if m:find('hintergrundbilder aus', 1, true) then off_msgs = off_msgs + 1 end end
spit(LOG, ERR, 'ab'); tick(11); spit(LOG, ERR, 'ab'); tick(11)
local off_msgs2 = 0
for _, m in ipairs(logged) do if m:find('hintergrundbilder aus', 1, true) then off_msgs2 = off_msgs2 + 1 end end
check('bilder aus: genau eine meldung, weitere fehler ändern nichts', off_msgs == 1 and off_msgs2 == 1 and layers() == 1, off_msgs2)

-- 9) F5 holt die bilder zurück; heilung wirkt auch, solange kein nutzungs-bild angezeigt wird
f5(); tick()
local bare = files()
spit(LOG, ERR, 'ab'); tick(11)
check('heilung ohne nutzungs-bild: logo wechselt trotzdem', bare ~= nil and (files()) ~= nil and (files()) ~= bare, (files()))
render_done(#jobs); tick(); tick()
local logo4, usage6, count = files()
check('F5 nach „bilder aus": logo + nutzung wieder da', count == 2 and logo4 ~= nil and logo4:find('bg%-heal') ~= nil and usage6 ~= nil, count)

-- 10) logo-quelle unlesbar → nur das logo fällt weg, der rest läuft (nur wenn die quelle im testordner liegt)
if LOGO:sub(1, #DIR) == DIR then
  os.remove(LOGO)
  tick(301); f5(); tick()
  local l, u, c = files()
  check('logo-quelle fehlt: logo-layer weg, nutzung bleibt', l == nil and u ~= nil and c == 1, c)
  spit(LOGO, LOGO_DATA)
  tick(301); f5(); tick()
  check('logo-quelle wieder da: F5 bringt das logo zurück', (files()) ~= nil and exists((files())))
end

local own = 0
for _, m in ipairs(logged) do if m:find(PATTERN) then own = own + 1 end end
check('eigene meldungen treffen das suchmuster nicht (keine selbst-auslösung)', #logged > 0 and own == 0, #logged .. ' meldungen')
check('invariante: jedes angezeigte bild existierte in jedem tick', broken == 0, broken .. ' verstöße')
end)
if not ok_run then check('abbruch', false, tostring(err_run)) end

for _, p in ipairs(jobs) do os.remove(p) end
os.remove(ALIVE)
os.remove(LOG)
os.remove(DIR .. '\\.wezterm-claude-usage.spec')
out:write(string.format('RESULT %d/%d\n', pass, total))
out:close()
return cfg
