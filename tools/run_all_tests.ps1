# Batch-run the Godot test suite.
# Rule tests run with --headless; visual tests need a real window because
# --script boots a full SceneTree (which ignores --headless for display init).
#
# Every run is bounded twice, so a hang can never stall the batch:
#   1) --quit-after <frames> - clean engine-side exit. A --script boot keeps
#      iterating the main loop after the test body returns, and after a runtime
#      error that aborts the body before quit() is reached. An idle loop then
#      runs forever (this is exactly what tests/rogue_build_rules.gd does).
#      Measured idle throughput in this project: ~120 frames/s headless,
#      ~60 frames/s windowed (vsync). The cap is derived from the wall budget
#      times a safety margin, so it never truncates a test that already fits its
#      budget, while an endless idle loop still ends in a finite, inspectable
#      exit.
#   2) wall-clock kill - hard backstop at budget + 10s.
#
# A run whose output has no "<n> checks, <n> failures" summary line is recorded
# as NO-SUMMARY instead of quietly looking green.
[CmdletBinding()]
param(
    [int]$TimeoutSec = 60,
    [int]$HeadlessFps = 120,
    [int]$WindowFps = 60,
    [double]$FrameCapMargin = 2.0,
    [string]$Filter = ""
)
$ErrorActionPreference = "Continue"

$exe = Join-Path (Get-Location).Path "Godot_v4.7.2-stable_win64_console.exe"
$out = "build\exp-report-runs.txt"
New-Item -ItemType Directory -Force -Path build | Out-Null
"" | Set-Content $out

$scripts = Get-ChildItem tests -File -Filter *.gd | Sort-Object Name
if ($Filter) { $scripts = @($scripts | Where-Object { $_.BaseName -like $Filter }) }

$bad = 0
foreach ($s in $scripts) {
    $rel = "tests/" + $s.Name
    $visual = ($s.BaseName -like '*_visual') -or ($s.BaseName -eq 'ui') -or ($s.BaseName -eq 'hybrid_vfx_preview')
    $log = "build\run-" + $s.BaseName + ".log"
    $fps = if ($visual) { $WindowFps } else { $HeadlessFps }
    $frameCap = [int]($TimeoutSec * $fps * $FrameCapMargin)
    $wallMs = ($TimeoutSec + 10) * 1000

    $gargs = @()
    if (-not $visual) { $gargs += "--headless" }
    $gargs += @("--path", ".", "--script", $rel, "--quit-after", "$frameCap")

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = $null
    try {
        $proc = Start-Process -FilePath $exe -ArgumentList $gargs -NoNewWindow -PassThru `
            -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
    } catch {
        Add-Content $out ("{0}`tSTART_FAILED`t0s`t{1}`t{2}" -f $s.BaseName, $_.Exception.Message, $log)
        Write-Host ("DONE {0} START_FAILED {1}" -f $s.BaseName, $_.Exception.Message)
        $bad++
        continue
    }

    $done = $proc.WaitForExit($wallMs)
    if ($done) {
        # NOTE: on this host Start-Process -PassThru never surfaces ExitCode
        # (verified: empty for both headless and windowed Godot runs), so the
        # verdict is driven by the summary line, the runtime-error count and the
        # timeout state instead of a bare exit code.
        $status = "exited"
    } else {
        try { $proc.Kill() } catch { }
        $status = "TIMEOUT(>${TimeoutSec}s)"
    }
    $sw.Stop()
    $raw = if (Test-Path $log) { Get-Content $log -Raw } else { "" }
    $errRaw = if (Test-Path ($log + ".err")) { Get-Content ($log + ".err") -Raw } else { "" }
    $combined = "$raw`n$errRaw"
    $errCount = ([regex]::Matches($combined, '(?m)^\s*(SCRIPT ERROR|ERROR|Parse Error|SHADER ERROR|COMPILATION ERROR)|Compilation failed')).Count

    $sum = [regex]::Match($combined, '(\d+)\s+checks?[^\d\r\n]*?(\d+)\s+failures?')
    if ($sum.Success) {
        $line = "checks=$($sum.Groups[1].Value) failures=$($sum.Groups[2].Value) errLines=$errCount"
        if ([int]$sum.Groups[2].Value -gt 0) { $bad++ }
    } else {
        $line = ($combined -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
        if (-not $line) { $line = "(no output)" }
        $line = "NO-SUMMARY errLines=$errCount | last: " + ($line -replace "`r", "").Trim()
        $bad++
    }
    Add-Content $out ("{0}`t{1}`t{2}s`t{3}`t{4}" -f $s.BaseName, $line, [math]::Round($sw.Elapsed.TotalSeconds, 1), $status, $log)
    Write-Host ("DONE {0} {1} {2}" -f $s.BaseName, $status, $line)
}
Write-Host "ALL FINISHED ($bad run(s) flagged: failures > 0, missing summary line, or start failure)"
