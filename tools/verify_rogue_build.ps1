[CmdletBinding()]
param([string]$GodotExe = "")
$ErrorActionPreference = "Stop"
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotExe) {
    $taskCandidate = Join-Path $env:LOCALAPPDATA 'Temp\crimson-godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $taskCandidate) { $GodotExe = $taskCandidate }
    else { $taskCommand = Get-Command godot -ErrorAction SilentlyContinue; if ($taskCommand) { $GodotExe = $taskCommand.Source } }
}
if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe)) { throw 'Pass -GodotExe with an installed Godot 4.7 executable.' }
foreach ($taskTest in @('attributes','systems','rogue_build_system','rogue_build_rules','rogue_build_progression','rogue_build_growth')) {
    $taskLog = Join-Path $taskProjectRoot "output/verify-$taskTest.log"
    & $GodotExe --headless --path $taskProjectRoot --script "tests/$taskTest.gd" --quit-after 600 --log-file $taskLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $taskLog -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet)) { throw "Failed: $taskTest (see $taskLog)" }
}
Write-Output 'Campaign regression and all new build rule/progression checks passed.'
