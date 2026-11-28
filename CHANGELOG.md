# Changelog

Alle relevanten Änderungen werden hier dokumentiert. Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), Versionierung folgt [SemVer](https://semver.org/lang/de/).

## [Unreleased]

### Fixed
- **Claude-Nutzung verschwand nach dem Start** — die Config renderte abwechselnd in zwei feste Dateien (`.a.png` / `.b.png`) und löschte die Zieldatei vor jedem Render. Beim Fensterstart wird mehrmals kurz hintereinander gerendert (Platzhalter, dann echte Daten); dabei verschwand das Bild, das WezTerm gerade übernehmen wollte. Ein fehlgeschlagenes Laden versucht WezTerm nicht erneut, die Anzeige blieb leer, bis sich der Inhalt änderte. Jetzt bekommt jeder Render eine eigene Datei (`.wezterm-claude-usage.<zeit>-<n>.png`), ein abgelöstes Bild wird erst nach 60 Sekunden gelöscht, Reste früherer Prozesse beim Start (nach einem Tag). Der Uninstaller räumt per Muster auf

### Added
- **Test für die Bild-Dateien** — `tests/render_test.lua` (in `tests/verify.sh --full`) fährt den Status-Poll mit gemockter Uhr und prüft u. a., dass das angezeigte Bild in jedem Tick existiert (19 Fälle)

## [0.5.0] — 2026-11-26

### Changed
- **Links nur noch per `Strg+Klick`** — der einfache Klick öffnet nicht mehr, er markiert nur; Doppelklick kopiert das Wort wie bisher. Markieren, Kopieren oder Fokussieren startet so nie versehentlich ein Programm. `Strg+Umschalt+Klick` bleibt Fallback

### Fixed
- **Tab „arbeitet" trotz stillem Bildschirm** — wartet Claude Code auf eine Hintergrund-Shell oder einen Hintergrund-Agenten, ist der Turn zu Ende und der Bildschirm steht still; der Tab sah fertig aus (bzw. nach der Glocke „wartet auf dich"), obwohl Claude weitermacht, sobald die Arbeit durch ist. Der Status-Poll liest jetzt Claudes unteren Rand: Shells in der Fußzeile (`· 1 shell ·`, `· 2 shells ·`), Agenten als Liste darunter (`● main` / `◯ <agent>  <tätigkeit>`, verschwindet, wenn alle fertig sind). Der Tab bleibt so lange busy. „ran 3 shell commands" oder eine zitierte Liste im Verlauf zählen nicht
- **Pfad-Links ohne installierten Editor** — fand die Shell `FILE_LINK_EDITOR` nicht, passierte beim Klick nichts, ohne Meldung. Jetzt geht der Pfad an das Windows-Standardprogramm (Linux-Pfade per `wslpath -w`), Ordner an den Explorer
- **Windows-Pfade im Editor** — `C:\…` ging unverändert an das Editor-Kommando in WSL. Jetzt wird der Pfad per `wslpath -u` nach `/mnt/c/…` übersetzt, `:zeile[:spalte]` wird vorher abgetrennt und wieder angehängt

### Added
- **Tests** — `tests/verify.sh` lädt die Config in der echten `wezterm.exe` (`pcall(dofile)` + Prüfung der eigenen Maus-Bindings, weil `show-keys` auch bei kaputter Config mit Exit 0 endet); `--full` prüft zusätzlich Link-Handler (13 Fälle) und Tab-States inkl. Hintergrund-Shells/-Agenten (17 Fälle). `.verify` / `.verify.full` binden das an das Verify-Gate
- **Dokumente im Standardprogramm** — PDFs, Office-Dateien, Bilder, Audio/Video und Archive (`EXTERNAL_EXT`) öffnen immer im Windows-Standardprogramm statt im Editor, Windows-Pfade direkt ohne Umweg über WSL. Nackte Dateinamen mit Office-Endung (`Dienstplan.xlsx`) sind jetzt ebenfalls klickbar

## [0.4.0] — 2026-10-28

### Fixed
- **Links in TUIs mit Maus-Capture** — Claude Code (ab 2.1.3xx), vim, htop & Co. fordern alle Maus-Events an; WezTerm wandte eigene Bindings dann nur noch mit `Shift` an, Links und Pfade im Claude-Tab waren nicht klickbar und Text nicht per Maus markierbar. Linksklick (Selektion + Link öffnen), Rechtsklick (Paste) und `Strg+Mausrad` (Zoom) sind jetzt zusätzlich mit `mouse_reporting = true` registriert und bleiben beim Terminal. Mausrad ohne Modifier geht weiter an die App (Claude Code scrollt damit sein Transkript)

- **Installer unter Windows PowerShell 5.1** — `install.ps1` und `uninstall.ps1` enthielten UTF-8 ohne BOM; PowerShell 5.1 liest das als ANSI, und das `—` wurde zum Anführungszeichen. Beide Scripts brachen schon beim Parsen ab, also auch `TerminalStack-Setup.exe` und `install.bat`. Die Dateien tragen jetzt ein BOM

### Changed
- **Statusleiste entschlackt** — Workspace und CWD sind raus, rechts stehen nur noch Datum und Uhrzeit

### Added
- **Claude-Nutzung am unteren Fensterrand** — 5h-Fenster, Wochen-Kontingent und Modell-Fenster des Claude-Abos (`◑ 5h 42% ↻14:30 · ◔ 7d 18% · ◔ Fable 31%`) unten links neben dem Logo, Farbe nach Restkontingent (grün → amber → rot, ab 90 % fett), Kreis als Füllstand, mehrere Accounts nebeneinander (`CLAUDE_USAGE`-Block). WezTerm kann dort keinen Text zeichnen, `install/claude-usage-render.ps1` rendert deshalb bei Inhaltsänderungen ein transparentes PNG als Hintergrund-Layer; `position = 'top'` zeigt die Nutzung stattdessen in der Tab-Leiste, dorthin fällt die Anzeige auch automatisch zurück, wenn das Bild ausbleibt. Poller `install/claude-usage.sh` läuft alle 5 min in WSL, der OAuth-Token bleibt dort (curl via stdin, kein Refresh); braucht `jq` + `curl`. Installer kopiert beide Helper nach `%USERPROFILE%`, Uninstaller räumt Helper, Cache und Bilder weg
- **Pfade ohne Zeilennummer klickbar** — absolut (`/home/…`), `~/…`, `./…`, relativ mit Verzeichnis (`config/wezterm.lua`), nackte Dateinamen mit bekannter Endung (`README.md`) und Windows-Pfade (`C:\…`), jeweils mit optionalem `:zeile[:spalte]`
- **`file://`-URIs** (OSC-8-Links aus TUIs) landen im Editor statt im Browser — inkl. `file://wsl.localhost/…` und `file:///C:/…`
- **Schließen-Bestätigung** — Fenster-X, `Alt+F4`, `Strg+Umschalt+W` und `Strg+Umschalt+X` fragen nach (`y`/`n`), auch wenn nur eine Shell läuft (`window_close_confirmation = 'AlwaysPrompt'`, leere Skip-Liste)

## [0.3.0] — 2026-09-23

### Fixed
- **Links anklickbar** — einfacher Linksklick (ohne Drag) öffnet den Link unter dem Cursor (`CompleteSelectionOrOpenLinkAtMouseCursor`). Vorher öffnete nur `Strg+Klick`, der Plain-Klick verwarf den Link
- **URLs → Browser** — `open-uri` startet den Default-Browser explizit über `rundll32 url.dll,FileProtocolHandler` statt über den WezTerm-Default. Kein Konsolen-Flackern, `&` in Query-Strings bleibt intakt
- **file:line → Editor** — `wsl.exe -e <editor>` fand Windows-Editoren im WSL-PATH nie (execvpe nutzt den init-PATH, nicht den Interop-PATH). Start läuft jetzt über `sh -c`; relative Pfade werden gegen das Pane-CWD aufgelöst, `~/` expandiert

### Added
- **`FILE_LINK_EDITOR`** — Editor-Kommando für `file:line`-Links konfigurierbar (`code`, `antigravity-ide`, `cursor`, …)
- **`Strg+Umschalt+Klick`** — Link öffnen in TUIs mit Maus-Capture (vim, htop)
- **Dark/Light-Theme** — Auto-Detect über die Windows-Systemeinstellung, `F10` Toggle light↔dark, `Shift+F10` Reset auf Auto

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
