# TerminalStack

**WezTerm-Konfiguration im Stackschmiede-Stil.**
Warme Werkstatt-Palette (Amber + Sage), WSL2-ready, Windows-freundliche Tastenbelegung, visuelle Hinweise wenn ein Tab Aufmerksamkeit braucht.

> by [Stackschmiede](https://stackschmiede.de)

---

## Features

- **Brand-Palette** — anthrazit bg, amber als primary, sage als accent. Lesbar, ruhig, professionell.
- **Tab-Attention** — inaktive Tabs werden amber markiert, sobald der dort laufende Prozess ein Bell-Signal sendet (z. B. Claude Code wenn es fertig ist und auf Input wartet). Die Markierung bleibt stehen, bis der Prozess tatsächlich weiterarbeitet (neuer Output erkannt) — du weißt also jederzeit, welcher Tab bereit ist und welcher gerade noch arbeitet.
- **Tab-Rename** — `F2` oder `Strg+Umschalt+E` öffnet ein Prompt. Enter setzt den Titel, leer = zurücksetzen.
- **Shift+Mausrad** — seitenweise durchs Scrollback.
- **Strg+Mausrad** — Font-Zoom (wie im Browser).
- **Windows-Style Clipboard** — `Strg+C` kopiert bei Selektion (sonst SIGINT), `Strg+V` paste, Rechtsklick paste.
- **Smart-Paste für Bilder** — `Strg+Umschalt+V` erkennt Bilder (z. B. Screenshot via `Win+Umschalt+S`) in der Zwischenablage, speichert sie nach `%TEMP%` und fügt den WSL-Pfad ein. Wenn im Tab gerade `claude` läuft, wird der Pfad als `@pfad` eingefügt — direkt konsumierbar von der Claude Code CLI. Ohne Bild im Clipboard → normaler Text-Paste.
- **WSL-Default-Domain** — jeder neue Tab öffnet direkt in WSL, nicht im Windows-Shell.
- **File:line Hyperlinks** — `Strg+Klick` auf `path/to/file.py:42` öffnet VS Code an der Zeile.
- **Wordmark-Logo** unten rechts — dezente Brand-Präsenz im Hintergrund.

## Installation

**Voraussetzung:** Windows 10/11 + WSL2 mit einer Linux-Distro (Ubuntu, Debian, …).

### 1. Repo holen

```powershell
git clone https://github.com/stackschmiede/stack-terminal.git
cd stack-terminal
```

Oder als ZIP herunterladen und entpacken.

### 2. Installer ausführen

Doppelklick auf `install\install.bat` — ein PowerShell-Fenster öffnet sich und fragt nach:

- **WSL-Distribution** (Default: erste gefundene, z. B. `Ubuntu`)
- **WSL-Username** (Default: `whoami` in der Distro)
- **Projects-Pfad** (Default: `/home/<user>/projects`)

Der Installer:

1. bietet `winget install wez.wezterm` an, falls WezTerm fehlt
2. sichert bestehende `%USERPROFILE%\.wezterm.lua` und `.wezterm-assets\` als `.bak.TIMESTAMP`
3. kopiert Assets + Config nach `%USERPROFILE%`
4. ersetzt Platzhalter mit deinen Werten

Danach WezTerm neu starten — fertig.

### CLI-Parameter (optional)

```powershell
.\install\install.ps1 -WslDistro Ubuntu -WslUsername myuser -ProjectsPath /home/myuser/code -Force
```

### Non-interactive (CI/Scripted)

```powershell
.\install\install.ps1 -NonInteractive -WslDistro Ubuntu -WslUsername myuser -Force
```

## Deinstallation

Doppelklick auf `install\uninstall.ps1` (oder über Rechtsklick → „Mit PowerShell ausführen"). Wenn ein Backup existiert, wird es wiederhergestellt.

## Anpassung

Nach der Installation editierst du `%USERPROFILE%\.wezterm.lua` direkt — WezTerm lädt Änderungen live nach.

Typische Anpassungen: Launch-Menü mit eigenen Projekten füllen, Farben tauschen, Font-Size. Details: [`docs/customization.md`](docs/customization.md).

## Shortcuts (Kurzübersicht)

| Shortcut | Aktion |
|---|---|
| `Strg+Umschalt+V` | Smart-Paste (Bild → WSL-Pfad, sonst Text) |
| `Strg+Umschalt+T` / `+N` | Neuer Tab in WSL |
| `F2` / `Strg+Umschalt+E` | Tab umbenennen |
| `Strg+Umschalt+Bild↑` / `Bild↓` | Tab nach links / rechts verschieben |
| `F6` | Tab detachen (in eigenes Fenster) |
| `Strg+Umschalt+W` | Tab schließen |
| `Strg+Umschalt+D` / `+R` | Pane horizontal / vertikal |
| `Strg+Umschalt+Alt+Pfeile` | Pane wechseln |
| `Strg+Umschalt+L` | Launcher (Projekte) |
| `Strg+Umschalt+O` | Workspace-Switcher |
| `Strg+Umschalt+F` | Scrollback durchsuchen |
| `Strg+Umschalt+Leer` | Quick Select |
| `Shift+Mausrad` / `Shift+Bild↑↓` | Seitenweise scrollen |
| `Strg+Mausrad` / `Strg+=/−/0` | Font-Zoom |
| `Strg+Klick` auf `file:line` | in VS Code öffnen |

## Projektstruktur

```
stack-terminal/
├── config/
│   ├── wezterm.lua           — Template mit Platzhaltern
│   └── assets/               — Logo-Dateien
├── install/
│   ├── install.ps1           — PowerShell-Installer
│   ├── install.bat           — Doppelklick-Wrapper
│   └── uninstall.ps1         — Restore/Cleanup
├── docs/
│   └── customization.md
└── preview/                  — Screenshots
```

## Credits

- **Brand & Config** · [Stackschmiede](https://stackschmiede.de)
- **Terminal-Emulator** · [WezTerm](https://wezfurlong.org/wezterm/) von Wez Furlong
- **Fonts** · [JetBrains Mono](https://www.jetbrains.com/mono/), [Inter](https://rsms.me/inter/)

## Lizenz

MIT — siehe [`LICENSE`](LICENSE). Logo und Wordmark „Stackschmiede" sind Markenzeichen und nicht durch die MIT-Lizenz abgedeckt; für eigene Forks bitte eigenes Wordmark verwenden.
