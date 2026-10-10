param([int[]]$Acts=@(1,2,3,4,5,6),[switch]$DungeonsOnly,[switch]$OutdoorsOnly,[switch]$CampsOnly)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$engine=Join-Path $projectRoot 'Godot_v4.7.2-stable_win64_console.exe'
$paths=@();foreach($act in $Acts){foreach($stage in $(if($CampsOnly){@(0)}else{1..$(if($act -eq 1){9}else{8})})){
    $name=if($act -eq 1){"opening-$stage"}else{"act$act-$stage"}
    if($DungeonsOnly){
        $plans=Get-Content -LiteralPath (Join-Path $projectRoot 'resources/story-exploration.json') -Raw | ConvertFrom-Json
        if("$($act):$stage" -notin $plans.dungeons.PSObject.Properties.Name){continue}
    }
    if($OutdoorsOnly){
        if($DungeonsOnly){throw 'Choose OutdoorsOnly or DungeonsOnly.'}
        $plans=Get-Content -LiteralPath (Join-Path $projectRoot 'resources/story-exploration.json') -Raw | ConvertFrom-Json
        if("$($act):$stage" -notin $plans.outdoor.PSObject.Properties.Name){continue}
    }
    $paths+="res://scenes/story/$name.tscn"
}}
$mutex=[Threading.Mutex]::new($false,'Local\CrimsonTideOpeningBake')
try{$locked=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$locked=$true}
if(-not $locked){throw 'Another scene bake is running.'}
$out=Join-Path $projectRoot 'output/exploration-bake.log';$err=Join-Path $projectRoot 'output/exploration-bake.err';$process=$null
$layoutPath=Join-Path $projectRoot '.godot/editor/editor_layout.cfg'
$layoutBytes=$null
try{
    if(Test-Path -LiteralPath $layoutPath){
        $layoutBytes=[IO.File]::ReadAllBytes($layoutPath)
        $layoutText=[Text.Encoding]::UTF8.GetString($layoutBytes)
        $layoutText=[regex]::Replace($layoutText,'(?m)^open_scenes=.*$',('open_scenes=PackedStringArray("'+$paths[0]+'")'))
        $layoutText=[regex]::Replace($layoutText,'(?m)^current_scene=.*$',('current_scene="'+$paths[0]+'"'))
        [IO.File]::WriteAllText($layoutPath,$layoutText,[Text.UTF8Encoding]::new($false))
    }
    $process=Start-Process -FilePath $engine -WorkingDirectory $projectRoot -ArgumentList @('--editor','--single-window','--path','.',($paths[0] -replace '^res://',''),'--','--bake-opening',('--bake-list='+($paths -join ','))) -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
    $lastCount=-1;$lastProgress=Get-Date
    while(-not $process.HasExited){
        Start-Sleep -Seconds 1
        $text=Get-Content -LiteralPath $out -Raw
        $count=([regex]::Matches($text,'BAKE_BATCH complete res://')).Count
        if($count -ne $lastCount){Write-Output "BAKED $count/$($paths.Count)";$lastCount=$count;$lastProgress=Get-Date}
        if($text -match 'BAKE_BATCH all complete'){break}
        if((Get-Content -LiteralPath $err -Raw) -match 'BAKE_BATCH failed|toolbar unavailable'){throw 'Bake failed; inspect exploration-bake.err.'}
        if(((Get-Date)-$lastProgress).TotalSeconds -gt 240){throw 'Bake made no progress for 240 seconds.'}
    }
    foreach($path in $paths){if($text -notmatch [regex]::Escape('BAKE_BATCH complete '+($path -replace '\.tscn$','.lmbake'))){throw "Bake not confirmed $path"}}
}finally{
    if($null -ne $process){
        Get-CimInstance Win32_Process | Where-Object {$_.Name -like 'Godot*' -and $_.CommandLine -like ('*--bake-list='+$paths[0]+'*')} | ForEach-Object {Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue}
    }
    if($null -ne $layoutBytes){[IO.File]::WriteAllBytes($layoutPath,$layoutBytes)}
    $mutex.ReleaseMutex();$mutex.Dispose()
}
& $engine --headless --path $projectRoot --script res://tools/pack_compatibility_scenes.gd
if($LASTEXITCODE -ne 0){throw 'Compatibility packing failed.'}
