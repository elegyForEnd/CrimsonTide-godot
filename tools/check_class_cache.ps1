# Crimson Tide - Godot global class-cache guard.
#
# Godot 4 keeps every "class_name" registration in
# .godot/global_script_class_cache.cfg, and .godot/ is gitignored. When a
# "git pull" adds brand new scripts (ui_art.gd, online_service.gd, ...) the
# local cache goes stale, the main scene script fails to parse with
# "Could not find type ...", and the game shows a BLACK SCREEN right after the
# intro is skipped - the scene node loads, but its script never attaches.
#
# This helper compares the class names declared in the scripts on disk with the
# names registered in the cache and rebuilds the cache when they disagree.
#
# Usage:
#   pwsh -File tools/check_class_cache.ps1 -ProjectPath .            # detect + repair
#   pwsh -File tools/check_class_cache.ps1 -ProjectPath . -CheckOnly # detect only
#
# Exit codes: 0 = cache usable, 1 = cache still stale, 2 = setup problem.

[CmdletBinding()]
param(
    [string]$ProjectPath = ".",
    [string]$GodotExe = "",
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Message) { Write-Host "[setup] $Message" }

function Get-DeclaredClasses([string]$Root) {
    $found = New-Object System.Collections.Generic.List[string]
    $files = Get-ChildItem -Path $Root -Recurse -Filter *.gd -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "[\\/]\.godot[\\/]" }
    foreach ($file in $files) {
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $match = [regex]::Match($line, '^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)')
            if ($match.Success -and -not $found.Contains($match.Groups[1].Value)) {
                $found.Add($match.Groups[1].Value)
            }
        }
    }
    return $found
}

function Get-MissingClasses([string]$CacheFile, $Declared) {
    $missing = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $CacheFile)) {
        foreach ($name in $Declared) { $missing.Add($name) }
        return $missing
    }
    $text = Get-Content -LiteralPath $CacheFile -Raw
    foreach ($name in $Declared) {
        if ($text -notmatch ('"' + [regex]::Escape($name) + '"')) { $missing.Add($name) }
    }
    return $missing
}

$root = (Resolve-Path -LiteralPath $ProjectPath).Path
$cacheFile = Join-Path $root ".godot/global_script_class_cache.cfg"

if (-not (Test-Path -LiteralPath (Join-Path $root "project.godot"))) {
    Write-Host "[error] No project.godot under $root"
    exit 2
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $candidates = @(
        (Join-Path $root "Godot_v4.7.2-stable_win64_console.exe"),
        (Join-Path $root "Godot_v4.7.2-stable_win64.exe")
    )
    $GodotExe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $GodotExe) { $GodotExe = "godot" }
}

$declared = Get-DeclaredClasses $root
$missing = Get-MissingClasses $cacheFile $declared

if ($missing.Count -eq 0) {
    Write-Info "Godot class cache is up to date ($($declared.Count) classes registered)."
    exit 0
}

Write-Info "Stale Godot class cache: $($missing.Count) class(es) missing -> $($missing -join ', ')"
if ($CheckOnly) {
    Write-Host "[setup] -CheckOnly requested, not rebuilding."
    exit 1
}

Write-Info "Rebuilding the cache: $GodotExe --headless --path . --import"
& $GodotExe --headless --path $root --import
Write-Info "Rebuild finished (exit $LASTEXITCODE)."

$stillMissing = Get-MissingClasses $cacheFile $declared
if ($stillMissing.Count -gt 0) {
    Write-Host "[error] Class cache still missing: $($stillMissing -join ', ')"
    Write-Host "[error] Close any running Godot editor for this project and re-run."
    exit 2
}

Write-Info "Class cache rebuilt successfully."
exit 0
