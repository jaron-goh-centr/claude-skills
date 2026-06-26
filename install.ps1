# install.ps1 — Install Jaron's Claude Code skills on Windows
# Usage: irm https://raw.githubusercontent.com/jarongoh/claude-skills/main/install.ps1 | iex
# Or:    git clone https://github.com/jarongoh/claude-skills && cd claude-skills && .\install.ps1

param(
    [switch]$Force,    # overwrite existing skills without prompting
    [switch]$DryRun    # show what would be copied, don't actually copy
)

$ErrorActionPreference = "Stop"
$SkillsTarget = Join-Path $env:USERPROFILE ".claude\skills"
$ScriptDir = $PSScriptRoot

if (-not $ScriptDir) {
    # Running via irm | iex — clone to temp
    $TempDir = Join-Path $env:TEMP "claude-skills-install"
    if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
    git clone https://github.com/jarongoh/claude-skills $TempDir
    $ScriptDir = $TempDir
}

Write-Host "Source : $ScriptDir"
Write-Host "Target : $SkillsTarget"

if (-not (Test-Path $SkillsTarget)) {
    New-Item -ItemType Directory -Path $SkillsTarget -Force | Out-Null
    Write-Host "Created $SkillsTarget"
}

$skills = Get-ChildItem $ScriptDir -Directory | Where-Object { $_.Name -notmatch '^\.' }
$installed = 0
$skipped = 0

foreach ($skill in $skills) {
    $dest = Join-Path $SkillsTarget $skill.Name
    $exists = Test-Path $dest

    if ($exists -and -not $Force) {
        Write-Host "  skip  $($skill.Name) (already exists — use -Force to overwrite)"
        $skipped++
        continue
    }

    if ($DryRun) {
        Write-Host "  dry   $($skill.Name)"
        $installed++
        continue
    }

    if ($exists) { Remove-Item $dest -Recurse -Force }
    Copy-Item $skill.FullName $dest -Recurse
    Write-Host "  +     $($skill.Name)"
    $installed++
}

Write-Host ""
Write-Host "Done. $installed installed, $skipped skipped."
Write-Host "Restart Claude Code to pick up new skills."
