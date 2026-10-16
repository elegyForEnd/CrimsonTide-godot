param([switch]$AllPoses)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$rpgRoot = Split-Path $PSScriptRoot -Parent
$rpgManifest = Get-Content -LiteralPath (Join-Path $rpgRoot 'assets/story/rpg-enemies-v1/manifest.json') -Encoding UTF8 -Raw | ConvertFrom-Json
$rpgDesign = Get-Content -LiteralPath (Join-Path $rpgRoot 'resources/scarlet/enemies.json') -Encoding UTF8 -Raw | ConvertFrom-Json
$rpgCampaign = Get-Content -LiteralPath (Join-Path $rpgRoot 'resources/scarlet/campaign.json') -Encoding UTF8 -Raw | ConvertFrom-Json
$columns = if($AllPoses) { 2 } else { 4 }
$tileWidth = 1600/$columns
$canvas = [System.Drawing.Bitmap]::new(1600,[int](16/$columns*420))
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.Clear([System.Drawing.Color]::FromArgb(18,23,33))
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = [System.Drawing.Font]::new('Microsoft YaHei',18)
$small = [System.Drawing.Font]::new('Microsoft YaHei',12)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(238,222,198))
$muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(160,182,199))
$card = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(37,43,55))
$index = 0
foreach($entry in $rpgManifest.entries.PSObject.Properties) {
    $key = $entry.Name
    $meta = $entry.Value
    $minion = $rpgDesign.minions.PSObject.Properties[$key]
    $info = if($minion) { $minion.Value } else { $rpgDesign.bosses.PSObject.Properties[$key].Value }
    $label = if($minion) { $info.name } else { $rpgCampaign.bosses.PSObject.Properties[$key].Value.name }
    $role = if($minion) { $info.role } else { $info.arena }
    $x = ($index % $columns)*$tileWidth
    $y = [math]::Floor($index/$columns)*420
    $graphics.FillRectangle($card,$x+6,$y+6,$tileWidth-12,408)
    $poses = if($AllPoses) { $meta.frames } else { @($meta.frames[0]) }
    $poseIndex = 0
    foreach($frame in $poses) {
    $path = if($frame.path) { $frame.path } else { $meta.path }
    $image = [System.Drawing.Image]::FromFile((Join-Path $rpgRoot $path.Replace('res://','')))
    $region = $frame.region
    $slotWidth = $tileWidth/$poses.Count
    $scale = [math]::Min(($slotWidth-35)/$region[2],320/$region[3])
    $w = $region[2]*$scale
    $h = $region[3]*$scale
    $dest = [System.Drawing.RectangleF]::new($x+$slotWidth*($poseIndex+.5)-$w/2,$y+330-$h,$w,$h)
    $pieces = @()
    if($frame.pieces) { $pieces = $frame.pieces } else { $pieces = @(,$region) }
    foreach($piece in $pieces) {
        $sourceRect = [System.Drawing.RectangleF]::new($piece[0],$piece[1],$piece[2],$piece[3])
        $pieceDest = [System.Drawing.RectangleF]::new($dest.X+($piece[0]-$region[0])*$scale,$dest.Y+($piece[1]-$region[1])*$scale,$piece[2]*$scale,$piece[3]*$scale)
        $graphics.DrawImage($image,$pieceDest,$sourceRect,[System.Drawing.GraphicsUnit]::Pixel)
    }
    $image.Dispose()
    $poseIndex++
    }
    $graphics.DrawString($label,$font,$brush,[single]($x+18),[single]($y+344))
    $graphics.DrawString($role,$small,$muted,[single]($x+18),[single]($y+382))
    $index++
}
$name = if($AllPoses) { 'all-poses.png' } else { 'contact-sheet.png' }
$path = Join-Path $rpgRoot ('assets/story/rpg-enemies-v1/'+$name)
$canvas.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose(); $canvas.Dispose(); $font.Dispose(); $small.Dispose(); $brush.Dispose(); $muted.Dispose(); $card.Dispose()
Write-Output $path
