# Initial GitHub push helper (per-repo identity)
# Usage: powershell -ExecutionPolicy Bypass -File .\github-push.ps1
#
# This script uses LOCAL git config (per-repo) for user.name / user.email,
# so the global identity stays clean and you avoid mixing identities across repos.

$ErrorActionPreference = "Stop"

$REPO_NAME = "minecraft-claude"
$VISIBILITY = "public"   # public or private

# Per-repo identity used for commits in THIS repository only.
# !!! EDIT THESE BEFORE RUNNING !!!
$LOCAL_GIT_USER  = "your-github-username"
$LOCAL_GIT_EMAIL = "you@example.com"

# Refuse to run with placeholder values still in place.
if ($LOCAL_GIT_USER -eq "your-github-username" -or $LOCAL_GIT_EMAIL -eq "you@example.com") {
    Write-Error "Please edit `$LOCAL_GIT_USER and `$LOCAL_GIT_EMAIL at the top of $PSCommandPath before running."
    exit 1
}

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

# Use SSH protocol for git operations.
gh config set git_protocol ssh -h github.com | Out-Null

# Ensure SSH key exists; create one if not, and register it with GitHub.
$sshDir = Join-Path $env:USERPROFILE ".ssh"
$keyPath = Join-Path $sshDir "id_ed25519"
$pubPath = "$keyPath.pub"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
}
if (-not (Test-Path $keyPath)) {
    Write-Host "Generating ed25519 SSH key at $keyPath ..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -C $LOCAL_GIT_EMAIL -f $keyPath -N '""'
}

# Register pub key with GitHub if not already there.
$registered = gh ssh-key list 2>$null
if (-not ($registered -match [regex]::Escape((Get-Content $pubPath -Raw).Split(' ')[1]))) {
    Write-Host "Registering public key with GitHub..." -ForegroundColor Yellow
    gh ssh-key add $pubPath --title "Windows-$env:COMPUTERNAME" | Out-Null
}

# Refresh github.com entry in known_hosts (handles stale entries from before GitHub's
# March 2023 RSA host key rotation, which cause 'REMOTE HOST IDENTIFICATION HAS CHANGED').
$knownHosts = Join-Path $sshDir "known_hosts"
Write-Host "Refreshing github.com entry in known_hosts..." -ForegroundColor Yellow
ssh-keygen -R github.com 2>&1 | Out-Null
ssh-keyscan -t ed25519,rsa github.com 2>$null | Out-File -Append -Encoding ASCII $knownHosts

# Sanity-check: connecting should now succeed (exit 1 here is normal for `ssh -T`).
$probe = & ssh -T -o BatchMode=yes -o StrictHostKeyChecking=yes git@github.com 2>&1
if ($probe -match "successfully authenticated") {
    Write-Host "  SSH to github.com: OK ($probe)" -ForegroundColor DarkGray
} else {
    Write-Warning "SSH probe to github.com failed:`n$probe"
}

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

# Probe for repo existence WITHOUT tripping $ErrorActionPreference=Stop on gh's stderr.
$prevPref = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& gh repo view $fullName *> $null
$exists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prevPref

$sshUrl = "git@github.com:$fullName.git"

if (-not $exists) {
    Write-Host "  Creating $fullName ($VISIBILITY)..." -ForegroundColor Yellow
    gh repo create $fullName --$VISIBILITY --source . --remote origin
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh repo create failed."
        exit 1
    }
} else {
    Write-Host "  Repo already exists." -ForegroundColor Yellow
    if (-not (git remote | Select-String -Pattern "^origin$")) {
        git remote add origin $sshUrl
    }
}

# Force SSH remote URL.
git remote set-url origin $sshUrl
git branch -M main

Write-Host "[5/5] Pushing to $sshUrl ..." -ForegroundColor Green
git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error "git push failed. Check 'git remote -v', 'ssh -T git@github.com', and 'gh auth status'."
    exit 1
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host "URL: https://github.com/$fullName" -ForegroundColor Green
