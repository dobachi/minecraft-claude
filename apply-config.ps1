# Generate a resolved Claude Desktop config from the example, replacing
# <PROJECT_DIR> with this directory's full path (with proper JSON escaping).
#
# Default action: write to ./claude_desktop_config.resolved.json AND copy to clipboard.
# With -Apply: also write directly into %APPDATA%\Claude\claude_desktop_config.json
#              (backed up to .bak first). Merging with existing content is NOT done;
#              use -Apply only when starting from an empty/uninstalled config.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\apply-config.ps1
#   powershell -ExecutionPolicy Bypass -File .\apply-config.ps1 -Apply

param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

$exampleFile  = Join-Path $PSScriptRoot "claude_desktop_config.example.json"
$resolvedFile = Join-Path $PSScriptRoot "claude_desktop_config.resolved.json"
$claudeFile   = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"

if (-not (Test-Path $exampleFile)) {
    Write-Error "Example file not found: $exampleFile"
    exit 1
}

# Build resolved JSON
$dir = $PSScriptRoot.Replace('\', '\\')
$raw = Get-Content -Encoding UTF8 -Raw $exampleFile
$resolved = $raw.Replace('<PROJECT_DIR>', $dir)

# Validate
try {
    $resolved | ConvertFrom-Json | Out-Null
} catch {
    Write-Error "Generated JSON is invalid: $_"
    exit 1
}
Write-Host "JSON OK" -ForegroundColor Green

# Write resolved file (UTF-8 without BOM)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($resolvedFile, $resolved, $utf8NoBom)
Write-Host "Wrote: $resolvedFile" -ForegroundColor Green

# Copy to clipboard
$resolved | Set-Clipboard
Write-Host "Copied to clipboard." -ForegroundColor Green

if ($Apply) {
    if (Test-Path $claudeFile) {
        Copy-Item $claudeFile "$claudeFile.bak" -Force
        Write-Host "Backed up existing config: $claudeFile.bak" -ForegroundColor Yellow
        Write-Warning "Existing claude_desktop_config.json will be OVERWRITTEN. Existing MCP entries are NOT merged."
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $claudeFile) | Out-Null
    }
    [System.IO.File]::WriteAllText($claudeFile, $resolved, $utf8NoBom)
    Write-Host "Applied to: $claudeFile" -ForegroundColor Cyan
    Write-Host "Restart Claude Desktop (including the tray icon) to take effect." -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "Next:"
    Write-Host "  - To paste into existing config: notepad `"$claudeFile`"  then Ctrl+V the relevant part"
    Write-Host "  - To overwrite directly:        re-run with -Apply (creates .bak first)"
}
