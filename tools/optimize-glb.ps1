<#
.SYNOPSIS
    Optimize a .glb 3D model for the web (meshopt + WebP), the same pipeline
    used to shrink the Dodger Stadium and Petco Park models.

.DESCRIPTION
    Wraps the glTF-Transform "optimize" command with safe, web-friendly defaults:
      - meshopt geometry compression
      - WebP texture compression
      - texture downscaling (default 2048px)
      - simplification OFF by default (preserves seats/detail and UV-mapped textures)

    Typical results: 70-90% smaller files with no visible quality loss.

.PARAMETER InputPath
    Path to the .glb file to optimize. If omitted, you'll be prompted (so you
    can also drag a file onto optimize-glb.bat).

.PARAMETER OutputPath
    Where to write the optimized file. Defaults to "<name>-optimized.glb" next
    to the input.

.PARAMETER TextureSize
    Maximum texture dimension in pixels. Default 2048. Use 1024 for smaller files.

.PARAMETER Simplify
    Also simplify (reduce) mesh geometry. Off by default. Only use this for very
    heavy models where you accept some detail loss — it can damage fine geometry.

.PARAMETER SimplifyError
    Simplification tolerance when -Simplify is set (fraction of model size).
    Default 0.001 (gentle).

.EXAMPLE
    .\optimize-glb.ps1 -InputPath "C:\Downloads\Stadium_XYZ.glb"

.EXAMPLE
    .\optimize-glb.ps1 -InputPath model.glb -TextureSize 1024 -Simplify
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath,

    [int]$TextureSize = 2048,

    [switch]$Simplify,

    [double]$SimplifyError = 0.001
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  $msg" -ForegroundColor Green }
function Write-Err([string]$msg)  { Write-Host "  $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "GLB Optimizer (meshopt + WebP)" -ForegroundColor White
Write-Host "==============================" -ForegroundColor DarkGray

# 1. Ensure the glTF-Transform CLI is available -----------------------------
if (-not (Get-Command gltf-transform -ErrorAction SilentlyContinue)) {
    Write-Err "The 'gltf-transform' CLI is not installed."
    Write-Host ""
    Write-Host "  Install it once with:" -ForegroundColor Yellow
    Write-Host "    npm install -g @gltf-transform/cli" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# 2. Resolve / prompt for the input -----------------------------------------
if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Read-Host "Drag your .glb here (or paste its full path) and press Enter"
}
# Strip surrounding quotes that Explorer / drag-drop may add
$InputPath = $InputPath.Trim().Trim('"')

if (-not (Test-Path -LiteralPath $InputPath)) {
    Write-Err "File not found: $InputPath"
    exit 1
}
$inItem = Get-Item -LiteralPath $InputPath
if ($inItem.Extension -ne '.glb') {
    Write-Err "Not a .glb file: $($inItem.Name)"
    exit 1
}

# 3. Decide the output path -------------------------------------------------
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $inItem.DirectoryName ($inItem.BaseName + '-optimized.glb')
}
$OutputPath = $OutputPath.Trim().Trim('"')
if ((Resolve-Path -LiteralPath $inItem.FullName).Path -eq
    ([System.IO.Path]::GetFullPath($OutputPath))) {
    Write-Err "Output would overwrite the input. Choose a different -OutputPath."
    exit 1
}

# 4. Build the optimize arguments -------------------------------------------
$arguments = @(
    'optimize',
    $inItem.FullName,
    $OutputPath,
    '--compress', 'meshopt',
    '--texture-compress', 'webp',
    '--texture-size', "$TextureSize"
)
if ($Simplify) {
    $arguments += @('--simplify-error', "$SimplifyError")
} else {
    $arguments += @('--simplify', 'false')
}

$inMB = [math]::Round($inItem.Length / 1MB, 2)
Write-Step "Input:     $($inItem.Name)  ($inMB MB)"
Write-Step "Output:    $([System.IO.Path]::GetFileName($OutputPath))"
Write-Step "Textures:  WebP, max ${TextureSize}px"
Write-Step "Simplify:  $([bool]$Simplify)"
Write-Host ""
Write-Step "Optimizing... (large models can take a few minutes)"

# 5. Run it (bump Node's memory for very large inputs) ----------------------
$env:NODE_OPTIONS = '--max-old-space-size=8192'
& gltf-transform @arguments
$code = $LASTEXITCODE

if ($code -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
    Write-Host ""
    Write-Err "Optimization failed (exit code $code)."
    exit 1
}

# 6. Report results ---------------------------------------------------------
$outItem = Get-Item -LiteralPath $OutputPath
$outMB = [math]::Round($outItem.Length / 1MB, 2)
$saved = if ($inItem.Length -gt 0) {
    [math]::Round((1 - $outItem.Length / $inItem.Length) * 100, 1)
} else { 0 }

Write-Host ""
Write-Ok "Done!  $inMB MB  ->  $outMB MB   ($saved% smaller)"
Write-Host "  Saved to: $($outItem.FullName)" -ForegroundColor Green
Write-Host ""
