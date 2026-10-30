# Customization

WezTerm lädt `~/.wezterm.lua` live nach — Änderungen sind nach dem Speichern sofort sichtbar.

## Farb-Palette tauschen

Oben in der Datei steht die Tabelle `local ss = { ... }`. Die drei wichtigsten Farben:

| Key | Rolle | Default |
|---|---|---|
| `primary` | Akzentfarbe: Cursor, aktiver Tab, Amber-Blink, Selektion | `#D4A574` |
| `accent` | Sekundäre Akzentfarbe: Sage-Pulsen | `#6B8E7F` |
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

Wenn du das Logo entfernst, `bottom` auf `6` oder `10` setzen — aber nur mit `CLAUDE_USAGE.position = 'top'` oder `enabled = false`: Die Claude-Nutzung liegt im selben Streifen und bleibt sonst unter dem Terminal verdeckt.

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

## Links & Editor

Klick (ohne Drag) oder `Strg+Klick` öffnet den Link unter dem Cursor. URLs und `mailto:` gehen an den Windows-Default-Browser (`rundll32 url.dll,FileProtocolHandler`), Pfade an den Editor:

```lua
local FILE_LINK_EDITOR = 'code'   -- 'antigravity-ide', 'cursor', …
```

Das Kommando muss im WSL-PATH auffindbar sein — die Windows-Interop-Pfade reichen (`which code` in WSL prüfen).

Erkannte Pfad-Formen (alle mit optionalem `:zeile` oder `:zeile:spalte`):

| Form | Beispiel |
|---|---|
| absolut (≥ 2 Segmente) | `/home/user/projekt/datei.py:42`, `/etc/hosts`, `/mnt/c/Users/x/` |
| home-relativ | `~/.claude/rules/x.md` |
| punkt-relativ | `./install/install.ps1`, `../x` |
| relativ mit Verzeichnis + Endung | `config/wezterm.lua`, `.github/workflows/x.yml` |
| nackter Dateiname mit bekannter Endung | `README.md`, `x.py.bak` — Liste `EXT` in der Config; Domains (`.de`, `.com`) bewusst nicht |
| Windows | `C:\Users\x\.wezterm.lua`, `D:/data/x.csv` |
| `file://`-URI (OSC 8 aus TUIs) | `file:///home/x`, `file://wsl.localhost/Ubuntu/home/x`, `file:///C:/x` |

Relative Pfade werden gegen das CWD des Panes aufgelöst (braucht OSC 7 aus der Shell), `~/` gegen `$HOME`. Weitere Endungen für nackte Dateinamen: `EXT`-String in der Config erweitern. Falsch-positive Treffer (z. B. `node.js` in Prosa) sind harmlos — der Editor öffnet dann eine leere Datei.

### Maus in TUIs mit Maus-Capture

Claude Code (ab 2.1.3xx), vim, htop, tmux & Co. schalten Mouse-Reporting ein; WezTerm reicht dann alle Maus-Events an die App durch und wendet eigene Bindings nur noch mit `Shift` an. Die Config registriert deshalb Linksklick (Selektion + Link öffnen), Rechtsklick (Paste) und `Strg+Mausrad` (Zoom) zusätzlich mit `mouse_reporting = true` — sie bleiben so in jeder TUI beim Terminal. Das Mausrad ohne Modifier geht weiter an die App (Claude Code scrollt damit sein Transkript, vim seinen Buffer).

Kehrseite: eine TUI, die eigene Klick-Interaktion anbietet (Cursor per Klick setzen, Optionen anklicken), bekommt den Linksklick nicht mehr. Wer das lieber hätte, löscht in `config.mouse_bindings` die Schleife, die die `mouse_reporting`-Varianten einträgt — dann gilt wieder: `Strg+Umschalt+Klick` für Links in TUIs.

Alternative auf Claude-Code-Seite: `export CLAUDE_CODE_DISABLE_MOUSE=1` (kein Mouse-Reporting, WezTerm-Standardverhalten) oder `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` (nur Scrollen) in der Shell-RC.

Plain-Klick auf Links wieder abschalten: in `terminal_owned_mouse()` bei `Up { streak = 1 }` / `mods = 'NONE'` die Action auf `act.CompleteSelection 'Clipboard'` setzen — dann öffnet nur noch `Strg+Klick`.

## Schließen-Bestätigung

Fenster-X, `Alt+F4`, `Strg+Umschalt+W` (Tab) und `Strg+Umschalt+X` (Pane) zeigen ein Overlay (`y` schließt, `n`/`Esc` bricht ab) — auch wenn nur eine Shell läuft:

```lua
config.window_close_confirmation = 'AlwaysPrompt'
config.skip_close_confirmation_for_processes_named = {}   -- sonst killt WezTerm bash/zsh/pwsh ohne Rückfrage
```

Abschalten: `'NeverPrompt'` und in `config.keys` bei `CloseCurrentTab`/`CloseCurrentPane` `confirm = false`. `exit` in der Shell schließt den Tab weiterhin ohne Rückfrage (`exit_behavior`).

## Claude-Nutzung am unteren Fensterrand

Unten links, neben dem Logo, steht die Auslastung des Claude-Abos: `◑ 5h 42% ↻14:30 · ◔ 7d 18% · ◔ Fable 31%` — 5-Stunden-Fenster (mit Reset-Uhrzeit), Wochen-Kontingent und die Modell-Fenster, die der Server für den Account liefert (z. B. Opus, Fable). Mehrere Accounts stehen nebeneinander in einer Zeile, getrennt durch `‖`.

Farbcodierung (pro Row, nach genutztem Anteil — Palette folgt dem Theme):

| genutzt | Farbe | Glyph |
|---|---|---|
| 0–50 % | grün (`success`) — viel übrig | `○` `◔` `◑` |
| 50–75 % | Verlauf grün → amber | `◑` `◕` |
| 75–90 % | Verlauf amber → rot | `◕` `●` |
| ab 90 % | rot (`danger`) + fett — knapp | `●` |

Der Kreis zeigt den Füllstand der angezeigten Zahl in fünf Stufen (`○` leer … `●` voll). Meldet der Server selbst `warning`/`critical`, wird die Farbe mindestens auf amber bzw. rot gehoben. Stufen über `thresholds` anpassbar; `numbers = 'left'` dreht Zahl und Glyph auf „übrig“ (Batterie-Logik: `● 5h 90%` = 90 % frei), die Farbe bleibt gleich.

Mechanik: `%USERPROFILE%\.wezterm-claude-usage.sh` (vom Installer kopiert) läuft alle `interval` Sekunden per `wsl.exe` in WSL, liest den OAuth-Token aus `<dir>/.credentials.json` und schreibt nur Prozente + Reset-Zeiten nach `%USERPROFILE%\.wezterm-claude-usage.json`. Die Config liest ausschließlich diesen Cache — der Token verlässt WSL nicht (curl bekommt ihn über stdin, nie als Argument; kein Refresh-Token-Gebrauch). Voraussetzung in WSL: `sudo apt install jq curl`.

WezTerm hat nur eine Leiste, und `tab_bar_at_bottom` würde auch die Tabs verschieben. Der Streifen unter dem Terminal ist deshalb nur als Hintergrund-Layer erreichbar: Ändert sich der Inhalt, schreibt die Config eine Beschreibung nach `.wezterm-claude-usage.spec` und startet `%USERPROFILE%\.wezterm-claude-usage-render.ps1`. Das Script zeichnet ein transparentes PNG (`.wezterm-claude-usage.a.png` / `.b.png` im Wechsel), die Config hängt es in `config.background` ein. Das passiert nur bei Inhaltsänderungen, typisch höchstens alle 5 Minuten, und außerdem beim Theme-Wechsel und mit `F5`.

Kehrseiten: Der Text im Bild ist nicht selektierbar und nicht klickbar, in schmalen Fenstern läuft er über das Logo. Bleibt das Bild 20 Sekunden aus, wandert die Anzeige automatisch in die Tab-Leiste und der Grund steht im WezTerm-Log (Details in `.wezterm-claude-usage.err`); `F5` versucht es neu.

```lua
local CLAUDE_USAGE = {
  enabled    = true,
  position   = 'bottom',            -- 'bottom' = Bild unten links | 'top' = rechts in der Tab-Leiste
  interval   = 300,                 -- Sekunden zwischen zwei Abfragen (1 Request pro Account)
  accounts   = {
    { label = '',  dir = '~/.claude' },      -- label = Prefix vor den Werten ('' = keiner)
    -- { label = 'B', dir = '~/.claude-b' }, -- Zweit-Account (CLAUDE_CONFIG_DIR)
  },
  rows       = nil,                 -- nil = alle Rows · sonst z. B. { '5h', '7d', 'Opus' }
  show_reset = 'session',           -- '↻'-Reset-Zeit: 'session' (nur 5h) | 'all' | 'none'
  numbers    = 'used',              -- 'used' (genutzt, wie /usage) | 'left' (übrig)
  thresholds = { 50, 75, 90 },      -- genutzt in %: bis 50 grün · →75 grün→amber · →90 amber→rot · ab 90 rot + fett
}
```

| Anzeige | Bedeutung |
|---|---|
| `◑ 5h 42% ↻14:30 · ◔ 7d 18%` | frisch; das 5h-Fenster setzt sich um 14:30 zurück |
| `◌ ◑ 5h 42% · ◔ 7d 18% (10m)` | grau, Cache rund 10 min alt (auf 5 min gerundet) — Poller erreicht den Server nicht (Netz, Endpoint geändert) |
| `claude: login` bzw. `(login)` | Token abgelaufen oder ausgeloggt — Claude Code einmal starten (erneuert den Token) oder `/login` |
| `◌ claude: no-config` / `no-token` | `dir` existiert nicht, keine `.credentials.json` oder nicht eingeloggt |
| `◌ claude: jq fehlt` | `sudo apt install jq` in WSL |

Abschalten: `enabled = false`. Mehrere Accounts verlängern die Zeile — reicht das Fenster nicht, `rows` filtern oder einen Account weglassen. Der Endpoint (`api.anthropic.com/api/oauth/usage`) ist derselbe, den Claude Code für `/usage` nutzt, aber nicht öffentlich dokumentiert; ändert sich sein Format, zeigt die Anzeige `◌ … (Nm)` und das Terminal läuft normal weiter. Manuell prüfen (in WSL): `bash /mnt/c/Users/<du>/.wezterm-claude-usage.sh --out /tmp/cu.json && cat /tmp/cu.json`.

## Debugging

WezTerm hat ein eingebautes Debug-Overlay: `Strg+Umschalt+L` → `DebugOverlay` (oder in `config.keys` ein eigenes Keybinding legen). Lua-Fehler erscheinen hier in Rot, inkl. Stack-Trace.

Config-Reload erzwingen: `Strg+Umschalt+R` (WezTerm-Default).
