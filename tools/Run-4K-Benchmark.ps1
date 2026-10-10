param([int]$Duration=600,[int]$Runs=3)
$ErrorActionPreference='Stop'
$benchmarkRoot=Split-Path $PSScriptRoot -Parent
$env:APPDATA=Join-Path $benchmarkRoot '.testappdata'
$exe=Join-Path $benchmarkRoot 'Godot_v4.7.2-stable_win64_console.exe'
$benchmark=Start-Process -FilePath $exe -WorkingDirectory $benchmarkRoot -ArgumentList @('--path','.', '--script','tests/story_4k_benchmark.gd','--','--benchmark',"--duration=$Duration","--runs=$Runs") -WindowStyle Hidden -RedirectStandardOutput (Join-Path $benchmarkRoot 'output/benchmark-full.log') -RedirectStandardError (Join-Path $benchmarkRoot 'output/benchmark-full.err') -PassThru
$gpuMonitor=Start-Process -FilePath 'python' -WorkingDirectory $benchmarkRoot -ArgumentList @('tools/monitor_story_gpu.py',($Duration*$Runs*2+180)) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $benchmarkRoot 'output/benchmark-gpu.log') -RedirectStandardError (Join-Path $benchmarkRoot 'output/benchmark-gpu.err') -PassThru
Write-Output "BENCHMARK_PID=$($benchmark.Id) GPU_MONITOR_PID=$($gpuMonitor.Id)"
$benchmark.WaitForExit()
$benchmark.Refresh()
if($benchmark.ExitCode -ne 0){throw 'Benchmark failed; inspect output/benchmark-full.err'}
Write-Output 'FULL_BENCHMARK_COMPLETE'
