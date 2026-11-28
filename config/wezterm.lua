-- TerminalStack — WezTerm Config by Stackschmiede
-- https://stackschmiede.de
--
-- Features:
--   · warm workshop brand palette (amber + sage)  ·  dark + light auto (Win11 system-detect)
--   · WSL2 default domain
--   · tab blink: idle shell (sage pulse) + attention (amber blink)
--   · tab rename: F2  or  Ctrl+Shift+E
--   · theme: F10 toggle light↔dark  ·  Shift+F10 reset auf system-autodetect
--   · shift + mousewheel: page scroll
--   · ctrl + mousewheel: font zoom
--   · windows-style copy/paste  (ctrl+c smart, ctrl+v paste, right-click paste)
--   · links: click / ctrl+click  ·  urls → browser, pfade[:zeile] → editor (FILE_LINK_EDITOR)
--   · maus auch in TUIs mit maus-capture (claude code, vim, htop): klick / selektion / paste bleiben beim terminal
--   · close-confirm: fenster / tab / pane schließen fragt nach (y/n)
--   · claude-abo-nutzung am unteren fensterrand (5h · 7d · modell-fenster; poller in WSL, braucht jq + curl)
--
-- Installer-filled placeholders:
--   {{WSL_USERNAME}}   — your wsl username
--   {{WSL_DISTRO}}     — your wsl distribution (e.g. Ubuntu, Debian)
--   {{PROJECTS_PATH}}  — wsl path to your projects folder
--   {{ASSETS_PATH}}    — windows path to the wordmark logo (C:\Users\...\.wezterm-assets)

local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

-- ═══════════════════════════════════════════════════════════════
-- stackschmiede brand palette — dark + light (warm workshop)
-- ═══════════════════════════════════════════════════════════════
local palette_dark = {
  mode         = 'dark',
  bg           = '#0F0F10',
  surface      = '#1A1A1C',
  surface2     = '#222225',
  fg           = '#EDEAE3',
  muted        = '#8A8680',
  border       = '#26262A',
  primary      = '#D4A574',  -- amber
  primarySoft  = '#E8C493',
  accent       = '#6B8E7F',  -- sage
  accentSoft   = '#8BA99C',
  success      = '#7FB069',
  warn         = '#E0A96D',
  danger       = '#C97064',
  ansi = {
    '#1A1A1C', '#C97064', '#6B8E7F', '#D4A574',
    '#7A8A99', '#A67F8E', '#8BA99C', '#8A8680',
  },
  brights = {
    '#26262A', '#D98580', '#7FB069', '#E8C493',
    '#9DB0C0', '#C09AA8', '#94BAB0', '#EDEAE3',
  },
  inactive_hsb     = { saturation = 0.9,  brightness = 0.82 },
  bg_image_opacity = 0.85,
  -- tab-chip colors (siehe make_colors / format-tab-title)
  active_chip      = '#6B8E7F',  -- sage (= accent)
  chip_text        = '#0F0F10',  -- dark anthracite (= bg) — text auf farbigen chips
  busy_text        = '#E8C493',  -- helles amber (= primarySoft) — busy-state text
}

local palette_light = {
  mode         = 'light',
  -- bg richtung warmes kraftpapier: gibt dim/faint-text (claude diff-context, ansi-grays)
  -- genug substrat für lesbaren kontrast. reines cream war zu blass.
  bg           = '#ECE3CC',  -- warm kraftpapier
  surface      = '#D9CCAE',  -- inactive-tab bg, klar gegen kraftpapier abgesetzt
  surface2     = '#C5B58F',
  fg           = '#1A1816',  -- nahezu schwarz, leicht warm
  muted        = '#4A4339',  -- secondary text — AA+ gegen kraftpapier
  border       = '#9A8E76',  -- hairlines (sichtbar, nicht dominant)
  primary      = '#8E5421',  -- amber, kräftiger — workshop-feel auf hell
  primarySoft  = '#B07840',
  accent       = '#345146',  -- sage, dunkler
  accentSoft   = '#557366',
  success      = '#446F2C',
  warn         = '#965A1E',
  danger       = '#8C2E25',
  -- ANSI-mapping light (gruvbox-light-style): alle text-slots dunkel auf hellem bg.
  -- `white` (7) + `bright-white` (15) als FG müssen lesbar sein — nicht hell-cream.
  -- Nur `bright-black` (8) bleibt mid-warm-grey: dient als bg für claude-input-blocks
  -- (Kontrast 5.3:1 gegen default fg `#1A1816`) und als very-muted text (3:1 → AA-large).
  ansi = {
    '#26231E', '#8C2E25', '#345146', '#8E5421',
    '#1F4A6E', '#5C3548', '#1F5B4F', '#5A5247',  -- 7 white = warm-grey-dark (text, ~6:1)
  },
  brights = {
    '#7A6F5C', '#A8362C', '#557366', '#B07840',  -- 8 bright-black = mid-warm-grey (block-bg)
    '#2D6090', '#7A4862', '#2C7868', '#3C3530',  -- 15 bright-white = sehr dunkel (text, ~10:1)
  },
  inactive_hsb     = { saturation = 0.96, brightness = 0.97 },
  bg_image_opacity = 0.55,
  -- tab-chip colors: im light mode dark text auf hellem amber (KEIN cream-auf-farbe,
  -- das wirkt sonst weiß-blass auf hellem terminal)
  active_chip      = '#B07840',  -- helles amber (= primarySoft) — text drauf bleibt lesbar
  chip_text        = '#1A1816',  -- dark anthracite (= fg) — kein "weiß"-effekt
  busy_text        = '#8E5421',  -- kräftiges amber (= primary) — sichtbar auf surface
}

-- shared palette table — closures (tab-title, status-bar) reference this directly;
-- mutated in-place on theme switch so re-renders automatically pick up new colors.
local ss = {}
local function assign_palette(target)
  for k in pairs(ss) do ss[k] = nil end
  for k, v in pairs(target) do ss[k] = v end
end

local function palette_for(appearance)
  if appearance and tostring(appearance):find('Light') then return palette_light end
  return palette_dark
end

-- helpers — build config-blocks from a palette (used at load + on theme switch)
local function make_colors(p)
  return {
    foreground        = p.fg,
    background        = p.bg,
    cursor_bg         = p.primary,
    cursor_fg         = p.bg,
    cursor_border     = p.primary,
    selection_bg      = p.primary,
    selection_fg      = p.bg,
    scrollbar_thumb   = p.border,
    split             = p.border,
    visual_bell       = p.primary,
    ansi              = p.ansi,
    brights           = p.brights,
    tab_bar = {
      background         = p.bg,
      active_tab         = { bg_color = p.active_chip, fg_color = p.chip_text, intensity = 'Bold' },
      inactive_tab       = { bg_color = p.surface,  fg_color = p.muted },
      inactive_tab_hover = { bg_color = p.surface2, fg_color = p.fg,      italic = false },
      new_tab            = { bg_color = p.bg,       fg_color = p.primary },
      new_tab_hover      = { bg_color = p.surface,  fg_color = p.primarySoft },
      inactive_tab_edge  = p.bg,
    },
  }
end

local function make_window_frame(p)
  return {
    font = wezterm.font { family = 'Inter', weight = 'Medium' },
    font_size = 10.0,
    active_titlebar_bg = p.bg,
    inactive_titlebar_bg = p.bg,
  }
end

-- nutzungs-bild (CLAUDE_USAGE.position = 'bottom'): schmaler streifen direkt am unteren fensterrand,
-- links neben dem logo. größe = png-pixel, skaliert wird nichts; die breite ist nur platz nach
-- rechts, transparenter rest kostet nichts.
-- x = linker rand IM bild: horizontal_offset kam bei align Left im fenster nicht an (text am fensterrand).
local CU_CANVAS = { w = 1800, h = 40, x = 24 }

local function make_background(p)
  local layers = {
    { source = { Color = p.bg }, width = '100%', height = '100%', opacity = 1.0 },
    {
      source             = { File = '{{ASSETS_PATH}}\\logo-wordmark.png' },
      repeat_x           = 'NoRepeat',
      repeat_y           = 'NoRepeat',
      vertical_align     = 'Bottom',
      horizontal_align   = 'Right',
      width              = 305,
      height             = 62,
      opacity            = p.bg_image_opacity,
      horizontal_offset  = -22,
      vertical_offset    = -18,
      attachment         = 'Fixed',
    },
  }
  if wezterm.GLOBAL.cu_png then
    layers[#layers + 1] = {
      source             = { File = wezterm.GLOBAL.cu_png },
      repeat_x           = 'NoRepeat',
      repeat_y           = 'NoRepeat',
      vertical_align     = 'Bottom',
      horizontal_align   = 'Left',
      width              = CU_CANVAS.w,
      height             = CU_CANVAS.h,
      opacity            = 1.0,
      attachment         = 'Fixed',
    }
  end
  return layers
end

-- ═══════════════════════════════════════════════════════════════
-- theme-switching: autodetect (Windows light/dark) + manueller override
--   F10        → toggle light ↔ dark (override aktiv, ignoriert system)
--   F10+SHIFT  → reset auf autodetect (folgt wieder dem system)
-- live-poll im update-status erkennt system-theme-wechsel ohne restart
-- ═══════════════════════════════════════════════════════════════
wezterm.GLOBAL.theme_override = wezterm.GLOBAL.theme_override or nil

local function safe_get_appearance()
  local ok, ap = pcall(function() return wezterm.gui.get_appearance() end)
  if ok and ap then return ap end
  return 'Dark'
end

local function effective_appearance(window)
  local override = wezterm.GLOBAL.theme_override
  if override == 'dark'  then return 'Dark' end
  if override == 'light' then return 'Light' end
  if window then
    local ok, ap = pcall(function() return window:get_appearance() end)
    if ok and ap then return ap end
  end
  return safe_get_appearance()
end

-- per-window-id tracker für den angewandten stand (`mode|png`: theme + nutzungs-bild) —
-- nach config-reload wird marker gecleart (siehe window-config-reloaded event), sodass next
-- apply_theme die neuen palette-werte in die overrides schreibt (sonst blockiert der no-op-guard).
wezterm.GLOBAL.applied_mode = wezterm.GLOBAL.applied_mode or {}

local function apply_theme(window)
  if not window then return end
  local wid = tostring(window:window_id())
  local p = palette_for(effective_appearance(window))
  local marker = p.mode .. '|' .. tostring(wezterm.GLOBAL.cu_png)
  if wezterm.GLOBAL.applied_mode[wid] == marker then return end  -- no-op (kein loop bei polling)
  assign_palette(p)
  local overrides = window:get_config_overrides() or {}
  overrides.colors            = make_colors(p)
  overrides.window_frame      = make_window_frame(p)
  overrides.background        = make_background(p)
  overrides.inactive_pane_hsb = p.inactive_hsb
  window:set_config_overrides(overrides)
  wezterm.GLOBAL.applied_mode[wid] = marker
end

-- nach config-reload (F5): marker clearen, sodass next update-status die palette
-- neu in die overrides schreibt — sonst gewinnen die alten overrides der session
-- über die frisch geladenen base-colors aus config.colors.
wezterm.on('window-config-reloaded', function(window, pane)
  local wid = tostring(window:window_id())
  wezterm.GLOBAL.applied_mode[wid] = nil
  apply_theme(window)
end)

local toggle_theme = wezterm.action_callback(function(window, pane)
  local cur = effective_appearance(window)
  wezterm.GLOBAL.theme_override = tostring(cur):find('Light') and 'dark' or 'light'
  apply_theme(window)
end)

local reset_theme_auto = wezterm.action_callback(function(window, pane)
  wezterm.GLOBAL.theme_override = nil
  apply_theme(window)
end)

-- initial assignment — respektiert persistenten override, sonst system
do
  local override = wezterm.GLOBAL.theme_override
  local initial_app
  if     override == 'dark'  then initial_app = 'Dark'
  elseif override == 'light' then initial_app = 'Light'
  else                            initial_app = safe_get_appearance() end
  assign_palette(palette_for(initial_app))
end

-- ═══════════════════════════════════════════════════════════════
-- wsl-domain
-- ═══════════════════════════════════════════════════════════════
config.wsl_domains = {
  {
    name = 'WSL:{{WSL_DISTRO}}',
    distribution = '{{WSL_DISTRO}}',
    username = '{{WSL_USERNAME}}',
    default_cwd = '{{PROJECTS_PATH}}',
    default_prog = { 'bash', '-l' },
  },
}
config.default_domain = 'WSL:{{WSL_DISTRO}}'

-- ═══════════════════════════════════════════════════════════════
-- schriftart + ligaturen
-- ═══════════════════════════════════════════════════════════════
config.font = wezterm.font_with_fallback {
  { family = 'JetBrains Mono',          harfbuzz_features = { 'calt=1', 'liga=1', 'clig=1' } },
  { family = 'JetBrainsMono Nerd Font', harfbuzz_features = { 'calt=1', 'liga=1', 'clig=1' } },
  'Symbols Nerd Font Mono',
  'Cascadia Code',
  'Consolas',
}
config.font_size = 11.0
config.line_height = 1.08

config.window_frame = make_window_frame(ss)

-- ═══════════════════════════════════════════════════════════════
-- terminal-palette
-- ═══════════════════════════════════════════════════════════════
config.colors = make_colors(ss)

-- ═══════════════════════════════════════════════════════════════
-- fenster + hintergrund (stackschmiede wordmark unten rechts)
-- ═══════════════════════════════════════════════════════════════
config.window_decorations = 'TITLE | RESIZE'
config.window_padding = { left = 10, right = 10, top = 4, bottom = 70 }
config.win32_system_backdrop = 'Disable'
config.window_background_opacity = 1.0
config.macos_window_background_blur = 0
config.inactive_pane_hsb = ss.inactive_hsb

config.background = make_background(ss)

-- ═══════════════════════════════════════════════════════════════
-- tab-bar
-- ═══════════════════════════════════════════════════════════════
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 34

-- ═══════════════════════════════════════════════════════════════
-- tab-state-maschine: idle / busy / attention
-- primär: foreground-process-name (bash/zsh/fish → idle, sonst → busy)
-- fallback: output-fingerprint für "transparente" prozesse (ssh/tmux/mosh/screen)
-- bell → attn_pending; cleart nur beim Tab-Fokus (nicht bei neuem Output)
-- ═══════════════════════════════════════════════════════════════
wezterm.GLOBAL.pane_state = wezterm.GLOBAL.pane_state or {}

local BUSY_WINDOW = 3  -- sekunden seit letztem output → "busy" (nur im fallback-pfad)

local SHELLS = {
  bash = true, zsh = true, fish = true, sh = true,
  dash = true, ksh = true, tcsh = true, pwsh = true, ['powershell'] = true,
}

-- "transparente" prozesse: wezterm sieht den wrapper, nicht das eigentlich-aktive tool
-- → für diese auf output-fingerprint zurückfallen
local TRANSPARENT = {
  ssh = true, mosh = true, ['mosh-client'] = true,
  tmux = true, screen = true, byobu = true,
}

local function proc_basename(name)
  if not name or name == '' then return nil end
  local b = name:match('([^/\\]+)$') or name
  b = b:gsub('%.exe$', '')
  return b:lower()
end

local function pane_fingerprint(pane)
  local ok, txt = pcall(function() return pane:get_lines_as_text(12) end)
  if not ok or not txt then return '0:', '' end
  -- djb2-hash über kompletten text → robust gegen identische suffixe + \r-overwrites
  local hash = 5381
  for i = 1, #txt do
    hash = (hash * 33 + txt:byte(i)) % 4294967296
  end
  return tostring(#txt) .. ':' .. hash, txt
end

-- claude code zeigt laufende hintergrund-arbeit am unteren rand: shells in der fußzeile
-- (`⏵⏵ … · 1 shell · ↓ to manage`), agenten als liste darunter (`● main` / `◯ <agent>  <tätigkeit>`,
-- verschwindet, sobald alle fertig sind). der turn ist dann zu ende und der bildschirm steht still,
-- claude macht aber weiter → zählt als busy. nur der untere rand zählt, damit „ran 3 shell commands"
-- oder eine zitierte liste im verlauf nicht greifen.
local function bg_item(l)  -- listeneintrag → name ('main', 'general-purpose', …); kein char-class: multibyte
  return l:match('^%s*● (%S+)') or l:match('^%s*◯ (%S+)')
end

local function has_bg_work(txt)
  local lines = {}
  for line in (txt or ''):gmatch('[^\n]+') do
    if line:find('%S') then lines[#lines + 1] = line end
  end
  local n = #lines
  -- agenten: einträge direkt am unteren rand (darunter höchstens die tmux-statuszeile), oben `main`
  local i = n
  if i >= 1 and not bg_item(lines[i]) then i = i - 1 end
  local agents = 0
  while i >= 1 and bg_item(lines[i]) and bg_item(lines[i]) ~= 'main' do
    agents = agents + 1
    i = i - 1
  end
  if agents > 0 and i >= 1 and bg_item(lines[i]) == 'main' then return true end
  -- shells: fußzeilen-form in den letzten 3 zeilen (fußzeile, statuszeile, tmux-status)
  for k = math.max(1, n - 2), n do
    local l = lines[k]
    if l:find('%d+ shells? ·') or l:find('%d+ shells?,') or l:find('%d+ shells?%s*$') then
      return true
    end
  end
  return false
end

-- entscheidet: ist diese pane aktuell "busy" (nicht-shell-prozess aktiv)?
local function pane_busy(pane, st, now)
  -- claude wartet auf hintergrund-shells oder -agenten (im status-poll erkannt)
  if st.bg_work then return true end
  -- primär: foreground-process-detection
  local ok, name = pcall(function() return pane:get_foreground_process_name() end)
  if ok then
    local b = proc_basename(name)
    if b then
      if SHELLS[b] then return false end
      if not TRANSPARENT[b] then return true end
      -- transparent → durchfallen zu fingerprint-fallback
    end
  end
  -- fallback: fingerprint-window (für ssh/tmux/mosh/screen + unerkannte panes)
  return (now - (st.last_change or 0)) < BUSY_WINDOW
end

local function get_state(pid)
  wezterm.GLOBAL.pane_state = wezterm.GLOBAL.pane_state or {}
  local st = wezterm.GLOBAL.pane_state[pid]
  if not st then
    st = { fp = '', last_change = 0, attn_pending = false, bell_fp = '' }
    wezterm.GLOBAL.pane_state[pid] = st
  end
  return st
end

wezterm.on('bell', function(window, pane)
  local pid = tostring(pane:pane_id())
  local st = get_state(pid)
  st.attn_pending = true
  st.bell_fp = pane_fingerprint(pane)
end)

-- tab-titel: 5-state-rendering (active, active+busy, inactive+busy, inactive+attention, inactive+idle)
wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local idx = tab.tab_index + 1
  local pane = tab.active_pane
  local title = (pane.title or ''):lower()
  local prefix = '·'
  if title:find('claude') then
    prefix = '◆'
  elseif title:find('ssh') or title:find('@') then
    prefix = '→'
  elseif title:find('python') or title:find('node') or title:find('flutter') then
    prefix = '▸'
  elseif title:find('vim') or title:find('nvim') then
    prefix = '✎'
  end
  local override = tab.tab_title
  local label
  if override and override ~= '' then
    label = override
  else
    label = 'terminal ' .. idx
  end
  if #label > max_width - 6 then
    label = label:sub(1, max_width - 7) .. '…'
  end
  local text = string.format('  %s %s  ', prefix, label)

  local pid = tostring(pane.pane_id)
  local st = get_state(pid)
  local now = os.time()
  local busy = pane_busy(pane, st, now)

  if tab.is_active then
    st.is_active = true
    return text
  else
    st.is_active = false
  end

  -- inactive + attention (fertig, unbeachtet): amber-bold
  if st.attn_pending and not busy then
    return {
      { Background = { Color = ss.primary } },
      { Foreground = { Color = ss.chip_text } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = text },
    }
  end

  -- inactive + busy (arbeitet): amber-soft auf surface
  if busy then
    return {
      { Background = { Color = ss.surface } },
      { Foreground = { Color = ss.busy_text } },
      { Text = text },
    }
  end

  -- inactive + idle: surface / muted (default)
  return text
end)

-- ═══════════════════════════════════════════════════════════════
-- claude-abo-nutzung (5h-fenster · 7d · modell-fenster)
-- ═══════════════════════════════════════════════════════════════
-- quelle: `%USERPROFILE%\.wezterm-claude-usage.sh` (vom installer kopiert) läuft alle
-- `interval` sekunden in WSL, liest den oauth-token aus <dir>/.credentials.json (bleibt
-- in WSL — nie in dieser config, nie in argv) und schreibt NUR prozente + reset-zeiten
-- nach `%USERPROFILE%\.wezterm-claude-usage.json`. hier wird nur dieser cache gelesen.
-- braucht in WSL: jq + curl (`sudo apt install jq curl`). anzeige: `◐ 5h 42% ↻14:30 · 7d 18% · Fable 31%`
-- farbe = restkontingent: grün → amber → rot nach genutztem anteil (stufen `thresholds`), ab der
-- rot-stufe fett; kreis-glyph ○◔◑◕● = füllstand der gezeigten zahl. `◌ … (10m)` = cache veraltet,
-- `claude: login` = token abgelaufen (claude code einmal starten).
-- anzeige-ort (`position`): wezterm hat nur EINE leiste, der freie streifen unter dem terminal ist
-- nur per background-layer erreichbar. 'bottom' rendert die nutzung deshalb als transparentes PNG
-- (`%USERPROFILE%\.wezterm-claude-usage-render.ps1`, nur bei inhalts-änderung) und legt es unten
-- links ein; 'top' schreibt sie rechts in die tab-leiste. kommt nach CU_RENDER_TIMEOUT sekunden
-- kein PNG, fällt die anzeige automatisch auf 'top' zurück (log_error); F5 versucht es neu.
local CLAUDE_USAGE = {
  enabled    = true,
  position   = 'bottom',                  -- 'bottom' = bild unten links im fenster | 'top' = rechts in der tab-leiste
  interval   = 300,                       -- sekunden zwischen zwei abfragen (1 request / account)
  accounts   = {                          -- label = prefix der zeile ('' = keiner) · dir = claude-config-dir in WSL
    { label = '', dir = '~/.claude' },
  },
  rows       = nil,                       -- nil = alle rows des servers · sonst z. b. { '5h', '7d', 'Opus' }
  show_reset = 'session',                 -- reset-zeit (↻) zeigen: 'session' (nur 5h) | 'all' | 'none'
  numbers    = 'used',                    -- zahl + glyph: 'used' (genutzt, wie /usage) | 'left' (übrig, batterie-logik)
  thresholds = { 50, 75, 90 },            -- genutzt in %: bis 50 grün · 50→75 grün→amber · 75→90 amber→rot · ab 90 rot + fett
}
local CU_SCRIPT = os.getenv('USERPROFILE') .. '\\.wezterm-claude-usage.sh'
local CU_CACHE  = os.getenv('WEZTERM_CLAUDE_USAGE_CACHE')          -- override nur für tests
  or (os.getenv('USERPROFILE') .. '\\.wezterm-claude-usage.json')
local CU_RENDER = os.getenv('USERPROFILE') .. '\\.wezterm-claude-usage-render.ps1'
local CU_DIR    = os.getenv('WEZTERM_CLAUDE_USAGE_DIR')            -- override nur für tests
  or os.getenv('USERPROFILE')
local CU_BASE   = CU_DIR .. '\\.wezterm-claude-usage'                -- + .<zeit>-<n>.png (je render) · .spec · .err
local CU_RENDER_TIMEOUT = 20                                             -- sekunden bis zum fallback auf 'top'
local CU_KEEP     = 60                                                   -- sekunden, die ein abgelöstes bild noch liegt
local CU_LEFTOVER = 86400                                                -- bilder früherer prozesse: nach einem tag weg
local CU_FONT_PT = 10                                                    -- schriftgröße im bild (px = pt × dpi / 72)
local CU_PIE    = { '○', '◔', '◑', '◕', '●' }                        -- füllstand in 5 stufen
local CU_STOPS  = { 'success', 'success', 'warn', 'danger', 'danger' }  -- farbverlauf: 0 · t1 · t2 · t3 · 100

local function cu_pie(frac)  -- frac 0..1 gefüllt
  local i = math.floor(frac * 4 + 0.5) + 1
  return CU_PIE[math.max(1, math.min(#CU_PIE, i))]
end

local function cu_hex_rgb(hex)
  local r, g, b = tostring(hex):match('^#(%x%x)(%x%x)(%x%x)$')
  if not r then return nil end
  return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

local function cu_mix(a, b, t)  -- zwei hex-farben linear mischen, t 0..1
  local r1, g1, b1 = cu_hex_rgb(a)
  local r2, g2, b2 = cu_hex_rgb(b)
  if not (r1 and r2) then return a end
  return string.format('#%02X%02X%02X',
    math.floor(r1 + (r2 - r1) * t + 0.5),
    math.floor(g1 + (g2 - g1) * t + 0.5),
    math.floor(b1 + (b2 - b1) * t + 0.5))
end

-- farbe nach genutztem anteil (palette-live: ss.success / ss.warn / ss.danger, folgt dem theme);
-- server-severity hebt nur an: warning ≥ t2, critical = rot
local function cu_color(used, severity)
  if severity == 'critical' then return ss.danger end
  local t = CLAUDE_USAGE.thresholds or { 50, 75, 90 }
  if severity == 'warning' then used = math.max(used, t[2]) end
  local stops = { 0, t[1], t[2], t[3], 100 }
  for i = 1, #stops - 1 do
    if used <= stops[i + 1] then
      local span = stops[i + 1] - stops[i]
      local f = span > 0 and (used - stops[i]) / span or 1
      return cu_mix(ss[CU_STOPS[i]], ss[CU_STOPS[i + 1]], f)
    end
  end
  return ss.danger
end

local function cu_read_cache()
  local f = io.open(CU_CACHE, 'r')
  if not f then return nil end
  local raw = f:read('*a')
  f:close()
  local ok, data = pcall(wezterm.json_parse, raw)
  if ok and type(data) == 'table' then return data end
  return nil
end

-- poller starten (max. 1× / 60 s — guard in GLOBAL überlebt config-reloads)
local function cu_spawn(now)
  local last = tonumber(wezterm.GLOBAL.cu_spawn_at) or 0
  if now - last < 60 and now - last >= 0 then return end
  wezterm.GLOBAL.cu_spawn_at = now
  local args = {
    'wsl.exe', '-d', '{{WSL_DISTRO}}', '-e', 'sh', '-c',
    's="$1"; shift; exec bash "$(wslpath -u "$s")" "$@"', '_',
    CU_SCRIPT, '--out', CU_CACHE, '--now', tostring(now),
    '--ttl', tostring(math.floor(CLAUDE_USAGE.interval / 2)),
  }
  for _, a in ipairs(CLAUDE_USAGE.accounts) do
    args[#args + 1] = '--account'
    args[#args + 1] = (a.label or '') .. '=' .. a.dir
  end
  wezterm.background_child_process(args)
end

local function cu_row_wanted(row)
  local want = CLAUDE_USAGE.rows
  if not want then return true end
  for _, w in ipairs(want) do
    if w:lower() == tostring(row.label or ''):lower() or w == row.kind then return true end
  end
  return false
end

local function cu_reset_text(row, now)
  local mode = CLAUDE_USAGE.show_reset
  local at = tonumber(row.resets_at)
  if mode == 'none' or not at then return '' end
  if mode == 'session' and row.kind ~= 'session' then return '' end
  return ' ↻' .. os.date(at - now < 86400 and '%H:%M' or '%a %H:%M', at)
end

-- anzeige als liste von runs { c = farbe, t = text, b = fett, p = füllstand 0..1 }, accounts
-- nebeneinander ({} wenn feature aus). p = kreis vor dem text: glyph in der tab-leiste, gezeichnet im bild.
local function cu_runs(now)
  if not CLAUDE_USAGE.enabled then return {} end
  local data = cu_read_cache()
  local age = data and (now - (tonumber(data.fetched_at) or 0)) or math.huge
  if age >= CLAUDE_USAGE.interval or age < 0 then cu_spawn(now) end  -- age < 0: uhr zurückgestellt
  local accounts = data and data.accounts
  if type(accounts) ~= 'table' or #accounts == 0 then
    return { { c = ss.muted, t = '◌ claude …' } }
  end
  local left_mode = CLAUDE_USAGE.numbers == 'left'
  local danger_at = (CLAUDE_USAGE.thresholds or {})[3] or 90
  local runs = {}
  local function push(color, text, bold, pie)
    runs[#runs + 1] = { c = color, t = text, b = bold, p = pie }
  end
  for i, acc in ipairs(accounts) do
    if i > 1 then push(ss.border, '  ‖  ') end
    local prefix = (acc.label and acc.label ~= '') and (acc.label .. ' ') or ''
    local rows = {}
    for _, r in ipairs(acc.rows or {}) do
      if cu_row_wanted(r) then rows[#rows + 1] = r end
    end
    local data_age = now - (tonumber(acc.updated_at) or 0)
    local stale = data_age > CLAUDE_USAGE.interval * 2 + 60
    if #rows == 0 then
      if acc.error == 'login' then push(ss.danger, prefix .. 'claude: login')
      elseif acc.error then push(ss.muted, prefix .. '◌ claude: ' .. tostring(acc.error))
      else push(ss.muted, prefix .. '◌ …') end
    else
      push(ss.muted, prefix .. (stale and '◌ ' or ''))
      for j, r in ipairs(rows) do
        if j > 1 then push(ss.border, ' · ') end
        local used = math.floor(math.max(0, math.min(100, tonumber(r.pct) or 0)))
        local shown = left_mode and (100 - used) or used
        local col = stale and ss.muted or cu_color(used, r.severity)
        local hot = not stale and (used >= danger_at or r.severity == 'critical')
        push(col, ' ' .. tostring(r.label or '?') .. ' ' .. shown .. '%' .. cu_reset_text(r, now), hot, shown / 100)
      end
      if acc.error == 'login' then
        push(ss.danger, ' (login)')
      elseif stale then
        -- auf 5 min gerundet: sonst ein render pro minute, solange der poller ausfällt
        push(ss.muted, ' (' .. math.floor(data_age / 300) * 5 .. 'm)')
      end
    end
  end
  return runs
end

-- runs → format-items für die tab-leiste
local function cu_format(runs)
  local seg = {}
  for _, r in ipairs(runs) do
    seg[#seg + 1] = { Foreground = { Color = r.c } }
    seg[#seg + 1] = { Attribute = { Intensity = r.b and 'Bold' or 'Normal' } }
    seg[#seg + 1] = { Text = (r.p and cu_pie(r.p) or '') .. r.t }
  end
  return seg
end

-- bild-zustand im GLOBAL (überlebt config-reloads, gilt für alle fenster):
--   cu_png = angezeigtes bild · cu_spec = zuletzt beauftragter inhalt · cu_seq = zähler für dateinamen
--   cu_job, cu_job_at = laufender render (ziel-png, start) · cu_failed = fallback auf die tab-leiste aktiv
--   cu_old = abgelöste bilder (pfad → zeitpunkt) · cu_swept = reste früherer prozesse aufgeräumt
-- jeder render schreibt ein NEUES bild, ein abgelöstes wird erst nach CU_KEEP gelöscht: wezterm übernimmt
-- overrides verzögert, und fehlt die datei in dem moment, bleibt die anzeige leer, bis sich der inhalt
-- ändert (der marker in apply_theme sieht keinen grund für einen neuen versuch). die früheren zwei
-- slots a/b wurden beim schnellen neu-rendern (fensterstart) gelöscht, während wezterm sie gerade lud.
local function cu_retire(path, now)
  if not path then return end
  local G = wezterm.GLOBAL
  if not G.cu_old then G.cu_old = {} end
  G.cu_old[path] = now  -- über G schreiben: eine lokale kopie der tabelle landet nicht im GLOBAL
end

local function cu_sweep(now)
  local G = wezterm.GLOBAL
  if G.cu_old then
    local due = {}
    for path in pairs(G.cu_old) do  -- werte per index lesen: pairs liefert sie als userdata, nicht als zahl
      local at = tonumber(G.cu_old[path])
      if not at or now - at >= CU_KEEP or now < at then due[#due + 1] = tostring(path) end
    end
    for _, path in ipairs(due) do
      os.remove(path)
      G.cu_old[path] = nil
    end
  end
  if G.cu_swept then return end
  G.cu_swept = true  -- einmal pro prozess: reste früherer prozesse und die alten slots a/b
  local ok, entries = pcall(wezterm.read_dir, CU_DIR)
  if not ok or type(entries) ~= 'table' then return end
  local function name_of(p) return p and p:match('[^\\/]+$') end
  for _, path in ipairs(entries) do
    local name = name_of(path)
    local id = name and name:match('^%.wezterm%-claude%-usage%.(.+)%.png$')
    if id and name ~= name_of(G.cu_png) and name ~= name_of(G.cu_job) then
      -- bild eines laufenden zweiten prozesses ist jünger als CU_LEFTOVER und bleibt; a/b ohne zeit → weg
      local at = tonumber(id:match('^(%d+)%-')) or 0
      if now - at >= CU_LEFTOVER or now < at then os.remove(path) end
    end
  end
end

local function cu_render_reset(now)
  local G = wezterm.GLOBAL
  if G.cu_png or G.cu_job then
    cu_retire(G.cu_png, now)
    cu_retire(G.cu_job, now)  -- ein noch laufender render schreibt es evtl. später
  end
  G.cu_png, G.cu_spec, G.cu_job = nil, nil, nil
end

local function cu_render(window, runs, now)
  local G = wezterm.GLOBAL
  if G.cu_job then
    local f = io.open(G.cu_job, 'rb')
    if f then
      f:close()
      cu_retire(G.cu_png, now)
      G.cu_png, G.cu_job = G.cu_job, nil  -- apply_theme übernimmt den neuen pfad im nächsten tick
    elseif now - G.cu_job_at >= 0 and now - G.cu_job_at < CU_RENDER_TIMEOUT then
      return
    else
      local e = io.open(CU_BASE .. '.err', 'rb')
      wezterm.log_error('claude-usage: kein bild nach ' .. CU_RENDER_TIMEOUT .. ' s, anzeige zurück in die tab-leiste'
        .. (e and (': ' .. e:read('*a')) or ''))
      if e then e:close() end
      G.cu_failed = true
      cu_render_reset(now)
      return
    end
  end
  local spec = wezterm.json_encode(runs)
  if spec == G.cu_spec then return end
  G.cu_spec = spec
  G.cu_seq = (tonumber(G.cu_seq) or 0) + 1
  local out = string.format('%s.%d-%d.png', CU_BASE, now, G.cu_seq)
  os.remove(CU_BASE .. '.err')
  -- dpi nur hier, nicht im vergleich: sonst rendern fenster auf zwei monitoren gegeneinander an
  local px = math.floor(CU_FONT_PT * window:get_dimensions().dpi / 72 + 0.5)
  local f = assert(io.open(CU_BASE .. '.spec', 'wb'))
  f:write(wezterm.json_encode { w = CU_CANVAS.w, h = CU_CANVAS.h, x = CU_CANVAS.x, font_px = px, lines = { runs } })
  f:close()
  G.cu_job, G.cu_job_at = out, now
  wezterm.background_child_process {
    'powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-File', CU_RENDER, '-Spec', CU_BASE .. '.spec', '-Out', out,
  }
end

local cu_last_err = nil
local function cu_status_items(window, now)
  local ok, items = pcall(function()
    cu_sweep(now)
    local bottom = CLAUDE_USAGE.position == 'bottom' and not wezterm.GLOBAL.cu_failed
    local runs = cu_runs(now)
    if bottom and #runs > 0 then
      cu_render(window, runs, now)
      return {}
    end
    cu_render_reset(now)
    return cu_format(runs)
  end)
  if not ok then
    if items ~= cu_last_err then wezterm.log_error('claude-usage: ' .. tostring(items)) end
    cu_last_err = items
    wezterm.GLOBAL.cu_failed = true  -- nie unsichtbar kaputt: nächster tick zeigt die tab-leiste
    return {}
  end
  if #items > 0 then
    table.insert(items, 1, { Text = '  ' })
    items[#items + 1] = { Attribute = { Intensity = 'Normal' } }
    items[#items + 1] = { Foreground = { Color = ss.border } }
    items[#items + 1] = { Text = '  │' }
  end
  return items
end

-- ═══════════════════════════════════════════════════════════════
-- status-bar + attention-polling (clearing bei neuem output)
-- ═══════════════════════════════════════════════════════════════
wezterm.on('update-status', function(window, pane)
  -- live-poll für system-theme-wechsel (no-op falls mode unverändert)
  pcall(function() apply_theme(window) end)

  -- pane-state-poll: fp-diff → last_change; fp-änderung nach bell → attn clear (busy-wieder)
  -- gesamter poll in pcall: fehler (tab/pane gerade geschlossen) dürfen status-bar nicht blocken
  pcall(function()
    wezterm.GLOBAL.pane_state = wezterm.GLOBAL.pane_state or {}
    local all_wins = wezterm.mux.all_windows()
    local now = os.time()
    local alive = {}
    for _, mwin in ipairs(all_wins) do
      for _, tab in ipairs(mwin:tabs()) do
        for _, p in ipairs(tab:panes()) do
          local pid = tostring(p:pane_id())
          alive[pid] = true
          local st = get_state(pid)
          local fp, txt = pane_fingerprint(p)
          st.bg_work = has_bg_work(txt)
          if fp ~= st.fp then
            st.fp = fp
            st.last_change = now
            if st.attn_pending and st.is_active then
              st.attn_pending = false
            end
          end
        end
      end
    end
    for pid in pairs(wezterm.GLOBAL.pane_state) do
      if not alive[pid] then wezterm.GLOBAL.pane_state[pid] = nil end
    end
  end)

  local time = wezterm.strftime('%H:%M')
  local date = wezterm.strftime('%a %d.%m')

  window:set_left_status('')
  local items = cu_status_items(window, os.time())
  for _, t in ipairs {
    { Foreground = { Color = ss.muted } },   { Text = '  ' .. date .. '  ' },
    { Foreground = { Color = ss.primary } }, { Attribute = { Intensity = 'Bold' } }, { Text = time .. '  ' },
  } do items[#items + 1] = t end
  window:set_right_status(wezterm.format(items))
end)

-- ═══════════════════════════════════════════════════════════════
-- hyperlinks (urls → browser · file:line → editor in wsl)
-- ═══════════════════════════════════════════════════════════════
-- editor für file:line-links. muss im WSL-PATH auffindbar sein — windows-interop
-- reicht: 'code' (VS Code), 'antigravity-ide' (Antigravity), 'cursor', …
-- start läuft über `sh -c`, weil `wsl.exe -e <cmd>` windows-pfade aus dem PATH
-- NICHT auflöst (execvpe nutzt den init-PATH, nicht den interop-PATH der session).
-- fehlt der editor (oder '') → windows-standardprogramm, wie doppelklick im explorer.
local FILE_LINK_EDITOR = 'code'

-- hyperlink-regeln: wezterm-defaults (urls in klammern, bare urls, mailto) + pfade in
-- allen üblichen formen, jeweils mit optionalem :zeile[:spalte]. highlight + uri = capture 1
-- (ohne das führende boundary-zeichen). bei überlappung gewinnt der längste treffer pro zelle.
local hyperlinks = wezterm.default_hyperlink_rules()

-- boundary = alles, was kein pfadzeichen ist (zeilenanfang, leerzeichen, klammern, quotes, →, │, …)
local PB = [[(?:^|[^\w.@+%/~\\$-])]]
-- optionales :zeile oder :zeile:spalte
local LC = [[(?::\d+(?::\d+)?)?]]
-- endungen für nackte dateinamen ohne verzeichnis (README.md, x.py:12) — domains (.de/.com) bewusst nicht
local EXT = 'py|js|mjs|cjs|ts|tsx|jsx|lua|dart|go|rs|md|json|ya?ml|toml|sh|bash|zsh|ps1|psm1|bat|cmd|iss'
  .. '|html?|css|scss|vue|svelte|rb|java|kt|kts|php|sql|astro|txt|cfg|ini|conf|log|csv|xml|env|lock'
  .. '|ipynb|c|h|cpp|hpp|cs|swift|zig|tf|hcl|nix|service|ics|vcf|pdf|png|jpe?g|gif|svg|webp'
  .. '|docx?|xlsx?|xlsm|pptx?|od[tsp]|rtf|epub|zip|mp3|mp4'

local PATH_RULES = {
  -- absolut (≥2 segmente): /home/user/projekt/datei.py · /etc/hosts · /mnt/c/Users/x/
  [[(/(?:[\w.@+%-]+/)+[\w.@+%-]*[\w@+%-]/?]] .. LC .. ')',
  -- home-relativ: ~/.claude/rules/x.md · ~/projekte/
  [[(~/(?:[\w.@+%-]+/)*[\w.@+%-]*[\w@+%-]/?]] .. LC .. ')',
  -- punkt-relativ: ./install/install.ps1 · ../x
  [[((?:\.\.?/)+(?:[\w.@+%-]+/)*[\w.@+%-]*[\w@+%-]/?]] .. LC .. ')',
  -- relativ mit verzeichnis + endung: config/wezterm.lua:42 · .github/workflows/x.yml
  [[(\.?[\w@+%-]+(?:/[\w.@+%-]+)*/[\w.@+%-]*\.[A-Za-z][A-Za-z0-9]{0,7}]] .. LC .. [[)\b]],
  -- nackter dateiname mit bekannter endung: README.md · x.py.bak · .wezterm.lua
  [[(\.?[\w@+%-]+(?:\.[\w@+%-]+)*\.(?:]] .. EXT .. [[)(?:\.[\w@+%-]+)*]] .. LC .. [[)\b]],
  -- windows: C:\Users\x\.wezterm.lua · D:/data/x.csv
  [=[([A-Za-z]:[\\/](?:[^\\/\s"'<>|*?:]+[\\/])*[^\\/\s"'<>|*?:]*[^\\/\s"'<>|*?:.]]=] .. LC .. ')',
}
for _, re in ipairs(PATH_RULES) do
  table.insert(hyperlinks, { regex = PB .. re, format = '$1', highlight = 1 })
end

-- owner/repo#123 → github-issue
table.insert(hyperlinks, {
  regex = [[\b([a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+)#(\d+)\b]],
  format = 'https://github.com/$1/issues/$2',
})

config.hyperlink_rules = hyperlinks

-- pane-cwd als linux-pfad (nil bei unbekanntem cwd oder windows-pfad)
local function pane_linux_cwd(pane)
  local ok, cwd_uri = pcall(function() return pane:get_current_working_dir() end)
  if not ok or not cwd_uri then return nil end
  local path = cwd_uri.file_path or tostring(cwd_uri)
  if type(path) ~= 'string' then return nil end
  path = path:gsub('^file://[^/]*', '')
  if path:sub(1, 1) ~= '/' or path:match('^/%a:/') then return nil end
  return (path:gsub('/$', ''))
end

-- dokumente + medien → immer windows-standardprogramm (ein editor kann sie nicht anzeigen)
local EXTERNAL_EXT = {}
for ext in ([[pdf doc docx xls xlsx xlsm ppt pptx odt ods odp rtf epub png jpg jpeg gif webp bmp
  ico tif tiff heic mp3 wav flac ogg m4a mp4 mkv mov avi webm zip 7z]]):gmatch('%w+') do
  EXTERNAL_EXT[ext] = true
end

-- `$0` = editor ('' = keiner), `$1` = pfad (linux oder C:\…), `$2` = ':zeile[:spalte]' oder ''.
-- editor gefunden → `editor -g pfad:zeile` (windows-pfade vorher nach /mnt/…), sonst
-- windows-standardprogramm (linux-pfade via wslpath -w; ordner → explorer). `~/` → $HOME.
local OPEN_SH = table.concat({
  [[f="$1"; case "$f" in "~/"*) f="$HOME/${f#"~/"}";; esac]],
  [[if [ -n "$0" ] && command -v "$0" >/dev/null 2>&1; then]]
    .. [[ case "$f" in [A-Za-z]:[\\/]*) f="$(wslpath -u "$f")" || exit 1;; esac;]]
    .. [[ exec "$0" -g "$f$2"; fi]],
  [[case "$f" in /*) f="$(wslpath -w "$f")" || exit 1;; esac]],
  [[exec /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$f"]],
}, '; ')

-- file://-uris (z.b. OSC-8-links aus TUIs) → pfad. percent-decoding, wsl-host-formen.
local function file_uri_to_path(uri)
  local rest = uri:gsub('^file://', '')
  rest = rest:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
  -- file://wsl.localhost/Ubuntu/home/x · file://wsl$/Ubuntu/home/x → /home/x
  local wslpath = rest:match('^wsl[%.%$][^/]*/[^/]+(/.*)$')
  if wslpath then return wslpath end
  -- file:///C:/x · file://C:/x → C:/x
  local win = rest:match('^/?(%a:[/\\].*)$')
  if win then return win end
  -- file:///home/x · file://localhost/home/x → /home/x
  return (rest:gsub('^localhost', ''))
end

local function open_path(editor, file, suffix)
  wezterm.background_child_process {
    'wsl.exe', '-d', '{{WSL_DISTRO}}', '-e', 'sh', '-c', OPEN_SH, editor, file, suffix,
  }
end

wezterm.on('open-uri', function(window, pane, uri)
  if uri:match('^file://') then
    -- file:// → wie pfad behandeln (editor)
    uri = file_uri_to_path(uri)
  elseif uri:match('^%a[%w+.-]*://') or uri:match('^mailto:') then
    -- urls + mailto → default-browser via windows-shell. rundll32 statt `cmd /c start`:
    -- kein konsolen-flackern, kein '&'-parsing durch cmd.
    wezterm.background_child_process { 'rundll32.exe', 'url.dll,FileProtocolHandler', uri }
    return false
  end

  -- pfad[:zeile[:spalte]]. satzzeichen am ende abschneiden (defensiv), zeile abtrennen.
  local target = uri:gsub('[.,;:]+$', '')
  local file, suffix = target:match('^(.-)(:%d+:?%d*)$')
  file = file or target
  suffix = suffix or ''
  local win = file:match('^%a:[/\\]') ~= nil
  -- relative linux-pfade gegen das pane-cwd auflösen (`~/` expandiert die shell)
  if not win and file:sub(1, 1) ~= '/' and file:sub(1, 2) ~= '~/' then
    local cwd = pane_linux_cwd(pane)
    if cwd then file = cwd .. '/' .. file end
  end
  local ext = (file:match('%.(%w+)$') or ''):lower()
  if not EXTERNAL_EXT[ext] then
    open_path(FILE_LINK_EDITOR, file, suffix)
  elseif win then
    -- windows-dokument: direkt, ohne umweg über wsl
    wezterm.background_child_process {
      'rundll32.exe', 'url.dll,FileProtocolHandler', (file:gsub('/', '\\')),
    }
  else
    open_path('', file, '')
  end
  return false
end)

-- ═══════════════════════════════════════════════════════════════
-- scrollback + render
-- ═══════════════════════════════════════════════════════════════
config.scrollback_lines = 50000
config.animation_fps = 1
config.max_fps = 60
-- Software-Rendering verhindert GPU-Context-Loss-Crash nach Monitor-Wake
-- Alternative: 'WebGpu' (moderner, testen falls Software zu langsam wirkt)
config.front_end = 'Software'
config.status_update_interval = 3000
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.default_cursor_style = 'SteadyBar'
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_duration_ms = 75,
  fade_out_duration_ms = 75,
  target = 'CursorColor',
}

-- ═══════════════════════════════════════════════════════════════
-- verhalten
-- ═══════════════════════════════════════════════════════════════
-- schließen bestätigen: fenster-X / Alt+F4 / Strg+Umschalt+W / Strg+Umschalt+X fragen
-- immer nach (overlay: y = schließen, n/Esc = abbrechen) — auch wenn nur eine shell läuft.
-- leere skip-liste: wezterm würde bash/zsh/pwsh sonst ohne rückfrage killen.
config.window_close_confirmation = 'AlwaysPrompt'
config.skip_close_confirmation_for_processes_named = {}
config.alternate_buffer_wheel_scroll_speed = 1
config.initial_cols = 140
config.initial_rows = 40
config.adjust_window_size_when_changing_font_size = false

-- ═══════════════════════════════════════════════════════════════
-- launch-menu (beispiel — passe an eigene projekte an)
-- ═══════════════════════════════════════════════════════════════
config.launch_menu = {
  { label = '· Home',     args = { 'bash', '-l' }, cwd = '/home/{{WSL_USERNAME}}' },
  { label = '· Projects', args = { 'bash', '-l' }, cwd = '{{PROJECTS_PATH}}' },
  -- eigene einträge hier ergänzen, z.b.:
  -- { label = '◆ my-project', args = { 'bash', '-l' }, cwd = '{{PROJECTS_PATH}}/my-project' },
}

-- ═══════════════════════════════════════════════════════════════
-- keybindings
-- ═══════════════════════════════════════════════════════════════
local smart_ctrl_c = wezterm.action_callback(function(window, pane)
  local sel = window:get_selection_text_for_pane(pane)
  if sel and sel ~= '' then
    window:perform_action(act.CopyTo 'Clipboard', pane)
    window:perform_action(act.ClearSelection, pane)
  else
    window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
  end
end)

local new_tab_wsl = wezterm.action_callback(function(window, pane)
  local cwd = '{{PROJECTS_PATH}}'
  local domain_ok, domain_name = pcall(function() return pane:get_domain_name() end)
  if domain_ok and domain_name == 'WSL:{{WSL_DISTRO}}' then
    local cwd_uri = pane:get_current_working_dir()
    if cwd_uri then
      local path = cwd_uri.file_path or tostring(cwd_uri)
      if type(path) == 'string' and path:sub(1, 1) == '/' and not path:match('^/%a:/') then
        cwd = path
      end
    end
  end
  window:perform_action(
    act.SpawnCommandInNewTab {
      args = { 'bash', '-l' },
      cwd = cwd,
      domain = { DomainName = 'WSL:{{WSL_DISTRO}}' },
    },
    pane
  )
end)

-- action_callback wrap, damit wezterm.format mit aktueller palette gerendert wird
local about_overlay = wezterm.action_callback(function(window, pane)
  window:perform_action(act.PromptInputLine {
    description = wezterm.format {
      { Foreground = { Color = ss.primary } }, { Attribute = { Intensity = 'Bold' } },
      { Text = '  TerminalStack  ·  Stackschmiede\n' },
      { Attribute = { Intensity = 'Normal' } },
      { Foreground = { Color = ss.border } },
      { Text = '  ──────────────────────────────────────\n' },
      { Foreground = { Color = ss.muted } },    { Text = '  Web      ' },
      { Foreground = { Color = ss.accentSoft } }, { Text = 'https://stackschmiede.de\n' },
      { Foreground = { Color = ss.muted } },    { Text = '  Stack    ' },
      { Foreground = { Color = ss.fg } },       { Text = 'WSL2 · WezTerm · Claude Code\n' },
      { Foreground = { Color = ss.muted } },    { Text = '  Lizenz   ' },
      { Foreground = { Color = ss.fg } },       { Text = 'MIT\n' },
      { Foreground = { Color = ss.border } },
      { Text = '  ──────────────────────────────────────\n' },
      { Foreground = { Color = ss.muted } },    { Text = '  [Enter] schließen\n' },
    },
    action = wezterm.action_callback(function(w, p, line) end),
  }, pane)
end)

local rename_tab = wezterm.action_callback(function(window, pane)
  window:perform_action(act.PromptInputLine {
    description = wezterm.format {
      { Attribute = { Intensity = 'Bold' } },
      { Foreground = { Color = ss.primary } },
      { Text = 'Rename tab (enter to set, empty to reset):' },
    },
    action = wezterm.action_callback(function(w, p, line)
      if line then
        w:active_tab():set_title(line)
      end
    end),
  }, pane)
end)

-- detach tab into its own window (requires recent wezterm for true move;
-- falls back to SpawnWindow on older builds)
local detach_tab = wezterm.action_callback(function(window, pane)
  local tab = window:active_tab()
  if not tab then return end
  local ok = pcall(function() tab:move_to_new_window() end)
  if not ok then
    window:perform_action(act.SpawnWindow, pane)
  end
end)

-- smart-paste (Ctrl+Shift+V):
-- if an image sits in the Windows clipboard → save to %TEMP% and paste the WSL path
-- (auto-prefix '@' when the active process is `claude`)
-- otherwise: fallback to normal text paste
local smart_paste = wezterm.action_callback(function(window, pane)
  local helper = os.getenv('USERPROFILE') .. '\\.wezterm-paste-image.ps1'
  local ok, stdout, _ = wezterm.run_child_process {
    'powershell.exe',
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', helper,
  }
  local path = (stdout or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if not ok or path == '' then
    window:perform_action(act.PasteFrom 'Clipboard', pane)
    return
  end
  local proc_raw = ''
  pcall(function() proc_raw = pane:get_foreground_process_name() or '' end)
  local proc = (proc_raw:match('([^/\\]+)$') or ''):lower():gsub('%.exe$', '')
  if proc:find('claude') then
    pane:paste('@' .. path .. ' ')
  else
    pane:paste(path)
  end
end)

-- F5: config neu laden und nutzungs-bild neu rendern (holt es auch nach einem fallback zurück)
local reload_config = wezterm.action_callback(function(window, pane)
  wezterm.GLOBAL.cu_failed = nil
  wezterm.GLOBAL.cu_spec = nil
  window:perform_action(act.ReloadConfiguration, pane)
end)

config.keys = {
  { key = 'c', mods = 'CTRL',       action = smart_ctrl_c },
  { key = 'v', mods = 'CTRL',       action = act.PasteFrom 'Clipboard' },
  { key = 't', mods = 'CTRL|SHIFT', action = new_tab_wsl },
  { key = 'n', mods = 'CTRL|SHIFT', action = new_tab_wsl },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  -- Ctrl+Shift+V: smart-paste (clipboard-image → WSL path, otherwise text)
  { key = 'v', mods = 'CTRL|SHIFT', action = smart_paste },

  { key = 'F1',                      action = about_overlay },
  { key = 'F2',                      action = rename_tab },
  { key = 'e',  mods = 'CTRL|SHIFT', action = rename_tab },

  { key = 'PageUp',   mods = 'CTRL|SHIFT', action = act.MoveTabRelative(-1) },
  { key = 'PageDown', mods = 'CTRL|SHIFT', action = act.MoveTabRelative(1) },
  { key = 'F6',                            action = detach_tab },

  { key = 'F5',                      action = reload_config },

  -- theme: F10 toggle light↔dark (override) · Shift+F10 reset auf system-autodetect
  { key = 'F10',                     action = toggle_theme },
  { key = 'F10', mods = 'SHIFT',     action = reset_theme_auto },

  { key = '-', mods = 'CTRL',       action = act.DecreaseFontSize },
  { key = '=', mods = 'CTRL',       action = act.IncreaseFontSize },
  { key = '0', mods = 'CTRL',       action = act.ResetFontSize },

  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },

  { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'r', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  { key = 'LeftArrow',  mods = 'CTRL|SHIFT|ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT|ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT|ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT|ALT', action = act.ActivatePaneDirection 'Down' },

  { key = 'PageUp',   mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = act.ScrollByPage(1) },

  { key = 'L',     mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|LAUNCH_MENU_ITEMS' } },
  { key = 'O',     mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'FUZZY|WORKSPACES' } },
  { key = 'f',     mods = 'CTRL|SHIFT', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'Space', mods = 'CTRL|SHIFT', action = act.QuickSelect },

  -- tab-cycling: ctrl+space (vorwärts) / ctrl+alt+← oder ctrl+` (rückwärts)
  { key = 'Space',     mods = 'CTRL',       action = act.ActivateTabRelative(1) },
  { key = 'LeftArrow', mods = 'CTRL|ALT',   action = act.ActivateTabRelative(-1) },
  { key = '`',         mods = 'CTRL',       action = act.ActivateTabRelative(-1) },
  -- default ctrl+tab deaktivieren
  { key = 'Tab',       mods = 'CTRL',       action = act.DisableDefaultAssignment },
}

-- ═══════════════════════════════════════════════════════════════
-- maus-bindings
-- TUIs mit maus-capture (claude code ≥2.1.3xx, vim, htop, …) bekommen von wezterm sonst
-- ALLE maus-events; bindings greifen dort nur mit Shift. die `mouse_reporting = true`-
-- varianten holen linksklick (selektion, strg+klick öffnet links), rechtsklick (paste) und
-- Strg+mausrad (zoom) auch in solchen TUIs zurück ans terminal. mausrad ohne modifier
-- bleibt bei der app (claude code scrollt damit sein eigenes transkript).
-- ═══════════════════════════════════════════════════════════════
local function terminal_owned_mouse()
  return {
    -- rechtsklick (einfach): paste aus zwischenablage
    { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = act.PasteFrom 'Clipboard' },
    -- doppel-rechtsklick (auf logo-bereich unten rechts): about-overlay
    -- hintergrundbild-layer ist nicht anklickbar in wezterm — doppel-rc ist der nächstbeste weg
    { event = { Down = { streak = 2, button = 'Right' } }, mods = 'NONE', action = about_overlay },
    -- linksklick: selektion starten (zelle / wort / zeile) · drag erweitert sie
    { event = { Down = { streak = 1, button = 'Left' } }, mods = 'NONE', action = act.SelectTextAtMouseCursor 'Cell' },
    { event = { Down = { streak = 2, button = 'Left' } }, mods = 'NONE', action = act.SelectTextAtMouseCursor 'Word' },
    { event = { Down = { streak = 3, button = 'Left' } }, mods = 'NONE', action = act.SelectTextAtMouseCursor 'Line' },
    { event = { Drag = { streak = 1, button = 'Left' } }, mods = 'NONE', action = act.ExtendSelectionToMouseCursor 'Cell' },
    { event = { Drag = { streak = 2, button = 'Left' } }, mods = 'NONE', action = act.ExtendSelectionToMouseCursor 'Word' },
    { event = { Drag = { streak = 3, button = 'Left' } }, mods = 'NONE', action = act.ExtendSelectionToMouseCursor 'Line' },
    -- loslassen: selektion → clipboard (doppelklick = wort kopieren) · links öffnet nur
    -- strg+klick, damit markieren und kopieren nie versehentlich etwas startet
    { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE', action = act.CompleteSelection 'Clipboard' },
    { event = { Up = { streak = 2, button = 'Left' } }, mods = 'NONE', action = act.CompleteSelection 'Clipboard' },
    { event = { Up = { streak = 3, button = 'Left' } }, mods = 'NONE', action = act.CompleteSelection 'Clipboard' },
    -- strg+klick: link öffnen (auch bei bestehender selektion) · Down = Nop, damit keine selektion startet
    { event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL', action = act.Nop },
    { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL', action = act.OpenLinkAtMouseCursor },
    -- strg + mausrad → zoom
    { event = { Down = { streak = 1, button = { WheelUp = 1 } } },   mods = 'CTRL', action = act.IncreaseFontSize },
    { event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = 'CTRL', action = act.DecreaseFontSize },
  }
end

config.mouse_bindings = {
  -- strg+shift+klick: link öffnen — shift umgeht mouse-reporting, greift also in jeder TUI
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL|SHIFT', action = act.OpenLinkAtMouseCursor },
  -- SHIFT + mausrad → seitenweise scrollen (shift = bypass, wirkt auch in TUIs)
  { event = { Down = { streak = 1, button = { WheelUp = 1 } } },   mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = 'SHIFT', action = act.ScrollByPage(1) },
}
-- jede terminal-eigene binding zweimal registrieren: normal + unter mouse-reporting
for _, b in ipairs(terminal_owned_mouse()) do
  table.insert(config.mouse_bindings, b)
  local r = {}
  for k, v in pairs(b) do r[k] = v end
  r.mouse_reporting = true
  table.insert(config.mouse_bindings, r)
end

return config
