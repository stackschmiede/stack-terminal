# Customization

WezTerm lädt `~/.wezterm.lua` live nach — Änderungen sind nach dem Speichern sofort sichtbar.

## Farb-Palette tauschen

Oben in der Datei steht die Tabelle `local ss = { ... }`. Die drei wichtigsten Farben:

| Key | Rolle | Default |
|---|---|---|
| `primary` | Akzentfarbe: Cursor, aktiver Tab, Amber-Blink, Selektion | `#D4A574` |
| `accent` | Sekundäre Akzentfarbe: Workspace-Label, Sage-Pulsen | `#6B8E7F` |
| `bg` | Canvas-Hintergrund | `#0F0F10` |

Weitere Tokens (`surface`, `surface2`, `fg`, `muted`, `border`) werden konsistent abgeleitet. Wenn du komplett andere Farben willst, ändere alle drei und passe optional `surface/surface2` an den neuen `bg` an.

## Eigene Projekte ins Launch-Menü

In `config.launch_menu = { ... }` ergänzen:

```lua
{ label = '◆ my-project',   args = { 'bash', '-l' }, cwd = '/home/USER/projects/my-project' },
{ label = '◆ Claude · app', args = { 'bash', '-lc', 'cd ~/projects/app && claude' } },
```

Aufruf via `Strg+Umschalt+L` — Fuzzy-Suche.

## Logo ersetzen

Das Wordmark-PNG liegt unter `%USERPROFILE%\.wezterm-assets\logo-wordmark.png`. Ersetzen reicht — Größe im `config.background`-Block anpassen:

```lua
{
  source = { File = '...\\logo-wordmark.png' },
  width  = 305,   -- px
  height = 62,    -- px
  horizontal_offset = -22,
  vertical_offset   = -18,
  opacity = 0.85,
}
```

Tipp: PNG mit Alpha (transparent). 2× Auflösung für HiDPI-Schärfe.

## Blink abschalten

In `format-tab-title` die beiden `if has_attention` / `elseif is_shell` Blöcke auskommentieren — dann fällt der Tab auf den Standardstil aus `config.colors.tab_bar.inactive_tab` zurück.

Oder den Takt verlangsamen: `config.status_update_interval = 1000` statt `500` → 1 Sekunde zwischen An/Aus.

## Font / Size

```lua
config.font = wezterm.font_with_fallback { 'JetBrains Mono', 'Cascadia Code', 'Consolas' }
config.font_size = 11.0
config.line_height = 1.08
```

Zoom zur Laufzeit: `Strg + =/−/0` oder `Strg+Mausrad`.

## Padding / Fenstergröße

```lua
config.window_padding = { left = 10, right = 10, top = 4, bottom = 70 }   -- Platz für Logo unten
config.initial_cols = 140
config.initial_rows = 40
```

Wenn du das Logo entfernst, `bottom` auf `6` oder `10` setzen.

## WSL-Distro wechseln

`config.wsl_domains` anpassen:

```lua
config.wsl_domains = {
  {
    name = 'WSL:Debian',
    distribution = 'Debian',
    username = 'meinuser',
    default_cwd = '/home/meinuser/projects',
    default_prog = { 'bash', '-l' },
  },
}
config.default_domain = 'WSL:Debian'
```

Die `new_tab_wsl`-Callback-Funktion referenziert ebenfalls den Distro-Namen — dort auch anpassen.

## Debugging

WezTerm hat ein eingebautes Debug-Overlay: `Strg+Umschalt+L` → `DebugOverlay` (oder in `config.keys` ein eigenes Keybinding legen). Lua-Fehler erscheinen hier in Rot, inkl. Stack-Trace.

Config-Reload erzwingen: `Strg+Umschalt+R` (WezTerm-Default).
