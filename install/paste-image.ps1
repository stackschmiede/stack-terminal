<#
.SYNOPSIS
  TerminalStack — Smart Clipboard-Paste Helper

.DESCRIPTION
  Wird von WezTerms smart_paste-Keybinding (Strg+Umschalt+V) aufgerufen.
  Prueft, ob sich ein Bild in der Windows-Zwischenablage befindet.
  Wenn ja → Bild nach %TEMP%\wezterm-paste-<ts>.png schreiben und WSL-Pfad ausgeben.
  Wenn nein → nichts ausgeben (wezterm faellt auf normalen text-paste zurueck).

.NOTES
  Project: TerminalStack (by Stackschmiede)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
} catch {
  exit 0
}

$img = [System.Windows.Forms.Clipboard]::GetImage()
if (-not $img) {
  exit 0   # kein bild → nichts ausgeben, wezterm nutzt text-paste
}

try {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
  $winPath = Join-Path $env:TEMP ("wezterm-paste-$stamp.png")
  $img.Save($winPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
  $img.Dispose()
}

# Windows-Pfad → WSL-Pfad:  C:\Users\... → /mnt/c/Users/...
$drive = $winPath.Substring(0, 1).ToLower()
$rest  = $winPath.Substring(2).Replace('\', '/')
$wsl   = "/mnt/$drive$rest"

Write-Output $wsl
