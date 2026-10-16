param([string]$ResultsPath='art/story-cg-crown-v2/generation-results.json')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$project=Split-Path -Parent $PSScriptRoot
$author=Join-Path $project 'art/story-cg-crown-v2'
$delivery=Join-Path $project 'assets/story/cg-scarlet-v2'
$masters=Join-Path $author 'masters'
$previews=Join-Path $delivery 'previews'
New-Item -ItemType Directory -Force -Path $masters,$delivery,$previews | Out-Null
$results=Get-Content -LiteralPath (Join-Path $project $ResultsPath) -Raw -Encoding UTF8 | ConvertFrom-Json
$prompts=Get-Content -LiteralPath (Join-Path $author 'prompts.json') -Raw -Encoding UTF8 | ConvertFrom-Json
function Scale-WholeImage([System.Drawing.Image]$image,[string]$path,[int]$width,[int]$height) {
    $bitmap=[System.Drawing.Bitmap]::new($width,$height)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $attributes=[System.Drawing.Imaging.ImageAttributes]::new()
    try {
        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.CompositingQuality=[System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $graphics.DrawImage($image,[System.Drawing.Rectangle]::new(0,0,$width,$height),0,0,$image.Width,$image.Height,[System.Drawing.GraphicsUnit]::Pixel,$attributes)
        $bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $attributes.Dispose(); $graphics.Dispose(); $bitmap.Dispose() }
}
$entries=@()
foreach($spec in $prompts.assets) {
    $match=@($results.assets | Where-Object {$_.id -eq $spec.id})
    if($match.Count -ne 1){throw "Missing or duplicate CG: $($spec.id)"}
    $source=[string]$match[0].source
    if(-not(Test-Path -LiteralPath $source)){throw "Missing generated image: $source"}
    $master=Join-Path $masters ($spec.id+'.png')
    if(Test-Path -LiteralPath $master){
        if((Get-FileHash -LiteralPath $master).Hash -ne (Get-FileHash -LiteralPath $source).Hash){throw "Existing master differs: $master"}
    }else{Copy-Item -LiteralPath $source -Destination $master}
    $image=[System.Drawing.Image]::FromFile($master)
    try {
        $width=$image.Width; $height=$image.Height
        if([Math]::Abs(($width/[double]$height)/(16.0/9)-1) -gt .02){throw "Unexpected frame ratio: $($spec.id) ${width}x${height}"}
        $final=Join-Path $delivery ($spec.id+'.png')
        if(-not(Test-Path -LiteralPath $final)){Scale-WholeImage $image $final 3840 2160}
        $preview=Join-Path $previews ($spec.id+'.png')
        if(-not(Test-Path -LiteralPath $preview)){Scale-WholeImage $image $preview 640 360}
        $verified=[System.Drawing.Image]::FromFile($final)
        try {if($verified.Width -ne 3840 -or $verified.Height -ne 2160){throw "Wrong 4K delivery size: $final"}}
        finally {$verified.Dispose()}
        $entries+= [ordered]@{id=$spec.id;title=$spec.title;scenes=@($spec.scenes);path="res://assets/story/cg-scarlet-v2/$($spec.id).png";source="art/story-cg-crown-v2/masters/$($spec.id).png";source_size=@($width,$height);delivery_size=@(3840,2160);native_4k=($width -eq 3840 -and $height -eq 2160);processing='whole-image high-quality bicubic resampling; no generative detail added';status='generated-flat-illustration';layers_available=$false;sha256=(Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash.ToLowerInvariant()}
    } finally {$image.Dispose()}
}
$manifest=[ordered]@{version=2;story='Scarlet / Crown and City';generator='built-in image_gen';target_size=@(3840,2160);illustrations=$entries;cinematics='all 24 runtime paths remain null';complete=$true;runtime_integrated=$true}
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $delivery 'manifest.json') -Encoding UTF8
$sheet=[System.Drawing.Bitmap]::new(1320,1620)
$graphics=[System.Drawing.Graphics]::FromImage($sheet)
$font=[System.Drawing.Font]::new('Microsoft YaHei',12)
try {
    $graphics.Clear([System.Drawing.Color]::FromArgb(255,16,19,29))
    for($index=0;$index -lt $entries.Count;$index++){
        $entry=$entries[$index];$column=$index%2;$row=[int][Math]::Floor($index/2)
        $preview=[System.Drawing.Image]::FromFile((Join-Path $previews ($entry.id+'.png')))
        try {$graphics.DrawImage($preview,10+$column*660,10+$row*405,640,360)} finally {$preview.Dispose()}
        $graphics.DrawString("$($entry.id)  $($entry.title)",$font,[System.Drawing.Brushes]::White,12+$column*660,375+$row*405)
    }
    $sheet.Save((Join-Path $delivery 'contact-sheet.png'),[System.Drawing.Imaging.ImageFormat]::Png)
} finally {$font.Dispose();$graphics.Dispose();$sheet.Dispose()}
$cards=foreach($entry in $entries){
    $title=[System.Net.WebUtility]::HtmlEncode($entry.title)
    "<a href='$($entry.id).png'><img src='previews/$($entry.id).png' alt='$title'><b>$($entry.id) · $title</b><small>$($entry.source_size[0])×$($entry.source_size[1]) → 3840×2160</small></a>"
}
$html="<!doctype html><html lang='zh-CN'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>王冠与空城 · 新CG</title><style>body{background:#10131d;color:#eee;font:16px 'Microsoft YaHei',sans-serif;margin:32px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}a{color:inherit;text-decoration:none;background:#202533;border-radius:8px;overflow:hidden}img{width:100%;display:block}b,small{display:block;padding:10px 14px}p,small{color:#b5bfd0;line-height:1.7}</style><h1>王冠与空城 · 7 张新增 CG</h1><p>内置 image_gen 制作。3840×2160 PNG 交付，保留生成原图；不足4K的原图经整图重采样，不称原生4K。静态插画已绑定剧情，所有动画继续留空。点击图片查看完整版。</p><main>$($cards -join "`n")</main></html>"
$html | Set-Content -LiteralPath (Join-Path $delivery 'gallery.html') -Encoding UTF8
Write-Output "Packaged $($entries.Count) new CGs. All animation slots remain empty."
