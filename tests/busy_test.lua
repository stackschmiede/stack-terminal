-- tab-state: lädt die config, füttert den status-poll mit fake-panes (bildschirmtexte unten) und
-- prüft, was format-tab-title für den inaktiven tab rendert: string = idle, tabelle = busy,
-- tabelle mit Attribute = attention (glocke). aufruf über tests/verify.sh --full.
-- fußzeilen: claude code 2.1.332 in tmux, per `tmux capture-pane` aufgenommen (real) bzw. daraus
-- abgeleitet (abgel.) — der verlauf darüber ist neutraler beispieltext.
local wezterm = require 'wezterm'
local handlers = {}
local orig_on = wezterm.on
wezterm.on = function(name, fn)
  handlers[name] = handlers[name] or {}
  table.insert(handlers[name], fn)
  return orig_on(name, fn)
end
wezterm.background_child_process = function() end

local cfg = dofile(os.getenv('WT_CFG'))

local TOP = {
  '● Beispieltext aus dem Verlauf.',
  '  Thought for 9s, ran 3 shell commands',
  '✢ Working… (4m 1s · ↓ 15.7k tokens)',
  '  ⎿  Tip: Use git worktrees to run multiple Claude sessions in parallel.',
  '────────────────────────────────────────',
  '❯ ',
  '────────────────────────────────────────',
  '  ● user · Opus · ctx 26%',
}
local TMUX = '[cc-9] 0:claude*                         "cc-9 · claude" 10:20 26-Nov-26'

-- bildschirm = TOP (bzw. eigener verlauf) + fußzeile/liste + tmux-status, wie wezterm: letzte 12 zeilen
local function screen(bottom, top)
  local t = {}
  for _, l in ipairs(top or TOP) do t[#t + 1] = l end
  for _, l in ipairs(bottom) do t[#t + 1] = l end
  t[#t + 1] = TMUX
  return table.concat(t, '\n', math.max(1, #t - 11), #t)
end

local IDLE        = '  ⏵⏵ bypass permissions on (shift+tab to cycle)'                                     -- real
local SHELL_BUSY  = '  ⏵⏵ bypass permissions on · 1 shell · esc to interrupt · ↓ to manage'                -- real
local SHELL_IDLE  = '  ⏵⏵ bypass permissions on · 1 shell · ↓ to manage'                                   -- abgel.
local SHELL2_IDLE = '  ⏵⏵ bypass permissions on · 2 shells · ↓ to manage'                                  -- abgel.
local AGENT_BUSY  = '  ⏵⏵ bypass permissions on (shift+tab to cycle) · esc to interrupt · ↓ to manage'    -- real
local AGENT_IDLE  = '  ⏵⏵ bypass permissions on (shift+tab to cycle) · ↓ to manage'                       -- real
local AGENT_DONE  = '  ⏵⏵ bypass permissions on (shift+tab to cycle) · /tasks to see subagents · esc to interrupt' -- real
local MAIN, AGENT = '  ● main', '  ◯ general-purpose  Test-Agent'                                             -- real

local QUOTE_TOP = {
  '● Zitat: ⏵⏵ bypass permissions on · 1 shell · esc to interrupt · ↓ to manage',
  '  ● main',
  '  ◯ general-purpose  Test-Agent',
  '────────────────────────────────────────',
  '❯ ',
  '────────────────────────────────────────',
  '  ● user · Opus · ctx 26%',
}

-- name, bildschirm, erwartung, glocke vorher
local cases = {
  { 'claude arbeitet, 1 shell',       screen({ SHELL_BUSY }),                                   'BUSY' },
  { 'idle, keine hintergrund-arbeit', screen({ IDLE }),                                         'IDLE' },
  { 'idle, 1 shell',                  screen({ SHELL_IDLE }),                                   'BUSY' },
  { 'idle, 2 shells',                 screen({ SHELL2_IDLE }),                                  'BUSY' },
  { 'agent läuft, claude arbeitet',   screen({ AGENT_BUSY, MAIN, AGENT }),                      'BUSY' },
  { 'agent läuft, turn zu ende',      screen({ AGENT_IDLE, MAIN, AGENT }),                      'BUSY' },
  { 'drei agenten',                   screen({ AGENT_IDLE, MAIN, AGENT, '  ◯ Explore  Suche', '  ◯ Plan  Entwurf' }), 'BUSY' },
  { 'agent + shell',                  screen({ SHELL_IDLE, MAIN, AGENT }),                      'BUSY' },
  { 'agent ausgewählt (◯ main)',      screen({ AGENT_IDLE, '  ◯ main', '  ● general-purpose  Test-Agent' }), 'BUSY' },
  { 'agent fertig',                   screen({ AGENT_DONE }),                                   'IDLE' },
  { 'verlauf zitiert fußzeile+liste', screen({ IDLE }, QUOTE_TOP),                              'IDLE' },
  { '„ran 3 shell commands" unten',   'x\n  Thought for 9s, ran 3 shell commands\n\n' .. TMUX,  'IDLE' },
  { 'bash-prompt',                    'user@pc:~/projects$ ls\na  b  c\nuser@pc:~/projects$ ',  'IDLE' },
  { 'leer',                           '',                                                       'IDLE' },
  { 'glocke + 1 shell',               screen({ SHELL_IDLE }),                                   'BUSY', true },
  { 'glocke + agent läuft',           screen({ AGENT_IDLE, MAIN, AGENT }),                      'BUSY', true },
  { 'glocke, nichts im hintergrund',  screen({ IDLE }),                                         'ATTN', true },
}

local out = assert(io.open(os.getenv('WT_OUT'), 'wb'))
local pass = 0
for i, c in ipairs(cases) do
  local text = c[2]
  local id = 1000 + i
  local fake_pane = {
    pane_id = function() return id end,
    get_lines_as_text = function() return text end,
  }
  wezterm.mux.all_windows = function()
    return { { tabs = function() return { { panes = function() return { fake_pane } end } } end } }
  end
  -- zwei polls: der erste legt den state an (schreibt in eine lokale kopie), ab dem zweiten wirkt es.
  -- die handler brechen danach am fake-fenster ab (set_left_status) — der poll davor ist durch
  for _ = 1, 2 do
    for _, h in ipairs(handlers['update-status'] or {}) do pcall(h, {}, fake_pane) end
  end
  local st = wezterm.GLOBAL.pane_state[tostring(id)]
  st.last_change = 0 -- fingerprint-fenster neutralisieren: nur die hintergrund-erkennung entscheidet
  if c[4] then st.attn_pending = true end
  local tab = {
    tab_index = 1, is_active = false, tab_title = 'test',
    active_pane = { title = 'cc-9 · claude', pane_id = id },
  }
  local r = handlers['format-tab-title'][1](tab, { tab }, { tab.active_pane }, cfg, false, 34)
  local got = 'IDLE'
  if type(r) == 'table' then
    got = 'BUSY'
    for _, item in ipairs(r) do
      if item.Attribute then got = 'ATTN' end
    end
  end
  local ok = got == c[3]
  if ok then pass = pass + 1 end
  out:write(string.format('%s %s: want=%s got=%s\n', ok and 'PASS' or 'FAIL', c[1], c[3], got))
end
out:write(string.format('RESULT %d/%d\n', pass, #cases))
out:close()
return cfg
