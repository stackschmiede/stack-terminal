# Changelog

Alle relevanten Änderungen werden hier dokumentiert. Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung folgt [SemVer](https://semver.org/lang/de/).

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
