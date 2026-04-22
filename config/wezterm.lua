-- TerminalStack — WezTerm Config by Stackschmiede
-- https://stackschmiede.de
--
-- Features:
--   · warm workshop brand palette (amber + sage on anthrazit)
--   · WSL2 default domain
--   · tab blink: idle shell (sage pulse) + attention (amber blink)
--   · tab rename: F2  or  Ctrl+Shift+E
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
-- stackschmiede brand palette (werkstatt-de, warm workshop)
-- ═══════════════════════════════════════════════════════════════
local ss = {
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
}

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

config.window_frame = {
  font = wezterm.font { family = 'Inter', weight = 'Medium' },
  font_size = 10.0,
  active_titlebar_bg = ss.bg,
  inactive_titlebar_bg = ss.bg,
}

-- ═══════════════════════════════════════════════════════════════
-- terminal-palette
-- ═══════════════════════════════════════════════════════════════
config.colors = {
  foreground        = ss.fg,
  background        = ss.bg,
  cursor_bg         = ss.primary,
  cursor_fg         = ss.bg,
  cursor_border     = ss.primary,
  selection_bg      = ss.primary,
  selection_fg      = ss.bg,
  scrollbar_thumb   = ss.border,
  split             = ss.border,
  visual_bell       = ss.primary,

  ansi = {
    ss.surface, ss.danger, ss.accent, ss.primary,
    '#7A8A99', '#A67F8E', '#8BA99C', ss.muted,
  },
  brights = {
    ss.border, '#D98580', ss.success, ss.primarySoft,
    '#9DB0C0', '#C09AA8', '#94BAB0', ss.fg,
  },

  tab_bar = {
    background         = ss.bg,
    active_tab         = { bg_color = ss.primary,  fg_color = ss.bg,      intensity = 'Bold' },
    inactive_tab       = { bg_color = ss.surface,  fg_color = ss.muted },
    inactive_tab_hover = { bg_color = ss.surface2, fg_color = ss.fg,      italic = false },
    new_tab            = { bg_color = ss.bg,       fg_color = ss.primary },
    new_tab_hover      = { bg_color = ss.surface,  fg_color = ss.primarySoft },
    inactive_tab_edge  = ss.bg,
  },
}

-- ═══════════════════════════════════════════════════════════════
-- fenster + hintergrund (stackschmiede wordmark unten rechts)
-- ═══════════════════════════════════════════════════════════════
config.window_decorations = 'TITLE | RESIZE'
config.window_padding = { left = 10, right = 10, top = 4, bottom = 70 }
config.win32_system_backdrop = 'Disable'
config.window_background_opacity = 1.0
config.macos_window_background_blur = 0
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.82 }

config.background = {
  { source = { Color = ss.bg }, width = '100%', height = '100%', opacity = 1.0 },
  {
    source             = { File = '{{ASSETS_PATH}}\\logo-wordmark.png' },
    repeat_x           = 'NoRepeat',
    repeat_y           = 'NoRepeat',
    vertical_align     = 'Bottom',
    horizontal_align   = 'Right',
    width              = 305,
    height             = 62,
    opacity            = 0.85,
    horizontal_offset  = -22,
    vertical_offset    = -18,
    attachment         = 'Fixed',
  },
}

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
-- pro pane fingerprint (letzte 12 zeilen) → erkennt auch \r-overwrites
-- bell → attn_pending; cleart nur beim Tab-Fokus (nicht bei neuem Output)
-- ═══════════════════════════════════════════════════════════════
wezterm.GLOBAL.pane_state = wezterm.GLOBAL.pane_state or {}

local BUSY_WINDOW = 3  -- sekunden seit letztem output → "busy"

local function pane_fingerprint(pane)
  local ok, txt = pcall(function() return pane:get_lines_as_text(12) end)
  if not ok or not txt then return '0:' end
  -- länge + suffix (letzte 64 zeichen) → robust gegen \r-overwrites in spinner-zeilen
  local suffix = txt:sub(-64)
  return tostring(#txt) .. ':' .. suffix
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
  local cwd = ''
  if pane.current_working_dir then
    local path = pane.current_working_dir.file_path or tostring(pane.current_working_dir)
    cwd = path:gsub('/$', ''):match('([^/]+)$') or path
  end
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
    label = cwd ~= '' and cwd or title
  end
  if #label > max_width - 6 then
    label = label:sub(1, max_width - 7) .. '…'
  end
  local text = string.format('  %d %s %s  ', idx, prefix, label)

  local pid = tostring(pane.pane_id)
  local st = get_state(pid)
  local now = os.time()
  local busy = (now - (st.last_change or 0)) < BUSY_WINDOW

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
      { Foreground = { Color = ss.bg } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = text },
    }
  end

  -- inactive + busy (arbeitet): amber-soft auf surface
  if busy then
    return {
      { Background = { Color = ss.surface } },
      { Foreground = { Color = ss.primarySoft } },
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
config.status_update_interval = 2000
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

local about_overlay = act.PromptInputLine {
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
}

local rename_tab = act.PromptInputLine {
  description = wezterm.format {
    { Attribute = { Intensity = 'Bold' } },
    { Foreground = { Color = ss.primary } },
    { Text = 'Rename tab (enter to set, empty to reset):' },
  },
  action = wezterm.action_callback(function(window, pane, line)
    if line then
      window:active_tab():set_title(line)
    end
  end),
}

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

  -- tab-cycling: ctrl+space (vorwärts) / ctrl+` (rückwärts)
  { key = 'Space', mods = 'CTRL',       action = act.ActivateTabRelative(1) },
  { key = '`',     mods = 'CTRL',       action = act.ActivateTabRelative(-1) },
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
