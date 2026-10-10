param([int[]]$Stages = @(0,1,7))
$ErrorActionPreference='Stop'
$bakeMutex=[Threading.Mutex]::new($false,'Local\CrimsonTideOpeningBake')
try { $hasBakeLock=$bakeMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $hasBakeLock=$true }
if(-not $hasBakeLock){ throw 'Another opening bake is running. Wait for it to finish.' }
$sceneRoot=Split-Path $PSScriptRoot -Parent
$bakeExe=Join-Path $sceneRoot 'Godot_v4.7.2-stable_win64_console.exe'
try {
foreach($stage in $Stages){
    $scenePath="res://scenes/story/opening-$stage.tscn"
    if(-not (Test-Path -LiteralPath (Join-Path $sceneRoot "scenes/story/opening-$stage.tscn"))){ throw "Bake scene does not exist: $scenePath. Pass -Stages @(0,1,7,9)." }
    $outLog=Join-Path $sceneRoot "output/bake-final-$stage.log"
    $errLog=Join-Path $sceneRoot "output/bake-final-$stage.err"
    $bakeProcess=Start-Process -FilePath $bakeExe -WorkingDirectory $sceneRoot -ArgumentList @('--editor','--single-window','--path','.',"scenes/story/opening-$stage.tscn",'--','--bake-opening',"--bake-scene=$scenePath") -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    $timer=[Diagnostics.Stopwatch]::StartNew()
    try {
        while($timer.Elapsed.TotalSeconds -lt 180){
            Start-Sleep -Seconds 1
            $bakeText=Get-Content -LiteralPath $outLog -Raw
            if($bakeText -match 'BAKE_BATCH complete'){ break }
            $bakeErrors=Get-Content -LiteralPath $errLog -Raw
            if($bakeErrors -match 'BAKE_BATCH failed|toolbar unavailable'){ throw "Baking failed: $errLog" }
        }
        if($bakeText -notmatch 'BAKE_BATCH complete'){ throw "Bake timeout: $scenePath" }
        Write-Output "BAKED $stage in $([math]::Round($timer.Elapsed.TotalSeconds,1))s"
    } finally {
        Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'Godot*' -and $_.CommandLine -like "*--bake-scene=$scenePath*"} | ForEach-Object {Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue}
    }
}
& $bakeExe --headless --path $sceneRoot --script res://tools/pack_compatibility_scenes.gd
if($LASTEXITCODE -ne 0){ throw 'Compatibility cache packing failed.' }
} finally {
$bakeMutex.ReleaseMutex()
$bakeMutex.Dispose()
}
