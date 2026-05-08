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
--   · hyperlinks for file:line  (opens in VS Code)
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

local function make_background(p)
  return {
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

-- per-window-id tracker für angewandten mode — nach config-reload wird marker
-- gecleart (siehe window-config-reloaded event), sodass next apply_theme die
-- neuen palette-werte in die overrides schreibt (sonst blockiert der no-op-guard).
wezterm.GLOBAL.applied_mode = wezterm.GLOBAL.applied_mode or {}

local function apply_theme(window)
  if not window then return end
  local wid = tostring(window:window_id())
  local p = palette_for(effective_appearance(window))
  if wezterm.GLOBAL.applied_mode[wid] == p.mode then return end  -- no-op (kein loop bei polling)
  assign_palette(p)
  local overrides = window:get_config_overrides() or {}
  overrides.colors            = make_colors(p)
  overrides.window_frame      = make_window_frame(p)
  overrides.background        = make_background(p)
  overrides.inactive_pane_hsb = p.inactive_hsb
  window:set_config_overrides(overrides)
  wezterm.GLOBAL.applied_mode[wid] = p.mode
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
  if not ok or not txt then return '0:' end
  -- djb2-hash über kompletten text → robust gegen identische suffixe + \r-overwrites
  local hash = 5381
  for i = 1, #txt do
    hash = (hash * 33 + txt:byte(i)) % 4294967296
  end
  return tostring(#txt) .. ':' .. hash
end

-- entscheidet: ist diese pane aktuell "busy" (nicht-shell-prozess aktiv)?
local function pane_busy(pane, st, now)
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
          local fp = pane_fingerprint(p)
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
  local workspace = window:active_workspace()
  local cwd = ''
  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri then
    local path = cwd_uri.file_path or tostring(cwd_uri)
    cwd = path:gsub('/$', ''):match('([^/]+)$') or '~'
  end

  window:set_left_status('')
  window:set_right_status(wezterm.format {
    { Foreground = { Color = ss.accent } },  { Text = '  ' .. workspace .. '  ' },
    { Foreground = { Color = ss.border } },  { Text = '│' },
    { Foreground = { Color = ss.fg } },      { Text = '  ~/' .. cwd .. '  ' },
    { Foreground = { Color = ss.border } },  { Text = '│' },
    { Foreground = { Color = ss.muted } },   { Text = '  ' .. date .. '  ' },
    { Foreground = { Color = ss.primary } }, { Attribute = { Intensity = 'Bold' } }, { Text = time .. '  ' },
  })
end)

-- ═══════════════════════════════════════════════════════════════
-- hyperlinks (urls + file:line → vscode in wsl)
-- ═══════════════════════════════════════════════════════════════
local hyperlinks = wezterm.default_hyperlink_rules()

table.insert(hyperlinks, {
  regex = [[([a-zA-Z0-9_/.~-]+\.(?:py|js|ts|tsx|jsx|lua|dart|go|rs|md|json|ya?ml|toml|sh|html|css|vue|svelte|rb|java|kt|php|sql|astro)):(\d+)(?::\d+)?]],
  format = '$0',
  highlight = 1,
})
table.insert(hyperlinks, {
  regex = [[\b([a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+)#(\d+)\b]],
  format = 'https://github.com/$1/issues/$2',
})

config.hyperlink_rules = hyperlinks

wezterm.on('open-uri', function(window, pane, uri)
  if uri:match('^https?://') or uri:match('^mailto:') then
    return
  end
  local file, line = uri:match('^(.+):(%d+)')
  local arg = file and (file .. ':' .. line) or uri
  wezterm.background_child_process { 'wsl.exe', '-e', 'code', '-g', arg }
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
config.window_close_confirmation = 'NeverPrompt'
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

  { key = 'F5',                      action = act.ReloadConfiguration },

  -- theme: F10 toggle light↔dark (override) · Shift+F10 reset auf system-autodetect
  { key = 'F10',                     action = toggle_theme },
  { key = 'F10', mods = 'SHIFT',     action = reset_theme_auto },

  { key = '-', mods = 'CTRL',       action = act.DecreaseFontSize },
  { key = '=', mods = 'CTRL',       action = act.IncreaseFontSize },
  { key = '0', mods = 'CTRL',       action = act.ResetFontSize },

  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
  { key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = false } },

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

config.mouse_bindings = {
  { event = { Down = { streak = 1, button = 'Right' } }, mods = 'NONE', action = act.PasteFrom 'Clipboard' },
  -- doppel-rechtsklick: about-overlay (hintergrundbild nicht anklickbar in wezterm)
  { event = { Down = { streak = 2, button = 'Right' } }, mods = 'NONE', action = about_overlay },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE', action = act.CompleteSelection 'Clipboard' },
  { event = { Up = { streak = 2, button = 'Left' } }, mods = 'NONE', action = act.CompleteSelection 'Clipboard' },
  { event = { Up = { streak = 3, button = 'Left' } }, mods = 'NONE', action = act.CompleteSelection 'Clipboard' },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL', action = act.OpenLinkAtMouseCursor },

  -- ctrl + wheel → zoom
  { event = { Down = { streak = 1, button = { WheelUp = 1 } } }, mods = 'CTRL', action = act.IncreaseFontSize },
  { event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = 'CTRL', action = act.DecreaseFontSize },

  -- shift + wheel → page scroll
  { event = { Down = { streak = 1, button = { WheelUp = 1 } } }, mods = 'SHIFT', action = act.ScrollByPage(-1) },
  { event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = 'SHIFT', action = act.ScrollByPage(1) },
}

return config
