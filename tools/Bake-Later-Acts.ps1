param([int[]]$Acts=@(2,3,4,5,6),[int[]]$Stages=@(0,7))
$ErrorActionPreference='Stop'
$rootPath=Split-Path $PSScriptRoot -Parent
$bakeExe=Join-Path $rootPath 'Godot_v4.7.2-stable_win64_console.exe'
$scenePaths=@(); foreach($act in $Acts){foreach($stage in $Stages){
    $relative="scenes/story/act$act-$stage.tscn"
    if(-not (Test-Path -LiteralPath (Join-Path $rootPath $relative))){throw "Missing scene $relative"}
    $scenePaths+="res://$relative"
}}
$mutex=[Threading.Mutex]::new($false,'Local\CrimsonTideOpeningBake')
try{$locked=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$locked=$true}
if(-not $locked){throw 'Another scene bake is running.'}
$log=Join-Path $rootPath 'output/story-later-bake.log'; $err=Join-Path $rootPath 'output/story-later-bake.err'
$process=$null
try{
    $process=Start-Process -FilePath $bakeExe -WorkingDirectory $rootPath -ArgumentList @('--editor','--single-window','--path','.',($scenePaths[0] -replace '^res://',''),'--','--bake-opening',("--bake-list="+($scenePaths -join ','))) -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
    $lastCount=-1; $lastProgress=Get-Date
    while(-not $process.HasExited){
        Start-Sleep -Seconds 1
        $text=Get-Content -LiteralPath $log -Raw
        $count=([regex]::Matches($text,'BAKE_BATCH complete res://')).Count
        if($count -ne $lastCount){Write-Output "BAKED $count/$($scenePaths.Count)"; $lastCount=$count; $lastProgress=Get-Date}
        if($text -match 'BAKE_BATCH all complete'){break}
        if((Get-Content -LiteralPath $err -Raw) -match 'BAKE_BATCH failed|toolbar unavailable'){throw 'Editor bake failed; inspect story-later-bake.err.'}
        if(((Get-Date)-$lastProgress).TotalSeconds -gt 180){throw 'Editor bake made no progress for 180 seconds.'}
    }
    $text=Get-Content -LiteralPath $log -Raw
    foreach($path in $scenePaths){if($text -notmatch [regex]::Escape('BAKE_BATCH complete '+($path -replace '\.tscn$','.lmbake'))){throw "Bake not confirmed $path"}}
}finally{
    if($null -ne $process){
        Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'Godot*' -and $_.CommandLine -like '*--bake-list=*'} | ForEach-Object {Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue}
    }
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
& $bakeExe --headless --path $rootPath --script res://tools/pack_compatibility_scenes.gd
if($LASTEXITCODE -ne 0){throw 'Compatibility packing failed.'}
