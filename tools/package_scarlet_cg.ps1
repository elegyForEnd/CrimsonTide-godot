param(
    [string]$ResultsPath = "art/story-cg-scarlet/generation-results.json"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$resultFile = Join-Path $projectRoot $ResultsPath
$promptFile = Join-Path $projectRoot "art/story-cg-scarlet/prompts.json"
$outputRoot = Join-Path $projectRoot "assets/story/cg-scarlet-v1"
$masterRoot = Join-Path $projectRoot "art/story-cg-scarlet/masters"
$previewRoot = Join-Path $outputRoot "previews"
New-Item -ItemType Directory -Path $outputRoot,$masterRoot,$previewRoot -Force | Out-Null
$generation = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json
$promptSet = Get-Content -LiteralPath $promptFile -Raw -Encoding UTF8 | ConvertFrom-Json
$entries = @()

function Write-ScaledPng {
    param([System.Drawing.Image]$InputImage,[string]$Destination,[int]$Width,[int]$Height)
    $bitmap = New-Object System.Drawing.Bitmap($Width,$Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(255,10,13,22))
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes = New-Object System.Drawing.Imaging.ImageAttributes
        try {
            $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
            $rectangle = New-Object System.Drawing.Rectangle(0,0,$Width,$Height)
            $graphics.DrawImage($InputImage,$rectangle,0,0,$InputImage.Width,$InputImage.Height,[System.Drawing.GraphicsUnit]::Pixel,$attributes)
        } finally { $attributes.Dispose() }
        $bitmap.Save($Destination,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

foreach ($spec in $promptSet.assets) {
    $result = @($generation.assets | Where-Object { $_.id -eq $spec.id })
    if ($result.Count -ne 1) { throw "Missing or duplicate generated image: $($spec.id)" }
    $sourcePath = [string]$result[0].source
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing image source: $sourcePath" }
    $masterPath = Join-Path $masterRoot "$($spec.id).png"
    $finalPath = Join-Path $outputRoot "$($spec.id).png"
    $previewPath = Join-Path $previewRoot "$($spec.id).png"
    if (Test-Path -LiteralPath $masterPath) {
        if ((Get-FileHash -LiteralPath $masterPath).Hash -ne (Get-FileHash -LiteralPath $sourcePath).Hash) {
            throw "Refusing to overwrite a different saved master: $masterPath"
        }
    } else { Copy-Item -LiteralPath $sourcePath -Destination $masterPath }
    $sourceImage = [System.Drawing.Image]::FromFile($masterPath)
    try {
        $sourceWidth = $sourceImage.Width; $sourceHeight = $sourceImage.Height
        $aspectError = [Math]::Abs(($sourceWidth / [double]$sourceHeight) / (16.0 / 9.0) - 1.0)
        if ($aspectError -gt 0.02) { throw "Unexpected aspect ratio for $($spec.id): ${sourceWidth}x${sourceHeight}" }
        $native4k = $sourceWidth -eq 3840 -and $sourceHeight -eq 2160
        if (-not (Test-Path -LiteralPath $finalPath)) {
            if ($native4k) { Copy-Item -LiteralPath $masterPath -Destination $finalPath }
            else { Write-ScaledPng $sourceImage $finalPath 3840 2160 }
        }
        if (-not (Test-Path -LiteralPath $previewPath)) { Write-ScaledPng $sourceImage $previewPath 640 360 }
        $verified = [System.Drawing.Image]::FromFile($finalPath)
        try { if ($verified.Width -ne 3840 -or $verified.Height -ne 2160) { throw "Wrong delivery dimensions: $finalPath" } }
        finally { $verified.Dispose() }
        $entries += [ordered]@{
            id=$spec.id; title=$spec.title; trigger=$spec.trigger
            path="res://assets/story/cg-scarlet-v1/$($spec.id).png"
            source="art/story-cg-scarlet/masters/$($spec.id).png"
            source_size=@($sourceWidth,$sourceHeight); delivery_size=@(3840,2160)
            native_4k=$native4k
            processing=$(if ($native4k) { "native-size copy" } else { "whole image high-quality bicubic resample; no generative detail added" })
            status="generated-flat-illustration"; layers_available=$false
            sha256=(Get-FileHash -LiteralPath $finalPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    } finally { $sourceImage.Dispose() }
}

$movies = @()
foreach ($movieIndex in 0..18) {
    $movieId = "CIN-{0:00}" -f $movieIndex
    $variants = @($movieId)
    if ($movieIndex -eq 6 -or $movieIndex -eq 17) { $variants=@("${movieId}A","${movieId}B") }
    foreach ($variant in $variants) { $movies += [ordered]@{id=$variant;status="reserved";path=$null;autoplay=$false} }
}
$manifest = [ordered]@{
    version=1;story="Scarlet Moon Testament / 赤月遗书";generator="built-in image_gen"
    target_size=@(3840,2160);complete=$true;runtime_integrated=$true
    reference_policy="user supplied assets/feiyue.png, assets/xueli.png, assets/yayu.png; existing queen portrait"
    illustrations=$entries;cinematics=$movies
}
$manifest | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $outputRoot "manifest.json") -Encoding UTF8

$columns=4; $cellWidth=660; $cellHeight=405
$rows=[int][Math]::Ceiling($entries.Count/[double]$columns)
$sheet=New-Object System.Drawing.Bitmap(($columns*$cellWidth),($rows*$cellHeight))
$sheetGraphics=[System.Drawing.Graphics]::FromImage($sheet)
$font=New-Object System.Drawing.Font("Microsoft YaHei",12)
try {
    $sheetGraphics.Clear([System.Drawing.Color]::FromArgb(255,15,19,29))
    for ($index=0; $index -lt $entries.Count; $index++) {
        $entry=$entries[$index]; $column=$index%$columns; $row=[int][Math]::Floor($index/[double]$columns)
        $preview=[System.Drawing.Image]::FromFile((Join-Path $previewRoot "$($entry.id).png"))
        try { $sheetGraphics.DrawImage($preview,($column*$cellWidth+10),($row*$cellHeight+10),640,360) }
        finally { $preview.Dispose() }
        $sheetGraphics.DrawString("$($entry.id)  $($entry.title)",$font,[System.Drawing.Brushes]::White,($column*$cellWidth+12),($row*$cellHeight+375))
    }
    $sheet.Save((Join-Path $outputRoot "contact-sheet.png"),[System.Drawing.Imaging.ImageFormat]::Png)
} finally { $font.Dispose();$sheetGraphics.Dispose();$sheet.Dispose() }

$cards = foreach ($entry in $entries) {
    $safeTitle=[System.Net.WebUtility]::HtmlEncode([string]$entry.title)
    "<a class='card' href='$($entry.id).png'><img loading='lazy' src='previews/$($entry.id).png' alt='$safeTitle'><span>$($entry.id) · $safeTitle</span><small>$($entry.source_size[0])×$($entry.source_size[1]) → 3840×2160</small></a>"
}
$html=@"
<!doctype html><html lang='zh-CN'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>赤月遗书 CG</title><style>body{margin:0;background:#10141e;color:#eee;font:16px 'Microsoft YaHei',sans-serif;padding:32px}h1{font-size:26px}p{color:#aeb8cc;line-height:1.7}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}.card{background:#1c2232;color:inherit;text-decoration:none;border-radius:10px;overflow:hidden}.card img{width:100%;display:block}.card span,.card small{display:block;padding:10px 14px}.card small{color:#9caaca;padding-top:0}</style><h1>赤月遗书 · CG 插画</h1><p>19 张成图 · 3840×2160 PNG。点击查看完整图片。保留生成原图，尺寸不足的成图经整图高质量放大；不是原生 4K 细节。过场动画仅保留空登记。当前为平面插画，尚无人物／表情分层，已接入赤月遗书ADV与鉴赏。</p><main class='grid'>$($cards -join "`n")</main></html>
"@
$html | Set-Content -LiteralPath (Join-Path $outputRoot "gallery.html") -Encoding UTF8
Write-Output "Packaged $($entries.Count) CG illustrations at 3840x2160; $($movies.Count) cinematic entries reserved."
