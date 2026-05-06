# Enable /connect from Minecraft Bedrock (UWP) to localhost
# by adding a loopback exemption for the Minecraft package(s).
#
# Why this is needed:
#   Minecraft for Windows is a UWP app. UWP apps are blocked from connecting to
#   loopback (localhost) by default for security. Without this exemption, the
#   /connect WebSocket command silently fails.
#
# Usage (must be elevated):
#   powershell -ExecutionPolicy Bypass -File .\enable-connect.ps1
#
# Optional flags:
#   -List        List current loopback exemptions and exit.
#   -Remove      Remove exemptions added for Minecraft packages.

param(
    [switch]$List,
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

# Known Minecraft UWP package family names
$packages = @(
    "Microsoft.MinecraftUWP_8wekyb3d8bbwe",                # Retail Bedrock
    "Microsoft.MinecraftWindowsBeta_8wekyb3d8bbwe",        # Preview / Beta
    "Microsoft.MinecraftEducationEdition_8wekyb3d8bbwe"    # Education Edition
)

function Test-IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($List) {
    Write-Host "Current loopback exemptions:" -ForegroundColor Cyan
    CheckNetIsolation LoopbackExempt -s
    return
}

if (-not (Test-IsAdmin)) {
    Write-Error "This script needs to run as Administrator. Right-click PowerShell -> Run as Administrator, then re-run."
    exit 1
}

foreach ($pkg in $packages) {
    if ($Remove) {
        Write-Host "Removing loopback exemption for $pkg ..." -ForegroundColor Yellow
        CheckNetIsolation LoopbackExempt -d -n="$pkg" 2>&1 | Out-Null
    } else {
        Write-Host "Adding loopback exemption for $pkg ..." -ForegroundColor Green
        CheckNetIsolation LoopbackExempt -a -n="$pkg" 2>&1 | Out-Null
    }
}

Write-Host ""
Write-Host "Done. Current exemptions:" -ForegroundColor Cyan
CheckNetIsolation LoopbackExempt -s | Select-String -Pattern "Minecraft" -Context 0,1
Write-Host ""
Write-Host "Restart Minecraft if it was already running, then try:" -ForegroundColor Yellow
Write-Host "  /connect localhost:8001/ws" -ForegroundColor Yellow
