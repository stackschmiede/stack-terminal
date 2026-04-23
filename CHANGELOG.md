# Changelog

Alle relevanten Änderungen werden hier dokumentiert. Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung folgt [SemVer](https://semver.org/lang/de/).

## [0.2.1] — 2026-04-23

### Changed
- **Active-Tab-Farbe** — `amber` → `sage` (Brand-Akzent). Klarere Abgrenzung zum Attention-State inaktiver Tabs, der weiterhin Amber nutzt

### Added
- **Tab-Cycling** — `Strg+Alt+←` als zweites Rückwärts-Binding (zusätzlich zu `` Strg+` ``)

### Removed
- **WezTerm-Default `Strg+Tab`** — via `DisableDefaultAssignment` neutralisiert

## [0.2.0] — 2026-04-22

### Added
- **Inno Setup Installer** (`install/TerminalStack.iss`) — branded `.exe` Wizard mit Dark/Amber-Design, keine Admin-Rechte nötig, auto-detect WSL-Distro + Username
- **Wizard-Branding** — `wizard-panel.png` (Seitenleiste) + `wizard-icon.png` (Inner-Pages)
- **GitHub Actions Release-Workflow** — Auto-Build `.exe` + ZIP bei `git tag v*`
- **Tab-State-Maschine** — 3 Zustände (idle/busy/attention) via Pane-Fingerprint; erkennt auch `\r`-Overwrites (TUI-Spinner, Streaming)
- **Busy-State** — Amber-soft wenn Prozess in letzten 3s Output schrieb
- **About-Overlay** — `F1` oder Doppel-Rechtsklick → PromptInputLine mit Brand-Info + stackschmiede.de
- **Config-Reload** — `F5` für manuellen Reload
- **Tab-Cycling** — `Strg+Leertaste` (vorwärts) / `` Strg+` `` (rückwärts)
- **Status-Bar Hint** — `ⓘ` neben der Uhrzeit als visueller About-Trigger

### Changed
- **Attention-Clearing** — statt Cursor-Row jetzt Fingerprint-Diff (robust gegen Spinner); cleart nur wenn User *im* Tab etwas tippt, nicht beim Durchtabben
- **Logo-Wordmark** — 4× Auflösung (1220×248 statt 305×62) — kristallklar auf HiDPI

### Security
- `.gitignore` erweitert — Preview-Screenshots, lokale Personal-Varianten, Log-Dateien geschützt

## [0.1.0] — 2026-04-22

### Erste Veröffentlichung

#### Added
- Stackschmiede-Brand-Palette (Amber + Sage auf warmem Anthrazit)
- WSL2-Default-Domain mit automatischem Projekt-CWD
- Tab-Attention-Markierung — Amber-Badge bei Bell-Event (Claude fertig, `\a`-Signal) im inaktiven Tab. State pro `pane_id` in `wezterm.GLOBAL.attention`, Anker ist die Cursor-Zeile zum Zeitpunkt des Bells. Markierung bleibt bestehen, auch beim Durchtabben (man kann gezielt wissen, welcher Tab Input erwartet). Clearing erfolgt automatisch, sobald der Prozess wieder Ausgabe produziert (Polling in `update-status` prüft, ob der Cursor weiter gewandert ist).
- Tab-Rename via `F2` und `Strg+Umschalt+E`
- Tab-Reorder via `Strg+Umschalt+Bild↑` / `Bild↓`
- Tab-Detach via `F6` (`MuxTab:move_to_new_window`, mit Fallback auf `SpawnWindow` bei älteren WezTerm-Builds)
- Smart-Paste (`Strg+Umschalt+V`) — PowerShell-Helper `paste-image.ps1` prüft die Zwischenablage auf Bildinhalt, speichert sie nach `%TEMP%\wezterm-paste-*.png`, fügt den WSL-Pfad ein (mit `@`-Prefix wenn `claude` im Vordergrund); Fallback auf normalen Text-Paste
- `Shift+Mausrad` für seitenweises Scrollen (plus `Shift+Bild↑/↓`)
- `Strg+Mausrad` für Font-Zoom
- Windows-Style Clipboard (`Strg+C` smart, `Strg+V`, Rechtsklick paste)
- File:line-Hyperlinks → öffnen in VS Code (via `wsl.exe -e code -g`)
- Launch-Menu Platzhalter für eigene Projekte
- PowerShell-Installer mit Platzhalter-Substitution + WezTerm winget-Install
- Uninstaller mit automatischem Backup-Restore
