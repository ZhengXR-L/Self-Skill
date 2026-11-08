<#
.SYNOPSIS
    Install SGLang skills into the global Trae skills directory.

.DESCRIPTION
    Scans .\skills for folders containing SKILL.md and copies (or junctions)
    them into the destination. Windows 11 / PowerShell 5.1+.
    Requires no administrator rights in either mode.

.PARAMETER Dest
    Install directory. Default: %USERPROFILE%\.trae-cn\skills

.PARAMETER Link
    Create a directory junction instead of copying. Repo edits take effect
    immediately and nothing is duplicated.

.PARAMETER Force
    Replace an already installed skill with the same folder name.

.PARAMETER DryRun
    Print what would happen without writing anything.

.PARAMETER List
    Only list installable skills.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Link -Force
#>
[CmdletBinding()]
param(
    [string]$Dest = (Join-Path $env:USERPROFILE ".trae-cn\skills"),
    [switch]$Link,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$List
)

$ErrorActionPreference = "Stop"

$RepoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Join-Path $RepoRoot "skills"

if (-not (Test-Path -LiteralPath $SkillRoot)) {
    throw "skills directory not found: $SkillRoot"
}

$skills = @(Get-ChildItem -LiteralPath $SkillRoot -Directory | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md")
} | Sort-Object Name)

if ($skills.Count -eq 0) {
    throw "no skill found under $SkillRoot"
}

function Get-SkillName {
    param([string]$SkillFile)
    $match = Select-String -LiteralPath $SkillFile -Pattern '^name:\s*(\S+)\s*$' | Select-Object -First 1
    if ($null -eq $match) { return $null }
    return $match.Matches[0].Groups[1].Value.Trim()
}

function Test-IsReparsePoint {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    return [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

if ($List) {
    "{0,-30} {1}" -f "FOLDER", "NAME"
    foreach ($s in $skills) {
        "{0,-30} {1}" -f $s.Name, (Get-SkillName (Join-Path $s.FullName "SKILL.md"))
    }
    return
}

$mode = if ($Link) { "junction" } else { "copy" }
Write-Host "Source : $SkillRoot"
Write-Host "Dest   : $Dest"
Write-Host "Mode   : $mode"
Write-Host ""

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
}

$installed = 0
foreach ($s in $skills) {
    $name = Get-SkillName (Join-Path $s.FullName "SKILL.md")
    if ([string]::IsNullOrWhiteSpace($name)) {
        Write-Warning "skip $($s.Name): no name field in SKILL.md"
        continue
    }
    if ($name -ne $s.Name) {
        Write-Warning "name mismatch: folder=$($s.Name) name=$name"
    }

    $target = Join-Path $Dest $s.Name

    if (Test-Path -LiteralPath $target) {
        if (-not $Force) {
            Write-Warning "exists, skip: $target (use -Force to replace)"
            continue
        }
        if ($DryRun) {
            Write-Host "[dry-run] remove $target"
        } elseif (Test-IsReparsePoint $target) {
            # Remove the junction only, never the repo folder behind it.
            [System.IO.Directory]::Delete($target, $false)
        } else {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }

    if ($DryRun) {
        Write-Host "[dry-run] install $($s.Name) -> $target"
        continue
    }

    if ($Link) {
        New-Item -ItemType Junction -Path $target -Target $s.FullName | Out-Null
    } else {
        Copy-Item -LiteralPath $s.FullName -Destination $target -Recurse -Force
    }

    Write-Host "installed: $($s.Name)"
    $installed++
}

Write-Host ""
Write-Host "Done. Installed $installed skill(s) into $Dest"
Write-Host "Restart the agent session to pick up new skills."
