# Claude Code (CLI) Windows install
# Usage: powershell -ExecutionPolicy Bypass -File .\install-claude-code.ps1
#
# Native Windows install via npm global.
# 既存の setup.ps1（MCP サーバ側）とは独立。Claude Code 自体は1台に1回入れれば
# どのプロジェクトからでも `claude` で起動できるので、setup.ps1 と分離している。

$ErrorActionPreference = "Stop"

Write-Host "=== Claude Code (CLI) install ===" -ForegroundColor Cyan

function Assert-Command($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "$name not found. $hint"
        exit 1
    }
}

# Node.js / npm の存在確認（setup.ps1 と同様の運用）
Assert-Command "node" "Install Node.js LTS from https://nodejs.org/  または  winget install OpenJS.NodeJS.LTS"
Assert-Command "npm"  "Bundled with Node.js. Reinstall Node.js."

$nodeVersion = (node --version) -replace "v", ""
$nodeMajor = [int]($nodeVersion.Split(".")[0])
if ($nodeMajor -lt 18) {
    Write-Error "Node.js $nodeVersion detected. Claude Code requires Node.js 18 or higher."
    exit 1
}
Write-Host "[1/3] Node.js $nodeVersion / npm $(npm --version)" -ForegroundColor Green

# 既存の Claude Code を検出（再インストールでも上書きされるが情報表示）
$existing = Get-Command claude -ErrorAction SilentlyContinue
if ($existing) {
    try {
        $current = & claude --version 2>$null
        Write-Host "  Existing claude detected: $current ($($existing.Source))" -ForegroundColor Yellow
    } catch {
        Write-Host "  Existing claude detected at: $($existing.Source)" -ForegroundColor Yellow
    }
}

Write-Host "[2/3] Running npm install -g @anthropic-ai/claude-code ..." -ForegroundColor Green
npm install -g "@anthropic-ai/claude-code"
if ($LASTEXITCODE -ne 0) {
    Write-Error "npm install failed (exit $LASTEXITCODE). 権限エラーなら管理者 PowerShell で再実行するか、npm prefix を確認してください。"
    exit 1
}

# PATH 反映チェック。新しい PowerShell ウィンドウで通ることが多い。
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeCmd) {
    Write-Warning "claude が現在のセッションの PATH から見えません。新しい PowerShell ウィンドウを開き直してから 'claude --version' を試してください。"
} else {
    $version = & claude --version 2>$null
    Write-Host "[3/3] Installed: $version" -ForegroundColor Green
    Write-Host "  Path: $($claudeCmd.Source)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=== Install complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. このフォルダで 'claude' を起動:"
Write-Host "     cd $PSScriptRoot"
Write-Host "     claude"
Write-Host "2. 初回はブラウザ認証が走ります (Anthropic アカウント or API キー)"
Write-Host "3. 起動後、.mcp.json の minecraft-bedrock サーバを承認するか聞かれるので 'Yes' で許可"
Write-Host "4. CLAUDE.md は自動で読み込まれ、Minecraft 行動原則が適用されます"
Write-Host ""
Write-Host "重要: Claude Desktop の Minecraft プロジェクトと **同時起動しない** こと。" -ForegroundColor Yellow
Write-Host "      両方が run-server.cmd を spawn するとポート 8001 が衝突して後発が落ちます。"
