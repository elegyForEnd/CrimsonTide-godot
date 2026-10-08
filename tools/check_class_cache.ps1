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
# It also guards a second, nastier failure mode: DUPLICATE class_name
# declarations. Verification rounds used to drop HEAD snapshots such as
# build/triage/head-session.gd or build/r0-verify/combat_visuals.HEAD.gd into
# gitignored scratch dirs. Those copies still declared
# "class_name TideSession" / "CombatVisuals", so a cache rebuild happily
# registered the COPY, the real scripts/ implementation was silently shadowed,
# and every newly wired feature looked broken at runtime. Rebuilding cannot
# resolve a duplicate - it just picks a winner - so this script now refuses to
# rebuild while duplicates exist and reports exactly which paths are fighting
# over a name.
#
# Usage:
#   pwsh -File tools/check_class_cache.ps1 -ProjectPath .            # detect + repair
#   pwsh -File tools/check_class_cache.ps1 -ProjectPath . -CheckOnly # detect only
#   pwsh -File tools/check_class_cache.ps1 -ProjectPath . -ImportResources # also import changed art
#
# Exit codes: 0 = cache usable, 1 = duplicate/shadowing or cache still stale, 2 = setup problem.

[CmdletBinding()]
param(
    [string]$ProjectPath = ".",
    [string]$GodotExe = "",
    [switch]$CheckOnly,
    [switch]$ImportResources
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Message) { Write-Host "[setup] $Message" }
function Write-Warn([string]$Message) { Write-Host "[warn] $Message" }
function Write-Err([string]$Message) { Write-Host "[error] $Message" }

function Get-ClassClaims([string]$Root) {
    # name -> list of project-relative script paths that declare it.
    # Scans EVERY *.gd under the project, gitignored scratch dirs included:
    # that is exactly where the shadowing copies came from.
    $claims = @{}
    $files = Get-ChildItem -Path $Root -Recurse -Filter *.gd -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "[\\/]\.godot[\\/]" }
    foreach ($file in $files) {
        $rel = $file.FullName.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName)) {
            $match = [regex]::Match($line, '^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)')
            if ($match.Success) {
                $name = $match.Groups[1].Value
                if (-not $claims.ContainsKey($name)) {
                    $claims[$name] = New-Object System.Collections.Generic.List[string]
                }
                if (-not $claims[$name].Contains($rel)) { $claims[$name].Add($rel) }
            }
        }
    }
    return $claims
}

function Get-DeclaredClasses([string]$Root) {
    $claims = Get-ClassClaims $Root
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($name in ($claims.Keys | Sort-Object)) { $found.Add($name) }
    return $found
}

function Get-CacheEntries([string]$CacheFile) {
    # Returns objects with Class + Path for every registration in the cache.
    $entries = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $CacheFile)) { return $entries }
    $text = Get-Content -LiteralPath $CacheFile -Raw
    foreach ($block in [regex]::Matches($text, '(?s)\{[^{}]*\}')) {
        $classMatch = [regex]::Match($block.Value, '"class"\s*:\s*"([^"]+)"')
        $pathMatch = [regex]::Match($block.Value, '"path"\s*:\s*"([^"]+)"')
        if ($classMatch.Success -and $pathMatch.Success) {
            $entries.Add([pscustomobject]@{
                Class = $classMatch.Groups[1].Value
                Path  = $pathMatch.Groups[1].Value
            })
        }
    }
    return $entries
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
    Write-Err "No project.godot under $root"
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

# --- 1. duplicate class_name declarations ---------------------------------
$claims = Get-ClassClaims $root
$dupes = @($claims.Keys | Where-Object { $claims[$_].Count -gt 1 } | Sort-Object)

if ($dupes.Count -gt 0) {
    Write-Err "$($dupes.Count) class name(s) are declared by more than one script:"
    foreach ($name in $dupes) {
        Write-Host ("  {0}:" -f $name)
        foreach ($path in $claims[$name]) { Write-Host ("      {0}" -f $path) }
    }
    Write-Err "A rebuild cannot fix this - Godot would register whichever copy it loads first,"
    Write-Err "silently shadowing the others. Delete or rename the copies (scratch/HEAD snapshots"
    Write-Err "under build/ or output/ are the usual suspects) and run this script again."
    exit 1
}

# --- 2. cache entries that do not point at res://scripts/ ------------------
$cacheEntries = Get-CacheEntries $cacheFile
$outside = @($cacheEntries | Where-Object { $_.Path -notlike 'res://scripts/*' })
$shadowing = @($outside | Where-Object { $claims.ContainsKey($_.Class) })

if ($shadowing.Count -gt 0) {
    Write-Err "$($shadowing.Count) registered class(es) are backed by a script outside res://scripts/:"
    foreach ($entry in $shadowing) {
        Write-Host ("  {0} -> {1}" -f $entry.Class, $entry.Path)
        foreach ($path in $claims[$entry.Class]) { Write-Host ("      declared by {0}" -f $path) }
    }
    Write-Err "This is the shadowing signature: the cache is serving a script that is not the real"
    Write-Err "implementation. Delete the stray copy and rebuild the cache."
    exit 1
}

if ($outside.Count -gt 0) {
    Write-Warn "$($outside.Count) cache entr(ies) live outside res://scripts/ (informational):"
    foreach ($entry in $outside) { Write-Host ("  {0} -> {1}" -f $entry.Class, $entry.Path) }
}

# --- 3. stale cache (missing registrations) -------------------------------
$declared = Get-DeclaredClasses $root
$missing = Get-MissingClasses $cacheFile $declared

if ($missing.Count -eq 0 -and (-not $ImportResources -or $CheckOnly)) {
    Write-Info "Godot class cache is up to date ($($declared.Count) classes registered)."
    exit 0
}

if ($missing.Count -gt 0) {
    Write-Info "Stale Godot class cache: $($missing.Count) class(es) missing -> $($missing -join ', ')"
}
if ($CheckOnly) {
    Write-Host "[setup] -CheckOnly requested, not rebuilding."
    exit 1
}

Write-Info "Importing changed resources and rebuilding classes before launch."
& $GodotExe --headless --path $root --editor --import
if ($LASTEXITCODE -ne 0) {
    Write-Err "Godot resource import failed (exit $LASTEXITCODE)."
    exit 2
}
Write-Info "Rebuild finished (exit $LASTEXITCODE)."

$stillMissing = Get-MissingClasses $cacheFile $declared
if ($stillMissing.Count -gt 0) {
    Write-Err "Class cache still missing: $($stillMissing -join ', ')"
    Write-Err "Close any running Godot editor for this project and re-run."
    exit 2
}

Write-Info "Class cache rebuilt successfully."
exit 0
