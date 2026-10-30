<#
.SYNOPSIS
  TerminalStack - Claude-Nutzung als Bild fuer den unteren Fensterrand

.DESCRIPTION
  WezTerm hat genau eine Leiste; der Streifen unter dem Terminal ist nur ueber
  background-Layer erreichbar. Die Config (cu_render) schreibt deshalb eine Spec
  und startet dieses Script, das daraus ein transparentes PNG zeichnet.

  Spec (JSON): { w, h, x, font_px, lines: [ [ { c, t, b, p }, ... ], ... ] }
    x = linker Rand im Bild in Pixeln
    c = Farbe '#RRGGBB', t = Text, b = fett, p = Fuellstand 0..1 (Kreis vor dem Text)

  Zeichen liegen auf einem festen Raster, damit Zeilen auch mit Fallback-Glyphen
  fluchten; die Kreise werden gezeichnet statt als Glyph gesetzt.

  Ausgabe: erst <Out>.tmp, dann Rename auf <Out> - die Config wartet auf <Out>.
  Fehler landen in <Spec>.err (Endung getauscht): stderr geht bei
  background_child_process verloren.

.NOTES
  Project: TerminalStack (by Stackschmiede)
  Nur ASCII in dieser Datei: PowerShell 5.1 liest BOM-loses UTF-8 als ANSI.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Spec,
  [Parameter(Mandatory = $true)][string]$Out
)

$ErrorActionPreference = 'Stop'

$LineFactor = 1.35   # Zeilenhoehe relativ zur Fontgroesse
$CapFactor  = 0.70   # Hoehe der Ziffern relativ zur Fontgroesse (Kreis-Zentrierung)
$PieFactor  = 0.72   # Kreis-Durchmesser relativ zur Fontgroesse

$Tmp = "$Out.tmp"
$Err = [System.IO.Path]::ChangeExtension($Spec, '.err')

function Get-MonoFamily {
  $installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object { $_.Name }
  foreach ($name in @('JetBrains Mono', 'Cascadia Mono', 'Consolas')) {
    if ($installed -contains $name) { return $name }
  }
  return [System.Drawing.FontFamily]::GenericMonospace.Name
}

try {
  Add-Type -AssemblyName System.Drawing

  $s = [System.IO.File]::ReadAllText($Spec, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  $lines = $s.lines

  # mehr Zeilen als Platz: Font schrumpfen statt abschneiden
  $px = [math]::Min([double]$s.font_px, [math]::Floor($s.h / ($lines.Count * $LineFactor)))
  $lh = [math]::Ceiling($px * $LineFactor)

  $bmp = New-Object System.Drawing.Bitmap ([int]$s.w), ([int]$s.h), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  # graustufen statt ClearType: subpixel-farbsaeume vertragen sich nicht mit Transparenz
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $family  = Get-MonoFamily
  $regular = New-Object System.Drawing.Font($family, [single]$px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $bold    = New-Object System.Drawing.Font($family, [single]$px, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt     = [System.Drawing.StringFormat]::GenericTypographic

  # ganzzahlige Zellbreite: gleichmaessiger Abstand trotz Einzelzeichen-Positionierung
  $cell = [math]::Ceiling($g.MeasureString('0000000000', $regular, [System.Drawing.PointF]::Empty, $fmt).Width / 10)

  $ff     = $regular.FontFamily
  $ascent = $px * $ff.GetCellAscent([System.Drawing.FontStyle]::Regular) / $ff.GetEmHeight([System.Drawing.FontStyle]::Regular)
  $d      = [math]::Round($px * $PieFactor)
  $stroke = [math]::Max(1.0, $px / 13)

  $x0 = [int]$s.x
  $y = [math]::Max(0, [math]::Floor(($s.h - $lines.Count * $lh) / 2))
  foreach ($line in $lines) {
    $col = 0
    foreach ($r in $line) {
      $color = [System.Drawing.ColorTranslator]::FromHtml($r.c)
      $brush = New-Object System.Drawing.SolidBrush($color)
      if ($null -ne $r.p) {
        $cx = $x0 + $col * $cell + ($cell - $d) / 2
        $cy = $y + $ascent - $px * $CapFactor / 2 - $d / 2
        $pen = New-Object System.Drawing.Pen($color, [single]$stroke)
        $g.DrawEllipse($pen, [single]$cx, [single]$cy, [single]$d, [single]$d)
        if ([double]$r.p -gt 0) {
          $g.FillPie($brush, [single]$cx, [single]$cy, [single]$d, [single]$d, [single]-90, [single](360 * [double]$r.p))
        }
        $col++
      }
      $font = if ($r.b) { $bold } else { $regular }
      foreach ($ch in $r.t.ToCharArray()) {
        if ($ch -ne ' ') {
          $g.DrawString([string]$ch, $font, $brush, [single]($x0 + $col * $cell), [single]$y, $fmt)
        }
        $col++
      }
    }
    $y += $lh
  }

  $bmp.Save($Tmp, [System.Drawing.Imaging.ImageFormat]::Png)
  [System.IO.File]::Delete($Out)
  [System.IO.File]::Move($Tmp, $Out)
} catch {
  Set-Content -LiteralPath $Err -Value ($_ | Out-String) -Encoding UTF8
  [System.IO.File]::Delete($Tmp)
  exit 1
}
