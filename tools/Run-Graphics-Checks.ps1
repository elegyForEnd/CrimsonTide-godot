param([string[]]$Tests=@('story_render_upgrade','story_asset_visual','story_visual','camp_visual','camp_modes','combat_visual','boss_all_states_visual','roguelike_visual','roguelike_vfx_visual'))
$ErrorActionPreference='Stop'
$checkRoot=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $checkRoot '.testappdata'
$checkExe=Join-Path $checkRoot 'Godot_v4.7.2-stable_win64_console.exe'
foreach($testName in $Tests){
    $outLog=Join-Path $checkRoot "output/graphics-$testName.log"
    $errLog=Join-Path $checkRoot "output/graphics-$testName.err"
    $checkProcess=Start-Process -FilePath $checkExe -WorkingDirectory $checkRoot -ArgumentList @('--path','.', '--script',"tests/$testName.gd") -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    if(-not $checkProcess.WaitForExit(180000)){ throw "Graphics check timeout: $testName" }
    $checkProcess.Refresh()
    $errors=Get-Content -LiteralPath $errLog -Raw
    if($checkProcess.ExitCode -ne 0 -or $errors -match 'SCRIPT ERROR|ERROR:'){ throw "Graphics check failed: $testName ($errLog)" }
    Write-Output "PASSED $testName"
}
