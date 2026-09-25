# install.ps1 - drop the layered-memory template into place.
#
#   .\install.ps1 -DshHome "$env:DSH_HOME" -ProjectRoot D:\myproject
#   (dry run by default; add -Apply to write)
#
# SAFETY: this never overwrites an existing AGENTS.md. Existing memory is the
# user's accumulated knowledge - if the file is already there the script stops
# and tells you, rather than clobbering it. Use -Force to back up and replace.
param(
    [string]$DshHome = $(if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $HOME '.dsh' }),
    [string]$ProjectRoot,
    [switch]$Force,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$Src = $PSScriptRoot
$Template = Join-Path $Src 'AGENTS.template.md'

function Say($m) { Write-Host $m }

Say "== dsh-agent-memory installer =="
Say "DSH_HOME    : $DshHome"
Say "project root: $(if ($ProjectRoot) { $ProjectRoot } else { '(not given - global level only)' })"
Say "mode        : $(if ($Apply) { 'APPLY (will write)' } else { 'dry-run' })"
Say ""

if (-not (Test-Path -LiteralPath $Template)) { throw "template not found: $Template" }

$targets = @()
$targets += @{ path = (Join-Path $DshHome 'AGENTS.md'); label = 'user-level memory' }
if ($ProjectRoot) {
    if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw "project root not found: $ProjectRoot"
    }
    $targets += @{ path = (Join-Path $ProjectRoot 'AGENTS.md'); label = 'project-level memory' }
    $targets += @{ path = (Join-Path $ProjectRoot 'memory');   label = 'project memory log dir'; dir = $true }
}

$blocked = $false
foreach ($t in $targets) {
    $exists = Test-Path -LiteralPath $t.path
    if ($t.dir) {
        Say ("  [dir ] {0,-22} {1}" -f $t.label, $t.path)
        if ($Apply -and -not $exists) { New-Item -ItemType Directory -Force -Path $t.path | Out-Null }
        continue
    }
    Say ("  [file] {0,-22} {1}" -f $t.label, $t.path)
    if ($exists -and -not $Force) {
        Say "         EXISTS -> will NOT overwrite (this is your accumulated memory)."
        Say "         Use -Force to back it up and replace, or skip this target."
        $blocked = $true
    } elseif ($exists -and $Force) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        Say "         exists -> backup to $($t.path).bak_$stamp"
        if ($Apply) { Copy-Item -LiteralPath $t.path -Destination "$($t.path).bak_$stamp" -Force }
    }
}

if ($blocked) {
    Say ""
    Say "Stopped: at least one AGENTS.md already exists. Nothing written."
    Say "Re-run with -Force if you really want to replace it (a timestamped backup is kept)."
    exit 1
}

if ($Apply) {
    foreach ($t in $targets) {
        if ($t.dir) { continue }
        Copy-Item -LiteralPath $Template -Destination $t.path -Force
        Say "  wrote $($t.path)"
    }
    Say ""
    Say "Next: open each AGENTS.md and replace every <angle-bracket> placeholder with your own values,"
    Say "      then delete the example entries (they only show the format)."
} else {
    Say ""
    Say "[dry-run] nothing written. Re-run with -Apply."
}
