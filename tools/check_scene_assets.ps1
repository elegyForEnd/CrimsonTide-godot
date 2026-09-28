param([switch]$VisualOnly, [switch]$Import)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
Push-Location $projectDirectory
try {
	if ($Import) {
		& '.\Godot_v4.7.2-stable_win64_console.exe' --headless --path $projectDirectory --editor --import *> build/scene-assets-import.log
		if ($LASTEXITCODE -ne 0) { throw 'Asset import failed' }
	}
    $checks = if ($VisualOnly) { @('scene_assets_visual', 'sprite_depth_visual') } else { @('scene_assets', 'world_3d', 'map', 'movement', 'systems', 'scene_assets_visual', 'sprite_depth_visual') }
    foreach ($check in $checks) {
        $arguments = @('--path', $projectDirectory, '--script', "tests/$check.gd", '--quit-after', '900')
        if ($check -notlike '*visual') { $arguments += '--headless' }
        $log = Join-Path $projectDirectory "build/check-$check.log"
        & '.\Godot_v4.7.2-stable_win64_console.exe' @arguments *> $log
        Get-Content -LiteralPath $log -Tail 5
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|SHADER ERROR:|ERROR:' -Quiet)) {
            throw "Validation failed: $check (see $log)"
        }
    }
} finally {
    Pop-Location
}
