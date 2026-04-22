<#
.SYNOPSIS
  TerminalStack — WezTerm Config Installer (Stackschmiede)

.DESCRIPTION
  Installiert die TerminalStack-Konfiguration für WezTerm auf Windows.
  Fragt nach WSL-Details, substituiert Platzhalter, kopiert Assets,
  sichert bestehende Configs.

.NOTES
  Project : TerminalStack (by Stackschmiede)
  Web     : https://stackschmiede.de
  License : MIT
#>

[CmdletBinding()]
param(
  [string]$WslUsername,
  [string]$WslDistro,
  [string]$ProjectsPath,
  [switch]$NonInteractive,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptRoot
$ConfigSrc  = Join-Path $RepoRoot 'config\wezterm.lua'
$AssetsSrc  = Join-Path $RepoRoot 'config\assets'
$ConfigDst  = Join-Path $env:USERPROFILE '.wezterm.lua'
$AssetsDst  = Join-Path $env:USERPROFILE '.wezterm-assets'

# ─── Brand-UI ────────────────────────────────────────────────────
function Write-Brand {
  $amber = "`e[38;2;212;165;116m"
  $sage  = "`e[38;2;107;142;127m"
  $muted = "`e[38;2;138;134;128m"
  $reset = "`e[0m"
  Write-Host ""
  Write-Host "$amber  ╔═══════════════════════════════════════════════╗$reset"
  Write-Host "$amber  ║$reset  TerminalStack — WezTerm Config                $amber║$reset"
  Write-Host "$amber  ║$reset  $sage by Stackschmiede · stackschmiede.de$reset       $amber║$reset"
  Write-Host "$amber  ╚═══════════════════════════════════════════════╝$reset"
  Write-Host ""
}

function Write-Step($msg)    { Write-Host "  $([char]0x2192) $msg" -ForegroundColor DarkYellow }
function Write-OK($msg)      { Write-Host "  $([char]0x2713) $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "  $([char]0x26A0) $msg" -ForegroundColor Yellow }
function Write-Err($msg)     { Write-Host "  $([char]0x2717) $msg" -ForegroundColor Red }
function Write-Muted($msg)   { Write-Host "  $msg" -ForegroundColor DarkGray }

Write-Brand

# ─── 1. WezTerm check ────────────────────────────────────────────
Write-Step "Pruefe WezTerm-Installation..."
$wezterm = Get-Command wezterm -ErrorAction SilentlyContinue
if (-not $wezterm) {
  Write-Warn "WezTerm nicht im PATH gefunden."
  if (-not $NonInteractive) {
    $install = Read-Host "  WezTerm jetzt via winget installieren? [j/N]"
    if ($install -match '^[jJyY]') {
      Write-Step "winget install wez.wezterm ..."
      winget install --id wez.wezterm --silent --accept-source-agreements --accept-package-agreements
      if ($LASTEXITCODE -ne 0) {
        Write-Err "winget-Installation fehlgeschlagen."
        exit 1
      }
      Write-OK "WezTerm installiert."
    } else {
      Write-Warn "Installation uebersprungen — Config wird trotzdem geschrieben."
    }
  }
} else {
  Write-OK "WezTerm gefunden: $($wezterm.Source)"
}

# ─── 2. WSL-Distro check + defaults ──────────────────────────────
Write-Step "Ermittele WSL-Distributionen..."
$wslRaw = $null
try {
  $wslRaw = (wsl.exe -l -q 2>$null) -replace "`0","" | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() }
} catch {}

if (-not $wslRaw -or $wslRaw.Count -eq 0) {
  Write-Warn "Keine WSL-Distribution gefunden — Default: Ubuntu"
  $wslDistros = @('Ubuntu')
} else {
  $wslDistros = @($wslRaw)
  Write-OK ("Gefunden: {0}" -f ($wslDistros -join ', '))
}

# ─── 3. Eingaben (interaktiv mit defaults) ───────────────────────
if (-not $WslDistro) {
  if ($NonInteractive) { $WslDistro = $wslDistros[0] }
  else {
    $default = $wslDistros[0]
    $in = Read-Host "  WSL-Distribution [$default]"
    $WslDistro = if ([string]::IsNullOrWhiteSpace($in)) { $default } else { $in }
  }
}

if (-not $WslUsername) {
  $defaultUser = ''
  try {
    $defaultUser = (wsl.exe -d $WslDistro -- whoami 2>$null | Out-String).Trim()
  } catch {}
  if ([string]::IsNullOrWhiteSpace($defaultUser)) { $defaultUser = $env:USERNAME.ToLower() }

  if ($NonInteractive) { $WslUsername = $defaultUser }
  else {
    $in = Read-Host "  WSL-Username [$defaultUser]"
    $WslUsername = if ([string]::IsNullOrWhiteSpace($in)) { $defaultUser } else { $in }
  }
}

if (-not $ProjectsPath) {
  $defaultPath = "/home/$WslUsername/projects"
  if ($NonInteractive) { $ProjectsPath = $defaultPath }
  else {
    $in = Read-Host "  Projects-Pfad (WSL) [$defaultPath]"
    $ProjectsPath = if ([string]::IsNullOrWhiteSpace($in)) { $defaultPath } else { $in }
  }
}

Write-Host ""
Write-Muted "Config wird erstellt mit:"
Write-Muted "  Distro   = $WslDistro"
Write-Muted "  Username = $WslUsername"
Write-Muted "  Projects = $ProjectsPath"
Write-Host ""

if (-not $NonInteractive -and -not $Force) {
  $confirm = Read-Host "  Fortfahren? [J/n]"
  if ($confirm -match '^[nN]') { Write-Warn "Abgebrochen."; exit 0 }
}

# ─── 4. Backup bestehender config ────────────────────────────────
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if (Test-Path $ConfigDst) {
  $backup = "$ConfigDst.bak.$timestamp"
  Write-Step "Backup: $backup"
  Copy-Item $ConfigDst $backup -Force
  Write-OK  "Alte .wezterm.lua gesichert."
}

if (Test-Path $AssetsDst) {
  $backup = "$AssetsDst.bak.$timestamp"
  Write-Step "Backup: $backup"
  Copy-Item $AssetsDst $backup -Recurse -Force
  Write-OK  "Alte .wezterm-assets/ gesichert."
}

# ─── 5. Assets kopieren ──────────────────────────────────────────
Write-Step "Kopiere Assets nach $AssetsDst"
New-Item -ItemType Directory -Path $AssetsDst -Force | Out-Null
Copy-Item -Path (Join-Path $AssetsSrc '*') -Destination $AssetsDst -Recurse -Force
Write-OK "Assets installiert."

# ─── 6. Config: Placeholders substituieren + schreiben ───────────
Write-Step "Schreibe .wezterm.lua"
# String.Replace (literal) — nicht -replace (regex), weil Lua-Pfade Backslashes enthalten
$content = Get-Content -Raw -Encoding UTF8 $ConfigSrc
$content = $content.Replace('{{WSL_USERNAME}}',  $WslUsername)
$content = $content.Replace('{{WSL_DISTRO}}',    $WslDistro)
$content = $content.Replace('{{PROJECTS_PATH}}', $ProjectsPath)
# Lua-String im config nutzt '\\' als backslash — hier den Windows-Pfad verdoppeln
$content = $content.Replace('{{ASSETS_PATH}}',   $AssetsDst.Replace('\','\\'))

Set-Content -Path $ConfigDst -Value $content -Encoding UTF8 -NoNewline:$false
Write-OK ".wezterm.lua geschrieben."

# ─── 6b. Paste-Helper (Smart-Paste für Bilder aus der Zwischenablage) ────
$PasteHelperSrc = Join-Path $ScriptRoot 'paste-image.ps1'
$PasteHelperDst = Join-Path $env:USERPROFILE '.wezterm-paste-image.ps1'
if (Test-Path $PasteHelperSrc) {
  Write-Step "Installiere Paste-Helper nach $PasteHelperDst"
  Copy-Item $PasteHelperSrc $PasteHelperDst -Force
  Write-OK "Smart-Paste-Helper installiert."
}

# ─── 7. Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  $([char]0x2605) Installation abgeschlossen." -ForegroundColor Green
Write-Host ""
Write-Muted "Naechste Schritte:"
Write-Muted "  1. WezTerm starten (oder neu starten, falls offen)"
Write-Muted "  2. Tab-Rename: F2 oder Strg+Umschalt+E"
Write-Muted "  3. Shift+Mausrad: seitenweise scrollen"
Write-Muted "  4. Bei Problemen: $ConfigDst.bak.$timestamp wiederherstellen"
Write-Host ""
Write-Host "  stackschmiede.de" -ForegroundColor DarkYellow
Write-Host ""

if (-not $NonInteractive) {
  Read-Host "  [Enter] zum Schliessen"
}
