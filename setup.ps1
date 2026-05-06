# Minecraft Bedrock MCP Server setup
# Usage: powershell -ExecutionPolicy Bypass -File .\setup.ps1

$ErrorActionPreference = "Stop"

$ROOT = $PSScriptRoot
$REPO_DIR = Join-Path $ROOT "server"
$REPO_URL = "https://github.com/Mming-Lab/minecraft-bedrock-mcp-server.git"

Write-Host "=== Minecraft Bedrock MCP Server setup ===" -ForegroundColor Cyan

function Assert-Command($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "$name not found. $hint"
        exit 1
    }
}

Assert-Command "git"  "Install from https://git-scm.com/download/win or run: winget install Git.Git"
Assert-Command "node" "Install Node.js LTS from https://nodejs.org/"
Assert-Command "npm"  "Bundled with Node.js. Reinstall Node.js."

$nodeVersion = (node --version) -replace "v", ""
$nodeMajor = [int]($nodeVersion.Split(".")[0])
if ($nodeMajor -lt 18) {
    Write-Warning "Node.js $nodeVersion detected. 18 or higher recommended."
}

if (Test-Path $REPO_DIR) {
    Write-Host "[1/3] Updating existing repo..." -ForegroundColor Green
    Push-Location $REPO_DIR
    git pull --ff-only
    Pop-Location
} else {
    Write-Host "[1/3] Cloning repo..." -ForegroundColor Green
    git clone $REPO_URL $REPO_DIR
}

Push-Location $REPO_DIR

Write-Host "[2/3] Running npm install..." -ForegroundColor Green
npm install

Write-Host "[3/3] Running npm run build..." -ForegroundColor Green
npm run build

Pop-Location

$serverJs = Join-Path $REPO_DIR "dist\server.js"
if (-not (Test-Path $serverJs)) {
    Write-Error "Build did not produce $serverJs. Check the output above."
    exit 1
}

Write-Host ""
Write-Host "=== Setup complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Open %APPDATA%\Claude\claude_desktop_config.json"
Write-Host "2. Merge claude_desktop_config.example.json into mcpServers"
Write-Host "3. Restart Claude Desktop"
Write-Host "4. Launch Minecraft Bedrock and create a world with cheats ON"
Write-Host "5. In chat, run: /connect localhost:8001/ws"
Write-Host ""
Write-Host "MCP server entry point:" -ForegroundColor Yellow
Write-Host ("  node " + '"' + $serverJs + '"')
