$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = Split-Path -Parent $PSScriptRoot
function Save-ScaledArt([string]$inputPath, [string]$outputPath, [int]$width, [int]$height) {
    $sourceImage = [System.Drawing.Image]::FromFile($inputPath)
    $targetImage = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($targetImage)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($sourceImage, 0, 0, $width, $height)
    $graphics.Dispose(); $sourceImage.Dispose()
    $targetImage.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $targetImage.Dispose()
}
$records = @()
foreach ($category in @('bg','npc')) {
    $sourceFolder = Join-Path $taskRoot ('art/scarlet-' + $(if ($category -eq 'bg') {'backgrounds'} else {'npc'}) + '/masters')
    New-Item -ItemType Directory -Force -Path $sourceFolder | Out-Null
    foreach ($asset in Get-ChildItem -LiteralPath (Join-Path $taskRoot "assets/story/scarlet/$category") -Filter '*.png') {
        $master = Join-Path $sourceFolder $asset.Name
        if (-not (Test-Path -LiteralPath $master)) { Copy-Item -LiteralPath $asset.FullName -Destination $master }
        $original = [System.Drawing.Image]::FromFile($master)
        $sourceSize = @($original.Width,$original.Height)
        $targetWidth = if ($category -eq 'bg') {3840} else {[int][Math]::Round(3840.0 * $original.Width / $original.Height)}
        $targetHeight = if ($category -eq 'bg') {2160} else {3840}
        $original.Dispose()
        Save-ScaledArt $master $asset.FullName $targetWidth $targetHeight
        $records += @{id=$asset.BaseName;category=$category;source_size=$sourceSize;delivery_size=@($targetWidth,$targetHeight);native_4k=$false;source=$master;path=$asset.FullName;processing='whole-image high quality bicubic resample, alpha preserved';sha256=(Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash.ToLower()}
    }
}
@{generator='built-in image_gen';assets=$records} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskRoot 'assets/story/scarlet/art-manifest.json') -Encoding utf8
Write-Output "Packaged $($records.Count) Scarlet assets; original masters preserved; delivery is resampled, not native 4K."
