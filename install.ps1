# Claude Code Vietnamese IME Fix - Windows Installer
# https://github.com/vunguyen-ai/claudecode-typing-vi

$ErrorActionPreference = "Stop"

function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

$RepoUrl = "https://raw.githubusercontent.com/vunguyen-ai/claudecode-typing-vi/main"
$TargetDir = "$env:USERPROFILE\.claude\scripts"

Write-Host ""
Write-Host "+==============================================+" -ForegroundColor Cyan
Write-Host "|  Claude Code Vietnamese IME Fix              |" -ForegroundColor Cyan
Write-Host "|  Ban va bo go tieng Viet                     |" -ForegroundColor Cyan
Write-Host "+==============================================+" -ForegroundColor Cyan
Write-Host ""

# Check Python
try {
    $null = python --version 2>&1
    Write-Success "Python found"
} catch {
    Write-Err "Python is required but not installed"
    Write-Host "    Download from: https://python.org/downloads"
    exit 1
}

# Check Claude Code
try {
    $claudeVersion = claude --version 2>&1 | Select-Object -First 1
    Write-Success "Claude Code found: $claudeVersion"
} catch {
    Write-Err "Claude Code not found"
    Write-Host "    Install with: npm install -g @anthropic-ai/claude-code"
    exit 1
}

# Create target directory
if (!(Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}
Write-Info "Target: $TargetDir"

# Determine script source
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LocalScripts = Join-Path $ScriptDir "scripts\vi-patch.ps1"

if (Test-Path $LocalScripts) {
    Write-Info "Installing from local repo..."
    Copy-Item "$ScriptDir\scripts\vi-patch.ps1" $TargetDir -Force
    Copy-Item "$ScriptDir\scripts\vi_patch_core.py" $TargetDir -Force
    Copy-Item "$ScriptDir\scripts\vi_patch_block_handler.py" $TargetDir -Force
    Copy-Item "$ScriptDir\scripts\vi-patch-update.ps1" $TargetDir -Force
} else {
    Write-Info "Downloading scripts from GitHub..."
    Invoke-WebRequest "$RepoUrl/scripts/vi-patch.ps1" -OutFile "$TargetDir\vi-patch.ps1"
    Invoke-WebRequest "$RepoUrl/scripts/vi_patch_core.py" -OutFile "$TargetDir\vi_patch_core.py"
    Invoke-WebRequest "$RepoUrl/scripts/vi_patch_block_handler.py" -OutFile "$TargetDir\vi_patch_block_handler.py"
    Invoke-WebRequest "$RepoUrl/scripts/vi-patch-update.ps1" -OutFile "$TargetDir\vi-patch-update.ps1"
}
Write-Success "Scripts installed"

# Add to PowerShell profile
$ProfilePath = $PROFILE.CurrentUserAllHosts
$ProfileDir = Split-Path -Parent $ProfilePath

if (!(Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

if (!(Test-Path $ProfilePath)) {
    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
}

$AliasBlock = @"

# Vietnamese IME fix for Claude Code
function claude-vi-patch { & `"$TargetDir\vi-patch.ps1`" @args }
function claude-update { & `"$TargetDir\vi-patch-update.ps1`" @args }
"@

$ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($ProfileContent -notmatch "claude-vi-patch") {
    Add-Content -Path $ProfilePath -Value $AliasBlock
    Write-Success "Functions added to PowerShell profile"
} else {
    Write-Info "Functions already exist in profile"
}

# Apply patch
Write-Host ""
Write-Info "Applying patch..."
& "$TargetDir\vi-patch.ps1" patch

Write-Host ""
Write-Host "+================================================================+" -ForegroundColor Green
Write-Host "|  CAI DAT THANH CONG!                                           |" -ForegroundColor Green
Write-Host "+================================================================+" -ForegroundColor Green
Write-Host "|                                                                |" -ForegroundColor Yellow
Write-Host "|  QUAN TRONG: Thoat va khoi dong lai Claude Code                |" -ForegroundColor Yellow
Write-Host "|  de ban va co hieu luc!                                        |" -ForegroundColor Yellow
Write-Host "|                                                                |" -ForegroundColor Yellow
Write-Host "|  Nhan Ctrl+C de thoat phien hien tai, sau do chay: claude      |" -ForegroundColor Yellow
Write-Host "|                                                                |" -ForegroundColor Yellow
Write-Host "+================================================================+" -ForegroundColor Green
Write-Host ""
Write-Host "Lenh kha dung (sau khi restart PowerShell):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  claude-vi-patch        Ap dung ban va" -ForegroundColor White
Write-Host "  claude-vi-patch status Kiem tra trang thai" -ForegroundColor White
Write-Host "  claude-update          Cap nhat Claude + tu dong va" -ForegroundColor White
Write-Host ""
