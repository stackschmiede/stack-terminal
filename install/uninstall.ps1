<#
.SYNOPSIS
  TerminalStack — Uninstaller / Restore
.DESCRIPTION
  Entfernt installierte Config + Assets. Restauriert aelteste .bak wenn vorhanden.
#>

[CmdletBinding()]
param(
  [switch]$NonInteractive,
  [switch]$KeepBackups
)

$ErrorActionPreference = 'Stop'
$ConfigDst = Join-Path $env:USERPROFILE '.wezterm.lua'
$AssetsDst = Join-Path $env:USERPROFILE '.wezterm-assets'

function Write-Step($m) { Write-Host "  $([char]0x2192) $m" -ForegroundColor DarkYellow }
function Write-OK($m)   { Write-Host "  $([char]0x2713) $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "  $([char]0x26A0) $m" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  TerminalStack — Uninstall" -ForegroundColor DarkYellow
Write-Host ""

if (-not $NonInteractive) {
  $confirm = Read-Host "  WezTerm-Config + Assets entfernen? [j/N]"
  if ($confirm -notmatch '^[jJyY]') { Write-Warn "Abgebrochen."; exit 0 }
}

# Neuestes Backup finden
$cfgBackup = Get-ChildItem -Path $env:USERPROFILE -Filter '.wezterm.lua.bak.*' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (Test-Path $ConfigDst) {
  if ($cfgBackup) {
    Write-Step "Restore: $($cfgBackup.Name) -> .wezterm.lua"
    Copy-Item $cfgBackup.FullName $ConfigDst -Force
    Write-OK "Alte Config wiederhergestellt."
  } else {
    Write-Step "Loesche .wezterm.lua (kein Backup gefunden)"
    Remove-Item $ConfigDst -Force
    Write-OK "Config entfernt."
  }
}

if (Test-Path $AssetsDst) {
  Write-Step "Loesche $AssetsDst"
  Remove-Item $AssetsDst -Recurse -Force
  Write-OK "Assets entfernt."
}

$PasteHelperDst = Join-Path $env:USERPROFILE '.wezterm-paste-image.ps1'
if (Test-Path $PasteHelperDst) {
  Write-Step "Loesche $PasteHelperDst"
  Remove-Item $PasteHelperDst -Force
  Write-OK "Paste-Helper entfernt."
}

if (-not $KeepBackups) {
  if (-not $NonInteractive) {
    $clean = Read-Host "  Auch alle .bak-Dateien loeschen? [j/N]"
    if ($clean -match '^[jJyY]') {
      Get-ChildItem -Path $env:USERPROFILE -Filter '.wezterm.lua.bak.*' -ErrorAction SilentlyContinue | Remove-Item -Force
      Get-ChildItem -Path $env:USERPROFILE -Filter '.wezterm-assets.bak.*' -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
      Write-OK "Backups geloescht."
    }
  }
}

Write-Host ""
Write-Host "  $([char]0x2605) Uninstall fertig." -ForegroundColor Green
Write-Host ""
