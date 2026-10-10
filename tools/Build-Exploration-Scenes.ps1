param([int[]]$Acts=@(1,2,3,4,5,6),[switch]$DungeonsOnly,[switch]$OutdoorsOnly)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$engine=Join-Path $projectRoot 'Godot_v4.7.2-stable_win64_console.exe'
foreach($act in $Acts){
    $stages=if($act -eq 1){'1,2,3,4,5,6,7,8,9'}else{'1,2,3,4,5,6,7,8'}
    if($DungeonsOnly){
        $plans=Get-Content -LiteralPath (Join-Path $projectRoot 'resources/story-exploration.json') -Raw | ConvertFrom-Json
        $stages=($plans.dungeons.PSObject.Properties.Name | Where-Object {$_ -like "$($act):*"} | ForEach-Object {($_ -split ':')[1]}) -join ','
    }
    if($OutdoorsOnly){
        if($DungeonsOnly){throw 'Choose OutdoorsOnly or DungeonsOnly.'}
        $plans=Get-Content -LiteralPath (Join-Path $projectRoot 'resources/story-exploration.json') -Raw | ConvertFrom-Json
        $stages=($plans.outdoor.PSObject.Properties.Name | Where-Object {$_ -like "$($act):*"} | ForEach-Object {($_ -split ':')[1]}) -join ','
    }
    # Isolate xatlas' native unwrap state for the larger clipped outdoor meshes.
    $jobs=if($OutdoorsOnly){$stages -split ','}else{@($stages)}
    foreach($jobStages in $jobs){
        & $engine --headless --path $projectRoot --script res://tools/build_story_scenes.gd -- "--act=$act" "--stages=$jobStages" --replace-generated
        if($LASTEXITCODE -ne 0){throw "Authoring failed in act $act stages $jobStages"}
    }
}
