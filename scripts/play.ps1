# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         even more conservative (the first thing to try when something is wrong): the newer
#               fast paths are already off by default (see below); this also drops the wide/echo paths
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Build        target\diag (the default, the build all measurements are of) or target\release
# -More         other settings: -More @{VICTORY_PANEL='1'}
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [ValidateSet('diag', 'release')][string]$Build = 'diag',
    # Resolution the layer announces to the title. Default 1080p: the title renders internally at
    # this size, so on an 8 GB NVIDIA card this is the single biggest lever for VRAM and fps, and it
    # removes the 4K-in-a-1080p-window blur (dxgi.rs, issues #3/#15). Try 1280x720 to lower it further.
    [string]$Display = '1920x1080',
    [hashtable]$More = @{}
)
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'; VICTORY_SKIP_PIPELINES = 'none'
    # Safe renderer-port defaults, aligned with upstream Play-VIctory.cmd (commit dacddbf, issues #9/#15):
    # the newer fast paths and 32-bit heap ports are OFF by default, because on 8 GB NVIDIA cards they can
    # drop road surfaces (PORT_CBV) and remove the host GPU device mid-frame ("device removed", THIN path).
    # Keep the pipeline library warm and never stall a draw 500 ms on a pipeline that is still compiling.
    VICTORY_THIN = '0'; VICTORY_JOIN_PARTS = '0'; VICTORY_UPLOAD_AHEAD = '1'
    VICTORY_PORT_CONSTANTS = '0'; VICTORY_PORT_CBV = '0'
    VICTORY_LIBRARY_STORE_LATER = '1'; VICTORY_PIPELINE_WAIT_MS = '0'
    # Renderer port #6: a reader/writer lock for the write-guards instead of one lock shared by every
    # fault and refresh. Measured on this 8 GB NVIDIA card: the guard-lock wait dropped from ~411 ms
    # to ~5 ms a frame, the heap-view pass from ~96 ms to ~5 ms, the copy-back ("landing") from
    # ~1021 ms to ~62 ms, and the card went from ~15% to ~98% busy (GPU-bound at last). watch.rs.
    VICTORY_PORT_GUARD = '1'
}
$settings.VICTORY_DISPLAY_MODE = $Display
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
}
# Opt back into a fast path for A/B testing with, e.g., -More @{VICTORY_THIN='1'}; lower the render
# resolution with -Display 1280x720; turn a default off with -More @{VICTORY_PORT_GUARD='0'}.
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; return }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; return }
# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$Exe = (Resolve-Path $Exe).Path
Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
try { & $victory run $Exe --execute } finally { Pop-Location }
