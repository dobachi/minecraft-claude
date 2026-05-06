# Initial GitHub push helper (per-repo identity)
# Usage: powershell -ExecutionPolicy Bypass -File .\github-push.ps1
#
# This script uses LOCAL git config (per-repo) for user.name / user.email,
# so the global identity stays clean and you avoid mixing identities across repos.

$ErrorActionPreference = "Stop"

$REPO_NAME = "minecraft-claude"
$VISIBILITY = "public"   # public or private

# Per-repo identity used for commits in THIS repository only.
$LOCAL_GIT_USER  = "dobachi"
$LOCAL_GIT_EMAIL = "dobachi1983oss@gmail.com"

Write-Host "=== GitHub initial push ===" -ForegroundColor Cyan

function Assert-Command($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "$name not found. $hint"
        exit 1
    }
}

Assert-Command "git" "winget install Git.Git"
Assert-Command "gh"  "winget install GitHub.cli (then reopen PowerShell)"

# gh auth (do this before git init so we can fail fast if not logged in)
gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "gh is not logged in. Running 'gh auth login'..." -ForegroundColor Yellow
    Write-Host "Choose: GitHub.com -> HTTPS -> Yes (auth git) -> Login with a web browser" -ForegroundColor Yellow
    gh auth login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh auth login failed."
        exit 1
    }
}
Write-Host "gh auth: OK" -ForegroundColor Green

# git init if needed
if (-not (Test-Path ".git")) {
    Write-Host "[1/5] git init" -ForegroundColor Green
    git init -b main | Out-Null
} else {
    Write-Host "[1/5] git already initialized" -ForegroundColor Green
}

# Set LOCAL identity (this repo only)
Write-Host "[2/5] Setting per-repo git identity..." -ForegroundColor Green
git config --local user.name  $LOCAL_GIT_USER
git config --local user.email $LOCAL_GIT_EMAIL
$localUser  = git config --local user.name
$localEmail = git config --local user.email
Write-Host "  local identity: $localUser <$localEmail>" -ForegroundColor DarkGray

# Safety: refuse to run if global identity is set (user explicitly asked to avoid global config).
$globalUser  = git config --global user.name  2>$null
$globalEmail = git config --global user.email 2>$null
if ($globalUser -or $globalEmail) {
    Write-Warning "Global git identity is set ($globalUser <$globalEmail>)."
    Write-Warning "You asked to avoid global config. Consider running:"
    Write-Warning "  git config --global --unset user.name"
    Write-Warning "  git config --global --unset user.email"
    Write-Warning "Continuing anyway (local config takes precedence in this repo)."
}

Write-Host "[3/5] git add + commit" -ForegroundColor Green
git add -A
$pending = git status --porcelain
if ($pending) {
    git commit -m "Initial commit: Claude x Minecraft Bedrock setup"
} else {
    Write-Host "  Nothing to commit." -ForegroundColor DarkGray
}

# Create remote repo if missing
$ghUser = (gh api user --jq .login).Trim()
$fullName = "$ghUser/$REPO_NAME"
Write-Host "[4/5] Ensuring remote repo $fullName exists..." -ForegroundColor Green
$exists = $false
gh repo view $fullName 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $exists = $true }

if (-not $exists) {
    Write-Host "  Creating $fullName ($VISIBILITY)..." -ForegroundColor Yellow
    gh repo create $fullName --$VISIBILITY --source . --remote origin --push
} else {
    Write-Host "  Repo already exists. Pushing..." -ForegroundColor Yellow
    if (-not (git remote | Select-String -Pattern "^origin$")) {
        git remote add origin "https://github.com/$fullName.git"
    }
    git branch -M main
    git push -u origin main
}

Write-Host ""
Write-Host "[5/5] Done." -ForegroundColor Cyan
Write-Host "URL: https://github.com/$fullName" -ForegroundColor Green
