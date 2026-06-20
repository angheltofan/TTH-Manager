# bake_multires_ico.ps1
#
# Builds a TRUE multi-resolution `windows/runner/resources/app_icon.ico`
# from `assets/branding/tth_icon_windows.png`.
#
# Why this exists:
#   `flutter_launcher_icons` emits only a SINGLE 256-px PNG-in-ICO. Windows
#   then has to downscale that one bitmap to 16 / 24 / 32 / 48-px for the
#   title bar, taskbar, tray and Alt+Tab — which looks blurry. Embedding
#   hand-rendered tiers at every common Windows icon size keeps the icon
#   crisp at every UI surface.
#
# Run it AFTER every `dart run flutter_launcher_icons` so the change isn't
# clobbered.  Idempotent — safe to re-run.

Add-Type -AssemblyName System.Drawing

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$srcPng   = Join-Path $repoRoot 'assets\branding\tth_icon_windows.png'
$dstIco   = Join-Path $repoRoot 'windows\runner\resources\app_icon.ico'
$sizes    = @(16, 24, 32, 48, 64, 128, 256)

if (-not (Test-Path $srcPng)) {
    throw "Source PNG not found: $srcPng"
}

$src = [System.Drawing.Image]::FromFile($srcPng)
$pngBuffers = @()
foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($src, 0, 0, $s, $s)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $pngBuffers += ,@($ms.ToArray())
    $ms.Dispose()
}
$src.Dispose()

# ICONDIR (6 bytes) + ICONDIRENTRY (16 bytes) * N + image payloads.
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$sizes.Count)

$dataOffset = 6 + ($sizes.Count * 16)
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $bytes = $pngBuffers[$i]
    $w = if ($s -ge 256) { 0 } else { $s }  # ICO spec: 0 means 256
    $bw.Write([Byte]$w)
    $bw.Write([Byte]$w)
    $bw.Write([Byte]0)
    $bw.Write([Byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$bytes.Length)
    $bw.Write([UInt32]$dataOffset)
    $dataOffset += $bytes.Length
}
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $bytes = $pngBuffers[$i]
    $bw.Write($bytes, 0, $bytes.Length)
}

[System.IO.File]::WriteAllBytes($dstIco, $ms.ToArray())
$bw.Dispose(); $ms.Dispose()

Write-Output ("baked {0} ({1} bytes, {2} sizes: {3})" -f $dstIco, (Get-Item $dstIco).Length, $sizes.Count, ($sizes -join ', '))
