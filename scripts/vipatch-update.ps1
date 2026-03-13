# Wrapper script: Updates Claude Code and auto-patches Vietnamese IME (Windows)
# Usage: claude-update

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find patch script
$PatchScript = Join-Path $ScriptDir "vipatch.ps1"
if (!(Test-Path $PatchScript)) {
    $PatchScript = "$env:USERPROFILE\.claude\scripts\vipatch.ps1"
}

if (!(Test-Path $PatchScript)) {
    Write-Host "Error: vipatch.ps1 not found" -ForegroundColor Red
    exit 1
}

Write-Host "Updating Claude Code..." -ForegroundColor Blue
npm update -g @anthropic-ai/claude-code

Write-Host ""
Write-Host "Applying Vietnamese IME patch..." -ForegroundColor Blue
& $PatchScript patch

Write-Host ""
Write-Host "Done! Claude Code updated and patched." -ForegroundColor Green
